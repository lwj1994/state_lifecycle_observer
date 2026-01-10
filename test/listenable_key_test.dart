import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

/// This test verifies the fix for ListenableObserver listener leak
/// when using the key parameter.

class KeyTestWidget extends StatefulWidget {
  final int userId;
  const KeyTestWidget({super.key, required this.userId});

  @override
  State<KeyTestWidget> createState() => _KeyTestWidgetState();
}

class _KeyTestWidgetState extends State<KeyTestWidget>
    with LifecycleOwnerMixin<KeyTestWidget> {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  late final ListenableObserver observer;

  int buildCount = 0;

  @override
  void initState() {
    super.initState();
    observer = ListenableObserver(
      this,
      listenable: notifier,
      key: () => widget.userId, // Use key parameter
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    buildCount++;
    return Text('Builds: $buildCount');
  }
}

void main() {
  testWidgets(
      'ListenableObserver with key maintains listener after key change',
      (tester) async {
    // 1. Initial render with userId = 1
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyTestWidget(userId: 1),
      ),
    );

    final state = tester.state<_KeyTestWidgetState>(find.byType(KeyTestWidget));
    final initialBuildCount = state.buildCount;

    // 2. Trigger notifier update, should trigger rebuild
    state.notifier.value = 100;
    await tester.pump();
    expect(state.buildCount, initialBuildCount + 1); // ✓ Should work

    // 3. Update widget, userId changes from 1 to 2 (triggers key change)
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyTestWidget(userId: 2),
      ),
    );

    final buildCountAfterKeyChange = state.buildCount;

    // 4. Trigger notifier update again
    state.notifier.value = 200;
    await tester.pump();

    // ✓ FIXED: buildCount should increase because listener is re-added in onInitState
    expect(state.buildCount, buildCountAfterKeyChange + 1);

    // 5. Verify one more time to ensure listener is still working
    state.notifier.value = 300;
    await tester.pump();
    expect(state.buildCount, buildCountAfterKeyChange + 2);
  });

  testWidgets('ListenableObserver without key works normally', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyTestWidget(userId: 1),
      ),
    );

    final state = tester.state<_KeyTestWidgetState>(find.byType(KeyTestWidget));
    final initialBuildCount = state.buildCount;

    // Trigger multiple notifier updates
    state.notifier.value = 100;
    await tester.pump();
    expect(state.buildCount, initialBuildCount + 1);

    state.notifier.value = 200;
    await tester.pump();
    expect(state.buildCount, initialBuildCount + 2);
  });
}
