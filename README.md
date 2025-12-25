# Flutter State Observer

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

You can easily create your own observers by extending `LifecycleObserver`.

Example: A `UserDataObserver` that:
1. Initializes data fetching in `onInit`.
2. Refetches data when `userId` changes in `onUpdate`.
3. Logs debug info in `onBuild`.

```dart
import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class Data {
  final String id;
  final String info;
  Data(this.id, this.info);
}

class UserDataObserver extends LifecycleObserver<ValueNotifier<Data?>> {
  // Mechanism to retrieve the latest param from the widget
  final String Function() getUserId;
  
  // Internal state to track changes
  late String _currentUserId;

  UserDataObserver(
    super.state, {
    required this.getUserId,
  });

  @override
  void onInit() {
    target = ValueNotifier(null);
    _currentUserId = getUserId();
    _fetchData(_currentUserId);
  }

  @override
  void onUpdate() {
    // Check if the dependency (userId) has changed
    final newUserId = getUserId();
    if (newUserId != _currentUserId) {
      debugPrint('UserId changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;
      _fetchData(_currentUserId);
    }
  }

  @override
  void onBuild(BuildContext context) {
    debugPrint('Building with user: $_currentUserId');
  }

  @override
  void onDispose() {
    target.dispose();
  }

  void _fetchData(String id) async {
    // Simulate network request
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentUserId == id) { // Avoid race conditions
      target.value = Data(id, 'Info for $id');
    }
  }
}
  }
}
```

## Comparison with flutter_hooks

| Feature | state_lifecycle_observer | flutter_hooks |
| :--- | :--- | :--- |
| **Paradigm** | OOP (Classes) | Functional (Hooks) |
| **Base Class** | Standard `StatefulWidget` | `HookWidget` |
| **Lifecycle** | Explicit (`onInit`, `onDispose`) | Implicit (`useEffect`) |
| **Learning Curve** | Low (Standard Flutter) | Moderate (Rules of Hooks) |
| **Magic** | Low (Mixin + List) | High (Element logic) |
| **Conditional Logic** | Supported anywhere | Not allowed in `build` |

### Why choose state_lifecycle_observer?
- You prefer object-oriented programming.
- You want to stick to standard `StatefulWidget`.
- You dislike the "Rules of Hooks" (e.g., no conditional hooks).
- You want explicit control over initialization and disposal.
