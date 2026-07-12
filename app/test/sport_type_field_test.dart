import 'package:cardio/core/db/providers.dart';
import 'package:cardio/features/recording/sport_type_field.dart';
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
