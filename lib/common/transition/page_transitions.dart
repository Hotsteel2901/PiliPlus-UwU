/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:PiliPlus/common/m3e/motion.dart';
import 'package:PiliPlus/common/widgets/haze/haze_config.dart'
    show backGestureInFlight;
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Where a tapped video card lives on screen, so the detail route can morph
/// out of it and back into it.
///
/// The rect is captured when the card is tapped. [resolveBegin] re-measures the
/// card every frame while it is still alive, which keeps the landing accurate
/// even if the list scrolled underneath the playback page, and returns null
/// once the card is gone (the zoom then falls back to the captured rect).
class CardZoomOrigin {
  CardZoomOrigin({
    required this.begin,
    this.resolveBegin,
    this.cover,
    this.radius = 12,
  });

  final Rect begin;

  final Rect? Function()? resolveBegin;

  /// Cover image shown while the route is still card sized.
  final String? cover;

  /// Corner radius of the source card.
  final double radius;

  Rect? resolve() => resolveBegin?.call();
}

/// An immutable snapshot of the Android back gesture currently in flight.
///
/// `active` spans the whole gesture: the drag *and* the settle that follows a
/// release, mirroring `Navigator.userGestureInProgress`. `dragging` is true
/// only while the finger is still down.
class BackGestureSnapshot {
  const BackGestureSnapshot({
    this.active = false,
    this.dragging = false,
    this.committed = false,
    this.dx = 0,
    this.dy = 0,
    this.releaseGone = 0,
    this.epoch = 0,
    this.owner,
  });

  static const BackGestureSnapshot idle = BackGestureSnapshot();

  /// Whether a gesture is in flight (dragging or settling).
  final bool active;

  /// Whether the finger is still down.
  final bool dragging;

  /// Whether the release committed the pop (as opposed to cancelling).
  final bool committed;

  /// Signed horizontal finger travel in logical pixels: positive moves the
  /// page towards the end edge (left-edge swipe), negative towards start.
  final double dx;

  /// Eased vertical shift in logical pixels, as per the Android 16 predictive
  /// back motion spec (`height / 20 - 8` maximum, eased by travel / height).
  final double dy;

  /// The linear "gone" progress (0 = on top, 1 = dismissed) at the release.
  final double releaseGone;

  /// Bumped on every gesture start; stale remaps keyed to an older epoch are
  /// ignored, so a route can never inherit the previous gesture's mapping.
  final int epoch;

  /// The route the gesture was accepted for. Transitions of *other* routes
  /// must not apply the finger-following motion to themselves.
  final PageRoute<dynamic>? owner;

  bool get released => active && !dragging;
}

/// Process-wide state of the one Android back gesture currently in flight.
///
/// Predictive back involves two routes at once: the top one being dragged and
/// the one underneath being revealed. Both of their transitions must agree on
/// the gesture phase and — crucially — on the progress reached at the commit,
/// because the framework restarts the route controller at `1.0` before
/// reversing it when a predictive back gesture commits
/// (flutter/flutter#184653). The gesture handler that owns the gesture writes
/// here *before* touching the route, and every [ContinuousBackProgress] reads
/// from here, so the remap around the commit is deterministic instead of
/// guessed from animation ticks (which misfired on janky frames and left the
/// transition latched at a wrong progress).
abstract final class BackGestureBridge {
  static int _epoch = 0;
  static bool _committing = false;
  static double _commitGone = 0;
  static BackGestureSnapshot _gesture = BackGestureSnapshot.idle;

  static int get epoch => _epoch;

  /// True between [armCommit] and the settle finishing. A controller jump to
  /// `1.0` may only be remapped while this is set.
  static bool get committing => _committing;

  /// The linear gone progress reached when the gesture committed.
  static double get commitGone => _commitGone;

  static BackGestureSnapshot get gesture => _gesture;

  static bool get active => _gesture.active;

  static bool get dragging => _gesture.dragging;

  /// A gesture was accepted for [owner].
  static void begin(PageRoute<dynamic> owner) {
    _epoch++;
    _committing = false;
    _commitGone = 0;
    _gesture = BackGestureSnapshot(
      active: true,
      dragging: true,
      epoch: _epoch,
      owner: owner,
    );
    // Glass surfaces drop to their solid fallback while the route (and the one
    // below it) is being transformed under the finger.
    backGestureInFlight.value = true;
  }

