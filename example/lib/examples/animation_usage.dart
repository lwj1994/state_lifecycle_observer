import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class AnimationUsageExample extends StatefulWidget {
  const AnimationUsageExample({super.key});

  @override
  State<AnimationUsageExample> createState() => _AnimationUsageExampleState();
}

class _AnimationUsageExampleState extends State<AnimationUsageExample>
    with TickerProviderStateMixin, LifecycleOwnerMixin<AnimationUsageExample> {
  late AnimationController _controller;
  late Animation<double> _animation;
  // Initialize the observer

  @override
  void initState() {
    super.initState();
    // Standard AnimationController setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Register observer to trigger rebuilds on animation tick
    ListenableObserver(this, listenable: _animation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('useAnimation Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100 + (_animation.value * 100),
              height: 100 + (_animation.value * 100),
              color: Colors.blue,
              child: const Center(
                child: Text('Grow', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Value: ${_animation.value.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'The widget rebuilds on every animation tick because of ListenableObserver.\n'
                'No AnimatedBuilder needed.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
