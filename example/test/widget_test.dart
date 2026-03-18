// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Gallery navigates to multiple controllers example', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('State Lifecycle Observer Gallery'), findsOneWidget);
    expect(find.text('Refutation: Multiple Controllers'), findsOneWidget);

    await tester.tap(find.text('Refutation: Multiple Controllers'));
    await tester.pumpAndSettle();

    expect(find.text('Multiple Controllers Demo'), findsOneWidget);
    expect(find.text('Text Controller'), findsOneWidget);
  });

  testWidgets('Multiple controllers play button stays in sync', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Refutation: Multiple Controllers'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
  });
}
