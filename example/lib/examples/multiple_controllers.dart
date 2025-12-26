import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class MultipleControllersExample extends StatefulWidget {
  const MultipleControllersExample({super.key});

  @override
  State<MultipleControllersExample> createState() =>
      _MultipleControllersExampleState();
}

class _MultipleControllersExampleState extends State<MultipleControllersExample>
    with TickerProviderStateMixin {
  // 1. Refute "creating two AnimationControllers is impossible":
  // We can create multiple observers. Each one requests a Ticker from the state.
  // Since we mixin [TickerProviderStateMixin] (not SingleTickerProviderStateMixin),
  // we can vend multiple tickers.
  late final _animController1 = AnimControllerObserver(
    this,
    duration: () => const Duration(seconds: 2),
  );

  late final _animController2 = AnimControllerObserver(
    this,
    duration: () => const Duration(seconds: 5),
  );

  // 2. Refute "conflict with each other on names":
  // Since we use Composition (Observers) instead of Inheritance (Mixins),
  // there is no namespace conflict.
  late final _textController = TextEditingControllerObserver(
    this,
    text: "Editable Text",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multiple Controllers Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Demonstrating usage of multiple AnimationControllers and a TextEditingController simultaneously using observers.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const Divider(),
            _buildAnimSection("Controller 1 (2s)", _animController1.target),
            const SizedBox(height: 16),
            _buildAnimSection("Controller 2 (5s)", _animController2.target),
            const Divider(),
            TextField(
              controller: _textController.target,
              decoration: const InputDecoration(
                labelText: "Text Controller",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimSection(String label, AnimationController controller) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                LinearProgressIndicator(value: controller.value),
          ),
        ),
        IconButton(
          onPressed: () {
            if (controller.isAnimating) {
              controller.stop();
            } else {
              controller.forward(from: 0);
            }
          },
          icon: Icon(controller.isAnimating ? Icons.pause : Icons.play_arrow),
        ),
      ],
    );
  }
}
