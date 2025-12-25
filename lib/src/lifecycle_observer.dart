import 'package:flutter/widgets.dart';

/// Interface for States that can manage LifecycleObservers.
abstract class StateWithObservers {
  void registerObserver(LifecycleObserver observer);
}

/// [V] is the type of the managed value (e.g., AnimationController).
/// [S] is the type of the State that owns this observer.
abstract class LifecycleObserver<V> {
  late V target;
  late State state;

  LifecycleObserver(this.state) {
    if (state is StateWithObservers) {
      (state as StateWithObservers).registerObserver(this);
    }
    onInit();
  }

  /// Lifecycle hooks for subclasses to override.
  void onInit() {}
  void onUpdate() {}
  void onBuild(BuildContext context) {}
  void onDispose() {}
}
