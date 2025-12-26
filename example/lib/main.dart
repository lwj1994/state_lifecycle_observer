import 'package:flutter/material.dart';

import 'examples/hello_world.dart';
import 'examples/timer.dart';
import 'examples/animation_usage.dart';
import 'examples/multiple_controllers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const GalleryPage(),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State Lifecycle Observer Gallery')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Basic Usage'),
            subtitle: const Text('Hello World with multiple observers'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelloWorldExample()),
              );
            },
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            title: const Text('Custom Observer: Timer'),
            subtitle: const Text('Reusable Timer logic'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TimerExample()));
            },
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            title: const Text('Custom Observer: useAnimation'),
            subtitle: const Text(
              'Rebuilds on animation tick (no AnimatedBuilder)',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AnimationUsageExample(),
                ),
              );
            },
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            title: const Text('Refutation: Multiple Controllers'),
            subtitle: const Text(
              '2 AnimationControllers + 1 TextEditingController',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MultipleControllersExample(),
                ),
              );
            },
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
