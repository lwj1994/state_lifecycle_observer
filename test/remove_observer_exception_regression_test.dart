import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class _ThrowingChildObserver extends LifecycleObserver<void> {
  _ThrowingChildObserver(
    super.state, {
    required this.shouldThrowOnDispose,
  });

  final bool Function() shouldThrowOnDispose;
  int buildCount = 0;

  @override
  void buildTarget() {}

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
  }

  @override
  void onDispose() {
    super.onDispose();
    if (shouldThrowOnDispose()) {
      throw StateError('child dispose failed');
    }
  }
}

class _RemovableParentObserver extends LifecycleObserver<void> {
  _RemovableParentObserver(
    super.state, {
    required this.childShouldThrowOnDispose,
  });

  final bool Function() childShouldThrowOnDispose;
  late final _ThrowingChildObserver childObserver;
  int buildCount = 0;

  @override
  void buildTarget() {}

  @override
  void onInitState() {
    super.onInitState();
    childObserver = _ThrowingChildObserver(
      state,
      shouldThrowOnDispose: childShouldThrowOnDispose,
    );
  }

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
  }
}

class _RemovableObserverWidget extends StatefulWidget {
  const _RemovableObserverWidget({
    required this.childShouldThrowOnDispose,
  });

  final bool childShouldThrowOnDispose;

  @override
  State<_RemovableObserverWidget> createState() =>
      _RemovableObserverWidgetState();
}

class _RemovableObserverWidgetState extends State<_RemovableObserverWidget>
    with LifecycleOwnerMixin {
  late final _RemovableParentObserver parentObserver = _RemovableParentObserver(
    this,
    childShouldThrowOnDispose: () => widget.childShouldThrowOnDispose,
  );

  void triggerRebuild() => setState(() {});

  void removeParentObserver() {
    removeLifecycleObserver(parentObserver);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class _InitFailureParentObserver extends LifecycleObserver<void> {
  _InitFailureParentObserver(
    super.state, {
    required this.childShouldThrowOnDispose,
  });

  final bool Function() childShouldThrowOnDispose;

  @override
  void buildTarget() {}

  @override
  void onInitState() {
    super.onInitState();
    _ThrowingChildObserver(
      state,
      shouldThrowOnDispose: childShouldThrowOnDispose,
    );
    throw StateError('init failed');
  }
}

class _InitFailureWidget extends StatefulWidget {
  const _InitFailureWidget();

  @override
  State<_InitFailureWidget> createState() => _InitFailureWidgetState();
}

class _InitFailureWidgetState extends State<_InitFailureWidget>
    with LifecycleOwnerMixin {
  @override
  void initState() {
    super.initState();
    _InitFailureParentObserver(
      this,
      childShouldThrowOnDispose: () => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

void main() {
  testWidgets(
      'removeLifecycleObserver detaches parent even when a child dispose throws',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _RemovableObserverWidget(
          childShouldThrowOnDispose: true,
        ),
      ),
    );

    final state = tester.state<_RemovableObserverWidgetState>(
      find.byType(_RemovableObserverWidget),
    );

    state.triggerRebuild();
    await tester.pump();

    final buildCountBeforeRemoval = state.parentObserver.buildCount;
    expect(() => state.removeParentObserver(), throwsStateError);

    state.triggerRebuild();
    await tester.pump();

    expect(state.parentObserver.buildCount, buildCountBeforeRemoval);
  });

  testWidgets(
      'failed observer initialization preserves the original init error',
      (tester) async {
    final originalOnError = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) {
      reportedErrors.add(details);
    };

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: _InitFailureWidget(),
        ),
      );
    } finally {
      FlutterError.onError = originalOnError;
    }

    final firstError = tester.takeException();
    final errorMessages = <String>[
      if (firstError != null) firstError.toString(),
      ...reportedErrors.map((details) => details.exceptionAsString()),
    ];
    expect(
      errorMessages.any((message) => message.contains('init failed')),
      isTrue,
    );
    expect(
      errorMessages.any((message) => message.contains('child dispose failed')),
      isTrue,
    );
  });
}
