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

import 'package:PiliPlus/common/m3e/m3e.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
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
  static const Duration cardZoomDuration = Duration(milliseconds: 420);

  /// Custom transition only applies while the user has not picked another
  /// (non native) page transition in the appearance settings.
  static bool get enabled =>
      Pref.hotTransitions && Pref.pageTransition == Transition.native;

  /// The video card container transform can be disabled on its own.
  static bool get cardZoomEnabled => enabled && Pref.cardZoomTransition;

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
    if (!enabled) {
      return null;
    }
    if (cardZoomEnabled && _cardZoomOf(route) != null) {
      return cardZoomDuration;
    }
    return M3EMotion.slow;
  }

  static Widget buildNative(
    PageRoute<dynamic> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final origin = cardZoomEnabled ? _cardZoomOf(route) : null;
    if (origin != null) {
      return _CardZoomTransition(
        animation: animation,
        origin: origin,
        child: child,
      );
    }
    if (!enabled) {
      // Fall back to the stock (patched) Android transition.
      return const PredictiveBackPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return _M3EFloatPageTransition(
      animation: animation,
      child: child,
    );
  }

  /// Animates the route below an incoming transition with a matching parallax,
  /// so the two routes move as one surface.
  static Widget? buildDelegated(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (child == null || !enabled) {
      return child;
    }
    return _M3EFloatSecondaryTransition(
      animation: secondaryAnimation,
      child: child,
    );
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

/// The default transition: the page floats up over the previous one, and on the
/// way back it follows the finger and shrinks into a rounded card.
class _M3EFloatPageTransition extends StatelessWidget {
  const _M3EFloatPageTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final direction = textDirection == TextDirection.rtl ? -1.0 : 1.0;

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, progress) {
        // progress: 0 = on top, 1 = dismissed.
        final t = progress.clamp(0.0, 1.0);
        final slide = size.width * 0.22 * direction * t;
        final scale = 1 - 0.06 * t;
        final radius = M3ECorner.xxl * t;
        final opacity = (1 - t * 1.35).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(slide, 0),
            child: Transform.scale(
              scale: scale,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(radius)),
                child: child,
              ),
            ),
          ),
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

    return ContinuousBackProgress(
      animation: animation,
      builder: (context, reveal) {
        // reveal: 1 = fully visible, 0 = fully covered.
        final r = reveal.clamp(0.0, 1.0);
        final covered = 1 - r;
        final scale = 1 - 0.06 * covered;
        final opacity = 1 - 0.32 * covered;
        final slide = -size.width * 0.06 * direction * covered;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(slide, 0),
            child: Transform.scale(scale: scale, child: child),
          ),
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
    required this.animation,
    required this.origin,
    required this.child,
  });

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
        final t = (1 - progress).clamp(0.0, 1.0);
        final end = Offset.zero & size;
        final live = origin.resolve();
        final begin = _clampToScreen(live ?? origin.begin, size);
        final rect = Rect.lerp(begin, end, t)!;
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
                child: child,
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
