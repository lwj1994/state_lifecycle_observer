# state_lifecycle_observer

[![pub package](https://img.shields.io/pub/v/state_lifecycle_observer.svg)](https://pub.dev/packages/state_lifecycle_observer)

A Flutter package to solve state reuse problems using an Observer pattern.

## Features

- **LifecycleObserver**: A base class for creating reusable state observers.
- **LifecycleObserverMixin**: A mixin to manage the lifecycle of observers within a `State`.
- **Common Observers**:
  - `AnimControllerObserver`: Reusable `AnimationController` logic.
  - `ScrollControllerObserver`: Manages `ScrollController`.
  - `TabControllerObserver`: Manages `TabController`.
  - `TextEditingControllerObserver`: Manages `TextEditingController`.

## Usage

1. Create a `StatefulWidget` and mixin `LifecycleObserverMixin`.
2. Instantiate observers in `initState`. They automatically register themselves.
3. Call `super.build(context)` in your `build` method.

```dart
class MyLogo extends StatefulWidget {
  final Duration speed;
  const MyLogo({super.key, required this.speed});

  @override
  State<MyLogo> createState() => _MyLogoState();
}

class _MyLogoState extends State<MyLogo> 
    with TickerProviderStateMixin, LifecycleObserverMixin<MyLogo> {
  
  late AnimControllerObserver _animObserver;
  late ScrollControllerObserver _scrollObserver;

  @override
  void initState() {
    super.initState();

    // LOGIC REUSE: Pass 'this' as the first argument.
    // The observer automatically registers itself to the mixin.
    _animObserver = AnimControllerObserver(
      this,
      duration: () => widget.speed,
    );

    _scrollObserver = ScrollControllerObserver(
      this,
      initialScrollOffset: 100.0,
    );

    _animObserver.target.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    // Notify observers about build
    super.build(context);
    
    return SingleChildScrollView(
      controller: _scrollObserver.target,
      child: ScaleTransition(
        scale: _animObserver.target, 
        child: const FlutterLogo()
      ),
    );
  }
}
```

### Using `key` to Recreate Targets

The `key` parameter functions similarly to React's `useEffect` dependencies or Flutter's `Key`.
When the value returned by the `key` callback changes, the observer will:
1. Dispose the current `target` (calls `onDisposeTarget`).
2. Re-create the `target` (calls `buildTarget`).

This is useful when your Controller depends on a specific property (e.g. `userId`) and needs to be fully reset when that property changes.

```dart
_observer = MyObserver(
  this,
  // When 'userId' changes, the old target is disposed and a new one is built.
  key: () => widget.userId, 
);
```

### Available Observers

#### AnimControllerObserver
Syncs properties from widget automatically. Support all `AnimationController` properties.
Requires `TickerProvider` (mix your state with `TickerProviderStateMixin`).

```dart
_anim = AnimControllerObserver(
  this,
  duration: () => widget.duration,
  reverseDuration: () => widget.reverseDuration,
  lowerBound: 0.0,
  upperBound: 1.0,
  debugLabel: 'MyAnim',
);
```

#### ScrollControllerObserver
Simplifies creation and disposal of `ScrollController`.

```dart
_scroll = ScrollControllerObserver(
  this,
  initialScrollOffset: 0.0,
  keepScrollOffset: true,
);
```

#### TabControllerObserver
Simplifies creation and disposal of `TabController`.
Requires `TickerProvider`.

```dart
_tab = TabControllerObserver(
  this,
  length: 3,
  initialIndex: 0,
);
```

#### TextEditingControllerObserver
Simplifies creation and disposal of `TextEditingController`.

```dart
_text = TextEditingControllerObserver(
  this,
  text: 'Initial Text',
);
```

### Custom Observer

You can easily create your own observers by extending `LifecycleObserver<V>`.

Example: A `UserDataObserver` that fetches data.

```dart
import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class Data {
  final String id;
  final String info;
  Data(this.id, this.info);
}

// LifecycleObserver<V> where V is ValueNotifier<Data?>
class UserDataObserver extends LifecycleObserver<ValueNotifier<Data?>> {
  // Mechanism to retrieve the latest param from the widget
  final String Function() getUserId;
  
  // Internal state to track changes
  late String _currentUserId;

  UserDataObserver(
    super.state, {
    required this.getUserId,
  });

  // 1. Create the target (called in constructor and when key changes)
  @override
  ValueNotifier<Data?> buildTarget() {
    _currentUserId = getUserId();
    final notifier = ValueNotifier<Data?>(null);
    _fetchData(_currentUserId, notifier); // Start fetch
    return notifier;
  }

  // 2. Handle widget updates (if key doesn't change)
  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    // Check if the dependency (userId) has changed without triggering a full rebuild (if key wasn't used)
    final newUserId = getUserId();
    if (newUserId != _currentUserId) {
      debugPrint('UserId changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;
      _fetchData(_currentUserId, target);
    }
  }

  @override
  void onBuild(BuildContext context) {
    debugPrint('Building with user: $_currentUserId');
  }

  // 3. Cleanup
  @override
  void onDisposeTarget(ValueNotifier<Data?> target) {
    target.dispose();
  }

  void _fetchData(String id, ValueNotifier<Data?> notifier) async {
    // Simulate network request
    await Future.delayed(const Duration(milliseconds: 500));
    // Simple check to avoid race conditions if observer was disposed/recreated
    if (_currentUserId == id) { 
      notifier.value = Data(id, 'Info for $id');
    }
  }
}
```

## Comparison with flutter_hooks

| Feature | state_lifecycle_observer | flutter_hooks |
| :--- | :--- | :--- |
| **Paradigm** | OOP (Classes) | Functional (Hooks) |
| **Base Class** | Standard `StatefulWidget` | `HookWidget` |
| **Lifecycle** | Explicit (`buildTarget`, `onDispose`) | Implicit (`useEffect`) |
| **Learning Curve** | Low (Standard Flutter) | Moderate (Rules of Hooks) |
| **Magic** | Low (Mixin + List) | High (Element logic) |
| **Conditional Logic** | Supported anywhere | only allowed in `build` |


