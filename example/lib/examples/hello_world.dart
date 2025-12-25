import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class HelloWorldExample extends StatefulWidget {
  const HelloWorldExample({super.key});

  @override
  State<HelloWorldExample> createState() => _HelloWorldExampleState();
}

class _HelloWorldExampleState extends State<HelloWorldExample>
    with TickerProviderStateMixin, LifecycleObserverMixin<HelloWorldExample> {
  // 1. Declare Observers for Tabs
  late TabControllerObserver _tab;

  // 2. Declare Observers for Tab 1 (Anim)
  late AnimControllerObserver _anim;

  // 3. Declare Observers for Tab 2 (Scroll)
  late ScrollControllerObserver _scroll;

  // 4. Declare Observers for Tab 3 (Input)
  late TextEditingControllerObserver _text;

  @override
  void initState() {
    super.initState();

    // Initialize Tab Controller
    _tab = TabControllerObserver(this, length: 3, initialIndex: 0);

    // Initialize Animation
    _anim = AnimControllerObserver(
      this,
      duration: () => const Duration(seconds: 2),
      lowerBound: 0.5,
      upperBound: 1.0,
    );
    _anim.target.repeat(reverse: true);

    // Initialize Scroll
    _scroll = ScrollControllerObserver(this, initialScrollOffset: 0.0);

    // Initialize Text
    _text = TextEditingControllerObserver(this, text: 'Hello from Observer!');
  }

  @override
  Widget build(BuildContext context) {
    // Notify observers about build
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observer Example'),
        bottom: TabBar(
          controller: _tab.target,
          tabs: const [
            Tab(icon: Icon(Icons.animation), text: 'Animation'),
            Tab(icon: Icon(Icons.list), text: 'Scroll'),
            Tab(icon: Icon(Icons.text_fields), text: 'Input'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab.target,
        children: [_buildAnimTab(), _buildScrollTab(), _buildTextTab()],
      ),
    );
  }

  Widget _buildAnimTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _anim.target,
            child: const FlutterLogo(size: 150),
          ),
          const SizedBox(height: 20),
          const Text('AnimationController is managed automatically.'),
        ],
      ),
    );
  }

  Widget _buildScrollTab() {
    return ListView.builder(
      controller: _scroll.target,
      itemCount: 100,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text('Item $index'),
          subtitle: const Text(
            'Scroll state managed by ScrollControllerObserver',
          ),
        );
      },
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _text.target,
            decoration: const InputDecoration(
              labelText: 'Type something',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder(
            valueListenable: _text.target,
            builder: (context, value, child) {
              return Text(
                'Current Value: ${value.text}',
                style: Theme.of(context).textTheme.headlineSmall,
              );
            },
          ),
        ],
      ),
    );
  }
}
