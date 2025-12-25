import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

// Test implementation for new observers
class AdditionalObserversTestWidget extends StatefulWidget {
  const AdditionalObserversTestWidget({super.key});

  @override
  State<AdditionalObserversTestWidget> createState() =>
      _AdditionalObserversTestWidgetState();
}

class _AdditionalObserversTestWidgetState
    extends State<AdditionalObserversTestWidget>
    with TickerProviderStateMixin, LifecycleObserverMixin {
  late ScrollControllerObserver scrollObserver;
  late TabControllerObserver tabObserver;
  late TextEditingControllerObserver textObserver;

  @override
  void initState() {
    super.initState();
    scrollObserver = ScrollControllerObserver(
      this,
      initialScrollOffset: 50.0,
      debugLabel: 'testScroll',
    );

    tabObserver = TabControllerObserver(
      this,
      length: 3,
      initialIndex: 1,
    );

    textObserver = TextEditingControllerObserver(
      this,
      text: 'Hello World',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Text(textObserver.target.text),
        Container(height: scrollObserver.target.initialScrollOffset),
      ],
    );
  }
}

void main() {
  testWidgets('Additional Observers initialize correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AdditionalObserversTestWidget(),
    ));

    final state = tester.state<_AdditionalObserversTestWidgetState>(
        find.byType(AdditionalObserversTestWidget));

    // Verify ScrollController
    expect(state.scrollObserver.target, isNotNull);
    expect(state.scrollObserver.target.initialScrollOffset, 50.0);

    // Verify TabController
    expect(state.tabObserver.target, isNotNull);
    expect(state.tabObserver.target.length, 3);
    expect(state.tabObserver.target.index, 1);

    // Verify TextEditingController
    expect(state.textObserver.target, isNotNull);
    expect(state.textObserver.target.text, 'Hello World');
  });

  testWidgets('Observers are disposed correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AdditionalObserversTestWidget(),
    ));

    // Triggers dispose
    await tester.pumpWidget(const SizedBox());
  });
}
