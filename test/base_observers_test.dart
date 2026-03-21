import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class BaseTestWidget extends StatefulWidget {
  final Future<int>? future;
  final Stream<int>? stream;
  final Listenable? listenable;
  final Function(dynamic data)? onBuild;

  const BaseTestWidget({
    super.key,
    this.future,
    this.stream,
    this.listenable,
    this.onBuild,
  });

  @override
  State<BaseTestWidget> createState() => _BaseTestWidgetState();
}

class _BaseTestWidgetState extends State<BaseTestWidget>
    with TickerProviderStateMixin, LifecycleOwnerMixin {
  late FutureObserver<int> futureObserver;
  late StreamObserver<int> streamObserver;
  late ListenableObserver listenableObserver;

  @override
  void initState() {
    super.initState();
    if (widget.future != null) {
      futureObserver = FutureObserver(
        this,
        future: widget.future,
        initialData: 0,
      );
    }
    if (widget.stream != null) {
      streamObserver = StreamObserver(
        this,
        stream: widget.stream,
        initialData: 0,
      );
    }
    if (widget.listenable != null) {
      listenableObserver = ListenableObserver(
        this,
        listenable: widget.listenable!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.future != null) {
      widget.onBuild?.call(futureObserver.target);
    }
    if (widget.stream != null) {
      widget.onBuild?.call(streamObserver.target);
    }
    if (widget.listenable != null) {
      widget.onBuild?.call(null); // snapshot irrelevant
    }
    return const SizedBox();
  }
}

void main() {
  group('ListenableObserver', () {
    testWidgets('rebuilds on notification', (tester) async {
      final notifier = ValueNotifier<int>(0);
      int buildCount = 0;

      await tester.pumpWidget(
        BaseTestWidget(
          listenable: notifier,
          onBuild: (_) => buildCount++,
        ),
      );

      expect(buildCount, 1);

      notifier.value = 1;
      await tester.pumpAndSettle();

      expect(buildCount, 2);
    });
  });

  group('FutureObserver', () {
    testWidgets('emits waiting then data', (tester) async {
      final completer = Completer<int>();

      await tester.pumpWidget(
        BaseTestWidget(
          future: completer.future,
        ),
      );

      // Initial state
      final state =
          tester.state<_BaseTestWidgetState>(find.byType(BaseTestWidget));
      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 0);

      // Complete future
      completer.complete(42);
      await tester.pump(); // Allow microtasks to propagate

      // Expect update
      expect(state.futureObserver.target.connectionState, ConnectionState.done);
      expect(state.futureObserver.target.data, 42);
    });
  });

  group('StreamObserver', () {
    testWidgets('emits waiting then events', (tester) async {
      final controller = StreamController<int>(sync: true);

      await tester.pumpWidget(
        BaseTestWidget(
          stream: controller.stream,
        ),
      );

      final state =
          tester.state<_BaseTestWidgetState>(find.byType(BaseTestWidget));
      expect(
          state.streamObserver.target.connectionState, ConnectionState.waiting);

      controller.add(100);
      await tester.pump();

      expect(
          state.streamObserver.target.connectionState, ConnectionState.active);
      expect(state.streamObserver.target.data, 100);

      controller.add(200);
      await tester.pump();

      expect(state.streamObserver.target.data, 200);

      controller.close();
      await tester.pump();

      expect(state.streamObserver.target.connectionState, ConnectionState.done);
    });

    testWidgets('handles stream error', (tester) async {
      final controller = StreamController<int>(sync: true);
      addTearDown(() => controller.close());

      await tester.pumpWidget(
        BaseTestWidget(
          stream: controller.stream,
        ),
      );

      final state =
          tester.state<_BaseTestWidgetState>(find.byType(BaseTestWidget));

      controller.addError('stream error', StackTrace.current);
      await tester.pump();

      expect(
          state.streamObserver.target.connectionState, ConnectionState.active);
      expect(state.streamObserver.target.hasError, true);
      expect(state.streamObserver.target.error, 'stream error');
    });
  });

  group('FutureObserver error', () {
    testWidgets('handles future error', (tester) async {
      final completer = Completer<int>();

      await tester.pumpWidget(
        BaseTestWidget(
          future: completer.future,
        ),
      );

      final state =
          tester.state<_BaseTestWidgetState>(find.byType(BaseTestWidget));
      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);

      completer.completeError('future error', StackTrace.current);
      await tester.pump();

      expect(state.futureObserver.target.connectionState, ConnectionState.done);
      expect(state.futureObserver.target.hasError, true);
      expect(state.futureObserver.target.error, 'future error');
    });
  });

  group('FutureObserver getters', () {
    testWidgets(
        'uses latest future and ignores stale completion after key change',
        (tester) async {
      final firstCompleter = Completer<int>();
      final secondCompleter = Completer<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: DynamicFutureWidget(
            version: 1,
            future: firstCompleter.future,
            initialData: 1,
          ),
        ),
      );

      final state = tester
          .state<_DynamicFutureWidgetState>(find.byType(DynamicFutureWidget));

      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: DynamicFutureWidget(
            version: 2,
            future: secondCompleter.future,
            initialData: 2,
          ),
        ),
      );

      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 2);

      firstCompleter.complete(100);
      await tester.pump();

      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 2);

      secondCompleter.complete(200);
      await tester.pump();

      expect(state.futureObserver.target.connectionState, ConnectionState.done);
      expect(state.futureObserver.target.data, 200);
    });

    testWidgets('evaluates getter inputs once per lifecycle update',
        (tester) async {
      final firstCompleter = Completer<int>();
      final secondCompleter = Completer<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: CountingFutureWidget(
            future: firstCompleter.future,
            initialData: 1,
          ),
        ),
      );

      final state = tester
          .state<_CountingFutureWidgetState>(find.byType(CountingFutureWidget));

      expect(state.futureGetterCallCount, 1);
      expect(state.initialDataGetterCallCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: CountingFutureWidget(
            future: secondCompleter.future,
            initialData: 2,
          ),
        ),
      );

      expect(state.futureGetterCallCount, 2);
      expect(state.initialDataGetterCallCount, 2);
    });

    testWidgets(
        'key rebuild with same pending future keeps a single completion callback',
        (tester) async {
      final completer = Completer<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: KeyChurnFutureWidget(
            version: 1,
            future: completer.future,
            initialData: 1,
          ),
        ),
      );

      final state = tester
          .state<_KeyChurnFutureWidgetState>(find.byType(KeyChurnFutureWidget));

      await tester.pumpWidget(
        MaterialApp(
          home: KeyChurnFutureWidget(
            version: 2,
            future: completer.future,
            initialData: 2,
          ),
        ),
      );

      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 2);

      completer.complete(42);
      await tester.pump();

      expect(state.futureObserver.safeSetStateCallCount, 1);
      expect(state.futureObserver.target.connectionState, ConnectionState.done);
      expect(state.futureObserver.target.data, 42);
    });

    testWidgets(
        'multiple key rebuilds with same pending future keep a single final callback',
        (tester) async {
      final completer = Completer<int>();

      await tester.pumpWidget(
        MaterialApp(
          home: KeyChurnFutureWidget(
            version: 1,
            future: completer.future,
            initialData: 1,
          ),
        ),
      );

      final state = tester
          .state<_KeyChurnFutureWidgetState>(find.byType(KeyChurnFutureWidget));

      await tester.pumpWidget(
        MaterialApp(
          home: KeyChurnFutureWidget(
            version: 2,
            future: completer.future,
            initialData: 2,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KeyChurnFutureWidget(
            version: 3,
            future: completer.future,
            initialData: 3,
          ),
        ),
      );

      expect(
          state.futureObserver.target.connectionState, ConnectionState.waiting);
      expect(state.futureObserver.target.data, 3);

      completer.complete(99);
      await tester.pumpAndSettle();

      expect(state.futureObserver.safeSetStateCallCount, 1);
      expect(state.futureObserver.target.connectionState, ConnectionState.done);
      expect(state.futureObserver.target.data, 99);
    });
  });

  group('StreamObserver getters', () {
    testWidgets('evaluates getter inputs once per lifecycle update',
        (tester) async {
      final firstController = StreamController<int>();
      final secondController = StreamController<int>();
      addTearDown(firstController.close);
      addTearDown(secondController.close);

      await tester.pumpWidget(
        MaterialApp(
          home: CountingStreamWidget(
            stream: firstController.stream,
            initialData: 1,
          ),
        ),
      );

      final state = tester
          .state<_CountingStreamWidgetState>(find.byType(CountingStreamWidget));

      expect(state.streamGetterCallCount, 1);
      expect(state.initialDataGetterCallCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: CountingStreamWidget(
            stream: secondController.stream,
            initialData: 2,
          ),
        ),
      );

      expect(state.streamGetterCallCount, 2);
      expect(state.initialDataGetterCallCount, 2);
    });
  });
}

