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

import 'package:PiliPlus/common/transition/page_transitions.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Animation<double> animation, void Function(double) onProgress) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ContinuousBackProgress(
      animation: animation,
      builder: (context, progress) {
        onProgress(progress);
        return const SizedBox.shrink();
      },
    ),
  );
}

void main() {
  test('right-edge back follows the finger, including a reversal', () {
    PredictiveBackEvent event(double x, double y, double progress) =>
        PredictiveBackEvent.fromMap({
          'touchOffset': <double>[x, y],
          'progress': progress,
          'swipeEdge': 1,
        });
    final start = event(390, 300, 0);
    expect(start.swipeEdge, SwipeEdge.right);
    final (out, down) = backGestureOffset(
      event: event(280, 330, 0.4),
      start: start.touchOffset,
      edge: start.swipeEdge,
      size: const Size(400, 800),
    );
    expect(out, -110);
    expect(down, greaterThan(0));
    final (reversed, _) = backGestureOffset(
      event: event(370, 300, 0.1),
      start: start.touchOffset,
      edge: start.swipeEdge,
      size: const Size(400, 800),
    );
    expect(reversed, -20);
  });

  test('left-edge back clamps movement towards the wrong edge', () {
    final start = PredictiveBackEvent.fromMap({
      'touchOffset': <double>[10, 300],
      'progress': 0.0,
      'swipeEdge': 0,
    });
    final move = PredictiveBackEvent.fromMap({
      'touchOffset': <double>[2, 300],
      'progress': 0.2,
      'swipeEdge': 0,
    });
    final (dx, dy) = backGestureOffset(
      event: move,
      start: start.touchOffset,
      edge: start.swipeEdge,
      size: const Size(400, 800),
    );
    expect(dx, 0);
    expect(dy, 0);
  });

  testWidgets('predictive back commit stays continuous', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    addTearDown(controller.dispose);
    addTearDown(BackGestureBridge.debugEnd);

    double progress = 0;
    await tester.pumpWidget(_host(controller, (v) => progress = v));
    expect(progress, closeTo(0, 0.001));

    // The user drags the back gesture halfway.
    controller.value = 0.4;
    await tester.pump();
    expect(progress, closeTo(0.6, 0.001));

    // Commit: the handler announces the reached progress on the bridge
    // *before* the framework resets the controller to 1.0 and reverses it.
    BackGestureBridge.debugArmCommit(0.6);
    controller.reverse(from: 1.0);
    await tester.pump();
    // The progress must not snap back to zero when the jump happens.
    expect(progress, closeTo(0.6, 0.001));

    await tester.pump(const Duration(milliseconds: 320));
    expect(progress, closeTo(1.0, 0.02));
    controller.stop();
    BackGestureBridge.debugEnd();
  });

  testWidgets('predictive back cancel springs back', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    addTearDown(controller.dispose);

    double progress = 0;
    await tester.pumpWidget(_host(controller, (v) => progress = v));

    controller.value = 0.4;
    await tester.pump();
    expect(progress, closeTo(0.6, 0.001));

    // Cancel: the controller animates back to 1.0 continuously.
    controller.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(progress, lessThan(0.6));

    await tester.pumpAndSettle();
    expect(progress, closeTo(0.0, 0.02));
    controller.stop();
  });

  testWidgets('a jump to top without a commit is not latched', (tester) async {
    // The old heuristic remapped *any* jump to 1.0, so a janky frame or a
    // plain push could latch the progress at a stale value. The bridge makes
    // the remap conditional on a real commit.
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    addTearDown(controller.dispose);
    addTearDown(BackGestureBridge.debugEnd);

    double progress = 0;
    await tester.pumpWidget(_host(controller, (v) => progress = v));

    controller.value = 0.4;
    await tester.pump();
    expect(progress, closeTo(0.6, 0.001));

    // Jump back to 1.0 *without* arming a commit: this is a cancel/push, so
    // the progress must return to 0, not latch at 0.6.
    controller.value = 1.0;
    await tester.pump();
    expect(progress, closeTo(0.0, 0.001));
    controller.stop();
  });

  testWidgets('a stale commit remap never leaks into the next gesture', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    addTearDown(controller.dispose);
    addTearDown(BackGestureBridge.debugEnd);

    double progress = 0;
    await tester.pumpWidget(_host(controller, (v) => progress = v));

    // First gesture commits at 0.6 and settles to fully dismissed.
    controller.value = 0.4;
    await tester.pump();
    BackGestureBridge.debugArmCommit(0.6);
    controller.reverse(from: 1.0);
    await tester.pump(const Duration(milliseconds: 320));
    expect(progress, closeTo(1.0, 0.02));
    BackGestureBridge.debugEnd();

    // A *new* gesture (new epoch) drags the value up from dismissed; the old
    // remap must be cleared so progress tracks 1 - value again.
    controller.value = 0.0;
    await tester.pump();
    expect(progress, closeTo(1.0, 0.001));
    BackGestureBridge.debugArmCommit(0.0); // bumps the epoch
    controller.value = 0.7;
    await tester.pump();
    expect(progress, closeTo(0.3, 0.001));
    controller.stop();
    BackGestureBridge.debugEnd();
  });

  testWidgets('glass scope paints app bar and dialog', (tester) async {
    await tester.pumpWidget(
      M3EGlassScope(
        enabled: true,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('glass bar')),
            body: const AlertDialog(title: Text('glass dialog')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('glass bar'), findsOneWidget);
    expect(find.text('glass dialog'), findsOneWidget);
  });
}
