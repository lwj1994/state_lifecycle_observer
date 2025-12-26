import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Interface for States that can manage [LifecycleObserver]s.
///
/// This interface is typically implemented by [LifecycleObserverMixin].
abstract class StateWithObservers {
  /// Registers a [LifecycleObserver] to be managed by this state.
  void registerObserver(LifecycleObserver observer);
}

/// A base class for observers that manage a specific target object [V].
///
/// [V] is the type of the managed value (e.g., [AnimationController]).
/// The observer automatically manages the creation, disposal, and updates
/// of the target object based on the widget's lifecycle.
abstract class LifecycleObserver<V> {
  /// The managed target object, such as a controller.
  late V target;

  /// The [State] object that this observer is attached to.
  final State state;

  /// The current key value used to detect changes.
  @protected
  Object? currentKey;

  /// A function that returns a key to identify when the target needs
  /// to be rebuilt.
  final Object? Function()? key;

  /// Creates a [LifecycleObserver] attached to the given [state].
  ///
  /// If the [state] does not mixin [LifecycleObserverMixin], this will throw
  /// an assertion error.
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

  /// Called when the widget configuration updates.
  ///
  /// If the [key] has changed, the [target] is disposed and rebuilt.
  @mustCallSuper
  @protected
  void onDidUpdateWidget() {
    if (currentKey != key?.call()) {
      currentKey = key?.call();
      onDisposeTarget(target);
      target = buildTarget();
    }
  }

  /// Called during the `build` phase of the widget.
  @protected
  void onBuild(BuildContext context) {}

  /// Called when the state is disposed.
  ///
  /// Automatically calls [onDisposeTarget] to clean up the [target].
  @mustCallSuper
  @protected
  void onDispose() {
    onDisposeTarget(target);
  }

  /// Override this method to perform cleanup for the [target].
  ///
  /// For example, call `target.dispose()` for controllers.
  @protected
  void onDisposeTarget(V target) {}

  /// Builds the target instance [V].
  ///
  /// This method is called when the observer is initialized or when the
  /// [key] changes.
  @protected
  V buildTarget();

  /// Safely calls [setState] on the managed [state].
  ///
  /// Checks the current scheduler phase. If the frame is being built, laid out,
  /// or painted, the update is deferred to the next frame. Otherwise, it is
  /// applied immediately.
  @protected
  void safeSetState(VoidCallback fn) {
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // ignore: invalid_use_of_protected_member
      state.setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member
        if (state.mounted) state.setState(fn);
      });
    }
  }
}
