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
  testWidgets('predictive back commit stays continuous', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    addTearDown(controller.dispose);

    double progress = 0;
    await tester.pumpWidget(_host(controller, (v) => progress = v));
    expect(progress, closeTo(0, 0.001));

    // The user drags the back gesture halfway.
    controller.value = 0.4;
    await tester.pump();
    expect(progress, closeTo(0.6, 0.001));

    // Commit: the framework resets the controller to 1.0 and reverses it.
    controller.reverse(from: 1.0);
    await tester.pump();
    // The progress must not snap back to zero when the jump happens.
    expect(progress, closeTo(0.6, 0.05));

    await tester.pump(const Duration(milliseconds: 320));
    expect(progress, closeTo(1.0, 0.02));
    controller.stop();
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
