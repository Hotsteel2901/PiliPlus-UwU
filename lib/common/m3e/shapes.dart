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
import 'dart:ui' show ClipOp, lerpDouble;

import 'package:material_ui/material_ui.dart';

/// Corner tokens of the Material 3 Expressive shape scale.
///
/// These are intentionally a little rounder than the classic M3 tokens so
/// surfaces read as the expressive generation of the design system.
abstract final class M3ECorner {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 32;
  static const double full = 1000;

  /// Picks the largest corner that keeps a round, "squircle" look for a
  /// surface whose shortest side is [shortestSide].
  static double fit(double shortestSide) {
    final limit = shortestSide / 3;
    for (final corner in const <double>[xxxl, xxl, xl, lg, md, sm, xs]) {
      if (limit >= corner) {
        return corner;
      }
    }
    return none;
  }
}

/// [BorderRadius] helpers built from [M3ECorner].
abstract final class M3ERadius {
  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius xs = BorderRadius.all(
    Radius.circular(M3ECorner.xs),
  );
  static const BorderRadius sm = BorderRadius.all(
    Radius.circular(M3ECorner.sm),
  );
  static const BorderRadius md = BorderRadius.all(
    Radius.circular(M3ECorner.md),
  );
  static const BorderRadius lg = BorderRadius.all(
    Radius.circular(M3ECorner.lg),
  );
  static const BorderRadius xl = BorderRadius.all(
    Radius.circular(M3ECorner.xl),
  );
  static const BorderRadius xxl = BorderRadius.all(
    Radius.circular(M3ECorner.xxl),
  );
  static const BorderRadius xxxl = BorderRadius.all(
    Radius.circular(M3ECorner.xxxl),
  );
  static const BorderRadius full = BorderRadius.all(
    Radius.circular(M3ECorner.full),
  );

  static BorderRadius all(double corner) => BorderRadius.circular(corner);

  static BorderRadius top(double corner) =>
      BorderRadius.vertical(top: Radius.circular(corner));

  static BorderRadius bottom(double corner) =>
      BorderRadius.vertical(bottom: Radius.circular(corner));

  static BorderRadius vertical({
    double top = M3ECorner.none,
    double bottom = M3ECorner.none,
  }) => BorderRadius.vertical(
    top: Radius.circular(top),
    bottom: Radius.circular(bottom),
  );
}

/// Material 3 Expressive shape helpers.
///
/// Every surface uses [RoundedSuperellipseBorder] so corners stay squircle
/// shaped instead of the circular corners used by classic M3.
abstract final class M3EShape {
  static const RoundedSuperellipseBorder none = RoundedSuperellipseBorder();
  static const RoundedSuperellipseBorder xs = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.xs,
  );
  static const RoundedSuperellipseBorder sm = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.sm,
  );
  static const RoundedSuperellipseBorder md = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.md,
  );
  static const RoundedSuperellipseBorder lg = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.lg,
  );
  static const RoundedSuperellipseBorder xl = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.xl,
  );
  static const RoundedSuperellipseBorder xxl = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.xxl,
  );
  static const RoundedSuperellipseBorder xxxl = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.xxxl,
  );
  static const RoundedSuperellipseBorder full = RoundedSuperellipseBorder(
    borderRadius: M3ERadius.full,
  );
  static const CircleBorder circle = CircleBorder();
  static const M3EInputBorder input = M3EInputBorder();

  static RoundedSuperellipseBorder all(double corner) =>
      RoundedSuperellipseBorder(borderRadius: M3ERadius.all(corner));

  static RoundedSuperellipseBorder top(double corner) =>
      RoundedSuperellipseBorder(borderRadius: M3ERadius.top(corner));

  static RoundedSuperellipseBorder bottom(double corner) =>
      RoundedSuperellipseBorder(borderRadius: M3ERadius.bottom(corner));

  static RoundedSuperellipseBorder vertical({
    double top = M3ECorner.none,
    double bottom = M3ECorner.none,
  }) => RoundedSuperellipseBorder(
    borderRadius: M3ERadius.vertical(top: top, bottom: bottom),
  );

  static RoundedSuperellipseBorder of(BorderRadius borderRadius) =>
      RoundedSuperellipseBorder(borderRadius: borderRadius);
}

/// An [InputBorder] that follows the expressive squircle shape.
///
/// Mirrors the behavior of [OutlineInputBorder] (including the label gap)
/// while painting a [RoundedSuperellipseBorder] instead of a rounded rect.
class M3EInputBorder extends InputBorder {
  const M3EInputBorder({
    super.borderSide = const BorderSide(),
    this.borderRadius = M3ERadius.lg,
    this.gapPadding = 4.0,
  });

  final BorderRadius borderRadius;
  final double gapPadding;

  RoundedSuperellipseBorder get _shape =>
      RoundedSuperellipseBorder(borderRadius: borderRadius, side: borderSide);

  @override
  bool get isOutline => true;

  @override
  bool get preferPaintInterior => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  M3EInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) {
    return M3EInputBorder(
      borderSide: borderSide ?? this.borderSide,
      borderRadius: borderRadius ?? this.borderRadius,
      gapPadding: gapPadding ?? this.gapPadding,
    );
  }

  @override
  M3EInputBorder scale(double t) {
    return M3EInputBorder(
      borderSide: borderSide.scale(t),
      borderRadius: borderRadius * t,
      gapPadding: gapPadding * t,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) => _shape.paintInterior(
    canvas,
    rect,
    paint,
    textDirection: textDirection,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is M3EInputBorder) {
      return M3EInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        gapPadding: a.gapPadding,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is M3EInputBorder) {
      return M3EInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        gapPadding: b.gapPadding,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final outline = rect.deflate(borderSide.width / 2);
    if (gapStart == null || gapExtent <= 0.0 || gapPercentage == 0.0) {
      _shape.paint(canvas, outline, textDirection: textDirection);
      return;
    }
    final extent = lerpDouble(
      0.0,
      gapExtent + gapPadding * 2.0,
      gapPercentage,
    )!;
    final start = switch (textDirection ?? TextDirection.ltr) {
      TextDirection.rtl => gapStart + gapPadding - extent,
      TextDirection.ltr => gapStart - gapPadding,
    };
    final radii = borderRadius.resolve(textDirection);
    final left = outline.left + math.max(0.0, start);
    final depth =
        math.max(radii.topLeft.y, radii.topRight.y) + borderSide.width;
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          left,
          outline.top - borderSide.width,
          left + extent,
          outline.top + depth,
        ),
        clipOp: ClipOp.difference,
      );
    _shape.paint(canvas, outline, textDirection: textDirection);
    canvas.restore();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is M3EInputBorder &&
        other.borderSide == borderSide &&
        other.borderRadius == borderRadius &&
        other.gapPadding == gapPadding;
  }

  @override
  int get hashCode => Object.hash(borderSide, borderRadius, gapPadding);
}
