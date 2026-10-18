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

import 'package:PiliPlus/common/m3e/m3e.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// Pops its child in: a short fade with a small scale-up.
///
/// Used for overlay surfaces that are not routes, such as toasts and loading
/// dialogs. Deliberately has no blur and no overshoot — a spring plus a
/// full-surface blur reads as a smeary flash on a phone, especially over the
/// video UI, and these are the surfaces you see most often.
class Materialize extends StatefulWidget {
  const Materialize({
    super.key,
    this.child,
    this.duration = const Duration(milliseconds: 200),
    this.beginScale = 0.94,
    this.curve,
    this.animate = true,
  });

  final Widget? child;

  final Duration duration;

  final double beginScale;

  /// Defaults to the emphasised decelerate token.
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
    if (!widget.animate || reduceMotion || !Pref.hotMotion) {
      return child;
    }
    final curve = widget.curve ?? M3EMotion.emphasizedDecelerate;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double raw = _controller.value.clamp(0.0, 1.0);
        final double eased = curve.transform(raw);
        return Opacity(
          opacity: M3EMotion.emphasizedDecelerate.transform(raw),
          child: Transform.scale(
            scale: widget.beginScale + (1 - widget.beginScale) * eased,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
