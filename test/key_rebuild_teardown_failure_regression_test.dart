import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class _ThrowingTarget {
  bool isDisposed = false;

  void dispose() {
    isDisposed = true;
  }
}

class _ThrowingDisposeObserver extends LifecycleObserver<_ThrowingTarget> {
  _ThrowingDisposeObserver(
    super.state, {
    required this.shouldThrowOnFirstDispose,
    super.key,
  });

  final bool Function() shouldThrowOnFirstDispose;
  int disposeAttemptCount = 0;
  int buildCount = 0;
  bool hasThrownOnDispose = false;

  @override
  _ThrowingTarget buildTarget() => _ThrowingTarget();

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    buildCount++;
  }

  @override
  void onDisposeTarget(_ThrowingTarget target) {
    disposeAttemptCount++;
    if (shouldThrowOnFirstDispose() && !hasThrownOnDispose) {
      hasThrownOnDispose = true;
      throw StateError('dispose failed during key rebuild');
    }
    target.dispose();
  }
}

class _ThrowingDisposeWidget extends StatefulWidget {
  const _ThrowingDisposeWidget({
    required this.version,
    required this.shouldThrowOnFirstDispose,
  });

  final int version;
  final bool shouldThrowOnFirstDispose;

  @override
  State<_ThrowingDisposeWidget> createState() => _ThrowingDisposeWidgetState();
}

class _ThrowingDisposeWidgetState extends State<_ThrowingDisposeWidget>
    with LifecycleOwnerMixin {
  late final _ThrowingDisposeObserver observer = _ThrowingDisposeObserver(
    this,
    shouldThrowOnFirstDispose: () => widget.shouldThrowOnFirstDispose,
    key: () => widget.version,
  );

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

void main() {
  testWidgets(
      'failed key-rebuild teardown removes observer instead of retrying forever',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _ThrowingDisposeWidget(
          version: 1,
          shouldThrowOnFirstDispose: false,
        ),
      ),
    );

    final state = tester.state<_ThrowingDisposeWidgetState>(
        find.byType(_ThrowingDisposeWidget));

    final originalTarget = state.observer.target;
    final buildCountBeforeFailure = state.observer.buildCount;

    await tester.pumpWidget(
      const MaterialApp(
        home: _ThrowingDisposeWidget(
          version: 2,
          shouldThrowOnFirstDispose: true,
        ),
      ),
    );

    expect(tester.takeException(), isStateError);
    expect(originalTarget.isDisposed, isTrue);
    final disposeAttemptCountAfterFailure = state.observer.disposeAttemptCount;
    final buildCountAfterFailure = state.observer.buildCount;

    expect(
        buildCountAfterFailure, greaterThanOrEqualTo(buildCountBeforeFailure));

    state.triggerRebuild();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(state.observer.disposeAttemptCount, disposeAttemptCountAfterFailure);
    expect(state.observer.buildCount, buildCountAfterFailure);
  });
}
