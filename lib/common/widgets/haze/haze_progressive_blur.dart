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
import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/common/widgets/haze/haze_config.dart';
import 'package:material_ui/material_ui.dart';

/// Edge a [HazeProgressiveBlur] grows from; blur is strongest there.
enum HazeEdge {
  top,
  bottom,
  left,
  right;

  bool get isVertical => this == top || this == bottom;
}

/// A progressive (gradient) blur over the backdrop, like iOS 26's scroll edge
/// effect and Haze's progressive blur.
///
/// Implemented with a stack of clipped [BackdropFilter] bands whose radius
/// follows a geometric ramp, so the blur fades continuously from [edge] to
/// nothing over [span] logical pixels. Bands are cheap enough for app bars but
/// still can be disabled with the global [HazeConfig].
class HazeProgressiveBlur extends StatelessWidget {
  const HazeProgressiveBlur({
    super.key,
    this.edge = HazeEdge.top,
    this.span = 120,
    this.sigma = 18,
    this.tint,
    this.child,
    this.enabled,
    this.overlap = 0.5,
  });

  final HazeEdge edge;

  /// Size of the effect, in logical pixels.
  final double span;

  /// Peak blur radius at [edge].
  final double sigma;

  /// Optional wash that follows the same falloff.
  final Color? tint;

  /// Drawn above the effect. Sizes the widget when provided.
  final Widget? child;

  final bool? enabled;

  /// How much neighbouring bands overlap, smooths out the band steps.
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final config = HazeConfig.of(context);
    final canBlur =
        (enabled ?? config.enabled) &&
        config.canBlur &&
        !isPageTransitionActive(context);
    if (!canBlur || span <= 0 || sigma <= 0) {
      if (child != null) {
        return child!;
      }
      return SizedBox(
        height: edge.isVertical ? span : null,
        width: edge.isVertical ? null : span,
      );
    }

    final bands = config.quality.bandCount.clamp(1, 16);
    final scale = config.quality.sigmaScale;
    final step = span / bands;
    final bandSize = step * (1 + overlap.clamp(0, 1));

    final children = <Widget>[
      for (int i = 0; i < bands; i++)
        _HazeBand(
          edge: edge,
          start: i * step,
          size: bandSize,
          // Full strength at the outer edge, fading geometrically inward.
          sigma: sigma * scale * math.pow(1 - i / bands, 1.4).toDouble(),
        ),
      if (tint != null)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: switch (edge) {
                    HazeEdge.top => Alignment.topCenter,
                    HazeEdge.bottom => Alignment.bottomCenter,
                    HazeEdge.left => Alignment.centerLeft,
                    HazeEdge.right => Alignment.centerRight,
                  },
                  end: switch (edge) {
                    HazeEdge.top => Alignment.bottomCenter,
                    HazeEdge.bottom => Alignment.topCenter,
                    HazeEdge.left => Alignment.centerRight,
                    HazeEdge.right => Alignment.centerLeft,
                  },
                  colors: <Color>[tint!, tint!.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ?child,
    ];

    final stack = Stack(
      fit: StackFit.passthrough,
      children: children,
    );
    if (child != null) {
      return stack;
    }
    return SizedBox(
      height: edge.isVertical ? span : null,
      width: edge.isVertical ? null : span,
      child: stack,
    );
  }
}

class _HazeBand extends StatelessWidget {
  const _HazeBand({
    required this.edge,
    required this.start,
    required this.size,
    required this.sigma,
  });

  final HazeEdge edge;
  final double start;
  final double size;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final Widget band = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.mirror,
        ),
        child: const SizedBox.expand(),
      ),
    );
    return switch (edge) {
      HazeEdge.top => Positioned(
        top: start,
        left: 0,
        right: 0,
        height: size,
        child: band,
      ),
      HazeEdge.bottom => Positioned(
        bottom: start,
        left: 0,
        right: 0,
        height: size,
        child: band,
      ),
      HazeEdge.left => Positioned(
        left: start,
        top: 0,
        bottom: 0,
        width: size,
        child: band,
      ),
      HazeEdge.right => Positioned(
        right: start,
        top: 0,
        bottom: 0,
        width: size,
        child: band,
      ),
    };
  }
}
