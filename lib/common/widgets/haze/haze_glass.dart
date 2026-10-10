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
import 'dart:ui' as ui;

import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:PiliPlus/common/widgets/haze/haze_config.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
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

/// The shared film-grain texture of the glass system.
///
/// Haze composites a low-amplitude noise over every frosted surface (its
/// `noiseFactor`, defaulting to 0.1): large blurs quantise into visible
/// bands, especially on gradients and video, and the grain dithers them away.
/// One 96×96 texture is generated once, tiled through an [ui.ImageShader]
/// and blended `overlay`, which leaves mid greys untouched and only lifts the
/// local contrast — exactly how Haze applies it.
abstract final class HazeNoise {
  static const int _size = 96;

  static final ValueNotifier<ui.ImageShader?> shader = ValueNotifier(null);

  static bool _generating = false;
  static ui.Image? _image;

  /// Backing grain texture once rasterised.
  static ui.Image? get image => _image;

  /// Starts generating the texture; safe to call from `build`. Until it is
  /// ready the glass simply renders without grain (one silent rebuild when
  /// it lands, driven by [shader]).
  static void ensure() {
    if (shader.value != null || _generating) {
      return;
    }
    _generating = true;
    _generate();
  }

  static Future<void> _generate() async {
    try {
      final random = math.Random(0x5EED2026); // fixed seed: stable grain
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Greys centred on 128: an `overlay` blend of 128 is the identity, so
      // only the ±spread shows up as grain.
      const levels = <int>[104, 116, 128, 140, 152];
      final pointsPerLevel = (_size * _size) ~/ levels.length;
      for (final level in levels) {
        final paint = Paint()
          ..color = Color.fromARGB(255, level, level, level)
          ..strokeWidth = 1;
        final points = List<ui.Offset>.generate(
          pointsPerLevel,
          (_) => ui.Offset(
            random.nextDouble() * _size,
            random.nextDouble() * _size,
          ),
        );
        canvas.drawPoints(ui.PointMode.points, points, paint);
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(_size, _size);
      picture.dispose();
      _image = image; // kept alive: the shader references it
      shader.value = ui.ImageShader(
        image,
        ui.TileMode.repeated,
        ui.TileMode.repeated,
        Matrix4.identity().storage,
        filterQuality: ui.FilterQuality.none,
      );
    } catch (_) {
      // Headless/test environments may not rasterise; glass without grain is
      // still correct glass.
      _generating = false;
    }
  }
}

/// Built-in glass recipes, inspired by Haze 2.0's `GlassStyle`.
enum HazeGlassStyle {
  /// Diffused, softer surface that keeps content readable on busy backdrops.
  regular(
    blur: 32,
    tintOpacityLight: 0.58,
    tintOpacityDark: 0.52,
    noiseFactor: 0.10,
  ),

  /// Shallow, consistent blur that keeps the background content prominent.
  clear(
    blur: 14,
    tintOpacityLight: 0.34,
    tintOpacityDark: 0.30,
    noiseFactor: 0.06,
  );

  const HazeGlassStyle({
    required this.blur,
    required this.tintOpacityLight,
    required this.tintOpacityDark,
    required this.noiseFactor,
  });

  /// Peak blur radius in logical pixels.
  final double blur;

  final double tintOpacityLight;
  final double tintOpacityDark;

  /// Grain amplitude, Haze's `noiseFactor`.
  final double noiseFactor;

  double tintOpacity({required bool isDark}) =>
      isDark ? tintOpacityDark : tintOpacityLight;

  /// Tint opacity of the opaque fallback (transparency reduced, blur off or a
  /// page transition in flight).
  ///
  /// Derived from the blur-state tint instead of a separate colour: the
  /// fallback has to read as "the same glass, momentarily solid", otherwise
  /// every navigation flashes the surface (the old 100%-opaque
  /// `surfaceContainer` fallback did exactly that).
  double fallbackOpacity({required bool isDark}) =>
      math.min(1.0, tintOpacity(isDark: isDark) + 0.30);
}

/// A frosted glass surface: blur, tint, film grain, a hairline edge and a
/// soft highlight, following the shape it is given.
///
/// This is a Flutter take on Haze 2.0's Glass. When the platform or the user
/// asks for less transparency (or glass is disabled in settings) the surface
/// gracefully degrades to a *tonally continuous* opaque material, so layout,
/// contrast and — importantly — the surface's own colour never break or flash.
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
    this.noise,
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

  /// Overrides the grain amplitude of [style]; `0` disables the grain.
  final double? noise;

  final List<BoxShadow>? shadows;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) => HazeTransitionGate(
    builder: _buildSurface,
  );

  Widget _buildSurface(BuildContext context, bool transitionActive) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final config = HazeConfig.of(context);
    final blurEnabled = (enabled ?? config.enabled) && config.canBlur;
    // A backdrop blur inside a route that is being translated or scaled has
    // to re-render the backdrop every frame; during a transition the surface
    // drops to its solid fallback, which is tint-matched to the blur state.
    final canBlur = blurEnabled && !transitionActive;

    final base = tint ?? colors.surfaceContainerHigh;
    final effectiveTintOpacity = tintOpacity ?? style.tintOpacity(isDark: isDark);
    final borderSide =
        border ??
        BorderSide(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.12 : 0.06,
          ),
        );
    final noiseAmount =
        (noise ?? style.noiseFactor) * config.quality.noiseScale;

    final Widget surface;
    if (canBlur) {
      if (noiseAmount > 0) {
        HazeNoise.ensure();
      }
      final sigma = (blur ?? style.blur) * config.quality.sigmaScale;
      final tintColor = base.withValues(alpha: effectiveTintOpacity);
      final highlightBase = highlightColor ?? Colors.white;

      surface = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              clipBehavior: clipBehavior,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: ui.TileMode.mirror,
                ),
                child: ColoredBox(
                  color: tintColor,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          // Film grain, under the content and the specular highlight.
          if (noiseAmount > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: shape),
                  clipBehavior: clipBehavior,
                  child: AnimatedBuilder(
                    animation: HazeNoise.shader,
                    builder: (context, _) {
                      final noiseShader = HazeNoise.shader.value;
                      if (noiseShader == null) {
                        return const SizedBox.shrink();
                      }
                      return CustomPaint(
                        painter: _NoisePainter(noiseShader, noiseAmount),
                      );
                    },
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
            color: base.withValues(
              alpha: blurEnabled
                  ? (effectiveTintOpacity + 0.30).clamp(0.0, 1.0)
                  : 1.0,
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

/// Paints the shared grain texture over the glass at [alpha].
class _NoisePainter extends CustomPainter {
  const _NoisePainter(this.shader, this.alpha);

  final ui.ImageShader shader;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    // `Paint.color` is ignored once a shader is set, so the grain amplitude is
    // applied with a `modulate` colour filter instead: it multiplies the
    // shader's alpha by [alpha] and leaves its RGB (the grain) untouched.
    final paint = Paint()
      ..shader = shader
      ..blendMode = ui.BlendMode.overlay
      ..colorFilter = ui.ColorFilter.mode(
        Color.fromARGB((alpha.clamp(0.0, 1.0) * 255).round(), 255, 255, 255),
        ui.BlendMode.modulate,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) =>
      oldDelegate.shader != shader || oldDelegate.alpha != alpha;
}