  /// The finger moved. Ignored once the gesture has been released: Android
  /// keeps streaming events while *it* animates a cancellation back to zero,
  /// and those must not flip the gesture back into the dragging phase.
  static void drag({required double dx, required double dy}) {
    final g = _gesture;
    if (!g.active || !g.dragging) {
      return;
    }
    _gesture = BackGestureSnapshot(
      active: true,
      dragging: true,
      dx: dx,
      dy: dy,
      epoch: g.epoch,
      owner: g.owner,
    );
  }

  /// The gesture was released and will settle back to the top.
  static void cancel(double releaseGone) {
    final g = _gesture;
    if (!g.active) {
      return;
    }
    _committing = false;
    _gesture = BackGestureSnapshot(
      active: true,
      dragging: false,
      committed: false,
      dx: g.dx,
      dy: g.dy,
      releaseGone: releaseGone,
      epoch: g.epoch,
      owner: g.owner,
    );
  }

  /// The gesture committed. Must run *before* `route.handleCommitBackGesture`
  /// so the controller jump it triggers is already covered by [committing].
  static void armCommit(double releaseGone) {
    final g = _gesture;
    if (!g.active) {
      return;
    }
    _committing = true;
    _commitGone = releaseGone;
    _gesture = BackGestureSnapshot(
      active: true,
      committed: true,
      dx: g.dx,
      dy: g.dy,
      releaseGone: releaseGone,
      epoch: g.epoch,
      owner: g.owner,
    );
  }

  /// The gesture fully settled (route popped, or restored to the top).
  ///
  /// The epoch is deliberately kept: a remap armed for it stays valid for the
  /// settled value, and the *next* gesture invalidates it by bumping it.
  static void end() {
    _committing = false;
    _commitGone = 0;
    _gesture = BackGestureSnapshot.idle;
    backGestureInFlight.value = false;
  }

  /// Test hook: pretends a gesture is in flight and commits at [gone].
  @visibleForTesting
  static void debugArmCommit(double gone) {
    _epoch++;
    _committing = true;
    _commitGone = gone;
    _gesture = BackGestureSnapshot(
      active: true,
      committed: true,
      releaseGone: gone,
      epoch: _epoch,
    );
  }

  /// Test hook for [end].
  @visibleForTesting
  static void debugEnd() => end();
}

/// Material 3 Expressive, predictive back aware page transitions for the whole
/// app, plus the container transform used by video cards.
///
/// Why not the stock implementation?
///
/// * `PredictiveBackPageTransitionsBuilder` only animates the route that is
///   being dismissed. GetX routes never provide a `delegatedTransition`, so
///   the route underneath stays completely static while the top one shrinks
///   and slides away — the seam between the two routes is what feels broken.
/// * The framework restarts the route controller at `1.0` before reversing it
///   when a predictive back gesture commits (flutter/flutter#184653), so a
///   transition that naively maps `animation.value` snaps at the commit point.
///   [ContinuousBackProgress] compensates for that jump, deterministically,
///   from the state kept in [BackGestureBridge].
/// * The stock shared-element variant is AOSP's, which shrinks the page into
///   a floating card only *after* the commit. The variant implemented here
///   keeps the page glued to the finger the whole time (iOS / HyperOS style
///   float) with the Android 16 motion spec's scale, device corner radius and
///   vertical shift, animates the route below with a matching parallax, and
///   settles with Material 3 Expressive easing.
abstract final class HotPageTransitions {
  /// Installs the transition hooks into the patched GetX runtime.
  ///
  /// Must be called once, before the first route is pushed.
  static void install() {
    GetNativeTransition.builder = buildNative;
    GetNativeTransition.delegatedTransition = buildDelegated;
    GetNativeTransition.duration = durationFor;
  }

  /// The video card container transform.
  ///
  /// The Material 3 Expressive `medium4` token (400 ms): the lower bound of the
  /// spec range for full-screen container transforms.
  static const Duration cardZoomDuration = M3EDurations.medium4;

