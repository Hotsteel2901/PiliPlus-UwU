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

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;
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

/// Material 3 Expressive, predictive back aware page transitions for the whole
/// app, plus the container transform used by video cards.
///
/// Why not the stock implementation?
///
/// * `PredictiveBackPageTransitionsBuilder` only animates the route that is
///   being dismissed. GetX routes never provide a `delegatedTransition`, so the
///   route underneath stays completely static while the top one shrinks and
///   slides away — the seam between the two routes is what feels broken.
/// * The framework restarts the route controller at `1.0` before reversing it
///   when a predictive back gesture commits (flutter/flutter#184653), so a
///   transition that naively maps `animation.value` snaps at the commit point.
///   [ContinuousBackProgress] compensates for that jump.
/// * The stock shared-element variant is AOSP's, which shrinks the page into a
///   floating card only *after* the commit. The variant implemented here keeps
///   the page glued to the finger the whole time (iOS / HyperOS style float),
///   animates the route below with a matching parallax, and settles with the
///   M3E spring curve.
abstract final class HotPageTransitions {
  /// Installs the transition hooks into the patched GetX runtime.
  ///
  /// Must be called once, before the first route is pushed.
  static void install() {
    GetNativeTransition.builder = buildNative;
    GetNativeTransition.delegatedTransition = buildDelegated;
    GetNativeTransition.duration = durationFor;
  }

  /// Duration of the video card container transform.
  static const Duration cardZoomDuration = Duration(milliseconds: 320);

  /// Only the app's own native page transition is ever replaced.
  static bool get _native => Pref.pageTransition == Transition.native;

  /// The generic M3E page open/close transition (opt in: it is the heaviest).
  static bool get m3eEnabled => _native && Pref.m3eTransition;

  /// The video card container transform, independent from [m3eEnabled].
  static bool get cardZoomEnabled => _native && Pref.cardZoomTransition;

  /// Whether the app drives the Android predictive back gesture itself.
  static bool get predictiveBack => _native && Pref.predictiveBack;

  static int _lastTap = 0;