class DynamicFutureWidget extends StatefulWidget {
  final int version;
  final Future<int>? future;
  final int? initialData;

  const DynamicFutureWidget({
    super.key,
    required this.version,
    required this.future,
    required this.initialData,
  });

  @override
  State<DynamicFutureWidget> createState() => _DynamicFutureWidgetState();
}

class _DynamicFutureWidgetState extends State<DynamicFutureWidget>
    with LifecycleOwnerMixin {
  late final FutureObserver<int> futureObserver = FutureObserver(
    this,
    futureGetter: () => widget.future,
    initialDataGetter: () => widget.initialData,
    key: () => widget.version,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class CountingFutureWidget extends StatefulWidget {
  final Future<int>? future;
  final int? initialData;

  const CountingFutureWidget({
    super.key,
    required this.future,
    required this.initialData,
  });

  @override
  State<CountingFutureWidget> createState() => _CountingFutureWidgetState();
}

class _CountingFutureWidgetState extends State<CountingFutureWidget>
    with LifecycleOwnerMixin {
  int futureGetterCallCount = 0;
  int initialDataGetterCallCount = 0;

  late final FutureObserver<int> futureObserver;

  @override
  void initState() {
    super.initState();
    futureObserver = FutureObserver(
      this,
      futureGetter: () {
        futureGetterCallCount++;
        return widget.future;
      },
      initialDataGetter: () {
        initialDataGetterCallCount++;
        return widget.initialData;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class KeyChurnFutureWidget extends StatefulWidget {
  final int version;
  final Future<int>? future;
  final int? initialData;

  const KeyChurnFutureWidget({
    super.key,
    required this.version,
    required this.future,
    required this.initialData,
  });

  @override
  State<KeyChurnFutureWidget> createState() => _KeyChurnFutureWidgetState();
}

class _KeyChurnFutureWidgetState extends State<KeyChurnFutureWidget>
    with LifecycleOwnerMixin {
  late final CountingSafeSetStateFutureObserver futureObserver =
      CountingSafeSetStateFutureObserver(
    this,
    futureGetter: () => widget.future,
    initialDataGetter: () => widget.initialData,
    key: () => widget.version,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class CountingSafeSetStateFutureObserver extends FutureObserver<int> {
  int safeSetStateCallCount = 0;

  CountingSafeSetStateFutureObserver(
    super.state, {
    required super.futureGetter,
    required super.initialDataGetter,
    required super.key,
  });

  @override
  void safeSetState(VoidCallback fn) {
    safeSetStateCallCount++;
    super.safeSetState(fn);
  }
}

class CountingStreamWidget extends StatefulWidget {
  final Stream<int>? stream;
  final int? initialData;

  const CountingStreamWidget({
    super.key,
    required this.stream,
    required this.initialData,
  });

  @override
  State<CountingStreamWidget> createState() => _CountingStreamWidgetState();
}

class _CountingStreamWidgetState extends State<CountingStreamWidget>
    with LifecycleOwnerMixin {
  int streamGetterCallCount = 0;
  int initialDataGetterCallCount = 0;

  late final StreamObserver<int> streamObserver;

  @override
  void initState() {
    super.initState();
    streamObserver = StreamObserver(
      this,
      streamGetter: () {
        streamGetterCallCount++;
        return widget.stream;
      },
      initialDataGetter: () {
        initialDataGetterCallCount++;
        return widget.initialData;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}