  /// The generic M3E float transition (`medium4`, like [cardZoomDuration]).
  static const Duration m3eDuration = M3EDurations.medium4;

  /// The stock fade-forwards duration the hybrid predictive-back mode must
  /// keep, so its timed push/pop matches `FadeForwardsPageTransitionsBuilder`
  /// (the `long1` token, eyeballed by Flutter against Android 16).
  static const Duration predictiveBackDuration = M3EDurations.long1;

  /// Only the app's own native page transition is ever replaced.
  static bool get _native => Pref.pageTransition == Transition.native;

  /// The generic M3E page open/close transition (opt in: it is the heaviest).
  static bool get m3eEnabled => _native && Pref.m3eTransition;

  /// The video card container transform, independent from [m3eEnabled].
  static bool get cardZoomEnabled => _native && Pref.cardZoomTransition;

  /// Whether the app drives the Android predictive back gesture itself.
  static bool get predictiveBack => _native && Pref.predictiveBack;

  static Object? _lastTapKey;
  static int _lastTapTime = 0;

  /// Guards against duplicate pushes without eating legitimate navigation.
  ///
  /// The same [key] (e.g. the video id) may not be claimed twice within
  /// 800 ms — that is a double tap on one card. Two *different* claims are
  /// only rejected within 120 ms, which is an accidental multi-touch, not a
  /// fast user. (The previous global 420 ms lock silently dropped the second
  /// of two quickly tapped cards.)
  static bool claimTap([Object? key]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final since = now - _lastTapTime;
    if (since < 120) {
      return false;
    }
    if (key != null && key == _lastTapKey && since < 800) {
      return false;
    }
    _lastTapKey = key;
    _lastTapTime = now;
    return true;
  }

  static Duration? durationFor(PageRoute<dynamic> route) {
    if (PlatformUtils.isDarwin) {
      // Apple platforms keep the Cupertino transition *and* its native timing;
      // none of the custom builders below ever run there.
      return null;
    }
    if (cardZoomEnabled && _cardZoomOf(route) != null) {
      return cardZoomDuration;
    }
    if (m3eEnabled) {
      return m3eDuration;
    }
    if (predictiveBack) {
      return predictiveBackDuration;
    }
    // Everything else keeps the stock, snappy 300ms.
    return null;
  }

  static Widget buildNative(
    PageRoute<dynamic> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The video card zoom is independent: it can be used on its own even when
    // the generic M3E transition is disabled.
    if (cardZoomEnabled) {
      final origin = _cardZoomOf(route);
      if (origin != null) {
        return _PredictiveBackGestureHandler(
          route: route,
          builder: (context) => _CardZoomTransition(
            route: route,
            animation: animation,
            origin: origin,
            child: child,
          ),
        );
      }
    }
    if (m3eEnabled) {
      return _PredictiveBackGestureHandler(
        route: route,
        builder: (context) => _M3EFloatPageTransition(
          route: route,
          animation: animation,
          child: child,
        ),
      );
    }
    if (predictiveBack) {
      // Stock push/pop, but a finger-following float while the gesture is
      // dragging the page: the platform's AOSP variant barely moves the page,
      // which is what feels sluggish and disconnected. The swap is seamless:
      // both builders render the page at identity when the route is at rest
      // on top, which is exactly where a gesture starts and ends.
      return _PredictiveBackGestureHandler(
        route: route,
        builder: (context) => BackGestureBridge.active
            ? _M3EFloatPageTransition(
                route: route,
                animation: animation,
                child: child,
              )
            : const FadeForwardsPageTransitionsBuilder().buildTransitions(
                route,
                context,
                animation,
                secondaryAnimation,
                child,
              ),
      );
    }
    // Predictive back turned off: plain M3 fade-forwards.
    return const FadeForwardsPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  /// Animates the route below an incoming transition so the two routes move as
  /// one surface. The custom paths use a matching scale, the stock path reuses
  /// the platform's fade-forwards delegation.
  static Widget? buildDelegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (child == null || !_native || PlatformUtils.isDarwin) {
      return child;
    }
    // A back gesture in flight always uses the float delegation, even in the
    // hybrid mode: the route below has to breathe with the dragged page
    // instead of sitting behind a stock fade. The swap happens while the
    // route below is still fully covered, so it is never visible.
    if (m3eEnabled ||
        cardZoomEnabled ||
        (predictiveBack && BackGestureBridge.active)) {
      return _M3EFloatSecondaryTransition(
        animation: secondaryAnimation,
        child: child,
      );
    }
    final delegated =
        const FadeForwardsPageTransitionsBuilder().delegatedTransition;
    if (delegated == null) {
      return child;
    }
    return delegated(
          context,
          animation,
          secondaryAnimation,
          allowSnapshotting,
          child,
        ) ??
        child;
  }

