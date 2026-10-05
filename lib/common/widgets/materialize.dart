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

import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Pops its child in with a spring: it scales up from [beginScale] while
/// fading in and un-blurring, the same materialise motion FlClash uses for
/// its surfaces.
///
/// Used for overlay surfaces that are not routes, such as toasts and loading
/// dialogs, where the spring cannot be provided by a route transition.
class Materialize extends StatefulWidget {
  const Materialize({
    super.key,
    this.child,
    this.duration = const Duration(milliseconds: 480),
    this.beginScale = 0.86,
    this.beginBlur = 10,
    this.curve,
    this.animate = true,
  });

  final Widget? child;

  final Duration duration;

  final double beginScale;

  final double beginBlur;

  /// Defaults to `m3ePopSpring` from `material_ui`.
  final Curve? curve;

  final bool animate;

  @override
  State<Materialize> createState() => _MaterializeState();
}

class _MaterializeState extends State<Materialize>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.animate || reduceMotion) {
      return child;
    }
    final curve = widget.curve ?? m3ePopSpring;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double raw = _controller.value.clamp(0.0, 1.0);
        final double spring = curve.transform(raw);
        final double reveal = spring.clamp(0.0, 1.0);
        return Opacity(
          opacity: Curves.easeOutCubic.transform(raw),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: widget.beginBlur * (1 - reveal),
              sigmaY: widget.beginBlur * (1 - reveal),
            ),
            child: Transform.scale(
              scale: widget.beginScale + (1 - widget.beginScale) * spring,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
