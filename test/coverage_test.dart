import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class CoverageTestWidget extends StatefulWidget {
  final Future<int>? future;
  final Stream<int>? stream;
  final bool testRemoveObserver;

  const CoverageTestWidget({
    super.key,
    this.future,
    this.stream,
    this.testRemoveObserver = false,
  });

  @override
  State<CoverageTestWidget> createState() => CoverageTestWidgetState();
}

class CoverageTestWidgetState extends State<CoverageTestWidget>
    with LifecycleOwnerMixin {
  FutureObserver<int>? futureObserver;
  StreamObserver<int>? streamObserver;
  MockLifecycleObserver? mockObserver;

  @override
  void initState() {
    super.initState();
    if (widget.future != null) {
      futureObserver = FutureObserver(
        this,
        future: widget.future,
      );
    } else {
      // Test null future
      futureObserver = FutureObserver(
        this,
        future: null,
      );
    }

    if (widget.stream != null) {
      streamObserver = StreamObserver(
        this,
        stream: widget.stream,
      );
    } else {
      // Test null stream
      streamObserver = StreamObserver(
        this,
        stream: null,
      );
    }

    if (widget.testRemoveObserver) {
      mockObserver = MockLifecycleObserver(this);
    }
  }

  void removeMockObserver() {
    if (mockObserver != null) {
      removeLifecycleObserver(mockObserver!);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Trigger build target for observers to ensure _subscribe is called
    futureObserver?.target;
    streamObserver?.target;
    return Container();
  }
}

class MockLifecycleObserver extends LifecycleObserver<void> {
  bool onDisposeCalled = false;

  MockLifecycleObserver(super.state);

  @override
  void buildTarget() {}

  @override
  void onDispose() {
    onDisposeCalled = true;
    super.onDispose();
  }
}

void main() {
  group('Coverage Tests', () {
    testWidgets('FutureObserver handles null future', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CoverageTestWidget(future: null),
      ));
      // Should not crash
    });

    testWidgets('StreamObserver handles null stream', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CoverageTestWidget(stream: null),
      ));
      // Should not crash
    });

    testWidgets('FutureObserver handles completion after dispose',
        (tester) async {
      final completer = Completer<int>();
      await tester.pumpWidget(MaterialApp(
        home: CoverageTestWidget(future: completer.future),
      ));

      // Dispose the widget
      await tester.pumpWidget(const SizedBox());

      // Complete future after dispose
      completer.complete(1);

      // Pump to process future completion
      await tester.pump();

      // Should not rely on state if check guards are working
    });

    testWidgets('FutureObserver handles error after dispose', (tester) async {
      final completer = Completer<int>();
      await tester.pumpWidget(MaterialApp(
        home: CoverageTestWidget(future: completer.future),
      ));

      // Dispose the widget
      await tester.pumpWidget(const SizedBox());

      // Complete future with error after dispose
      completer.completeError('error');

      // Pump to process future completion
      await tester.pump();

      // Should not rely on state if check guards are working
    });

    testWidgets('removeLifecycleObserver works and calls onDispose',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CoverageTestWidget(testRemoveObserver: true),
      ));

      final state = tester
          .state<CoverageTestWidgetState>(find.byType(CoverageTestWidget));

      expect(state.mockObserver!.onDisposeCalled, isFalse);

      // Remove observer
      state.removeMockObserver();

      expect(state.mockObserver!.onDisposeCalled, isTrue);
    });
  });
}