  static CardZoomOrigin? _cardZoomOf(PageRoute<dynamic> route) {
    final arguments = route.settings.arguments;
    if (arguments is Map) {
      final origin = arguments['cardZoom'];
      if (origin is CardZoomOrigin) {
        return origin;
      }
    }
    return null;
  }
}

/// Drives a continuous 0..1 progress from a route animation.
///
/// `0` means "fully on top" and `1` means "fully dismissed". The value is
/// derived from `1 - animation.value` except around a predictive back commit,
/// where the framework resets the controller to `1.0` before reversing it
/// (flutter/flutter#184653). The remap is armed by [BackGestureBridge] — the
/// handler that owns the gesture announces the commit *and* the exact progress
/// it happened at — so the jump is compensated deterministically. Any upward
/// movement of the animation (a push, or a new gesture) invalidates the remap,
/// and the epoch guard makes sure a remap can never leak into the next
/// gesture.
class ContinuousBackProgress extends StatefulWidget {
  const ContinuousBackProgress({
    super.key,
    required this.animation,
    required this.builder,
  });

  final Animation<double> animation;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ContinuousBackProgress> createState() => _ContinuousBackProgressState();
}

class _ContinuousBackProgressState extends State<ContinuousBackProgress> {
  double _lastValue = 1;
  double _progress = 0;
  double? _commitGone;
  int _commitEpoch = -1;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.animation.value;
    _progress = _compute(_lastValue);
    widget.animation.addListener(_onTick);
  }

  @override
  void didUpdateWidget(ContinuousBackProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_onTick);
      widget.animation.addListener(_onTick);
      _commitGone = null;
      _lastValue = widget.animation.value;
      _progress = _compute(_lastValue);
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onTick);
    super.dispose();
  }

  bool get _remapValid =>
      _commitGone != null && _commitEpoch == BackGestureBridge.epoch;

  double _compute(double value) {
    final v = value.clamp(0.0, 1.0);
    final commit = _commitGone;
    if (commit != null && _remapValid) {
      // The controller is reversing from 1.0 back to 0.0; spread the
      // remaining travel over the progress already reached at the commit.
      return (commit + (1 - commit) * (1 - v)).clamp(0.0, 1.0);
    }
    return 1 - v;
  }

  void _onTick() {
    final value = widget.animation.value.clamp(0.0, 1.0);
    final jumpedToTop = value >= 1.0 && _lastValue < 1.0;
    if (jumpedToTop &&
        BackGestureBridge.committing &&
        (!_remapValid)) {
      // The commit jump: arm the deterministic remap from the bridge, which
      // was set *before* the framework restarted the controller.
      _commitGone = BackGestureBridge.commitGone;
      _commitEpoch = BackGestureBridge.epoch;
    } else if (value > _lastValue) {
      // Moving back towards "covered" (a push, or a fresh gesture dragging
      // the value up): a remap from an earlier commit is stale.
      _commitGone = null;
    }
    _lastValue = value;
    final next = _compute(value);
    if (next != _progress) {
      setState(() => _progress = next);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}

/// Fallback display corner radius for the predictive back card, matching the
/// AOSP transition (`_kDeviceBorderRadius`) when Android does not report the
/// real display corners.
const double _kFallbackDeviceCorner = 32;

double _deviceCorner(BuildContext context) {
  final radii = MediaQuery.maybeDisplayCornerRadiiOf(context);
  final corner = radii?.topLeft.x ?? _kFallbackDeviceCorner;
  return corner.clamp(16.0, 48.0);
}

/// The default transition: the page floats up over the previous one, and on
/// the way back it follows the finger, rounds into the device-corner card of
/// the Android 16 predictive back spec and settles with M3E easing.
class _M3EFloatPageTransition extends StatelessWidget {
  const _M3EFloatPageTransition({
    required this.route,
    required this.animation,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final direction = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final corner = _deviceCorner(context);
    // The page is wrapped once so the whole route is rasterised into a single
    // layer; the transition then only re-composites it (transform + a solid
    // scrim) instead of repainting the page every frame.
    final page = RepaintBoundary(child: child);

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, progress) {
        // progress: 0 = on top, 1 = dismissed.
        final raw = progress.clamp(0.0, 1.0);
        // Only the gesture owner floats with the finger; every other route
        // keeps its own, animation-driven rendering.
        final bridge = BackGestureBridge.gesture;
        final g = identical(bridge.owner, route)
            ? bridge
            : BackGestureSnapshot.idle;

        final double t; // eased "gone" driving scale
        final double slide;
        final double lift;
        final double radius;
        final double scrim;
        if (!g.active) {
          // Timed push/pop: no transform layer at rest, M3E emphasized tokens
          // otherwise — decelerate for the page entering the screen,
          // accelerate for the page leaving it.
          if (raw <= 0.001) {
            return child;
          }
          final status = animation.status;
          final goingAway =
              status == AnimationStatus.reverse ||
              status == AnimationStatus.dismissed;
          t = goingAway
              ? Easing.emphasizedAccelerate.transform(raw)
              : 1 - Easing.emphasizedDecelerate.transform(1 - raw);
          slide = size.width * 0.22 * direction * t;
          lift = 0;
          radius = 0;
          // A cheap solid scrim instead of a full page `Opacity`: an
          // `Opacity` forces a saveLayer over the whole route every frame.
          scrim = 0.24 * t;
        } else if (g.dragging) {
          // Glued to the finger, linear with the system gesture progress —
          // no easing tail. The page shrinks to the spec's 0.90 floor and
          // rounds towards the display's own corner radius as it is dragged.
          t = raw;
          slide = g.dx;
          lift = g.dy;
          radius = corner * raw;
          // No self-scrim while dragging: darkening the dragged page is what
          // made the gesture look muddy. Depth comes from the scale, the
          // rounding and the parallax of the route below.
          scrim = 0;
        } else if (g.committed) {
          // Released towards the pop: carry the exact finger position into an
          // emphasized slide off the edge, continuous with the drag.
          final span = 1 - g.releaseGone;
          final k = span <= 0.001
              ? 1.0
              : ((raw - g.releaseGone) / span).clamp(0.0, 1.0);
          final eased = Curves.easeInOutCubicEmphasized.transform(k);
          final edgeSign = g.dx == 0 ? direction : g.dx.sign;
          t = raw;
          slide = g.dx + (edgeSign * size.width * 1.05 - g.dx) * eased;
          lift = g.dy * (1 - eased);
          radius = corner * (g.releaseGone + (1 - g.releaseGone) * eased);
          scrim = 0;
        } else {
          // Released towards a cancel: spring back to identity, decelerating
          // out of the finger position (M3E emphasizedDecelerate).
          final span = g.releaseGone;
          final k = span <= 0.001
              ? 1.0
              : (1 - raw / span).clamp(0.0, 1.0);
          final eased = Easing.emphasizedDecelerate.transform(k);
          t = raw;
          slide = g.dx * (1 - eased);
          lift = g.dy * (1 - eased);
          radius = corner * raw;
          scrim = 0;
        }

        final scale = 1 - (g.active ? 0.10 : 0.06) * t;
        Widget content = Transform(
          transform: Matrix4.identity()
            ..translateByDouble(slide, lift, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1),
          alignment: Alignment.center,
          child: page,
        );
        // The rounded card look is only needed while a back gesture owns the
        // page; clipping the whole route every timed frame would force a new
        // clip layer for nothing.
        if (radius > 0.5) {
          content = ClipRRect(
            borderRadius: BorderRadius.circular(
              radius.clamp(0, size.shortestSide / 2),
            ),
            child: content,
          );
        }
        if (scrim <= 0.001) {
          return content;
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            content,
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: scrim)),
            ),
          ],
        );
      },
    );
  }
}

