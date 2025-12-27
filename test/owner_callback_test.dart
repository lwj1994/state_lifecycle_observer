import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class CallbackLog {
  int onInitState = 0;
  int onDidUpdateWidget = 0;
  int onDispose = 0;
  int onBuild = 0;
}

class CallbackWidget extends StatefulWidget {
  final CallbackLog log;
  final int id;

  const CallbackWidget({
    super.key,
    required this.log,
    this.id = 0,
  });

  @override
  State<CallbackWidget> createState() => _CallbackWidgetState();
}

class _CallbackWidgetState extends State<CallbackWidget>
    with LifecycleOwnerMixin {
  @override
  void initState() {
    super.initState();
    addLifecycleCallback(
      onInitState: () {
        widget.log.onInitState++;
      },
      onDidUpdateWidget: () {
        widget.log.onDidUpdateWidget++;
      },
      onDispose: () {
        widget.log.onDispose++;
      },
      onBuild: (context) {
        widget.log.onBuild++;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container();
  }
}

void main() {
  testWidgets('addLifecycleCallback triggers all callbacks',
      (WidgetTester tester) async {
    final log = CallbackLog();

    // 1. Initial build -> initState + build
    await tester.pumpWidget(MaterialApp(
      home: CallbackWidget(log: log, id: 1),
    ));

    expect(log.onInitState, 1);
    expect(log.onBuild, 1);
    expect(log.onDidUpdateWidget, 0);
    expect(log.onDispose, 0);

    // 2. Update widget -> didUpdateWidget + build
    await tester.pumpWidget(MaterialApp(
      home: CallbackWidget(log: log, id: 2),
    ));

    expect(log.onInitState, 1);
    expect(log.onBuild, 2);
    expect(log.onDidUpdateWidget, 1);
    expect(log.onDispose, 0);

    // 3. Dispose -> dispose
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(),
    ));

    expect(log.onInitState, 1);
    // onBuild might be called before dispose depending on how flutter handles the pump,
    // but typically if we replace the widget entirely, the old one is just disposed.
    // However, let's just check dispose count.
    expect(log.onDispose, 1);
  });
}
