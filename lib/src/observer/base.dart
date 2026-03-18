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

  @override
  AsyncSnapshot<T> buildTarget() {
    return _snapshotForCurrentFuture();
  }

  Future<T>? _activeFuture;

  @override
  void onInitState() {
    super.onInitState();
    _subscribe();
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    if (future != _activeFuture) {
      target = _snapshotForCurrentFuture();
      _subscribe();
    } else if (target.connectionState == ConnectionState.waiting ||
        target.connectionState == ConnectionState.none) {
      target = _snapshotForCurrentFuture();
    }
  }

  AsyncSnapshot<T> _snapshotForCurrentFuture() {
    final data = initialData;
    final snapshot = data == null
        ? AsyncSnapshot<T>.nothing()
        : AsyncSnapshot<T>.withData(ConnectionState.none, data);
    return future == null ? snapshot : snapshot.inState(ConnectionState.waiting);
  }

  void _subscribe() {
    final nextFuture = future;
    if (nextFuture == _activeFuture) return;
    _activeFuture = nextFuture;

    if (nextFuture == null) {
      return;
    }

    nextFuture.then((data) {
      if (_activeFuture == nextFuture && state.mounted) {
        safeSetState(() {
          target = AsyncSnapshot<T>.withData(ConnectionState.done, data);
        });
      }
    }, onError: (error, stackTrace) {
      if (_activeFuture == nextFuture && state.mounted) {
        safeSetState(() {
          target = AsyncSnapshot<T>.withError(
            ConnectionState.done,
            error,
            stackTrace,
          );
        });
      }
    });
  }

  @override
  void onDisposeTarget(AsyncSnapshot<T> target) {
    _activeFuture = null;
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

  StreamSubscription<T>? _subscription;
  Stream<T>? _activeStream;

  @override
  AsyncSnapshot<T> buildTarget() {
    return _snapshotForCurrentStream();
  }

  @override
  void onInitState() {
    super.onInitState();
    _subscribe();
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    if (stream != _activeStream) {
      target = _snapshotForCurrentStream();
      _subscribe();
    } else if (target.connectionState == ConnectionState.waiting ||
        target.connectionState == ConnectionState.none) {
      target = _snapshotForCurrentStream();
    }
  }

  AsyncSnapshot<T> _snapshotForCurrentStream() {
    final data = initialData;
    final snapshot = data == null
        ? AsyncSnapshot<T>.nothing()
        : AsyncSnapshot<T>.withData(ConnectionState.none, data);
    return stream == null ? snapshot : snapshot.inState(ConnectionState.waiting);
  }

  void _subscribe() {
    final nextStream = stream;
    _subscription?.cancel();
    _subscription = null;
    _activeStream = nextStream;
    if (nextStream == null) return;

    _subscription = nextStream.listen(
      (data) {
        if (!state.mounted) return;
        safeSetState(() {
          target = AsyncSnapshot<T>.withData(ConnectionState.active, data);
        });
      },
      onError: (error, stackTrace) {
        if (!state.mounted) return;
        safeSetState(() {
          target = AsyncSnapshot<T>.withError(
            ConnectionState.active,
            error,
            stackTrace,
          );
        });
      },
      onDone: () {
        if (!state.mounted) return;
        safeSetState(() {
          target = target.inState(ConnectionState.done);
        });
      },
    );
  }

  @override
  void onDisposeTarget(AsyncSnapshot<T> target) {
    _subscription?.cancel();
    _subscription = null;
    _activeStream = null;
  }
}