/// Animates the route underneath an incoming one: it recedes and dims a little
/// while covered, and springs back to full size as it is revealed by a back
/// gesture. During a gesture the parallax is linear (it has to track the
/// finger); timed transitions use the M3E emphasized tokens.
class _M3EFloatSecondaryTransition extends StatelessWidget {
  const _M3EFloatSecondaryTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final direction = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    final page = RepaintBoundary(child: child);

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, reveal) {
        // reveal: 1 = fully visible, 0 = fully covered.
        final r = reveal.clamp(0.0, 1.0);
        if (r >= 0.999) {
          return child;
        }
        final covered = 1 - r;
        final double t;
        if (BackGestureBridge.active) {
          // Linear: the route below has to track the dragged page 1:1.
          t = covered;
        } else {
          final status = animation.status;
          t = status == AnimationStatus.forward ||
                  status == AnimationStatus.completed
              // Being covered by a push: accelerate away.
              ? Easing.emphasizedAccelerate.transform(covered)
              // Being revealed by a pop: decelerate in.
              : 1 - Easing.emphasizedDecelerate.transform(r);
        }
        // The Android 16 predictive back spec scales the revealed route from
        // 0.95; the small counter-slide is the iOS-style parallax that keeps
        // the two surfaces reading as one stack.
        final scale = 1 - 0.05 * t;
        final slide = -size.width * 0.06 * direction * t;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Transform(
              transform: Matrix4.identity()
                ..translateByDouble(slide, 0, 0, 1)
                ..scaleByDouble(scale, scale, 1, 1),
              alignment: Alignment.center,
              child: page,
            ),
            if (t > 0.001)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.20 * t),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The video card container transform.
