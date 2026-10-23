import 'package:cardio/core/db/providers.dart';
import 'package:cardio/features/recording/sport_type_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens recent sport types on tap without editing text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Running');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith(
            (_) async => ['Running', 'Cycling'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cycling'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.text, 'Running');
    expect(find.text('Cycling'), findsOneWidget);
  });

  testWidgets('selects a recent sport by tapping an option', (tester) async {
    final controller = TextEditingController(text: 'Running');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith(
            (_) async => ['Running', 'Cycling'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Cycling'));
    await tester.pump();

    expect(controller.text, 'Cycling');
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('supports keyboard selection while recent types are open', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Running');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith(
            (_) async => ['Running', 'Cycling'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    // First press reveals the highlight on the first option; a second steps to
    // the next one.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'Cycling');
    expect(focusNode.hasFocus, isFalse);
    expect(find.text('Running'), findsNothing);
  });

  testWidgets('first arrow-down highlights and selects the first option', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Running');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith(
            (_) async => ['Running', 'Cycling'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'Running');
    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('options fit above the keyboard and scroll without selecting', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final sports = [for (var i = 0; i < recentSportsTypeLimit; i++) 'Sport $i'];

    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    // Keyboard covering the bottom half of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith((_) async => sports),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump();

    final listBottom = tester
        .getBottomLeft(find.byType(SingleChildScrollView))
        .dy;
    expect(listBottom, lessThanOrEqualTo(300));

    final last = find.text('Sport ${recentSportsTypeLimit - 1}');
    await tester.drag(find.text('Sport 1'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(focusNode.hasFocus, isTrue);
    expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(300));

    await tester.tap(last);
    await tester.pump();
    expect(controller.text, 'Sport ${recentSportsTypeLimit - 1}');
  });

  testWidgets('options shrink when the keyboard appears after they open', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final sports = [for (var i = 0; i < recentSportsTypeLimit; i++) 'Sport $i'];

    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Mirrors the app: a shell Scaffold whose body is a nested navigator (as
    // StatefulShellRoute builds). The shell strips the keyboard inset from
    // its body's MediaQuery and shrinks the body instead, so the nested
    // overlay never sees viewInsets.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith((_) async => sports),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Start recording')),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 56),
                      SportTypeField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Sport type',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: const SizedBox(height: 80),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump();

    // The keyboard slides up only after the list is already showing.
    for (final inset in [100.0, 200.0, 300.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final listBottom = tester
        .getBottomLeft(find.byType(SingleChildScrollView))
        .dy;
    expect(listBottom, lessThanOrEqualTo(300));
  });

  testWidgets(
    'selects an option with a mouse click',
    (tester) async {
      final controller = TextEditingController(text: 'Running');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            distinctSportTypesProvider.overrideWith(
              (_) async => ['Running', 'Cycling'],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SportTypeField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'Sport type'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.tap(find.text('Cycling'), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(controller.text, 'Cycling');
      expect(focusNode.hasFocus, isFalse);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('enter keeps typed custom sport when no option was highlighted', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Running');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distinctSportTypesProvider.overrideWith(
            (_) async => ['Running', 'Cycling'],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SportTypeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Sport type'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Rowing');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, 'Rowing');
    expect(focusNode.hasFocus, isFalse);
    expect(find.text('Cycling'), findsNothing);
  });
}
