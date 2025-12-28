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

  testWidgets('LifecycleObserver throws StateError without mixin',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NoMixinWidget(),
    ));

    // We expect the pump to trigger the exception in initState
    expect(tester.takeException(), isStateError);
  });

  // --- Composing Observers Tests ---

  testWidgets('Composing Observers - child observers register via Zone',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ComposingObserverWidget(),
    ));

    final state = tester.state<_ComposingObserverWidgetState>(
        find.byType(ComposingObserverWidget));

    // Parent observer is registered
    expect(state.parentObserver.target.id, 100);
    expect(state.parentObserver.target.isDisposed, false);

    // Child observer created inside parent's onInitState should also be registered
    expect(state.parentObserver.childObserver, isNotNull);
    expect(state.parentObserver.childObserver!.target.id, 200);
    expect(state.parentObserver.childObserver!.target.isDisposed, false);

    // Dispose the widget
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(),
    ));

    // Both parent and child should be disposed
    expect(state.parentObserver.target.isDisposed, true);
    expect(state.parentObserver.childObserver!.target.isDisposed, true);
  });

  testWidgets(
      'Composing Observers - child observers can be created in onDidUpdateWidget',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OnDidUpdateWidget(version: 1),
    ));

    final state =
        tester.state<_OnDidUpdateWidgetState>(find.byType(OnDidUpdateWidget));

    // Initially no child observer
    expect(state.observer.childObserver, isNull);

    // Trigger didUpdateWidget by changing version
    await tester.pumpWidget(const MaterialApp(
      home: OnDidUpdateWidget(version: 2),
    ));

    // Child observer should now be created via Zone
    expect(state.observer.childObserver, isNotNull);
    expect(state.observer.childObserver!.target.id, 200);

    // Dispose and verify both are cleaned up
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(state.observer.target.isDisposed, true);
    expect(state.observer.childObserver!.target.isDisposed, true);
  });

  testWidgets('Composing Observers - child observers can be created in onBuild',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OnBuildWidget(),
    ));

    final state = tester.state<_OnBuildWidgetState>(find.byType(OnBuildWidget));

    // First build - no child observer yet (created on second build)
    expect(state.observer.buildCount, 1);
    expect(state.observer.childObserver, isNull);

    // Trigger second build
    state.triggerRebuild();
    await tester.pump();

    // Child observer should now be created via Zone
    expect(state.observer.buildCount, 2);
    expect(state.observer.childObserver, isNotNull);
    expect(state.observer.childObserver!.target.id, 200);

    // Dispose and verify both are cleaned up
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(state.observer.target.isDisposed, true);
  });

  testWidgets(
      'Zone-based registration - observer with non-mixin State inside Zone',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ZoneRegistrationTestWidget(),
    ));

    final state = tester.state<_ZoneRegistrationTestWidgetState>(
        find.byType(ZoneRegistrationTestWidget));

    // First pump - child widget is built, but parentObserver not initialized yet
    expect(state._initialized, false);

    // Trigger rebuild so GlobalKey.currentState is available
    // Trigger rebuild so GlobalKey.currentState is available
    state.triggerRebuild();
    await tester.pump();

    // Now the zoneObserver should be created via Zone-based registration
    expect(state._initialized, true);
    expect(state.parentObserver.zoneObserver, isNotNull);
    expect(state.parentObserver.zoneObserver!.target.id, 200);

    // Verify disposal works correctly
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(state.parentObserver.target.isDisposed, true);
    expect(state.parentObserver.zoneObserver!.target.isDisposed, true);
  });
}

// --- Composing Observer Test Helpers ---

/// A parent observer that creates a child observer in onInitState.
class ParentObserver extends LifecycleObserver<TestController> {
  ChildObserver? childObserver;
  ZoneChildObserver? zoneChildObserver;

  ParentObserver(super.state);

  @override
  TestController buildTarget() {
    return TestController(100);
  }

  @override
  void onInitState() {
    super.onInitState();
    // Create a child observer with the mixin state - takes direct path
    childObserver = ChildObserver(state);
  }

  @override
  void onDisposeTarget(TestController target) {
    target.dispose();
  }
}

/// A child observer that explicitly takes a non-LifecycleOwnerMixin State.
/// When created inside a Zone with addLifecycleObserver, it uses Zone-based
/// registration (line 91 in lifecycle_observer.dart).
class ZoneChildObserver extends LifecycleObserver<TestController> {
  // Takes any State, including non-mixin ones
  ZoneChildObserver(super.state);

  @override
  TestController buildTarget() {
    return TestController(200);
  }

