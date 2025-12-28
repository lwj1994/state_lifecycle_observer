import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class LateObserver extends LifecycleObserver<void> {
  LateObserver(super.state);

  int initCallCount = 0;
  int disposeCallCount = 0;

  @override
  void onInitState() {
    super.onInitState();
    initCallCount++;
  }

  @override
  void buildTarget() {}

  @override
  void onDisposeTarget(void target) {
    disposeCallCount++;
  }
}

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});

  @override
  TestWidgetState createState() => TestWidgetState();
}

class TestWidgetState extends State<TestWidget> with LifecycleOwnerMixin {
  LateObserver? observer;

  void addObserverLate() {
    observer = LateObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

void main() {
  testWidgets(
      'Observer added late (after initState) receives onInitState immediately',
      (tester) async {
    await tester.pumpWidget(const TestWidget());

    final state = tester.state<TestWidgetState>(find.byType(TestWidget));

    // Add observer LATE, after pumpWidget has already run initState
    state.addObserverLate();

    // Verify onInitState was called immediately
    expect(state.observer!.initCallCount, 1);
  });

  testWidgets('Observer added in initState receives onInitState',
      (tester) async {
    // We need a widget that adds observer in initState
    await tester.pumpWidget(const InitStateWidget());
    final state =
        tester.state<InitStateWidgetState>(find.byType(InitStateWidget));
    expect(state.observer!.initCallCount, 1);
  });

  testWidgets(
      'Accessing target before initialization throws LateInitializationError',
      (tester) async {
    await tester.pumpWidget(const PrematureAccessWidget());
    final state = tester
        .state<PrematureAccessWidgetState>(find.byType(PrematureAccessWidget));
    expect(state.errorCaught, isTrue);
  });

  testWidgets('safeSetState does nothing when state is disposed',
      (tester) async {
    await tester.pumpWidget(const DisposedStateWidget());

    final state = tester
        .state<DisposedStateWidgetState>(find.byType(DisposedStateWidget));
    final observer = state.observer;

    // Dispose the widget
    await tester.pumpWidget(const SizedBox());

    // Call safeSetState after disposal - should not throw
    observer.callSafeSetState();

    // Value should remain unchanged
    expect(observer.target, 0);
  });
}

class InitStateWidget extends StatefulWidget {
  const InitStateWidget({super.key});

  @override
  InitStateWidgetState createState() => InitStateWidgetState();
}

class InitStateWidgetState extends State<InitStateWidget>
    with LifecycleOwnerMixin {
  LateObserver? observer;

  @override
  void initState() {
    super.initState();
    observer = LateObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

class PrematureAccessObserver extends LifecycleObserver<void> {
  PrematureAccessObserver(super.state);

  @override
  void buildTarget() {}
}

class PrematureAccessWidget extends StatefulWidget {
  const PrematureAccessWidget({super.key});
  @override
  PrematureAccessWidgetState createState() => PrematureAccessWidgetState();
}

class PrematureAccessWidgetState extends State<PrematureAccessWidget>
    with LifecycleOwnerMixin {
  bool errorCaught = false;

  @override
  void initState() {
    // Intentionally NOT calling super.initState() yet.
    // Creating observer here means it's registered but onInitState hasn't run yet.
    final obs = PrematureAccessObserver(this);
    try {
      // Access target. Should throw LateInitializationError.
      // ignore: unused_local_variable
      final t = obs.target;
    } catch (e) {
      if (e.toString().contains('LateInitializationError')) {
        errorCaught = true;
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

// Test for safeSetState during build phase (persistentCallbacks)
class SafeSetStateObserver extends LifecycleObserver<int> {
  int rebuildCount = 0;

  SafeSetStateObserver(super.state);

  @override
  int buildTarget() => 0;

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    // Call safeSetState during build. This should defer to postFrameCallback.
    if (rebuildCount == 0) {
      safeSetState(() {
        target = target + 1;
      });
    }
    rebuildCount++;
  }
}

class SafeSetStateDuringBuildWidget extends StatefulWidget {
  const SafeSetStateDuringBuildWidget({super.key});
  @override
  SafeSetStateDuringBuildWidgetState createState() =>
      SafeSetStateDuringBuildWidgetState();
}

class SafeSetStateDuringBuildWidgetState
    extends State<SafeSetStateDuringBuildWidget> with LifecycleOwnerMixin {
  late final observer = SafeSetStateObserver(this);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text('${observer.target}');
  }
}

// Test for safeSetState when disposed
class DisposedStateWidget extends StatefulWidget {
  const DisposedStateWidget({super.key});
  @override
  DisposedStateWidgetState createState() => DisposedStateWidgetState();
}

class DisposedStateObserver extends LifecycleObserver<int> {
  DisposedStateObserver(super.state);

  @override
  int buildTarget() => 0;

  void callSafeSetState() {
    safeSetState(() {
      target = 999;
    });
  }
}

class DisposedStateWidgetState extends State<DisposedStateWidget>
    with LifecycleOwnerMixin {
  late final observer = DisposedStateObserver(this);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}
