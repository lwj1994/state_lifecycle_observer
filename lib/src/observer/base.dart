import 'dart:async';
import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/src/lifecycle_observer.dart';

/// An observer that listens to a [Listenable] (like [Animation]
/// or [ValueNotifier])
/// and triggers a rebuild when the value changes.
class ListenableObserver extends LifecycleObserver<Listenable> {
  final Listenable? _initialListenable;
  final Listenable Function()? _listenableGetter;

  ListenableObserver(
    super.state, {
    Listenable? listenable,
    Listenable Function()? listenableGetter,
    super.key,
  })  : assert(
          listenable != null || listenableGetter != null,
          'ListenableObserver requires either listenable or listenableGetter.',
        ),
        _initialListenable = listenable,
        _listenableGetter = listenableGetter;

  Listenable get _listenable =>
      _listenableGetter?.call() ?? _initialListenable!;

  @override
  void onInitState() {
    super.onInitState();
    // Add listener in onInitState instead of constructor
    // to ensure it's re-added when key changes trigger rebuild
    target.addListener(_markNeedsBuild);
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    final nextListenable = _listenable;
    if (!identical(target, nextListenable)) {
      target.removeListener(_markNeedsBuild);
      target = nextListenable;
      target.addListener(_markNeedsBuild);
    }
  }

  @override
  void onDisposeTarget(Listenable target) {
    target.removeListener(_markNeedsBuild);
  }

  void _markNeedsBuild() {
    safeSetState(() {});
  }

  @override
  Listenable buildTarget() {
    return _listenable;
  }
}

/// An observer that manages a [Future].
///
/// It exposes the state of the future as an [AsyncSnapshot].
class FutureObserver<T> extends LifecycleObserver<AsyncSnapshot<T>> {
  /// The future to observe.
  final Future<T>? _initialFuture;
  final Future<T>? Function()? _futureGetter;

  /// The initial data to use before the future completes.
  final T? _initialDataValue;
  final T? Function()? _initialDataGetter;

  FutureObserver(
    super.state, {
    Future<T>? future,
    Future<T>? Function()? futureGetter,
    T? initialData,
    T? Function()? initialDataGetter,
    super.key,
  })  : _initialFuture = future,
        _futureGetter = futureGetter,
        _initialDataValue = initialData,
        _initialDataGetter = initialDataGetter;

  Future<T>? get future => _futureGetter?.call() ?? _initialFuture;
  T? get initialData => _initialDataGetter?.call() ?? _initialDataValue;

  Future<T>? _pendingFuture;
  T? _pendingInitialData;
  bool _hasPendingInputs = false;

  @override
  AsyncSnapshot<T> buildTarget() {
    return _snapshotForFuture(
      _hasPendingInputs ? _pendingFuture : future,
      _hasPendingInputs ? _pendingInitialData : initialData,
    );
  }

  Future<T>? _activeFuture;
  int _activeSubscriptionGeneration = 0;
  bool _activeFutureIsPending = false;
  AsyncSnapshot<T>? _preservedSnapshotOnNextInit;

  @override
  void onInitState() {
    final nextFuture = future;
    final nextInitialData = initialData;
    _cachePendingInputs(nextFuture, nextInitialData);
    try {
      super.onInitState();
    } finally {
      _clearPendingInputs();
    }
    final preservedSnapshot = _preservedSnapshotOnNextInit;
    _preservedSnapshotOnNextInit = null;
    if (preservedSnapshot != null) {
      target = preservedSnapshot;
      return;
    }
    _subscribe(nextFuture);
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    final nextFuture = future;
    final nextInitialData = initialData;
    if (nextFuture != _activeFuture) {
      target = _snapshotForFuture(nextFuture, nextInitialData);
      _subscribe(nextFuture);
    } else if (target.connectionState == ConnectionState.waiting ||
        target.connectionState == ConnectionState.none) {
      target = _snapshotForFuture(nextFuture, nextInitialData);
    }
  }

  void _cachePendingInputs(Future<T>? future, T? initialData) {
    _pendingFuture = future;
    _pendingInitialData = initialData;
    _hasPendingInputs = true;
  }

  void _clearPendingInputs() {
    _pendingFuture = null;
    _pendingInitialData = null;
    _hasPendingInputs = false;
  }

  AsyncSnapshot<T> _snapshotForFuture(Future<T>? future, T? initialData) {
    final snapshot = initialData == null
        ? AsyncSnapshot<T>.nothing()
        : AsyncSnapshot<T>.withData(ConnectionState.none, initialData);
    return future == null
        ? snapshot
        : snapshot.inState(ConnectionState.waiting);
  }

  void _subscribe(Future<T>? nextFuture, {bool force = false}) {
    if (!force &&
        nextFuture == _activeFuture &&
        (nextFuture == null || _activeFutureIsPending)) {
      return;
    }
    _activeFuture = nextFuture;
    final subscriptionGeneration = ++_activeSubscriptionGeneration;
    _activeFutureIsPending = nextFuture != null;

    if (nextFuture == null) {
      return;
    }

    nextFuture.then((data) {
      if (_activeSubscriptionGeneration != subscriptionGeneration ||
          _activeFuture != nextFuture) {
        return;
      }
      _activeFutureIsPending = false;
      if (!canSafelySetState) {
        return;
      }
      safeSetState(() {
        target = AsyncSnapshot<T>.withData(ConnectionState.done, data);
      });
    }, onError: (error, stackTrace) {
      if (_activeSubscriptionGeneration != subscriptionGeneration ||
          _activeFuture != nextFuture) {
        return;
      }
      _activeFutureIsPending = false;
      if (!canSafelySetState) {
        return;
      }
      safeSetState(() {
        target = AsyncSnapshot<T>.withError(
          ConnectionState.done,
          error,
          stackTrace,
        );
      });
    });
  }

