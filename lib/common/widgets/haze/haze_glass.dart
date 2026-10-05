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

import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:PiliPlus/common/widgets/haze/haze_config.dart';
import 'package:material_ui/material_ui.dart';

/// Applies [side] to [shape] when the concrete border supports it.
ShapeBorder _shapeWithSide(ShapeBorder shape, BorderSide side) =>
    switch (shape) {
      RoundedSuperellipseBorder() => shape.copyWith(side: side),
      RoundedRectangleBorder() => shape.copyWith(side: side),
      StadiumBorder() => shape.copyWith(side: side),
      CircleBorder() => shape.copyWith(side: side),
      _ => shape,
    };

/// Built-in glass recipes, inspired by Haze 2.0's `GlassStyle`.
enum HazeGlassStyle {
  /// Diffused, softer surface that keeps content readable on busy backdrops.
  regular(
    blur: 32,
    tintOpacityLight: 0.58,
    tintOpacityDark: 0.52,
    fallbackLight: 1.0,
    fallbackDark: 1.0,
  ),

  /// Shallow, consistent blur that keeps the background content prominent.
  clear(
    blur: 14,
    tintOpacityLight: 0.34,
    tintOpacityDark: 0.30,
    fallbackLight: 0.82,
    fallbackDark: 0.76,
  );

  const HazeGlassStyle({
    required this.blur,
    required this.tintOpacityLight,
    required this.tintOpacityDark,
    required this.fallbackLight,
    required this.fallbackDark,
  });

  /// Peak blur radius in logical pixels.
  final double blur;

  final double tintOpacityLight;
  final double tintOpacityDark;
  final double fallbackLight;
  final double fallbackDark;

  double tintOpacity({required bool isDark}) =>
      isDark ? tintOpacityDark : tintOpacityLight;

  double fallbackOpacity({required bool isDark}) =>
      isDark ? fallbackDark : fallbackLight;
}

/// A frosted glass surface: blur, tint, a hairline edge and a soft highlight,
/// following the shape it is given.
///
/// This is a Flutter take on Haze 2.0's Glass. When the platform or the user
/// asks for less transparency (or glass is disabled in settings) the surface
/// gracefully degrades to an opaque Material 3 tonal container, so layout and
/// contrast never break.
class HazeGlass extends StatelessWidget {
  const HazeGlass({
    super.key,
    required this.child,
    this.shape = const RoundedSuperellipseBorder(
      borderRadius: M3ERadius.full,
    ),
    this.style = HazeGlassStyle.regular,
    this.enabled,
    this.blur,
    this.tint,
    this.tintOpacity,
    this.border,
    this.highlight = true,
    this.highlightColor,
    this.shadows,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;

  /// Shape of the glass; corners are clipped to it.
  final ShapeBorder shape;

  final HazeGlassStyle style;

  /// Per-instance override of [HazeConfig.enabled].
  final bool? enabled;

  /// Per-instance blur override, in logical pixels.
  final double? blur;

  /// Base tint color, defaults to the current `surfaceContainerHigh`.
  final Color? tint;

  /// Overrides the tint opacity of [style].
  final double? tintOpacity;

  final BorderSide? border;

  /// Paints a soft specular highlight across the surface.
  final bool highlight;

  final Color? highlightColor;

  final List<BoxShadow>? shadows;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final config = HazeConfig.of(context);
    final canBlur =
        (enabled ?? config.enabled) &&
        config.canBlur &&
        !isPageTransitionActive(context);

    final borderSide =
        border ??
        BorderSide(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.12 : 0.06,
          ),
        );

    final Widget surface;
    if (canBlur) {
      final sigma = (blur ?? style.blur) * config.quality.sigmaScale;
      final tintColor = (tint ?? colors.surfaceContainerHigh).withValues(
        alpha: tintOpacity ?? style.tintOpacity(isDark: isDark),
      );
      final highlightBase = highlightColor ?? Colors.white;

      surface = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              clipBehavior: clipBehavior,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.mirror,
                ),
                child: ColoredBox(
                  color: tintColor,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          child,
          if (highlight)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: shape,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        highlightBase.withValues(alpha: isDark ? 0.10 : 0.42),
                        highlightBase.withValues(alpha: 0.0),
                        highlightBase.withValues(alpha: isDark ? 0.04 : 0.12),
                      ],
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: _shapeWithSide(shape, borderSide),
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      surface = ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: clipBehavior,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: _shapeWithSide(shape, borderSide),
            color: (tint ?? colors.surfaceContainer).withValues(
              alpha: tintOpacity ?? style.fallbackOpacity(isDark: isDark),
            ),
          ),
          child: child,
        ),
      );
    }

    if (shadows != null && shadows!.isNotEmpty) {
      return DecoratedBox(
        decoration: ShapeDecoration(shape: shape, shadows: shadows),
        child: surface,
      );
    }
    return surface;
  }
}
