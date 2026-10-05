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

import 'package:PiliPlus/common/m3e/shapes.dart';
import 'package:PiliPlus/common/widgets/haze/haze.dart';
import 'package:PiliPlus/utils/feed_back.dart' show enableFeedback;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Layout and motion tokens for the floating navigation dock.
///
/// The visual language follows the iOS tab bar lens as popularised by
/// FlClash: a pill whose selection is a spring-driven lens that can be
/// dragged across the bar, jelly-stretches with velocity, swells when the bar
/// is pressed and settles with a bounce.
const double _barHeight = 62;
const double _barPadding = 4;
const double _edgeMargin = 21;
const double _shadowRoom = 8;
const double _hitSlop = 8;
const double _maxItemExtent = 72;
const int _fullWidthCount = 5;
const double _iconSize = 24;
const double _labelGap = 2;
const double _labelInset = 2;
const double _labelSize = 10;
const double _minLabelSize = 9;
const double _pressGrowth = 1 / 8;
const double _maxPressGrowth = 16;
const double _lensGrowth = 14;
const double _lensMagnify = 0.12;
const double _hoverMagnet = 0.2;
const double _hoverParallax = 0.5;
const double _hoverAlpha = 0.08;
const double _hoverSwell = 0.4;
const double _jellySpeed = 8;
const double _jellyStretch = 0.25;
const double _overdrag = 0.35;
const double _pullLimit = 7 / 32;
const double _pullStretch = 0.5;
const Duration _flingProjection = Duration(milliseconds: 100);

final SpringDescription _trackSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 120),
);
final SpringDescription _liftSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 280),
  bounce: 0.2,
);
final SpringDescription _settleSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 500),
  bounce: 0.32,
);
final SpringDescription _hoverSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 260),
  bounce: 0.18,
);
final SpringDescription _fadeSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 200),
);

double _rubberBand(double overshoot, double limit) {
  final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
  return limit * pull * overshoot.sign;
}

/// The lens's box, measured from the start edge of the destination at 0.
Rect _lensRect({
  required double position,
  required double velocity,
  required double extent,
  required double height,
  required double lift,
}) {
  final stretch =
      (velocity.abs() / _jellySpeed).clamp(0.0, 1.0) * _jellyStretch;
  final growth = _lensGrowth * 2 * lift;
  final width = (extent + growth) * (1 + stretch);
  final lensHeight = (height + growth) * (1 - stretch / 2);
  return Rect.fromLTWH(
    (position + 0.5) * extent - width / 2,
    (height - lensHeight) / 2,
    width,
    lensHeight,
  );
}

