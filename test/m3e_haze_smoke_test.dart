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

import 'package:PiliPlus/common/m3e/m3e.dart';
import 'package:PiliPlus/common/widgets/haze/haze.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _buildTestApp({
  bool enabled = true,
  HazeQuality quality = HazeQuality.balanced,
  bool reduceTransparency = false,
}) {
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFB7299)),
  ).toM3ETheme();

  return MaterialApp(
    theme: theme,
    home: HazeConfig(
      enabled: enabled,
      quality: quality,
      reduceTransparency: reduceTransparency,
      child: Scaffold(
        appBar: AppBar(title: const Text('M3E')),
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: ColoredBox(color: Color(0xFFFFC107)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: HazeGlass(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('glass'),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: HazeProgressiveBlur(
                edge: HazeEdge.top,
                span: 120,
                child: SizedBox(height: 120),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.home), label: 'home'),
            NavigationDestination(icon: Icon(Icons.person), label: 'me'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Material 3 Expressive theme builds', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(find.text('M3E'), findsOneWidget);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('glass returns after a route transition settles', (tester) async {
    bool? transitioning;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => HazeTransitionGate(
                builder: (context, active) {
                  transitioning = active;
                  return const Scaffold(body: Text('destination'));
                },
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(transitioning, isTrue);
    await tester.pumpAndSettle();
    expect(transitioning, isFalse);
  });

  testWidgets('interactive back drops glass and restores it on release', (tester) async {
    addTearDown(() => backGestureInFlight.value = false);
    bool? transitioning;
    await tester.pumpWidget(MaterialApp(
      home: HazeTransitionGate(
        builder: (context, active) {
          transitioning = active;
          return const Scaffold(body: Text('surface'));
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(transitioning, isFalse);
    backGestureInFlight.value = true;
    await tester.pump();
    expect(transitioning, isTrue);
    backGestureInFlight.value = false;
    await tester.pump();
    expect(transitioning, isFalse);
  });

  testWidgets('progressive edge keeps an opaque tint with blur off', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HazeConfig(
        quality: HazeQuality.none,
        child: Scaffold(
          body: HazeProgressiveBlur(
            tint: Color(0x6688AACC),
            child: SizedBox(height: 120),
          ),
        ),
      ),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox &&
            widget.color == const Color(0xFF88AACC),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Haze glass degrades without blur', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        enabled: false,
        quality: HazeQuality.none,
        reduceTransparency: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('glass'), findsOneWidget);
  });
}
