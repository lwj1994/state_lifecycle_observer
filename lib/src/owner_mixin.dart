import 'dart:async';

import 'package:flutter/widgets.dart';
import 'lifecycle_observer.dart';

/// A mixin that manages [LifecycleObserver]s within a [State].
///
/// This mixin handles the registration, key updates, build notifications,
/// and disposal of observers.
///
/// To use this mixin:
/// 1. Add it to your [State] class.
/// 2. Call `super.build(context)` within your [build] method.
mixin LifecycleOwnerMixin<T extends StatefulWidget> on State<T> {
  // Use raw LifecycleObserver to allow any observer type.
  final List<LifecycleObserver> _observers = [];
  LifecycleState _lifecycleState = LifecycleState.created;
  LifecycleState get lifecycleState => _lifecycleState;

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    _lifecycleState = LifecycleState.initialized;
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      // Run inside a Zone that provides access to addLifecycleObserver,
      // allowing nested observers to register with this state.
      runZoned(
        // ignore: invalid_use_of_protected_member
        () => observer.onInitState(),
        zoneValues: {addLifecycleObserverZoneKey: addLifecycleObserver},
      );
    }
  }

  /// Registers a [LifecycleObserver] to be managed by this state.
  @protected
  void addLifecycleObserver(LifecycleObserver observer) {
    // If the state is already initialized, we manually "replay" the initialization
    // for this new observer so it catches up.
    if (_lifecycleState == LifecycleState.initialized) {
      // Run inside a Zone that provides access to addLifecycleObserver,
      // allowing nested observers to register with this state.
      runZoned(
        // ignore: invalid_use_of_protected_member
        () => observer.onInitState(),
        zoneValues: {addLifecycleObserverZoneKey: addLifecycleObserver},
      );
    }
    _observers.add(observer);
  }

  /// Removes a [LifecycleObserver] from this state and disposes it.
  ///
  /// This is useful when you need to dynamically remove observers
  /// without disposing the entire State.
  @protected
  void removeLifecycleObserver(LifecycleObserver observer) {
    if (_observers.remove(observer)) {
      // ignore: invalid_use_of_protected_member
      observer.onDispose();
    }
  }

  /// Adds a simple callback-based observer to the state.
  void addLifecycleCallback({
    VoidCallback? onInitState,
    VoidCallback? onDidUpdateWidget,
    VoidCallback? onDispose,
    void Function(BuildContext)? onBuild,
  }) {
    // The observer registers itself in the constructor.
    _CallbackLifecycleObserver(
      this,
      onInitState: onInitState,
      onDidUpdateWidget: onDidUpdateWidget,
      onDispose: onDispose,
      onBuild: onBuild,
    );
  }

  @override
  @mustCallSuper
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      // Run inside a Zone that provides access to addLifecycleObserver,
      // allowing nested observers to register with this state.
      runZoned(
        // ignore: invalid_use_of_protected_member
        () => observer.onDidUpdateWidget(),
        zoneValues: {addLifecycleObserverZoneKey: addLifecycleObserver},
      );
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _lifecycleState = LifecycleState.disposed;
    // Create a copy to iterate over while disposing
    for (var observer in List.of(_observers)) {
      // Do NOT provide addLifecycleObserver in Zone during dispose -
      // creating observers during dispose is not allowed as they would
      // never be properly initialized or disposed.
      // ignore: invalid_use_of_protected_member
      observer.onDispose();
    }
    _observers.clear();
    super.dispose();
  }

  /// Manually call this method in your `build` method.
  ///
  /// This triggers `onBuild` for all registered observers.
  /// The return value is typically ignored as this is called via `super.build`.
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      // Run inside a Zone that provides access to addLifecycleObserver,
      // allowing nested observers to register with this state.
      runZoned(
        // ignore: invalid_use_of_protected_member
        () => observer.onBuild(context),
        zoneValues: {addLifecycleObserverZoneKey: addLifecycleObserver},
      );
    }
    return const SizedBox.shrink();
  }
}

/// A [LifecycleObserver] that accepts callbacks for lifecycle events.
class _CallbackLifecycleObserver extends LifecycleObserver<void> {
  final VoidCallback? _onInitState;
  final VoidCallback? _onDidUpdateWidget;
  final VoidCallback? _onDispose;
  final void Function(BuildContext)? _onBuild;

  _CallbackLifecycleObserver(
    super.state, {
    VoidCallback? onInitState,
    VoidCallback? onDidUpdateWidget,
    VoidCallback? onDispose,
    void Function(BuildContext)? onBuild,
  })  : _onInitState = onInitState,
        _onDidUpdateWidget = onDidUpdateWidget,
        _onDispose = onDispose,
        _onBuild = onBuild;

  @override
  void buildTarget() {}

  @override
  void onInitState() {
    super.onInitState();
    _onInitState?.call();
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    _onDidUpdateWidget?.call();
  }

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    _onBuild?.call(context);
  }

  @override
  void onDispose() {
    _onDispose?.call();
    super.onDispose();
  }
}