///
/// The whole destination route is laid out full screen and then mapped so that
/// its player lands exactly on the tapped card, clipped to the interpolated
/// rect and corner radius. The card cover is painted on top while the route is
/// still card sized and cross-fades into the real page, so push *and* pop are a
/// single, seamless morph — including while a predictive back gesture is
/// dragging the player back towards the card.
///
/// Per the shared element spec, a committed gesture does *not* throw the page
/// off the edge: it lands the card in its slot (the finger offset retracts to
/// zero while the morph completes), and a cancelled gesture re-expands it.
class _CardZoomTransition extends StatelessWidget {
  const _CardZoomTransition({
    required this.route,
    required this.animation,
    required this.origin,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final CardZoomOrigin origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, progress) {
        final gone = progress.clamp(0.0, 1.0);
        final open = 1 - gone;
        final bridge = BackGestureBridge.gesture;
        final g = identical(bridge.owner, route)
            ? bridge
            : BackGestureSnapshot.idle;

        final double t; // openness 0..1, eased for timed motion
        final double dx;
        final double dy;
        if (!g.active) {
          // Fully open: hand the page back untouched so its own `BackdropFilter`
          // glass renders normally (a permanent transform/clip layer breaks it).
          if (open >= 0.999) {
            return child;
          }
          final status = animation.status;
          final goingAway =
              status == AnimationStatus.reverse ||
              status == AnimationStatus.dismissed;
          // Container transform: decelerate opening, accelerate closing.
          t = goingAway
              ? 1 - Easing.emphasizedAccelerate.transform(gone)
              : Easing.emphasizedDecelerate.transform(open);
          dx = 0;
          dy = 0;
        } else if (g.dragging) {
          // Linear and glued to the finger: the window shrinks towards the
          // card exactly as fast as the system gesture progresses.
          t = open;
          dx = g.dx;
          dy = g.dy * open;
        } else {
          // Released — commit (land in the card slot) or cancel (re-expand):
          // either way the finger offset retracts to zero with the M3E
          // decelerate token while `t` keeps following the raw progress.
          final span = g.committed ? 1 - g.releaseGone : g.releaseGone;
          final travel = g.committed
              ? gone - g.releaseGone
              : g.releaseGone - gone;
          final k = span <= 0.001 ? 1.0 : (travel / span).clamp(0.0, 1.0);
          final eased = Easing.emphasizedDecelerate.transform(k);
          t = open;
          dx = g.dx * (1 - eased);
          dy = g.dy * open * (1 - eased);
        }

        final end = Offset.zero & size;
        final live = origin.resolve();
        final begin = _clampToScreen(live ?? origin.begin, size);
        final rect = Rect.lerp(begin, end, t)!.translate(dx, dy);
        final scale = rect.width <= 0 ? 1.0 : rect.width / size.width;
        // Map the top of the player (roughly the status bar inset) onto the top
        // of the interpolated window, and let the rest of the page follow.
        final topInset = padding.top;
        // At card size the player (below the status bar) must land at the
        // source rect. Fade this correction out as the window expands, or the
        // page jumps by the status-bar height when the full-screen shortcut
        // returns the untransformed child at the end of the animation.
        final dyOffset = rect.top - topInset * scale * (1 - t);
        final radius = origin.radius * (1 - t);
        final coverOpacity = (1 - t / 0.55).clamp(0.0, 1.0);

        return ClipPath(
          clipper: _WindowClipper(rect: rect, radius: radius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(rect.left, dyOffset, 0, 1)
                  ..scaleByDouble(scale, scale, 1, 1),
                alignment: Alignment.topLeft,
                child: RepaintBoundary(child: child),
              ),
              if (origin.cover != null && coverOpacity > 0.001)
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: coverOpacity,
                      child: ColoredBox(
                        color: Colors.black,
                        child: NetworkImgLayer(
                          src: origin.cover!,
                          width: rect.width,
                          height: rect.height,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Rect _clampToScreen(Rect rect, Size size) {
    final width = rect.width.clamp(1.0, size.width);
    final height = rect.height.clamp(1.0, size.height);
    final left = rect.left.clamp(-width * 0.5, size.width - width * 0.5);
    final top = rect.top.clamp(-height * 0.5, size.height - height * 0.5);
    return Rect.fromLTWH(left, top, width, height);
  }
}

/// Clips to a rounded window; used by the card zoom.
class _WindowClipper extends CustomClipper<Path> {
  const _WindowClipper({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(radius.clamp(0, math.min(rect.width, rect.height) / 2)),
      ),
    );

  @override
  bool shouldReclip(_WindowClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}

/// Maps Android's edge and touch coordinates to signed page travel.
///
/// Kept separate from the observer so left/right swipes and reversals can be
/// regression-tested with actual [PredictiveBackEvent.fromMap] events.
@visibleForTesting
(double, double) backGestureOffset({
  required PredictiveBackEvent event,
  required Offset? start,
  required SwipeEdge? edge,
  required Size size,
}) {
  final current = event.touchOffset;
  if (start == null || current == null || size.isEmpty) {
    return (0, 0);
  }
  final edgeSign = edge == SwipeEdge.right ? -1.0 : 1.0;
  final travel = (current.dx - start.dx) * edgeSign;
  final dx = edgeSign * travel.clamp(0.0, size.width);
  final rawDy = current.dy - start.dy;
  final yMax = math.max(0.0, size.height / 20 - 8);
  final easedDy =
      Curves.easeOut.transform((rawDy.abs() / size.height).clamp(0.0, 1.0)) *
      rawDy.sign * yMax;
  return (dx, easedDy.clamp(-yMax, yMax));
}

/// Feeds the Android predictive back gesture into a route's animation.
///
/// This is the piece of `PredictiveBackPageTransitionsBuilder` that actually
/// makes predictive back work: the system sends `PredictiveBackEvent`s to
/// [WidgetsBindingObserver]s, and the top route's controller is driven from
/// them so it can be dragged and then committed or cancelled. Custom page
/// transitions have to provide it themselves.
///
/// The handler is the *only* writer of [BackGestureBridge]: it announces the
/// gesture, streams the finger into it, and announces the release together
/// with the exact progress it happened at — captured **before** the framework
/// restarts the controller, which is what makes the commit continuous.
class _PredictiveBackGestureHandler extends StatefulWidget {
  const _PredictiveBackGestureHandler({
    required this.route,
    required this.builder,
  });

  final PageRoute<dynamic> route;
  final Widget Function(BuildContext context) builder;

  @override
  State<_PredictiveBackGestureHandler> createState() =>
      __PredictiveBackGestureHandlerState();
}

class __PredictiveBackGestureHandlerState
    extends State<_PredictiveBackGestureHandler> with WidgetsBindingObserver {
  Offset? _dragStart;
  SwipeEdge? _swipeEdge;

  /// True between an accepted start and the end of the settle. Events are only
  /// delivered to the observer that accepted the start, but guarding every
  /// callback keeps the bridge safe even if the platform replays events.
  bool _ownsGesture = false;

  /// The one-shot listener watching a release settle, kept so a *new* gesture
  /// starting mid-settle can detach it (a stale `completed` firing into the
  /// new drag would tear its state down).
  Animation<double>? _settleAnimation;
  AnimationStatusListener? _settleListener;

  bool get _isEnabled =>
      HotPageTransitions.predictiveBack &&
      widget.route.isCurrent &&
      widget.route.popGestureEnabled;

  double get _raw {
    final animation = widget.route.animation;
    if (animation == null) {
      return 0;
    }
    return (1 - animation.value).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _clearSettleWatch();
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsGesture) {
      _ownsGesture = false;
      BackGestureBridge.end();
    }
    super.dispose();
  }

  /// The finger position mapped into the page motion.
  ///
  /// Android reports the edge the gesture started from, which is more reliable
  /// than the raw delta's sign: a left edge swipe pushes the page right and
  /// vice versa. The horizontal travel is projected onto that direction, so
  /// dragging back towards the edge *retracts* the page instead of pushing it
  /// deeper (the old `abs()` did exactly that). The vertical shift follows the
  /// Android 16 motion spec: `easeOut(|dy| / height)` capped at
  /// `height / 20 - 8`.
  (double, double) _dragValues(PredictiveBackEvent backEvent) {
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) {
      return (0, 0);
    }
    return backGestureOffset(
      event: backEvent,
      start: _dragStart,
      edge: _swipeEdge,
      size: size,
    );
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_isEnabled || backEvent.isButtonEvent) {
      return false;
    }
    // A new gesture may start while the previous release is still settling;
    // its watcher must not fire into this one.
    _clearSettleWatch();
    _ownsGesture = true;
    _dragStart = backEvent.touchOffset;
    _swipeEdge = backEvent.swipeEdge;
    BackGestureBridge.begin(widget.route);
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_ownsGesture) {
      return;
    }
    final (dx, dy) = _dragValues(backEvent);
    BackGestureBridge.drag(dx: dx, dy: dy);
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
    // Rebuild *and* the controller tick both land before the next frame, so
    // the page tracks the finger without a frame of lag.
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void handleCancelBackGesture() {
    if (!_ownsGesture) {
      return;
    }
    // Captured before the route call: cancel starts animating immediately.
    final gone = _raw;
    widget.route.handleCancelBackGesture();
    BackGestureBridge.cancel(gone);
    if (mounted) {
      setState(() {});
    }
    _watchSettle(AnimationStatus.completed);
  }

  @override
  void handleCommitBackGesture() {
    if (!_ownsGesture) {
      return;
    }
    // Captured *and announced* before the route call: committing pops the
    // route and restarts the controller at 1.0 synchronously, after which the
    // progress is no longer the one the finger had reached.
    final gone = _raw;
    BackGestureBridge.armCommit(gone);
    widget.route.handleCommitBackGesture();
    if (mounted) {
      setState(() {});
    }
    _watchSettle(AnimationStatus.dismissed);
  }

  /// Ends the gesture once the route settles at [target], with a synchronous
  /// fallback for the (rare) case of the controller already being there.
  void _watchSettle(AnimationStatus target) {
    _clearSettleWatch();
    final animation = widget.route.animation;
    if (animation == null ||
        animation.status == target ||
        !animation.isAnimating) {
      _finish();
      return;
    }
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status != target) {
        return;
      }
      _clearSettleWatch();
      _finish();
    };
    _settleAnimation = animation;
    _settleListener = listener;
    animation.addStatusListener(listener);
  }

  void _clearSettleWatch() {
    final animation = _settleAnimation;
    final listener = _settleListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _settleAnimation = null;
    _settleListener = null;
  }

  void _finish() {
    _ownsGesture = false;
    _dragStart = null;
    _swipeEdge = null;
    BackGestureBridge.end();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
