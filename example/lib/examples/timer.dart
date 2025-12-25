import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

import '../observers/timer_observer.dart';

class TimerExample extends StatefulWidget {
  const TimerExample({super.key});

  @override
  State<TimerExample> createState() => _TimerExampleState();
}

class _TimerExampleState extends State<TimerExample>
    with LifecycleObserverMixin<TimerExample> {
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    TimerObserver(
      this,
      duration: const Duration(seconds: 1),
      onTimerCallback: (timer) {
        setState(() {
          _counter++;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Timer Observer Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Counter increments every second:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            const Text(
              'The Timer is automatically cancelled when you leave this page.',
            ),
          ],
        ),
      ),
    );
  }
}
