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
/// During a drag the route controller is seeked directly, so
/// [Animation.isAnimating] stays false even though the whole route — and the
/// one underneath — is being transformed every frame. A [BackdropFilter] under
/// that motion has to re-sample and re-blur its backdrop each frame, which is
/// the single most expensive thing the glass system can do. Surfaces read this
/// through [isPageTransitionActive] and drop to their tonally-matched solid
/// fallback for the duration, keeping the gesture at full frame rate.
///
/// Declared here (a leaf both the transitions and the glass can import) rather
/// than in `page_transitions.dart` to keep the dependency one-directional.
final ValueNotifier<bool> backGestureInFlight = ValueNotifier(false);

/// Rebuilds glass only when a route starts/stops animating or a predictive back
/// gesture begins/ends. Listening to animation *status* rather than every tick
/// avoids rebuilding the frosted subtree on every navigation frame, while
/// ensuring the blur actually returns after the transition settles.
class HazeTransitionGate extends StatefulWidget {
  const HazeTransitionGate({super.key, required this.builder});

  final Widget Function(BuildContext context, bool transitioning) builder;

  @override
  State<HazeTransitionGate> createState() => _HazeTransitionGateState();
}

class _HazeTransitionGateState extends State<HazeTransitionGate> {
  Animation<double>? _primary;
  Animation<double>? _secondary;

  @override
  void initState() {
    super.initState();
    backGestureInFlight.addListener(_onStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (primary != _primary) {
      _primary?.removeStatusListener(_onStatusChanged);
      _primary = primary;
      _primary?.addStatusListener(_onStatusChanged);
    }
    if (secondary != _secondary) {
      _secondary?.removeStatusListener(_onStatusChanged);
      _secondary = secondary;
      _secondary?.addStatusListener(_onStatusChanged);
    }
  }

  void _onStatusChanged([AnimationStatus? _]) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _primary?.removeStatusListener(_onStatusChanged);
    _secondary?.removeStatusListener(_onStatusChanged);
    backGestureInFlight.removeListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, isPageTransitionActive(context));
}

/// Whether the route owning [context] is currently animating a page transition.
///
/// A backdrop blur inside a route that is being translated or scaled must
/// re-render the backdrop every frame, which is extremely expensive (especially
/// on Skia). Glass surfaces therefore fall back to their opaque tonal rendering
/// for the duration of a transition, which keeps push/pop/back-gesture motion
/// at full frame rate.
bool isPageTransitionActive(BuildContext context) {
  // A predictive back drag seeks the controller directly, so `isAnimating`
  // misses it; the bridge flag and the route's gesture flag cover the
  // interactive phase. The latter also catches the native Android
  // predictive-back transition, which the app does not drive itself.
  if (backGestureInFlight.value) {
    return true;
  }
  final route = ModalRoute.of(context);
  if (route?.popGestureInProgress ?? false) {
    return true;
  }
  final animation = route?.animation;
  final secondary = route?.secondaryAnimation;
  return (animation?.isAnimating ?? false) ||
      (secondary?.isAnimating ?? false);
}
