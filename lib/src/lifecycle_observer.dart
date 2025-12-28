import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

/// Zone key for accessing the parent's addLifecycleObserver function.
/// This enables nested observers to register with the top-level State.
final _addLifecycleObserverZoneKey = Object();

/// Returns the Zone key for addLifecycleObserver.
/// Used internally by LifecycleOwnerMixin.
Object get addLifecycleObserverZoneKey => _addLifecycleObserverZoneKey;

/// The current lifecycle state of the observer/owner.
enum LifecycleState {
  /// The object is created but not yet initialized.
  created,

  /// The object's [initState] has been called.
  initialized,

  /// The object's [dispose] has been called.
  disposed,
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
  /// If the [state] does not mixin [LifecycleOwnerMixin], this will throw
  /// an assertion error.
  ///
  /// ## Nested Observer Support (Zone-based Registration)
  ///
  /// This constructor supports nested observers, where an observer can create
  /// child observers within its lifecycle methods (e.g., [onInitState]).
  ///
  /// When [state] is a [LifecycleOwnerMixin], the observer registers directly.
  /// When [state] is not a [LifecycleOwnerMixin] (e.g., when creating a nested
  /// observer inside another observer), the constructor looks up the
  /// [addLifecycleObserver] function from the current Dart [Zone].
  ///
  /// The [LifecycleOwnerMixin] runs all observer lifecycle callbacks inside
  /// a Zone that provides access to its [addLifecycleObserver] method via
  /// [addLifecycleObserverZoneKey]. This allows nested observers to register
  /// with the top-level State without needing a direct reference to it.
  ///
  /// **Example:**
  /// ```dart
  /// class ParentObserver extends LifecycleObserver<void> {
  ///   ParentObserver(super.state);
  ///
  ///   @override
  ///   void onInitState() {
  ///     // This nested observer will register via Zone lookup.
  ///     ChildObserver(state);
  ///   }
  /// }
  /// ```
  LifecycleObserver(this.state, {this.key}) {
    if (state is LifecycleOwnerMixin) {
      // Direct registration: state is a LifecycleOwnerMixin.
      // ignore: invalid_use_of_protected_member
      (state as LifecycleOwnerMixin).addLifecycleObserver(this);
    } else {
      // Zone-based registration: look up addLifecycleObserver from the Zone.
      // This enables nested observers created inside another observer's
      // lifecycle methods to register with the top-level State.
      final addObserver = Zone.current[_addLifecycleObserverZoneKey] as void
          Function(LifecycleObserver)?;
      if (addObserver != null) {
        addObserver(this);
      } else {
        throw StateError(
            'State must mixin LifecycleOwnerMixin to use LifecycleObserver');
      }
    }
  }

  /// Registers a [LifecycleObserver] to be managed by this state.
  // coverage:ignore-start
  @protected
  void addLifecycleObserver(LifecycleObserver observer) {}
  // coverage:ignore-end

  /// Called when the observer is initialized.
  ///
  /// This is where [target] is built and [currentKey] is set.
  /// This method is idempotent.
  @mustCallSuper
  @protected
  void onInitState() {
    currentKey = key?.call();
    target = buildTarget();
  }

  /// Called when the widget configuration updates.
  @protected
  void onDidUpdateWidget() {}

  /// Called during the `build` phase of the widget.
  ///
  /// If the [key] has changed, the [target] is disposed and rebuilt.
  @mustCallSuper
  @protected
  void onBuild(BuildContext context) {
    if (currentKey != key?.call()) {
      onDisposeTarget(target);
      onInitState();
    }
  }

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
    if (state is LifecycleOwnerMixin &&
        (state as LifecycleOwnerMixin).lifecycleState ==
            LifecycleState.disposed) {
      return;
    }
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    if (schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // ignore: invalid_use_of_protected_member
      state.setState(fn);
    } else {
      // coverage:ignore-start
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member
        if (state.mounted) state.setState(fn);
      });
      // coverage:ignore-end
    }
  }
}
