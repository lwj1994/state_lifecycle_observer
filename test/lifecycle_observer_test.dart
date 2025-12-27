import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

// --- Test Widgets & Observers ---

class TestController {
  bool isDisposed = false;
  int id;
  TestController(this.id);
  void dispose() {
    isDisposed = true;
  }
}

class TestObserver extends LifecycleObserver<TestController> {
  TestObserver(
    super.state, {
    super.key,
  });

  @override
  TestController buildTarget() {
    // Determine ID based on key if possible, else default to 0
    final id = (key?.call() as int?) ?? 0;
    return TestController(id);
  }

  @override
  void onDisposeTarget(TestController target) {
    target.dispose();
  }
}

class TestWidget extends StatefulWidget {
  final int id;
  const TestWidget({super.key, this.id = 0});

  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> with LifecycleOwnerMixin {
  late TestObserver observer;

  @override
  void initState() {
    super.initState();
    observer = TestObserver(
      this,
      key: () => widget.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Explicitly do NOT call super.build(context) to test manual/mixin behavior if needed,
    // but the mixin docs say we should.
    // However, the mixin overrides build.
    return super.build(context);
  }
}

class NoMixinWidget extends StatefulWidget {
  const NoMixinWidget({super.key});

  @override
  State<NoMixinWidget> createState() => _NoMixinWidgetState();
}

class _NoMixinWidgetState extends State<NoMixinWidget> {
  // Intentionally NOT mixing in LifecycleObserverMixin
  late TestObserver observer;

  @override
  void initState() {
    super.initState();
    // This should throw an assertion error
    observer = TestObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

void main() {
  testWidgets('LifecycleObserver initializes correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 1),
    ));

    final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
    expect(state.observer.target.id, 1);
    expect(state.observer.target.isDisposed, false);
  });

  testWidgets('LifecycleObserver rebuilds target when key changes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 1),
    ));

    final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
    final oldController = state.observer.target;
    expect(oldController.id, 1);

    // Update widget with new ID (which updates the key)
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 2),
    ));

    final newController = state.observer.target;
    expect(newController.id, 2);
    expect(newController, isNot(equals(oldController)));

    // Verify old target was disposed
    expect(oldController.isDisposed, true);
    expect(newController.isDisposed, false);
  });

  testWidgets('LifecycleObserver DOES NOT rebuild target when key stays same',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 1),
    ));

    final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
    final oldController = state.observer.target;

    // Pump same widget again
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 1),
    ));

    expect(state.observer.target, equals(oldController));
    expect(oldController.isDisposed, false);
  });

  testWidgets('LifecycleObserver disposes target when widget is disposed',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(id: 1),
    ));

    final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
    final controller = state.observer.target;

    // Push new widget to dispose the old one
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(),
    ));

    expect(controller.isDisposed, true);
  });

  testWidgets('LifecycleObserver throws assertion error without mixin',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NoMixinWidget(),
    ));

    // We expect the pump to trigger the exception in initState
    expect(tester.takeException(), isAssertionError);
  });
}
