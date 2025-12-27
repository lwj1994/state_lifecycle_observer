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
    for (var observer in _observers) {
      // ignore: invalid_use_of_protected_member
      observer.onInitState();
    }
  }

  /// Registers a [LifecycleObserver] to be managed by this state.
  void addLifecycleObserver(LifecycleObserver observer) {
    // If the state is already initialized, we manually "replay" the initialization
    // for this new observer so it catches up.
    if (_lifecycleState == LifecycleState.initialized) {
      // ignore: invalid_use_of_protected_member
      observer.onInitState();
    }
    _observers.add(observer);
  }

  /// Adds a simple callback-based observer to the state.
  void addLifecyleCallback({
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
    // Automatically trigger sync logic in all observers.
    for (var observer in _observers) {
      // ignore: invalid_use_of_protected_member
      observer.onDidUpdateWidget();
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _lifecycleState = LifecycleState.disposed;
    for (var observer in _observers) {
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
    for (var observer in _observers) {
      // ignore: invalid_use_of_protected_member
      observer.onBuild(context);
    }
    return Container();
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
