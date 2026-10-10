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
/// follows an exponential falloff — Haze's default `HazeProgressive.exponential`
/// mode — so the blur is strongest at [edge] and eases continuously down to a
/// soft floor over [span] logical pixels instead of stepping to zero. Bands
/// overlap by [overlap] to hide the discrete steps. Cheap enough for app bars
/// but still disabled with the global [HazeConfig] on the lower tiers.
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
    this.falloff = 3.0,
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

  /// Exponential decay constant of the sigma ramp across [span]. Larger values
  /// concentrate the blur nearer the [edge]; `3.0` matches Haze's exponential
  /// progressive default (the innermost band settles at ~5% of [sigma]).
  final double falloff;

  @override
  Widget build(BuildContext context) => HazeTransitionGate(
    builder: _buildBlur,
  );

  Widget _buildBlur(BuildContext context, bool transitionActive) {
    final config = HazeConfig.of(context);
    final canBlur =
        (enabled ?? config.enabled) && config.canBlur && !transitionActive;
    if (!canBlur || span <= 0 || sigma <= 0) {
      final fallback = child ?? SizedBox(
        height: edge.isVertical ? span : null,
        width: edge.isVertical ? null : span,
      );
      if (tint == null) {
        return fallback;
      }
      // The scroll edge must not vanish when quality is "none", the user
      // requests less transparency, or a route is being transformed. Match
      // the tint during motion; fully cover it when blur is unavailable.
      final opacity = transitionActive && config.canBlur
          ? (tint!.a + 0.30).clamp(0.0, 1.0)
          : 1.0;
      return ColoredBox(
        color: tint!.withValues(alpha: opacity),
        child: fallback,
      );
    }

    final int bands = config.quality.bandCount.clamp(2, 16);
    final double scale = config.quality.sigmaScale;
    final double peak = sigma * scale;
    final double step = span / bands;
    final double overlapClamped = overlap.clamp(0.0, 1.0);
    // Feather every band's outer edge over this many pixels so the cumulative
    // blur eases across a band boundary instead of stepping.
    final double feather = step * overlapClamped;

    // Exponential (Haze `HazeProgressive.exponential`) ramp: each band is
    // anchored at [edge] and reaches `step * (i + 1)` inward. Because a
    // BackdropFilter composes the blur of everything painted beneath it, the
    // cumulative sigma at the edge telescopes to [peak] and decays smoothly
    // towards zero at `span`. Per-band sigma is `peak · r^i · √(1 − r²)` with
    // `r = e^(−falloff/bands)`, which makes the cumulative profile a clean
    // exponential in distance and keeps the effect monotonic (no banding).
    // Keep the square-root normalisation finite even for a caller-provided
    // zero/negative falloff (which otherwise makes every band NaN).
    final double r = math.exp(-math.max(falloff, 0.001) / bands);
    final double norm = math.sqrt(1 - r * r);

    final children = <Widget>[
      // Widest/weakest band first (bottom of the stack) so the strongest,
      // narrowest band lands on top at the edge.
      for (int i = bands - 1; i >= 0; i--)
        _HazeBand(
          edge: edge,
          reach: step * (i + 1),
          sigma: peak * math.pow(r, i).toDouble() * norm,
          fadeStop: feather <= 0 ? 1.0 : 1.0 - feather / (step * (i + 1)),
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

/// One band of the progressive blur: a [BackdropFilter] anchored at [edge] that
/// reaches [reach] pixels inward, whose blur contribution is feathered to
/// transparent over its outer edge by a [ShaderMask] (`dstIn`).
///
/// Stacking these — weakest/widest at the bottom, strongest/narrowest on top —
/// composes a smooth, monotonically-decreasing progressive blur: at any point
/// the visible blur is the Gaussian composition of every band that still has
/// opacity there, so it is strongest at the edge and eases to nothing at `span`
/// with no hard steps.
class _HazeBand extends StatelessWidget {
  const _HazeBand({
    required this.edge,
    required this.reach,
    required this.sigma,
    required this.fadeStop,
  });

  final HazeEdge edge;

  /// Distance from [edge] this band covers, in logical pixels.
  final double reach;

  /// Gaussian sigma applied by this band.
  final double sigma;

  /// Normalised position (0..1) within the band where the outer-edge feather
  /// begins; the blur is fully opaque before it and fades to zero at 1.0.
  final double fadeStop;

  @override
  Widget build(BuildContext context) {
    // Blur is anchored at the edge and feathers out towards `reach`.
    final Alignment begin = switch (edge) {
      HazeEdge.top => Alignment.topCenter,
      HazeEdge.bottom => Alignment.bottomCenter,
      HazeEdge.left => Alignment.centerLeft,
      HazeEdge.right => Alignment.centerRight,
    };
    final Alignment end = switch (edge) {
      HazeEdge.top => Alignment.bottomCenter,
      HazeEdge.bottom => Alignment.topCenter,
      HazeEdge.left => Alignment.centerRight,
      HazeEdge.right => Alignment.centerLeft,
    };

    final Widget band = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect rect) => LinearGradient(
        begin: begin,
        end: end,
        colors: <Color>[
          Colors.white,
          Colors.white,
          Colors.white.withValues(alpha: 0),
        ],
        stops: <double>[0.0, fadeStop.clamp(0.0, 1.0), 1.0],
      ).createShader(rect),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.mirror,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    return switch (edge) {
      HazeEdge.top => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: reach,
        child: band,
      ),
      HazeEdge.bottom => Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: reach,
        child: band,
      ),
      HazeEdge.left => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: reach,
        child: band,
      ),
      HazeEdge.right => Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: reach,
        child: band,
      ),
    };
  }
}
