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

import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:material_ui/material_ui.dart';

/// Rendering budget of the Haze glass system.
///
/// Mirrors Haze's performance modes: higher quality means more blur, more
/// progressive-blur bands, grain on the glass and more light.
enum HazeQuality with EnumWithLabel {
  quality(sigmaScale: 1.0, bandCount: 10, noiseScale: 1.0),
  balanced(sigmaScale: 0.72, bandCount: 7, noiseScale: 0.85),
  performance(sigmaScale: 0.45, bandCount: 4, noiseScale: 0),
  none(sigmaScale: 0, bandCount: 0, noiseScale: 0);

  const HazeQuality({
    required this.sigmaScale,
    required this.bandCount,
    required this.noiseScale,
  });

  final double sigmaScale;
  final int bandCount;

  /// Scales the Haze `noiseFactor` film grain; `0` disables it (an extra
  /// layer the lowest tiers should not pay for).
  final double noiseScale;

  @override
  String get label => switch (this) {
    HazeQuality.quality => '高质量',
    HazeQuality.balanced => '均衡',
    HazeQuality.performance => '流畅',
    HazeQuality.none => '关闭模糊',
  };
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

/// Set while an Android predictive back gesture is in flight (drag *or*
/// settle), by `BackGestureBridge` in `page_transitions.dart`.
///
/// Glass deliberately does **not** react to this any more. Every surface keeps
/// the material it was built with for its whole lifetime: the old behaviour —
/// dropping to an opaque tint while a route animated — changed the colour of
/// the app bar, the dock and every dialog on the first frame and changed it
/// back on the last one, which is exactly the "the chrome flashes on every
/// navigation" feeling. The rendering budget is chosen once, through
/// [HazeQuality], instead.
final ValueNotifier<bool> backGestureInFlight = ValueNotifier(false);
