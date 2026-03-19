import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

/// Zone key for accessing the parent's addLifecycleObserver function.
/// This enables nested observers to register with the top-level State.
final _addLifecycleObserverZoneKey = Object();

/// Zone key for tracking the currently executing observer.
///
/// This lets the owner preserve parent-child relationships for composed
/// observers created inside lifecycle callbacks.
final _currentLifecycleObserverZoneKey = Object();

/// Zone key for accessing the owner's child-disposal callback.
final _disposeLifecycleObserverChildrenZoneKey = Object();

/// Zone key for accessing the owner's observer-removal callback.
final _removeLifecycleObserverZoneKey = Object();

/// Returns the Zone key for addLifecycleObserver.
/// Used internally by LifecycleOwnerMixin.
Object get addLifecycleObserverZoneKey => _addLifecycleObserverZoneKey;

/// Returns the Zone key for the currently executing observer.
Object get currentLifecycleObserverZoneKey => _currentLifecycleObserverZoneKey;

/// Returns the Zone key for disposing an observer's child subtree.
Object get disposeLifecycleObserverChildrenZoneKey =>
    _disposeLifecycleObserverChildrenZoneKey;

/// Returns the Zone key for removing an observer from its owner.
Object get removeLifecycleObserverZoneKey => _removeLifecycleObserverZoneKey;

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
  bool _hasTarget = false;

  /// The [State] object that this observer is attached to.
  final State state;

  /// The current key value used to detect changes.
  @protected
  Object? currentKey;

  /// A function that returns a key to identify when the target needs
  /// to be rebuilt.
  final Object? Function()? key;

  late final void Function(LifecycleObserver)?
      _disposeLifecycleObserverChildren;
  late final void Function(LifecycleObserver)? _removeLifecycleObserver;

  /// Creates a [LifecycleObserver] attached to the given [state].
  ///
  /// If the [state] does not mixin [LifecycleOwnerMixin], this will throw
  /// a [StateError].
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
      final owner = state as LifecycleOwnerMixin;
      _disposeLifecycleObserverChildren = (observer) {
        // ignore: invalid_use_of_protected_member
        owner.disposeLifecycleObserverChildren(observer);
      };
      _removeLifecycleObserver = (observer) {
        // ignore: invalid_use_of_protected_member
        owner.removeLifecycleObserver(observer);
      };
      // Direct registration: state is a LifecycleOwnerMixin.
      // ignore: invalid_use_of_protected_member
      owner.addLifecycleObserver(this);
    } else {
      _disposeLifecycleObserverChildren =
          Zone.current[_disposeLifecycleObserverChildrenZoneKey] as void
              Function(LifecycleObserver)?;
      _removeLifecycleObserver = Zone.current[_removeLifecycleObserverZoneKey]
          as void Function(LifecycleObserver)?;
      // Zone-based registration: look up addLifecycleObserver from the Zone.
      // This enables nested observers created inside another observer's
      // lifecycle methods to register with the top-level State.
      final addObserver = Zone.current[_addLifecycleObserverZoneKey] as void
          Function(LifecycleObserver)?;
      if (addObserver != null) {
        addObserver(this);
      } else {
        throw StateError(
            'LifecycleObserver creation failed: The provided State does not mixin LifecycleOwnerMixin, '
            'and no Zone-based registration is available. '
            'This usually means:\n'
            '1. Your State class is missing "with LifecycleOwnerMixin<YourWidget>"\n'
            '2. You are creating an observer outside of lifecycle methods (e.g., in a non-observer constructor)\n'
            'Please ensure your State mixes in LifecycleOwnerMixin.');
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
    _hasTarget = true;
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
      _disposeLifecycleObserverChildren?.call(this);
      if (_hasTarget) {
        onDisposeTarget(target);
        _hasTarget = false;
      }
      try {
        onInitState();
      } catch (_) {
        // Remove the observer entirely so a failed re-init cannot leave
        // a partially rebuilt subtree registered for later frames.
        _removeLifecycleObserver?.call(this);
        rethrow;
      }
    }
  }

  /// Called when the state is disposed.
  ///
  /// Automatically calls [onDisposeTarget] to clean up the [target].
  @mustCallSuper
  @protected
  void onDispose() {
    disposeTargetIfNeeded();
  }

  /// Ensures the current [target] is disposed at most once.
  ///
  /// Used internally by [LifecycleOwnerMixin] to guarantee cleanup even when
  /// an observer override throws before reaching `super.onDispose()`.
  void disposeTargetIfNeeded() {
    if (!_hasTarget) {
      return;
    }
    onDisposeTarget(target);
    _hasTarget = false;
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
    if (!state.mounted) {
      return;
    }
    if (state is LifecycleOwnerMixin &&
        (state as LifecycleOwnerMixin).lifecycleState ==
            LifecycleState.disposed) {
      return;
    }
    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    // Only defer while Flutter is actively building/layouting/painting.
    if (schedulerPhase != SchedulerPhase.persistentCallbacks) {
      // ignore: invalid_use_of_protected_member
      state.setState(fn);
    } else {
      // Defer until the current frame has finished rendering.
      // coverage:ignore-start
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member
        if (state.mounted) state.setState(fn);
      });
      // coverage:ignore-end
    }
  }
}
