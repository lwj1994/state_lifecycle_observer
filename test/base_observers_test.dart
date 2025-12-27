import 'dart:async';
import 'package:flutter/widgets.dart';
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
      await tester.pump();

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
  });
}