  /// Guards against duplicate pushes caused by very fast repeated taps.
  static bool claimTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTap < 420) {
      return false;
    }
    _lastTap = now;
    return true;
  }

  static Duration? durationFor(PageRoute<dynamic> route) {
    if (cardZoomEnabled && _cardZoomOf(route) != null) {
      return cardZoomDuration;
    }
    if (m3eEnabled) {
      return const Duration(milliseconds: 300);
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
        return PredictiveBackGestureHandler(
          route: route,
          builder: (context, gesturing, dragDx) => _CardZoomTransition(
            route: route,
            animation: animation,
            origin: origin,
            dragDx: dragDx,
            child: child,
          ),
        );
      }
    }
    if (m3eEnabled) {
      return PredictiveBackGestureHandler(
        route: route,
        builder: (context, gesturing, dragDx) => _M3EFloatPageTransition(
          route: route,
          animation: animation,
          dragDx: dragDx,
          child: child,
        ),
      );
    }
    if (predictiveBack) {
      // Stock push/pop, but a finger-following float while the gesture is
      // dragging the page: the platform's AOSP variant barely moves the page,
      // which is what feels sluggish and disconnected.
      return PredictiveBackGestureHandler(
        route: route,
        builder: (context, gesturing, dragDx) => gesturing
            ? _M3EFloatPageTransition(
                route: route,
                animation: animation,
                dragDx: dragDx,
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
    if (child == null || !_native) {
      return child;
    }
    if (m3eEnabled || cardZoomEnabled) {
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
/// (flutter/flutter#184653). The jump is detected and the remaining travel is
/// re-parameterised from the progress that had already been reached, so the
/// motion never snaps.
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
  double? _commitProgress;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.animation.value;
    _progress = _compute(widget.animation.value);
    widget.animation.addListener(_onTick);
  }

  @override
  void didUpdateWidget(ContinuousBackProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_onTick);
      widget.animation.addListener(_onTick);
      _lastValue = widget.animation.value;
      _progress = _compute(_lastValue);
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onTick);
    super.dispose();
  }

  double _compute(double value) {
    final v = value.clamp(0.0, 1.0);
    final commit = _commitProgress;
    if (commit != null) {
      // The controller is now reversing from 1.0 back to 0.0; spread the
      // remaining travel over it.
      return (commit + (1 - commit) * (1 - v)).clamp(0.0, 1.0);
    }
    return 1 - v;
  }

  void _onTick() {
    final value = widget.animation.value.clamp(0.0, 1.0);
    // A predictive back commit restarts the controller at 1.0 before reversing
    // it (flutter/flutter#184653). The jump is an instantaneous move to the
    // upper bound from wherever the gesture had reached.
    if (_commitProgress == null &&
        value >= 1.0 &&
        _lastValue < 1.0 - 0.08 &&
        _progress > 0.05) {
      _commitProgress = _progress;
    }
    _lastValue = value;
    setState(() => _progress = _compute(value));
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}

/// Maps the linear "how far gone" progress (0 = present, 1 = dismissed) onto an
/// eased one that always starts fast and settles gently.
///
/// The direction matters: on a pop the value runs 0 -> 1 and on a push 1 -> 0,
/// so a single curve has to be mirrored. Applying one curve to both is what
/// made the retract look "slow and then suddenly gone".
double _easeGone(double gone, bool goingAway) => goingAway
    ? Curves.easeOutCubic.transform(gone)
    : Curves.easeInCubic.transform(gone);

/// The default transition: the page floats up over the previous one, and on the
/// way back it follows the finger and shrinks into a rounded card.
class _M3EFloatPageTransition extends StatelessWidget {
  const _M3EFloatPageTransition({
    required this.route,
    required this.animation,
    this.dragDx = 0,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;

  /// The finger's horizontal travel during a back gesture, so the page can
  /// follow it exactly.
  final double dragDx;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final direction = textDirection == TextDirection.rtl ? -1.0 : 1.0;
    // The page is wrapped once so the whole route is rasterised into a single
    // layer; the transition then only re-composites it (transform + a solid
    // scrim) instead of repainting the page every frame.
    final page = RepaintBoundary(child: child);

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, progress) {
        // progress: 0 = on top, 1 = dismissed.
        final raw = progress.clamp(0.0, 1.0);
        // At rest the page must not be wrapped in a transform/clip layer:
        // a `BackdropFilter` inside one renders incorrectly (and flickers) on
        // Skia, and there is nothing to animate anyway.
        if (raw <= 0.001) {
          return child;
        }
        // While a back gesture is dragging the page it must track the finger
        // 1:1; timed motion is eased so it starts fast and settles, whichever
        // way it runs.
        final t = route.popGestureInProgress
            ? raw
            : _easeGone(raw, animation.status == AnimationStatus.reverse);
        // While the finger is on screen the page is glued to it, so it feels
        // like it is physically dragged away.
        final follow = route.popGestureInProgress && dragDx != 0;
        final slide = follow ? dragDx : size.width * 0.22 * direction * t;
        final scale = 1 - 0.06 * t;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Deliberately no clip here: clipping the whole route every frame
            // forces a new clip layer and is the main source of dropped frames.
            // The rounded "card" look is only needed while a back gesture is
            // dragging the page, and the platform's own gesture transition
            // handles that.
            Transform(
              transform: Matrix4.identity()
                ..translateByDouble(slide, 0, 0, 1)
                ..scaleByDouble(scale, scale, 1, 1),
              alignment: Alignment.center,
              child: page,
            ),
            // A cheap solid scrim instead of a full page `Opacity`: an
            // `Opacity` forces a saveLayer over the whole route every frame,
            // which is what made the transition stutter on Skia.
            if (t > 0.001)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.30 * t),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Animates the route underneath an incoming one: it recedes and dims a little
/// while covered, and springs back to full size as it is revealed by a back
/// gesture.
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
        final covered = _easeGone(
          1 - r,
          animation.status == AnimationStatus.forward,
        );
        if (covered <= 0.001) {
          return child;
        }
        final scale = 1 - 0.06 * covered;
        final slide = -size.width * 0.06 * direction * covered;

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
            if (covered > 0.001)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.22 * covered),
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
class _CardZoomTransition extends StatelessWidget {
  const _CardZoomTransition({
    required this.route,
    required this.animation,
    required this.origin,
    this.dragDx = 0,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final CardZoomOrigin origin;

  /// The finger's horizontal travel during a back gesture.
  final double dragDx;
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
        // Fully open: hand the page back untouched so its own `BackdropFilter`
        // glass renders normally (a permanent transform/clip layer breaks it).
        if (open >= 0.999) {
          return child;
        }
        // 1:1 while the back gesture drags it; timed motion is eased so it
        // starts fast and settles, whichever way it runs.
        final t = route.popGestureInProgress
            ? open
            : 1 - _easeGone(gone, animation.status == AnimationStatus.reverse);
        final end = Offset.zero & size;
        final live = origin.resolve();
        final begin = _clampToScreen(live ?? origin.begin, size);
        final follow = route.popGestureInProgress && dragDx != 0;
        final rect = Rect.lerp(begin, end, t)!.translate(follow ? dragDx : 0, 0);
        final scale = rect.width <= 0 ? 1.0 : rect.width / size.width;
        // Map the top of the player (roughly the status bar inset) onto the top
        // of the interpolated window, and let the rest of the page follow.
        final topInset = padding.top;
        final dy = rect.top - topInset * scale;
        final radius = origin.radius * (1 - t);
        final coverOpacity = (1 - t / 0.55).clamp(0.0, 1.0);

        return ClipPath(
          clipper: _WindowClipper(rect: rect, radius: radius),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(rect.left, dy, 0, 1)
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

/// Feeds the Android predictive back gesture into a route's animation.
///
/// This is the piece of `PredictiveBackPageTransitionsBuilder` that actually
/// makes predictive back work: the system sends `PredictiveBackEvent`s to
/// [WidgetsBindingObserver]s, and the top route's controller is driven from
/// them so it can be dragged and then committed or cancelled. Custom page
/// transitions have to provide it themselves.
class PredictiveBackGestureHandler extends StatefulWidget {
  const PredictiveBackGestureHandler({
    super.key,
    required this.route,
    required this.builder,
  });

  final PageRoute<dynamic> route;

  /// Built with `gesturing` true while the user is dragging the back gesture and
  /// `dragDx` holding the finger's horizontal travel in logical pixels, so the
  /// caller can move the page exactly with the finger.
  final Widget Function(BuildContext context, bool gesturing, double dragDx)
  builder;

  @override
  State<PredictiveBackGestureHandler> createState() =>
      _PredictiveBackGestureHandlerState();
}

class _PredictiveBackGestureHandlerState
    extends State<PredictiveBackGestureHandler> with WidgetsBindingObserver {
  bool _gesturing = false;
  double _dragDx = 0;
  Offset? _dragStart;

  bool get _isEnabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.route.animation?.removeStatusListener(_onStatus);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // A cancelled gesture animates back to `completed`; only then may we leave
    // the finger-following transition, otherwise the page would pop mid flight.
    if (status == AnimationStatus.completed && _gesturing) {
      widget.route.animation?.removeStatusListener(_onStatus);
      setState(() {
        _gesturing = false;
        _dragDx = 0;
        _dragStart = null;
      });
    }
  }

  void _setGesturing(bool value) {
    if (_gesturing == value) {
      return;
    }
    setState(() => _gesturing = value);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (!_isEnabled || backEvent.isButtonEvent) {
      return false;
    }
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _dragStart = backEvent.touchOffset;
    _dragDx = 0;
    _setGesturing(true);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    final start = _dragStart;
    final current = backEvent.touchOffset;
    if (start != null && current != null) {
      _dragDx = current.dx - start.dx;
    }
    widget.route.handleUpdateBackGestureProgress(
      progress: 1 - backEvent.progress,
    );
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
    // Fall back to the eased motion: the finger is gone.
    setState(() {
      _dragDx = 0;
      _dragStart = null;
    });
    // Keep the finger-following transition until the route settles back.
    widget.route.animation?.addStatusListener(_onStatus);
  }

  @override
  void handleCommitBackGesture() {
    widget.route.handleCommitBackGesture();
    setState(() {
      _dragDx = 0;
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _gesturing, _dragDx);
}
