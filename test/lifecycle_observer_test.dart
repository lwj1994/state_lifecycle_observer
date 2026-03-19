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
      'removeLifecycleObserver disposes composed child observers recursively',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: RemovableComposedObserverWidget(),
    ));

    final state = tester.state<_RemovableComposedObserverWidgetState>(
        find.byType(RemovableComposedObserverWidget));

    expect(state.parentObserver.childObserver, isNotNull);
    expect(state.parentObserver.childObserver!.target.isDisposed, isFalse);

    final initialBuildCount = state.parentObserver.childObserver!.buildCount;
    state.triggerRebuild();
    await tester.pump();
    expect(
        state.parentObserver.childObserver!.buildCount, initialBuildCount + 1);

    state.removeParentObserver();

    expect(state.parentObserver.target.isDisposed, isTrue);
    expect(state.parentObserver.childObserver!.target.isDisposed, isTrue);

    final buildCountAfterRemoval =
        state.parentObserver.childObserver!.buildCount;
    state.triggerRebuild();
    await tester.pump();

    expect(
      state.parentObserver.childObserver!.buildCount,
      buildCountAfterRemoval,
    );
  });

  testWidgets(
      'key change recreates composed child observers without keeping stale ones',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: KeyedComposedObserverWidget(version: 1),
    ));

    final state = tester.state<_KeyedComposedObserverWidgetState>(
        find.byType(KeyedComposedObserverWidget));

    final oldChild = state.parentObserver.childObserver!;
    final oldBuildCount = oldChild.buildCount;

    await tester.pumpWidget(const MaterialApp(
      home: KeyedComposedObserverWidget(version: 2),
    ));

    expect(oldChild.target.isDisposed, isTrue);
    expect(oldChild.buildCount, oldBuildCount);
    expect(state.parentObserver.childObserver, isNot(same(oldChild)));

    final newChild = state.parentObserver.childObserver!;
    state.triggerRebuild();
    await tester.pump();

    expect(oldChild.buildCount, oldBuildCount);
    expect(newChild.buildCount, 1);
  });

  testWidgets(
      'failed observer initialization does not leave broken observer registered',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FailingObserverWidget(),
    ));

    expect(tester.takeException(), isStateError);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed key-based reinitialization disposes partial observer subtree',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FailingKeyRebuildWidget(version: 1, shouldThrow: false),
    ));

    final state = tester.state<_FailingKeyRebuildWidgetState>(
        find.byType(FailingKeyRebuildWidget));
    final originalChild = state.parentObserver.childObserver!;

    await tester.pumpWidget(const MaterialApp(
      home: FailingKeyRebuildWidget(version: 2, shouldThrow: true),
    ));

    expect(tester.takeException(), isStateError);

    final failedChild = state.parentObserver.childObserver!;
    expect(failedChild, isNot(same(originalChild)));
    expect(state.parentObserver.target.isDisposed, isTrue);
    expect(failedChild.target.isDisposed, isTrue);

    final buildCountAfterFailure = failedChild.buildCount;
    state.triggerRebuild();
    await tester.pump();

    expect(failedChild.buildCount, buildCountAfterFailure);
  });

  testWidgets(
      'creating an observer during removeLifecycleObserver teardown throws and still disposes target',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TeardownRegistrationWidget(),
    ));

    final state = tester.state<_TeardownRegistrationWidgetState>(
        find.byType(TeardownRegistrationWidget));

    expect(() => state.removeObserver(), throwsStateError);
    expect(state.observer.target.isDisposed, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating an observer after owner disposal throws StateError',
      (WidgetTester tester) async {
    late _DisposedOwnerWidgetState state;

    await tester.pumpWidget(MaterialApp(
      home: _DisposedOwnerWidget(
        onReady: (ownerState) {
          state = ownerState;
        },
      ),
    ));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(state.mounted, isFalse);
    expect(() => ChildObserver(state), throwsStateError);
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

  testWidgets(
      'Zone-registered observer key change disposes nested child observers',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ZoneKeyedObserverWidget(version: 1, shouldThrow: false),
    ));

    final state = tester.state<_ZoneKeyedObserverWidgetState>(
        find.byType(ZoneKeyedObserverWidget));

    expect(state.isInitialized, isFalse);

    state.triggerRebuild();
    await tester.pump();

    final zoneObserver = state.parentObserver.zoneObserver!;
    final oldChild = zoneObserver.childObserver!;
    final oldChildBuildCount = oldChild.buildCount;

    await tester.pumpWidget(const MaterialApp(
      home: ZoneKeyedObserverWidget(version: 2, shouldThrow: false),
    ));

    expect(oldChild.target.isDisposed, isTrue);
    expect(zoneObserver.childObserver, isNot(same(oldChild)));

    final newChild = zoneObserver.childObserver!;
    state.triggerRebuild();
    await tester.pump();

    expect(oldChild.buildCount, oldChildBuildCount);
    expect(newChild.buildCount, 1);
  });

  testWidgets(
      'Zone-registered observer failing key rebuild removes broken observer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ZoneKeyedObserverWidget(version: 1, shouldThrow: false),
    ));

    final state = tester.state<_ZoneKeyedObserverWidgetState>(
        find.byType(ZoneKeyedObserverWidget));

    state.triggerRebuild();
    await tester.pump();

    final zoneObserver = state.parentObserver.zoneObserver!;
    final originalChild = zoneObserver.childObserver!;
    final buildCountBeforeFailure = zoneObserver.buildCount;

    await tester.pumpWidget(const MaterialApp(
      home: ZoneKeyedObserverWidget(version: 2, shouldThrow: true),
    ));

    expect(tester.takeException(), isStateError);
    expect(zoneObserver.target.isDisposed, isTrue);
    expect(originalChild.target.isDisposed, isTrue);

    state.triggerRebuild();
    await tester.pump();

    expect(zoneObserver.buildCount, buildCountBeforeFailure);
  });

  testWidgets('owner teardown keeps disposing observers after an error',
      (WidgetTester tester) async {
    late _DisposeErrorWidgetState state;

    await tester.pumpWidget(MaterialApp(
      home: _DisposeErrorWidget(
        onReady: (readyState) {
          state = readyState;
        },
      ),
    ));

    final trailingTarget = state.trailingObserver.target;

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(tester.takeException(), isStateError);
    expect(state.throwingObserver.target.isDisposed, isTrue);
    expect(trailingTarget.isDisposed, isTrue);
    expect(state.disposeFinallyRan, isTrue);
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

class TrackingChildObserver extends LifecycleObserver<TestController> {
  int buildCount = 0;

  TrackingChildObserver(super.state);

  @override
  TestController buildTarget() => TestController(500);

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class RemovableParentObserver extends LifecycleObserver<TestController> {
  TrackingChildObserver? childObserver;

  RemovableParentObserver(super.state);

  @override
  TestController buildTarget() => TestController(450);

  @override
  void onInitState() {
    super.onInitState();
    childObserver = TrackingChildObserver(state);
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class KeyedParentObserver extends LifecycleObserver<TestController> {
  TrackingChildObserver? childObserver;

  KeyedParentObserver(
    super.state, {
    super.key,
  });

  @override
  TestController buildTarget() => TestController((key?.call() as int?) ?? 600);

  @override
  void onInitState() {
    super.onInitState();
    childObserver = TrackingChildObserver(state);
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class FailingObserver extends LifecycleObserver<TestController> {
  FailingObserver(super.state);

  @override
  TestController buildTarget() {
    throw StateError('init failed');
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class FailingRebuildParentObserver extends LifecycleObserver<TestController> {
  final bool Function() shouldThrow;
  TrackingChildObserver? childObserver;

  FailingRebuildParentObserver(
    super.state, {
    required this.shouldThrow,
    super.key,
  });

  @override
  TestController buildTarget() => TestController(700);

  @override
  void onInitState() {
    super.onInitState();
    childObserver = TrackingChildObserver(state);
    if (shouldThrow()) {
      throw StateError('rebuild failed');
    }
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class TeardownRegistrationObserver extends LifecycleObserver<TestController> {
  TeardownRegistrationObserver(super.state);

  @override
  TestController buildTarget() => TestController(800);

  @override
  void onDispose() {
    ChildObserver(state);
    super.onDispose();
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
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

class RemovableComposedObserverWidget extends StatefulWidget {
  const RemovableComposedObserverWidget({super.key});

  @override
  State<RemovableComposedObserverWidget> createState() =>
      _RemovableComposedObserverWidgetState();
}

class _RemovableComposedObserverWidgetState
    extends State<RemovableComposedObserverWidget> with LifecycleOwnerMixin {
  late final RemovableParentObserver parentObserver =
      RemovableParentObserver(this);

  void removeParentObserver() {
    removeLifecycleObserver(parentObserver);
  }

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class KeyedComposedObserverWidget extends StatefulWidget {
  final int version;

  const KeyedComposedObserverWidget({
    super.key,
    required this.version,
  });

  @override
  State<KeyedComposedObserverWidget> createState() =>
      _KeyedComposedObserverWidgetState();
}

class _KeyedComposedObserverWidgetState
    extends State<KeyedComposedObserverWidget> with LifecycleOwnerMixin {
  late final KeyedParentObserver parentObserver = KeyedParentObserver(
    this,
    key: () => widget.version,
  );

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class FailingObserverWidget extends StatefulWidget {
  const FailingObserverWidget({super.key});

  @override
  State<FailingObserverWidget> createState() => _FailingObserverWidgetState();
}

class _FailingObserverWidgetState extends State<FailingObserverWidget>
    with LifecycleOwnerMixin {
  @override
  void initState() {
    super.initState();
    FailingObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class FailingKeyRebuildWidget extends StatefulWidget {
  final int version;
  final bool shouldThrow;

  const FailingKeyRebuildWidget({
    super.key,
    required this.version,
    required this.shouldThrow,
  });

  @override
  State<FailingKeyRebuildWidget> createState() =>
      _FailingKeyRebuildWidgetState();
}

class _FailingKeyRebuildWidgetState extends State<FailingKeyRebuildWidget>
    with LifecycleOwnerMixin {
  late final FailingRebuildParentObserver parentObserver =
      FailingRebuildParentObserver(
    this,
    shouldThrow: () => widget.shouldThrow,
    key: () => widget.version,
  );

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class TeardownRegistrationWidget extends StatefulWidget {
  const TeardownRegistrationWidget({super.key});

  @override
  State<TeardownRegistrationWidget> createState() =>
      _TeardownRegistrationWidgetState();
}

class _TeardownRegistrationWidgetState extends State<TeardownRegistrationWidget>
    with LifecycleOwnerMixin {
  late final TeardownRegistrationObserver observer =
      TeardownRegistrationObserver(this);

  void removeObserver() => removeLifecycleObserver(observer);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class _DisposedOwnerWidget extends StatefulWidget {
  final void Function(_DisposedOwnerWidgetState state) onReady;

  const _DisposedOwnerWidget({
    required this.onReady,
  });

  @override
  State<_DisposedOwnerWidget> createState() => _DisposedOwnerWidgetState();
}

class _DisposedOwnerWidgetState extends State<_DisposedOwnerWidget>
    with LifecycleOwnerMixin {
  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
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

class KeyedZoneObserver extends LifecycleObserver<TestController> {
  final bool Function() shouldThrow;
  TrackingChildObserver? childObserver;
  int buildCount = 0;

  KeyedZoneObserver(
    super.state, {
    required this.shouldThrow,
    super.key,
  });

  @override
  TestController buildTarget() => TestController((key?.call() as int?) ?? 850);

  @override
  void onInitState() {
    super.onInitState();
    childObserver = TrackingChildObserver(state);
    if (shouldThrow()) {
      throw StateError('zone rebuild failed');
    }
  }

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class ZoneKeyedParentObserver extends LifecycleObserver<TestController> {
  final State nonMixinState;
  final int Function() version;
  final bool Function() shouldThrow;
  KeyedZoneObserver? zoneObserver;

  ZoneKeyedParentObserver(
    super.state,
    this.nonMixinState, {
    required this.version,
    required this.shouldThrow,
  });

  @override
  TestController buildTarget() => TestController(860);

  @override
  void onInitState() {
    super.onInitState();
    zoneObserver = KeyedZoneObserver(
      nonMixinState,
      key: version,
      shouldThrow: shouldThrow,
    );
  }

  @override
  void onDisposeTarget(TestController target) => target.dispose();
}

class DisposeErrorObserver extends LifecycleObserver<TestController> {
  DisposeErrorObserver(super.state);

  @override
  TestController buildTarget() => TestController(870);

  @override
  void onDispose() {
    super.onDispose();
    throw StateError('dispose failed');
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

class ZoneKeyedObserverWidget extends StatefulWidget {
  final int version;
  final bool shouldThrow;

  const ZoneKeyedObserverWidget({
    super.key,
    required this.version,
    required this.shouldThrow,
  });

  @override
  State<ZoneKeyedObserverWidget> createState() =>
      _ZoneKeyedObserverWidgetState();
}

class _ZoneKeyedObserverWidgetState extends State<ZoneKeyedObserverWidget>
    with LifecycleOwnerMixin {
  late ZoneKeyedParentObserver parentObserver;
  final GlobalKey<_NonMixinState> nonMixinKey = GlobalKey<_NonMixinState>();
  bool isInitialized = false;

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!isInitialized && nonMixinKey.currentState != null) {
      parentObserver = ZoneKeyedParentObserver(
        this,
        nonMixinKey.currentState!,
        version: () => widget.version,
        shouldThrow: () => widget.shouldThrow,
      );
      isInitialized = true;
    }
    return _NonMixinWidget(key: nonMixinKey);
  }
}

class _DisposeErrorWidget extends StatefulWidget {
  final void Function(_DisposeErrorWidgetState state) onReady;

  const _DisposeErrorWidget({
    required this.onReady,
  });

  @override
  State<_DisposeErrorWidget> createState() => _DisposeErrorWidgetState();
}

class _DisposeErrorWidgetState extends State<_DisposeErrorWidget>
    with LifecycleOwnerMixin {
  late final DisposeErrorObserver throwingObserver;
  late final TestObserver trailingObserver;
  bool disposeFinallyRan = false;

  @override
  void initState() {
    super.initState();
    throwingObserver = DisposeErrorObserver(this);
    trailingObserver = TestObserver(this);
    widget.onReady(this);
  }

  @override
  void dispose() {
    try {
      super.dispose();
    } finally {
      disposeFinallyRan = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}