  @override
  void onDisposeTarget(TestController target) {
    target.dispose();
  }
}

/// A child observer created inside a parent observer.
class ChildObserver extends LifecycleObserver<TestController> {
  ChildObserver(super.state);

  @override
  TestController buildTarget() {
    return TestController(200);
  }

  @override
  void onDisposeTarget(TestController target) {
    target.dispose();
  }
}

class ComposingObserverWidget extends StatefulWidget {
  const ComposingObserverWidget({super.key});

  @override
  State<ComposingObserverWidget> createState() =>
      _ComposingObserverWidgetState();
}

class _ComposingObserverWidgetState extends State<ComposingObserverWidget>
    with LifecycleOwnerMixin {
  late ParentObserver parentObserver;

  @override
  void initState() {
    super.initState();
    parentObserver = ParentObserver(this);
  }
}

// --- Test for creating observers in onDidUpdateWidget ---

class OnDidUpdateObserver extends LifecycleObserver<TestController> {
  ChildObserver? childObserver;
  int updateCount = 0;

  OnDidUpdateObserver(super.state);

  @override
  TestController buildTarget() => TestController(300);

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    updateCount++;
    // Create a child observer on first update
    if (updateCount == 1 && childObserver == null) {
      childObserver = ChildObserver(state);
    }
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class OnDidUpdateWidget extends StatefulWidget {
  final int version;
  const OnDidUpdateWidget({super.key, this.version = 0});

  @override
  State<OnDidUpdateWidget> createState() => _OnDidUpdateWidgetState();
}

class _OnDidUpdateWidgetState extends State<OnDidUpdateWidget>
    with LifecycleOwnerMixin {
  late OnDidUpdateObserver observer;

  @override
  void initState() {
    super.initState();
    observer = OnDidUpdateObserver(this);
  }
}

// --- Test for creating observers in onBuild ---

class OnBuildObserver extends LifecycleObserver<TestController> {
  ChildObserver? childObserver;
  int buildCount = 0;

  OnBuildObserver(super.state);

  @override
  TestController buildTarget() => TestController(400);

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
    // Create a child observer on second build
    if (buildCount == 2 && childObserver == null) {
      childObserver = ChildObserver(state);
    }
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class OnBuildWidget extends StatefulWidget {
  const OnBuildWidget({super.key});

  @override
  State<OnBuildWidget> createState() => _OnBuildWidgetState();
}

class _OnBuildWidgetState extends State<OnBuildWidget>
    with LifecycleOwnerMixin {
  late OnBuildObserver observer;

  @override
  void initState() {
    super.initState();
    observer = OnBuildObserver(this);
  }

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

// --- Zone Registration Test (covers line 91) ---

/// A non-mixin State for testing Zone-based registration.
class _NonMixinState extends State<_NonMixinWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

class _NonMixinWidget extends StatefulWidget {
  const _NonMixinWidget({super.key});
  @override
  State<_NonMixinWidget> createState() => _NonMixinState();
}

/// Observer that creates a child observer with a non-mixin State reference.
/// This triggers the Zone-based registration path (line 91).
class ZoneParentObserver extends LifecycleObserver<TestController> {
  ZoneChildObserver? zoneObserver;
  final State nonMixinState;

  ZoneParentObserver(super.state, this.nonMixinState);

  @override
  TestController buildTarget() => TestController(100);

  @override
  void onInitState() {
    super.onInitState();
    // Create a child observer with a non-mixin State reference.
    // Since nonMixinState does NOT implement LifecycleOwnerMixin,
    // but we're inside a Zone with addLifecycleObserver available,
    // this will trigger the Zone-based registration path (line 91).
    zoneObserver = ZoneChildObserver(nonMixinState);
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class ZoneRegistrationTestWidget extends StatefulWidget {
  const ZoneRegistrationTestWidget({super.key});

  @override
  State<ZoneRegistrationTestWidget> createState() =>
      _ZoneRegistrationTestWidgetState();
}

class _ZoneRegistrationTestWidgetState extends State<ZoneRegistrationTestWidget>
    with LifecycleOwnerMixin {
  late ZoneParentObserver parentObserver;
  final GlobalKey<_NonMixinState> nonMixinKey = GlobalKey<_NonMixinState>();
  bool _initialized = false;

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Defer parentObserver creation to the second build when nonMixinKey.currentState is available
    if (!_initialized && nonMixinKey.currentState != null) {
      parentObserver = ZoneParentObserver(this, nonMixinKey.currentState!);
      _initialized = true;
    }
    return _NonMixinWidget(key: nonMixinKey);
  }
}