  @override
  void onDisposeTarget(AsyncSnapshot<T> target) {
    final isKeyRebuild = currentKey != key?.call();
    if (isKeyRebuild &&
        _activeFuture != null &&
        identical(future, _activeFuture) &&
        !_activeFutureIsPending) {
      _preservedSnapshotOnNextInit = target;
      return;
    }
    _preservedSnapshotOnNextInit = null;
  }

  @override
  void onDispose() {
    try {
      super.onDispose();
    } finally {
      _activeFuture = null;
      _activeFutureIsPending = false;
      _preservedSnapshotOnNextInit = null;
      _activeSubscriptionGeneration++;
    }
  }
}

/// An observer that manages a [Stream].
///
/// It exposes the state of the stream as an [AsyncSnapshot] and automatically
/// handles subscription cancellation.
class StreamObserver<T> extends LifecycleObserver<AsyncSnapshot<T>> {
  /// The stream to observe.
  final Stream<T>? _initialStream;
  final Stream<T>? Function()? _streamGetter;

  /// The initial data to use before the stream emits any value.
  final T? _initialDataValue;
  final T? Function()? _initialDataGetter;

  StreamObserver(
    super.state, {
    Stream<T>? stream,
    Stream<T>? Function()? streamGetter,
    T? initialData,
    T? Function()? initialDataGetter,
    super.key,
  })  : _initialStream = stream,
        _streamGetter = streamGetter,
        _initialDataValue = initialData,
        _initialDataGetter = initialDataGetter;

  Stream<T>? get stream => _streamGetter?.call() ?? _initialStream;
  T? get initialData => _initialDataGetter?.call() ?? _initialDataValue;

  Stream<T>? _pendingStream;
  T? _pendingInitialData;
  bool _hasPendingInputs = false;

  StreamSubscription<T>? _subscription;
  Stream<T>? _activeStream;
  bool _reuseActiveSubscriptionOnNextInit = false;
  AsyncSnapshot<T>? _preservedSnapshotOnNextInit;

  @override
  AsyncSnapshot<T> buildTarget() {
    return _snapshotForStream(
      _hasPendingInputs ? _pendingStream : stream,
      _hasPendingInputs ? _pendingInitialData : initialData,
    );
  }

  @override
  void onInitState() {
    final nextStream = stream;
    final nextInitialData = initialData;
    _cachePendingInputs(nextStream, nextInitialData);
    try {
      super.onInitState();
    } finally {
      _clearPendingInputs();
    }
    if (_reuseActiveSubscriptionOnNextInit) {
      final preservedSnapshot = _preservedSnapshotOnNextInit;
      _reuseActiveSubscriptionOnNextInit = false;
      _preservedSnapshotOnNextInit = null;
      if (preservedSnapshot == null ||
          preservedSnapshot.connectionState == ConnectionState.none ||
          preservedSnapshot.connectionState == ConnectionState.waiting) {
        target = _snapshotForStream(nextStream, nextInitialData);
      } else {
        target = preservedSnapshot;
      }
      return;
    }
    _subscribe(nextStream);
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    final nextStream = stream;
    final nextInitialData = initialData;
    if (nextStream != _activeStream) {
      target = _snapshotForStream(nextStream, nextInitialData);
      _subscribe(nextStream);
    } else if (target.connectionState == ConnectionState.waiting ||
        target.connectionState == ConnectionState.none) {
      target = _snapshotForStream(nextStream, nextInitialData);
    }
  }

  void _cachePendingInputs(Stream<T>? stream, T? initialData) {
    _pendingStream = stream;
    _pendingInitialData = initialData;
    _hasPendingInputs = true;
  }

  void _clearPendingInputs() {
    _pendingStream = null;
    _pendingInitialData = null;
    _hasPendingInputs = false;
  }

  AsyncSnapshot<T> _snapshotForStream(Stream<T>? stream, T? initialData) {
    final snapshot = initialData == null
        ? AsyncSnapshot<T>.nothing()
        : AsyncSnapshot<T>.withData(ConnectionState.none, initialData);
    return stream == null
        ? snapshot
        : snapshot.inState(ConnectionState.waiting);
  }

  void _subscribe(Stream<T>? nextStream) {
    _subscription?.cancel();
    _subscription = null;
    _activeStream = nextStream;
    if (nextStream == null) return;

    _subscription = nextStream.listen(
      (data) {
        if (!canSafelySetState) return;
        safeSetState(() {
          target = AsyncSnapshot<T>.withData(ConnectionState.active, data);
        });
      },
      onError: (error, stackTrace) {
        if (!canSafelySetState) return;
        safeSetState(() {
          target = AsyncSnapshot<T>.withError(
            ConnectionState.active,
            error,
            stackTrace,
          );
        });
      },
      onDone: () {
        if (!canSafelySetState) return;
        safeSetState(() {
          target = target.inState(ConnectionState.done);
        });
      },
    );
  }

  @override
  void onDisposeTarget(AsyncSnapshot<T> target) {
    final isKeyRebuild = currentKey != key?.call();
    if (isKeyRebuild && identical(stream, _activeStream)) {
      _reuseActiveSubscriptionOnNextInit = true;
      _preservedSnapshotOnNextInit = target;
      return;
    }
    _subscription?.cancel();
    _subscription = null;
    _activeStream = null;
    _reuseActiveSubscriptionOnNextInit = false;
    _preservedSnapshotOnNextInit = null;
  }
}
