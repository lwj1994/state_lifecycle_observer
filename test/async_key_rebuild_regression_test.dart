import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class _KeyedStreamWidget extends StatefulWidget {
  const _KeyedStreamWidget({
    required this.version,
    required this.stream,
  });

  final int version;
  final Stream<int>? stream;

  @override
  State<_KeyedStreamWidget> createState() => _KeyedStreamWidgetState();
}

class _KeyedStreamWidgetState extends State<_KeyedStreamWidget>
    with LifecycleOwnerMixin {
  late final StreamObserver<int> observer = StreamObserver<int>(
    this,
    streamGetter: () => widget.stream,
    initialData: 0,
    key: () => widget.version,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(
      '${observer.target.connectionState.name}:${observer.target.data}',
      textDirection: TextDirection.ltr,
    );
  }
}

class _ThenCountingFuture<T> implements Future<T> {
  _ThenCountingFuture(this._inner);

  final Future<T> _inner;
  int thenCallCount = 0;

  @override
  Stream<T> asStream() => _inner.asStream();

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return _inner.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    thenCallCount++;
    return _inner.then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(
    Duration timeLimit, {
    FutureOr<T> Function()? onTimeout,
  }) {
    return _inner.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _inner.whenComplete(action);
  }
}

class _KeyedFutureWidget extends StatefulWidget {
  const _KeyedFutureWidget({
    required this.version,
    required this.future,
    required this.initialData,
  });

  final int version;
  final Future<int>? future;
  final int initialData;

  @override
  State<_KeyedFutureWidget> createState() => _KeyedFutureWidgetState();
}

class _KeyedFutureWidgetState extends State<_KeyedFutureWidget>
    with LifecycleOwnerMixin {
  late final FutureObserver<int> observer = FutureObserver<int>(
    this,
    futureGetter: () => widget.future,
    initialDataGetter: () => widget.initialData,
    key: () => widget.version,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(
      '${observer.target.connectionState.name}:${observer.target.data}',
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  testWidgets(
      'StreamObserver keeps the active single-subscription stream across key churn',
      (tester) async {
    final controller = StreamController<int>();
    final stream = controller.stream;
    addTearDown(() => controller.close());

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedStreamWidget(
          version: 1,
          stream: stream,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedStreamWidget(
          version: 2,
          stream: stream,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('waiting:0'), findsOneWidget);

    controller.add(42);
    await tester.pump();
    await tester.pump();

    expect(find.text('active:42'), findsOneWidget);
  });

  testWidgets(
      'FutureObserver does not accumulate handlers across key churn of the same future',
      (tester) async {
    final completer = Completer<int>();
    final future = _ThenCountingFuture<int>(completer.future);

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedFutureWidget(
          version: 1,
          future: future,
          initialData: 1,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedFutureWidget(
          version: 2,
          future: future,
          initialData: 2,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedFutureWidget(
          version: 3,
          future: future,
          initialData: 3,
        ),
      ),
    );

    expect(future.thenCallCount, 1);
    expect(find.text('waiting:3'), findsOneWidget);

    completer.complete(42);
    await tester.pump();
    await tester.pump();

    expect(find.text('done:42'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: _KeyedFutureWidget(
          version: 4,
          future: future,
          initialData: 99,
        ),
      ),
    );

    expect(future.thenCallCount, 1);
    expect(find.text('done:42'), findsOneWidget);
  });

  testWidgets(
      'FutureObserver rebuilds latest initialData when key changes and future stays null',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _KeyedFutureWidget(
          version: 1,
          future: null,
          initialData: 1,
        ),
      ),
    );

    expect(find.text('none:1'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: _KeyedFutureWidget(
          version: 2,
          future: null,
          initialData: 2,
        ),
      ),
    );

    expect(find.text('none:2'), findsOneWidget);
  });
}
