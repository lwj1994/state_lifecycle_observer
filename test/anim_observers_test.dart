import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

// Wrapper widget for AnimControllerObserver
class AnimTestWidget extends StatefulWidget {
  final Duration duration;
  final Duration? reverseDuration;
  const AnimTestWidget({
    super.key,
    required this.duration,
    this.reverseDuration,
  });

  @override
  State<AnimTestWidget> createState() => _AnimTestWidgetState();
}

class _AnimTestWidgetState extends State<AnimTestWidget>
    with TickerProviderStateMixin, LifecycleObserverMixin {
  late AnimControllerObserver animObserver;

  @override
  void initState() {
    super.initState();
    animObserver = AnimControllerObserver(
      this,
      duration: () => widget.duration,
      reverseDuration: () => widget.reverseDuration,
      debugLabel: 'testAnim',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by Mixin
    return Container();
  }
}

// Simple Animation implementation for testing
class TestAnimation extends Animation<double>
    with
        AnimationLazyListenerMixin,
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin {
  double _value = 0.0;

  @override
  double get value => _value;

  set value(double newValue) {
    _value = newValue;
    notifyListeners();
  }

  AnimationStatus _status = AnimationStatus.forward;
  @override
  AnimationStatus get status => _status;
  set status(AnimationStatus s) {
    _status = s;
    notifyStatusListeners(s);
  }

  @override
  void didStartListening() {}

  @override
  void didStopListening() {}
}

class AnimationObserverTestWidget extends StatefulWidget {
  const AnimationObserverTestWidget({super.key});

  @override
  State<AnimationObserverTestWidget> createState() =>
      _AnimationObserverTestWidgetState();
}

class _AnimationObserverTestWidgetState
    extends State<AnimationObserverTestWidget> with LifecycleObserverMixin {
  final TestAnimation animation = TestAnimation();
  late AnimationObserver<double> observer;

  @override
  void initState() {
    super.initState();
    observer = AnimationObserver(
      this,
      animation: animation,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(observer.target.toString());
  }
}

void main() {
  testWidgets('AnimControllerObserver initializes and updates',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AnimTestWidget(duration: Duration(seconds: 1)),
    ));

    final state =
        tester.state<_AnimTestWidgetState>(find.byType(AnimTestWidget));
    expect(state.animObserver.target, isNotNull);
    expect(state.animObserver.target.duration, const Duration(seconds: 1));
    expect(state.animObserver.target.reverseDuration, isNull);
    expect(state.animObserver.target.debugLabel, 'testAnim');

    // Update duration and reverseDuration
    await tester.pumpWidget(const MaterialApp(
      home: AnimTestWidget(
        duration: Duration(seconds: 2),
        reverseDuration: Duration(milliseconds: 500),
      ),
    ));

    expect(state.animObserver.target.duration, const Duration(seconds: 2));
    expect(state.animObserver.target.reverseDuration,
        const Duration(milliseconds: 500));

    // Dispose
    await tester.pumpWidget(const SizedBox());
    // AnimationController.dispose() is called (implied).
  });

  testWidgets('AnimationObserver rebuilds on animation change',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AnimationObserverTestWidget(),
    ));

    expect(find.text('0.0'), findsOneWidget);

    final state = tester.state<_AnimationObserverTestWidgetState>(
        find.byType(AnimationObserverTestWidget));

    // Animate
    state.animation.value = 0.5;
    await tester.pump();

    expect(find.text('0.5'), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
  });
}
