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

import 'package:material_ui/material_ui.dart';

/// Rendering budget of the Haze glass system.
///
/// Mirrors Haze's performance modes: higher quality means more blur, more
/// progressive-blur bands and more light on the glass.
enum HazeQuality {
  quality(sigmaScale: 1.0, bandCount: 10),
  balanced(sigmaScale: 0.72, bandCount: 7),
  performance(sigmaScale: 0.45, bandCount: 4),
  none(sigmaScale: 0, bandCount: 0);

  const HazeQuality({required this.sigmaScale, required this.bandCount});

  final double sigmaScale;
  final int bandCount;
}

/// App level configuration for the Haze glass system.
///
/// Values are provided once from [MyApp] so widgets do not have to read
/// preferences themselves and the whole UI reacts to a preference change at
/// the same time.
class HazeConfig extends InheritedWidget {
  const HazeConfig({
    super.key,
    this.enabled = true,
    this.quality = HazeQuality.balanced,
    this.reduceTransparency = false,
    required super.child,
  });

  /// Whether glass surfaces may blur the content behind them.
  final bool enabled;

  final HazeQuality quality;

  /// Accessibility: when true surfaces fall back to opaque material.
  final bool reduceTransparency;

  static const HazeConfig fallback = HazeConfig(child: SizedBox.shrink());

  static HazeConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HazeConfig>() ?? fallback;

  /// Whether glass can currently be painted at all.
  bool get canBlur =>
      enabled && !reduceTransparency && quality != HazeQuality.none;

  HazeConfig copyWith({
    bool? enabled,
    HazeQuality? quality,
    bool? reduceTransparency,
  }) => HazeConfig(
    enabled: enabled ?? this.enabled,
    quality: quality ?? this.quality,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    child: child,
  );

  @override
  bool updateShouldNotify(HazeConfig oldWidget) =>
      enabled != oldWidget.enabled ||
      quality != oldWidget.quality ||
      reduceTransparency != oldWidget.reduceTransparency;
}
