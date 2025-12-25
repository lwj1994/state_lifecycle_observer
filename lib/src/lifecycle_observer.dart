import 'package:flutter/widgets.dart';

/// Interface for States that can manage LifecycleObservers.
abstract class StateWithObservers {
  void registerObserver(LifecycleObserver observer);
}

/// [V] is the type of the managed value (e.g., AnimationController).
abstract class LifecycleObserver<V> {
  late V target;
  late State state;

  Object? currentKey;

  Object? Function()? key;

  LifecycleObserver(this.state, {this.key}) {
    if (state is StateWithObservers) {
      (state as StateWithObservers).registerObserver(this);
    } else {
      assert(false,
          'State must mixin LifecycleObserverMixin to use LifecycleObserver');
    }
    currentKey = key?.call();
    target = buildTarget();
  }

  @mustCallSuper
  void onDidUpdateWidget() {
    if (currentKey != key?.call()) {
      currentKey = key?.call();
      onDisposeTarget(target);
      target = buildTarget();
    }
  }

  void onBuild(BuildContext context) {}

  @mustCallSuper
  void onDispose() {
    onDisposeTarget(target);
  }

  void onDisposeTarget(V target) {}

  V buildTarget();
}
