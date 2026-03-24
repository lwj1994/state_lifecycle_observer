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
///
/// Like other Flutter mixins that hook into `build` (for example
/// [AutomaticKeepAliveClientMixin]), this mixin is order-sensitive when
/// combined with other mixins that also override `build`.
mixin LifecycleOwnerMixin<T extends StatefulWidget> on State<T> {
  // Use raw LifecycleObserver to allow any observer type.
  final List<LifecycleObserver> _observers = [];
  final Map<LifecycleObserver, Set<LifecycleObserver>> _observerChildren = {};
  final Map<LifecycleObserver, LifecycleObserver> _observerParents = {};
  int _observerTeardownDepth = 0;
  LifecycleState _lifecycleState = LifecycleState.created;
  LifecycleState get lifecycleState => _lifecycleState;

  void _runObserverCallback(
    LifecycleObserver observer,
    VoidCallback callback,
  ) {
    final registrationScope = Completer<void>();
    try {
      runZoned(
        callback,
        zoneValues: {
          addLifecycleObserverZoneKey: addLifecycleObserver,
          disposeLifecycleObserverChildrenZoneKey:
              disposeLifecycleObserverChildren,
          removeLifecycleObserverZoneKey: removeLifecycleObserver,
          lifecycleOwnerStateZoneKey: this,
          lifecycleObserverRegistrationScopeZoneKey: registrationScope,
          currentLifecycleObserverZoneKey: observer,
        },
      );
    } finally {
      registrationScope.complete();
    }
  }

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    _lifecycleState = LifecycleState.initialized;
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      if (!_observers.contains(observer)) {
        continue;
      }
      try {
        _runObserverCallback(observer, () {
          // ignore: invalid_use_of_protected_member
          observer.onInitState();
        });
      } catch (error, stackTrace) {
        _disposeObserverSubtree(
          observer,
          <LifecycleObserver>{},
          onError: _reportDeferredDisposeError,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  /// Registers a [LifecycleObserver] to be managed by this state.
  @protected
  void addLifecycleObserver(LifecycleObserver observer) {
    if (_observers.contains(observer)) {
      return;
    }
    _assertCanRegisterObserver();
    final parent =
        Zone.current[currentLifecycleObserverZoneKey] as LifecycleObserver?;
    final registrationScope = Zone
        .current[lifecycleObserverRegistrationScopeZoneKey] as Completer<void>?;
    if (parent != null &&
        (registrationScope == null || registrationScope.isCompleted)) {
      throw StateError(
          'LifecycleObserver creation failed: nested observers must be created synchronously inside lifecycle callbacks. '
          'Creating them from async tasks is not supported.');
    }
    if (parent != null && parent != observer && !_observers.contains(parent)) {
      throw StateError(
          'LifecycleObserver creation failed: the parent observer is no longer active. '
          'Creating observers asynchronously after a lifecycle callback is not supported.');
    }

    _observers.add(observer);

    if (parent != null && parent != observer) {
      _observerParents[observer] = parent;
      _observerChildren
          .putIfAbsent(parent, () => <LifecycleObserver>{})
          .add(observer);
    }

    // If the state is already initialized, we manually "replay" the initialization
    // for this new observer so it catches up.
    if (_lifecycleState == LifecycleState.initialized) {
      try {
        _runObserverCallback(observer, () {
          // ignore: invalid_use_of_protected_member
          observer.onInitState();
        });
      } catch (error, stackTrace) {
        _disposeObserverSubtree(
          observer,
          <LifecycleObserver>{},
          onError: _reportDeferredDisposeError,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  /// Removes a [LifecycleObserver] from this state and disposes it.
  ///
  /// This is useful when you need to dynamically remove observers
  /// without disposing the entire State.
  @protected
  void removeLifecycleObserver(LifecycleObserver observer) {
    _disposeObserverSubtree(observer, <LifecycleObserver>{});
  }

  /// Disposes any child observers currently composed under [observer].
  ///
  /// This is used when an observer rebuilds its own target due to a key change,
  /// ensuring the entire composed subtree is recreated from a clean state.
  @protected
  void disposeLifecycleObserverChildren(LifecycleObserver observer) {
    final children = List<LifecycleObserver>.of(
      _observerChildren[observer] ?? const <LifecycleObserver>{},
    );
    for (final child in children) {
      _disposeObserverSubtree(child, <LifecycleObserver>{});
    }
  }

  void _disposeObserverSubtree(
    LifecycleObserver observer,
    Set<LifecycleObserver> disposedObservers, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (!disposedObservers.add(observer)) {
      return;
    }
    _observerTeardownDepth++;
    Object? firstError;
    StackTrace? firstStackTrace;

    void recordError(Object error, StackTrace stackTrace) {
      if (firstError == null) {
        firstError = error;
        firstStackTrace = stackTrace;
        return;
      }
      if (onError != null) {
        onError(error, stackTrace);
      } else {
        _reportDeferredDisposeError(error, stackTrace);
      }
    }

    try {
      final children = List<LifecycleObserver>.of(
        _observerChildren[observer] ?? const <LifecycleObserver>{},
      );
      for (final child in children) {
        _disposeObserverSubtree(
          child,
          disposedObservers,
          onError: recordError,
        );
      }

      _detachObserverRelations(observer);

      if (_observers.remove(observer)) {
        try {
          // ignore: invalid_use_of_protected_member
          observer.onDispose();
        } catch (error, stackTrace) {
          recordError(error, stackTrace);
        } finally {
          try {
            // ignore: invalid_use_of_protected_member
            observer.disposeTargetIfNeeded();
          } catch (error, stackTrace) {
            recordError(error, stackTrace);
          }
        }
      }
    } finally {
      _observerTeardownDepth--;
    }

    if (firstError != null) {
      if (onError != null) {
        onError(firstError!, firstStackTrace!);
      } else {
        Error.throwWithStackTrace(firstError!, firstStackTrace!);
      }
    }
  }

  void _reportDeferredDisposeError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'state_lifecycle_observer',
        context: ErrorDescription(
          'while disposing LifecycleOwnerMixin observers',
        ),
      ),
    );
  }

  void _assertCanRegisterObserver() {
    if (_lifecycleState == LifecycleState.disposed) {
      throw StateError(
          'LifecycleObserver creation failed: State.dispose() has already started. '
          'Creating observers after disposal is not supported.');
    }
    if (_observerTeardownDepth > 0) {
      throw StateError(
          'LifecycleObserver creation failed: another observer is currently being disposed. '
          'Creating observers inside onDispose/removeLifecycleObserver is not supported.');
    }
  }

  void _detachObserverRelations(LifecycleObserver observer) {
    _observerChildren.remove(observer);
    final parent = _observerParents.remove(observer);
    if (parent != null) {
      final siblings = _observerChildren[parent];
      siblings?.remove(observer);
      if (siblings != null && siblings.isEmpty) {
        _observerChildren.remove(parent);
      }
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
    Object? firstError;
    StackTrace? firstStackTrace;
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      if (!_observers.contains(observer)) {
        continue;
      }
      try {
        // ignore: invalid_use_of_protected_member
        _runObserverCallback(observer, observer.onDidUpdateWidget);
      } catch (error, stackTrace) {
        _disposeObserverSubtree(
          observer,
          <LifecycleObserver>{},
          onError: _reportDeferredDisposeError,
        );
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          _reportDeferredDisposeError(error, stackTrace);
        }
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _lifecycleState = LifecycleState.disposed;
    final disposedObservers = <LifecycleObserver>{};
    Object? firstError;
    StackTrace? firstStackTrace;

    void recordDisposeError(Object error, StackTrace stackTrace) {
      if (firstError == null) {
        firstError = error;
        firstStackTrace = stackTrace;
        return;
      }
      _reportDeferredDisposeError(error, stackTrace);
    }

    final roots = List<LifecycleObserver>.of(
      _observers.where((observer) => !_observerParents.containsKey(observer)),
    );

    for (final observer in roots) {
      _disposeObserverSubtree(
        observer,
        disposedObservers,
        onError: recordDisposeError,
      );
    }

    for (final observer in List.of(_observers)) {
      _disposeObserverSubtree(
        observer,
        disposedObservers,
        onError: recordDisposeError,
      );
    }

    _observers.clear();
    _observerChildren.clear();
    _observerParents.clear();
    try {
      super.dispose();
    } catch (error, stackTrace) {
      recordDisposeError(error, stackTrace);
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  /// Call `super.build(context)` within your `build` method to trigger
  /// `onBuild` for all registered observers.
  ///
  /// The returned [Widget] (a [SizedBox.shrink]) is typically discarded
  /// by the overriding method.
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    Object? firstError;
    StackTrace? firstStackTrace;
    // Create a copy to allow nested observer registration during iteration
    for (var observer in List.of(_observers)) {
      if (!_observers.contains(observer)) {
        continue;
      }
      try {
        // ignore: invalid_use_of_protected_member
        _runObserverCallback(observer, () => observer.onBuild(context));
      } catch (error, stackTrace) {
        _disposeObserverSubtree(
          observer,
          <LifecycleObserver>{},
          onError: _reportDeferredDisposeError,
        );
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        } else {
          _reportDeferredDisposeError(error, stackTrace);
        }
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
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
    super.onDispose();
    _onDispose?.call();
  }
}