/// A value that springs toward a target the finger may move every frame.
///
/// [AnimationController.animateWith] restarts its ticker, whose first frame
/// reads no elapsed time, so retargeting it on every pointer move holds the
/// value still for as long as the finger keeps moving.
class _Spring extends ChangeNotifier implements ValueListenable<double> {
  _Spring(TickerProvider vsync, this._value) {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _value;
  double _target = 0;
  SpringSimulation? _simulation;
  double _now = 0;
  double _start = 0;

  @override
  double get value => _value;

  double get target => _simulation == null ? _value : _target;

  double get velocity => _simulation?.dx(_now - _start) ?? 0;

  void springTo(double target, SpringDescription spring) {
    _simulation = SpringSimulation(spring, _value, target, velocity);
    _target = target;
    if (_ticker.isActive) {
      _start = _now;
      return;
    }
    _now = _start = 0;
    _ticker.start();
  }

  void jumpTo(double value) {
    _simulation = null;
    _ticker.stop();
    _value = value;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    _now = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final simulation = _simulation!;
    final time = _now - _start;
    if (simulation.isDone(time)) {
      _value = _target;
      _simulation = null;
      _ticker.stop();
    } else {
      _value = simulation.x(time);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

// A soft, wide drop in the manner of iOS rather than a Material elevation.
List<BoxShadow> _dockShadows(ColorScheme colorScheme) {
  final strength = colorScheme.brightness == Brightness.dark ? 3.0 : 1.0;
  return <BoxShadow>[
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.08 * strength),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.04 * strength),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

({double width, double height}) _measureLabel(
  BuildContext context,
  String label,
  TextStyle? style,
) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final size = (width: painter.width, height: painter.height);
  painter.dispose();
  return size;
}

/// A destination of the floating navigation dock.
class FloatingNavigationDestination {
  const FloatingNavigationDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.tooltip,
    this.enabled = true,
  });

  final Widget icon;

  final Widget? selectedIcon;

  final String label;

  final String? tooltip;

  final bool enabled;
}

/// A floating pill of destinations whose selection is a lens that springs
/// between them.
///
/// Pressing swells the whole bar; dragging slides the lens across the bar,
/// selecting where it is let go, and stretches the bar past either end. On
/// desktop the destination under the cursor gets a highlight that leans
/// toward the pointer.
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.destinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
  });

  final List<FloatingNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final height = _DockBar.heightOf(context);
    final bottomMargin = math.max(
      _edgeMargin,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final width = destinations.length >= _fullWidthCount
        ? double.infinity
        : destinations.length * _maxItemExtent + _barPadding * 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _edgeMargin,
        _shadowRoom,
        _edgeMargin,
        bottomMargin,
      ),
      child: RepaintBoundary(
        child: _HitSlop(
          child: SizedBox(
            height: height,
            child: Center(
              child: SizedBox(
                width: width,
                child: _DockBar(
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onDestinationSelected,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets a touch that misses the dock by at most [_hitSlop] still reach it.
class _HitSlop extends SingleChildRenderObjectWidget {
  const _HitSlop({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitSlop();
}

class _RenderHitSlop extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    if (size.isEmpty ||
        !(Offset.zero & size).inflate(_hitSlop).contains(position)) {
      return false;
    }
    if (!hitTestChildren(result, position: _onSpine(position))) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  // A pill's rounded ends clip hit tests; its straight core never does.
  Offset _onSpine(Offset position) {
    final radius = size.shortestSide / 2;
    return Offset(
      position.dx.clamp(radius, size.width - radius),
      size.height / 2,
    );
  }
}

class _DockBar extends StatefulWidget {
  const _DockBar({
    required this.destinations,
    required this.selectedIndex,
    this.onSelected,
  });

  final List<FloatingNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static double heightOf(BuildContext context) =>
      _barHeight +
      MediaQuery.textScalerOf(context).scale(_labelSize) -
      _labelSize;

  @override
  State<_DockBar> createState() => _DockBarState();
}

class _DockBarState extends State<_DockBar> with TickerProviderStateMixin {
  late final _Spring _lens = _Spring(this, _selectedIndex.toDouble());
  late final _Spring _lift = _Spring(this, 0);
  late final _Spring _hover = _Spring(this, 0);
  late final _Spring _hoverShow = _Spring(this, 0);
  late final _Spring _swell = _Spring(this, 0);
  late final _Spring _stretch = _Spring(this, 0);
  late final Listenable _barMotion = Listenable.merge([_swell, _stretch]);
  late final Listenable _motion = Listenable.merge([_lens, _lift]);
  late final Listenable _hoverMotion = Listenable.merge([_hover, _hoverShow]);
  int? _pointer;
  int? _pressedIndex;
  double _pressX = 0;
  bool _dragging = false;
  VelocityTracker? _tracker;
  Offset? _cursor;
  final ValueNotifier<double?> _hoverAt = ValueNotifier<double?>(null);

  int get _lastIndex => math.max(0, widget.destinations.length - 1);

  int get _selectedIndex => widget.selectedIndex.clamp(0, _lastIndex);

  @override
  void didUpdateWidget(covariant _DockBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rest = _lensRest;
    if (_pressedIndex == null && _lens.target != rest) {
      _lens.springTo(rest, _settleSpring);
    }
  }

  @override
  void dispose() {
    _lens.dispose();
    _lift.dispose();
    _hover.dispose();
    _hoverShow.dispose();
    _swell.dispose();
    _stretch.dispose();
    _hoverAt.dispose();
    super.dispose();
  }

  void _haptic() {
    if (enableFeedback) {
      HapticFeedback.selectionClick();
    }
  }

  double _positionAt(Offset localPosition) {
    final width = context.size!.width;
    final dx = Directionality.of(context) == TextDirection.ltr
        ? localPosition.dx
        : width - localPosition.dx;
    final extent = (width - _barPadding * 2) / widget.destinations.length;
    final position = (dx - _barPadding) / extent - 0.5;
    if (position < 0) {
      return _rubberBand(position, _overdrag);
    }
    if (position > _lastIndex) {
      return _lastIndex + _rubberBand(position - _lastIndex, _overdrag);
    }
    return position;
  }

  int _indexAt(double position) => position.round().clamp(0, _lastIndex);

  double _leanAt(double position) {
    final index = _indexAt(position);
    return index + (position - index) * _hoverMagnet;
  }

  double get _lensRest {
    final hoverAt = _hoverAt.value;
    if (hoverAt == null || _indexAt(hoverAt) != _selectedIndex) {
      return _selectedIndex.toDouble();
    }
    return _leanAt(hoverAt);
  }

  // A lens headed to a just-tapped destination is left for didUpdateWidget.
  void _leanLens() {
    if (_pressedIndex != null || _indexAt(_lens.target) != _selectedIndex) {
      return;
    }
    final rest = _lensRest;
    if (_lens.target != rest) {
      _lens.springTo(rest, _hoverSpring);
    }
  }

  void _showHover() {
    final cursor = _cursor;
    if (cursor == null || _pointer != null || widget.destinations.isEmpty) {
      return;
    }
    final position = _positionAt(cursor);
    final target = _leanAt(position);
    _hoverAt.value = position;
    if (_hoverShow.target == 0 && _hoverShow.value == 0) {
      _hover.jumpTo(target);
    } else {
      _hover.springTo(target, _hoverSpring);
    }
    _hoverShow.springTo(1, _fadeSpring);
    _leanLens();
  }

  void _settleSwell() {
    final target = _cursor == null ? 0.0 : _hoverSwell;
    if (_pointer == null && _swell.target != target) {
      _swell.springTo(target, _settleSpring);
    }
  }

  void _handleHover(PointerHoverEvent event) {
    // The engine synthesizes a hover before a touch lands, and the touch
    // pointer lingers until removed, so a tap would leave the highlight on.
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    _cursor = event.localPosition;
    _showHover();
    _settleSwell();
  }

  void _handleExit(PointerExitEvent event) {
    _cursor = null;
    _hoverShow.springTo(0, _fadeSpring);
    _hoverAt.value = null;
    _leanLens();
    _settleSwell();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _hoverShow.springTo(0, _fadeSpring);
    _hoverAt.value = null;
    _swell.springTo(1, _liftSpring);
    _press(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer == _pointer) {
      _tracker?.addPosition(event.timeStamp, event.localPosition);
      _slide(event.localPosition);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    final tracker = _tracker;
    _tracker = null;
    if (event is PointerUpEvent && tracker != null) {
      _fling(tracker.getVelocity().pixelsPerSecond.dx);
    }
    _release(commit: event is PointerUpEvent);
    _stretch.springTo(0, _settleSpring);
    if (_cursor != null) {
      _cursor = event.localPosition;
      _showHover();
    }
    _settleSwell();
  }

  void _press(Offset localPosition) {
    if (widget.destinations.isEmpty) {
      return;
    }
    final index = _indexAt(_positionAt(localPosition));
    _pressedIndex = index;
    _pressX = localPosition.dx;
    _dragging = false;
    _lift.springTo(1, _liftSpring);
    _lens.springTo(index.toDouble(), _settleSpring);
  }

  void _slide(Offset localPosition) {
    if (_pressedIndex == null) {
      return;
    }
    if (!_dragging) {
      if ((localPosition.dx - _pressX).abs() < kTouchSlop) {
        return;
      }
      _dragging = true;
    }
    final size = context.size!;
    final overshoot =
        localPosition.dx - localPosition.dx.clamp(0.0, size.width);
    _stretch.springTo(
      _rubberBand(overshoot, size.shortestSide * _pullLimit),
      _trackSpring,
    );
    final position = _positionAt(localPosition);
    _lens.springTo(position, _trackSpring);
    final index = _indexAt(position);
    if (index != _pressedIndex) {
      _haptic();
      _pressedIndex = index;
    }
  }

  /// Carries a drag let go mid-flick on to the next destination, at most one
  /// past the one under the finger.
  void _fling(double velocityX) {
    final pressed = _pressedIndex;
    if (!_dragging || pressed == null) {
      return;
    }
    final extent =
        (context.size!.width - _barPadding * 2) / widget.destinations.length;
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final lead =
        velocityX /
        extent *
        direction *
        _flingProjection.inMicroseconds /
        Duration.microsecondsPerSecond;
    final index = (_lens.target + lead)
        .round()
        .clamp(pressed - 1, pressed + 1)
        .clamp(0, _lastIndex);
    if (index != pressed) {
      _haptic();
      _pressedIndex = index;
    }
  }

  void _release({required bool commit}) {
    final index = _pressedIndex;
    if (index == null) {
      return;
    }
    _pressedIndex = null;
    _dragging = false;
    _lift.springTo(0, _settleSpring);
    if (!commit) {
      _lens.springTo(_selectedIndex.toDouble(), _settleSpring);
      return;
    }
    _lens.springTo(index.toDouble(), _settleSpring);
    if (index != widget.selectedIndex) {
      widget.onSelected?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: _labelSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    );
    final labels = <({double width, double height})>[
      for (final destination in widget.destinations)
        _measureLabel(context, destination.label, labelStyle),
    ];
    final widest = labels.fold(
      0.0,
      (width, label) => math.max(width, label.width),
    );
    final lineHeight = labels.fold(
      0.0,
      (height, label) => math.max(height, label.height),
    );

    final bar = HazeGlass(
      shape: M3EShape.full,
      tint: colorScheme.surfaceContainer,
      tintOpacity: theme.brightness == Brightness.dark ? 0.72 : 0.78,
      shadows: _dockShadows(colorScheme),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: MouseRegion(
          onHover: _handleHover,
          onExit: _handleExit,
          child: Padding(
            padding: const EdgeInsets.all(_barPadding),
            // Above the LayoutBuilder: rebuilding anything under one relays
            // it out, and that repaint would otherwise reach the whole dock.
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extent =
                      constraints.maxWidth /
                      math.max(1, widget.destinations.length);
                  final room = extent - _labelInset * 2;
                  final labelScale = widest <= room
                      ? 1.0
                      : math.max(room / widest, _minLabelSize / _labelSize);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      if (widget.destinations.isNotEmpty)
                        AnimatedBuilder(
                          animation: _motion,
                          builder: (_, _) => _Lens(
                            position: _lens.value,
                            velocity: _lens.velocity,
                            extent: extent,
                            height: constraints.maxHeight,
                            lift: _lift.value,
                          ),
                        ),
                      if (widget.destinations.isNotEmpty)
                        AnimatedBuilder(
                          animation: _hoverMotion,
                          builder: (_, _) => _HoverHighlight(
                            position: _hover.value,
                            extent: extent,
                            opacity: _hoverShow.value,
                          ),
                        ),
                      Row(
                        children: <Widget>[
                          for (final (index, destination)
                              in widget.destinations.indexed)
                            Expanded(
                              child: _DockItem(
                                destination: destination,
                                selected: index == _selectedIndex,
                                index: index,
                                lens: _lens,
                                hoverAt: _hoverAt,
                                lift: _lift,
                                labelStyle: labelStyle?.copyWith(
                                  fontSize: _labelSize * labelScale,
                                ),
                                labelHeight: lineHeight,
                                labelOverflows:
                                    labels[index].width * labelScale > room,
                                onActivate: () =>
                                    widget.onSelected?.call(index),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _barMotion,
      builder: (_, child) => _PressTransform(
        lift: _swell.value,
        pull: Offset(_stretch.value, 0),
        child: child,
      ),
      child: bar,
    );
  }
}

/// The pointer's highlight, drawn to the destination under it and leaning a
/// little toward the cursor, as iPadOS highlights a tab bar item; the item
/// under it follows the cursor half as far.
class _HoverHighlight extends StatelessWidget {
  const _HoverHighlight({
    required this.position,
    required this.extent,
    required this.opacity,
  });

  final double position;
  final double extent;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final alpha = _hoverAlpha * opacity.clamp(0.0, 1.0);
    if (alpha == 0) {
      return const SizedBox.shrink();
    }
    return Positioned.directional(
      textDirection: Directionality.of(context),
      start: position * extent,
      top: 0,
      bottom: 0,
      width: extent,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: alpha),
          shape: M3EShape.full,
        ),
      ),
    );
  }
}

/// The lens: the spring-driven pill that marks the selection.
class _Lens extends StatelessWidget {
  const _Lens({
    required this.position,
    required this.velocity,
    required this.extent,
    required this.height,
    required this.lift,
  });

  final double position;
  final double velocity;
  final double extent;
  final double height;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rect = _lensRect(
      position: position,
      velocity: velocity,
      extent: extent,
      height: height,
      lift: lift,
    );
    return PositionedDirectional(
      start: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Color.alphaBlend(
            colorScheme.onSecondaryContainer.withValues(
              alpha: 0.08 * lift.clamp(0.0, 1.0),
            ),
            colorScheme.secondaryContainer,
          ),
          shape: M3EShape.full,
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.index,
    required this.lens,
    required this.hoverAt,
    required this.lift,
    required this.labelStyle,
    required this.labelHeight,
    required this.labelOverflows,
    required this.onActivate,
  });

  final FloatingNavigationDestination destination;
  final bool selected;
  final int index;
  final _Spring lens;

  /// Where the pointer hovers, in destinations from the first one's center.
  final ValueListenable<double?> hoverAt;
  final ValueListenable<double> lift;
  final TextStyle? labelStyle;
  final double labelHeight;
  final bool labelOverflows;
  final VoidCallback onActivate;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem>
    with SingleTickerProviderStateMixin {
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) {
        widget.onActivate();
        return null;
      },
    ),
  };
  late final _Spring _parallax = _Spring(this, 0);
  late final Listenable _motion = Listenable.merge(<Listenable>[
    widget.lens,
    widget.lift,
    _parallax,
  ]);
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.hoverAt.addListener(_followPointer);
  }

  @override
  void didUpdateWidget(covariant _DockItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoverAt != widget.hoverAt) {
      oldWidget.hoverAt.removeListener(_followPointer);
      widget.hoverAt.addListener(_followPointer);
    }
    _followPointer();
  }

  @override
  void dispose() {
    widget.hoverAt.removeListener(_followPointer);
    _parallax.dispose();
    super.dispose();
  }

  void _followPointer() {
    final hoverAt = widget.hoverAt.value;
    final offset = hoverAt == null ? 0.0 : hoverAt - widget.index;
    final target = offset.abs() > 0.5
        ? 0.0
        : offset * _hoverMagnet * _hoverParallax;
    if (target != _parallax.target) {
      _parallax.springTo(target, _hoverSpring);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final destination = widget.destination;
    final content = AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        // How much of the lens sits over this destination.
        final emphasis = (1 - (widget.lens.value - widget.index).abs()).clamp(
          0.0,
          1.0,
        );
        final lift = widget.lift.value;
        final color = destination.enabled
            ? Color.lerp(
                colorScheme.onSurfaceVariant,
                colorScheme.primary,
                emphasis,
              )!
            : colorScheme.onSurface.withValues(alpha: 0.38);
        final selectedIcon = destination.selectedIcon;
        final icon = IconTheme.merge(
          data: IconThemeData(size: _iconSize, color: color),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (selectedIcon == null)
                destination.icon
              else ...<Widget>[
                Opacity(opacity: 1 - emphasis, child: destination.icon),
                Opacity(opacity: emphasis, child: selectedIcon),
              ],
            ],
          ),
        );
        return Transform.scale(
          scale: 1 + _lensMagnify * emphasis * lift,
          child: FractionalTranslation(
            translation: Offset(_parallax.value, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                icon,
                const SizedBox(height: _labelGap),
                SizedBox(
                  height: widget.labelHeight,
                  child: Center(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: widget.labelStyle?.copyWith(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return FocusableActionDetector(
      actions: _actions,
      enabled: destination.enabled,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      child: Semantics(
        container: true,
        button: true,
        selected: widget.selected,
        label: destination.label,
        excludeSemantics: true,
        onTap: destination.enabled ? widget.onActivate : null,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: _focused
                ? colorScheme.onSurface.withValues(alpha: 0.1)
                : Colors.transparent,
            shape: _focused
                ? M3EShape.full.copyWith(
                    side: BorderSide(color: colorScheme.secondary, width: 2),
                  )
                : M3EShape.full,
          ),
          child: widget.labelOverflows
              ? Tooltip(
                  message: destination.tooltip ?? destination.label,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

class _PressTransform extends SingleChildRenderObjectWidget {
  const _PressTransform({required this.lift, required this.pull, super.child});

  final double lift;
  final Offset pull;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPressTransform(lift, pull);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressTransform renderObject,
  ) {
    renderObject
      ..lift = lift
      ..pull = pull;
  }
}

/// Swells the bar under a press and stretches it after a dragging finger,
/// springing back on release.
class _RenderPressTransform extends RenderProxyBox {
  _RenderPressTransform(this._lift, this._pull);

  double _lift;
  Offset _pull;

  set lift(double value) {
    if (value == _lift) {
      return;
    }
    _lift = value;
    markNeedsPaint();
  }

  set pull(Offset value) {
    if (value == _pull) {
      return;
    }
    _pull = value;
    markNeedsPaint();
  }

  Matrix4 get _transform {
    final swell =
        1 +
        _lift * math.min(_pressGrowth * 2, _maxPressGrowth / size.longestSide);
    final scaleX = swell * (1 + _pull.dx.abs() / size.width * _pullStretch);
    final scaleY = swell * (1 + _pull.dy.abs() / size.height * _pullStretch);
    final center = size.center(Offset.zero);
    return Matrix4.diagonal3Values(scaleX, scaleY, 1)..setTranslationRaw(
      center.dx * (1 - scaleX) + _pull.dx,
      center.dy * (1 - scaleY) + _pull.dy,
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty || (_lift == 0 && _pull == .zero)) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }
}
