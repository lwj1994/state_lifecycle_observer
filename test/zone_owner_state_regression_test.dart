import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class _NonMixinWidget extends StatefulWidget {
  const _NonMixinWidget({super.key});

  @override
  State<_NonMixinWidget> createState() => _NonMixinState();
}

class _NonMixinState extends State<_NonMixinWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ZoneListenableParentObserver extends LifecycleObserver<void> {
  _ZoneListenableParentObserver(
    super.state,
    this.nonMixinState,
    this.notifier,
  );

  final State nonMixinState;
  final ValueNotifier<int> notifier;
  late final ListenableObserver childObserver;

  @override
  void onInitState() {
    super.onInitState();
    childObserver = ListenableObserver(
      nonMixinState,
      listenable: notifier,
    );
  }

  @override
  void buildTarget() {}
}

class _ZoneListenableWidget extends StatefulWidget {
  const _ZoneListenableWidget({
    required this.notifier,
    required this.showChild,
  });

  final ValueNotifier<int> notifier;
  final bool showChild;

  @override
  State<_ZoneListenableWidget> createState() => _ZoneListenableWidgetState();
}

class _ZoneListenableWidgetState extends State<_ZoneListenableWidget>
    with LifecycleOwnerMixin {
  final GlobalKey<_NonMixinState> childKey = GlobalKey<_NonMixinState>();
  _ZoneListenableParentObserver? observer;
  int buildCount = 0;

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    buildCount++;
    super.build(context);
    if (observer == null && childKey.currentState != null) {
      observer = _ZoneListenableParentObserver(
        this,
        childKey.currentState!,
        widget.notifier,
      );
    }
    return Column(
      textDirection: TextDirection.ltr,
      children: [
        Text('build:$buildCount', textDirection: TextDirection.ltr),
        if (widget.showChild) _NonMixinWidget(key: childKey),
      ],
    );
  }
}

class _ZoneFutureParentObserver extends LifecycleObserver<void> {
  _ZoneFutureParentObserver(
    super.state,
    this.nonMixinState,
    this.future,
  );

  final State nonMixinState;
  final Future<int> future;
  late final FutureObserver<int> childObserver;

  @override
  void onInitState() {
    super.onInitState();
    childObserver = FutureObserver<int>(
      nonMixinState,
      future: future,
      initialData: 0,
    );
  }

  @override
  void buildTarget() {}
}

class _ZoneFutureWidget extends StatefulWidget {
  const _ZoneFutureWidget({
    required this.future,
    required this.showChild,
  });

  final Future<int> future;
  final bool showChild;

  @override
  State<_ZoneFutureWidget> createState() => _ZoneFutureWidgetState();
}

class _ZoneFutureWidgetState extends State<_ZoneFutureWidget>
    with LifecycleOwnerMixin {
  final GlobalKey<_NonMixinState> childKey = GlobalKey<_NonMixinState>();
  _ZoneFutureParentObserver? observer;

  void triggerRebuild() => setState(() {});

  String get statusText {
    final snapshot = observer?.childObserver.target;
    if (snapshot == null) {
      return 'uninitialized';
    }
    return '${snapshot.connectionState.name}:${snapshot.data}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (observer == null && childKey.currentState != null) {
      observer = _ZoneFutureParentObserver(
        this,
        childKey.currentState!,
        widget.future,
      );
    }
    return Column(
      textDirection: TextDirection.ltr,
      children: [
        Text(statusText, textDirection: TextDirection.ltr),
        if (widget.showChild) _NonMixinWidget(key: childKey),
      ],
    );
  }
}

void main() {
  testWidgets('Zone-registered ListenableObserver rebuilds the owner state',
      (tester) async {
    final notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: _ZoneListenableWidget(
          notifier: notifier,
          showChild: true,
        ),
      ),
    );

    final state = tester
        .state<_ZoneListenableWidgetState>(find.byType(_ZoneListenableWidget));

    state.triggerRebuild();
    await tester.pump();

    expect(find.text('build:2'), findsOneWidget);

    notifier.value = 1;
    await tester.pump();

    expect(find.text('build:3'), findsOneWidget);
  });

  testWidgets(
      'Zone-registered FutureObserver still updates after the foreign state unmounts',
      (tester) async {
    final completer = Completer<int>();

    await tester.pumpWidget(
      MaterialApp(
        home: _ZoneFutureWidget(
          future: completer.future,
          showChild: true,
        ),
      ),
    );

    final state =
        tester.state<_ZoneFutureWidgetState>(find.byType(_ZoneFutureWidget));

    state.triggerRebuild();
    await tester.pump();

    expect(find.text('waiting:0'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: _ZoneFutureWidget(
          future: completer.future,
          showChild: false,
        ),
      ),
    );

    completer.complete(42);
    await tester.pump();
    await tester.pump();

    expect(find.text('done:42'), findsOneWidget);
  });
}
