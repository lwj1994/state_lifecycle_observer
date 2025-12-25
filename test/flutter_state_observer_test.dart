import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

// Test implementation of ObserverMixin
class TestWidget extends StatefulWidget {
  final Duration speed;
  const TestWidget({super.key, required this.speed});

  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget>
    with TickerProviderStateMixin, LifecycleObserverMixin {
  late AnimControllerObserver animObserver;
  AnimationController get controller {
    return animObserver.target;
  }

  @override
  void initState() {
    super.initState();
    animObserver = AnimControllerObserver(
      this,
      duration: () => widget.speed,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

void main() {
  testWidgets('AnimControllerObserver syncs duration on widget update',
      (WidgetTester tester) async {
    const duration1 = Duration(seconds: 1);
    const duration2 = Duration(seconds: 2);

    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(speed: duration1),
    ));

    final state = tester.state<_TestWidgetState>(find.byType(TestWidget));
    expect(state.animObserver.target.duration, duration1);

    // Update widget with new duration
    await tester.pumpWidget(const MaterialApp(
      home: TestWidget(speed: duration2),
    ));

    expect(state.animObserver.target.duration, duration2);
  });
}
