import 'dart:async';
import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/src/lifecycle_observer.dart';

/// An observer that listens to a [Listenable] (like [Animation]
/// or [ValueNotifier])
/// and triggers a rebuild when the value changes.
class ListenableObserver extends LifecycleObserver<Listenable> {
  final Listenable _listenable;
  ListenableObserver(
    super.state, {
    required Listenable listenable,
    super.key,
  }) : _listenable = listenable {
    _listenable.addListener(_markNeedsBuild);
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
  final Future<T>? future;

  /// The initial data to use before the future completes.
  final T? initialData;

  FutureObserver(
    super.state, {
    this.future,
    this.initialData,
    super.key,
  });

  @override
  AsyncSnapshot<T> buildTarget() {
    _subscribe();
    return AsyncSnapshot<T>.withData(
      ConnectionState.waiting,
      initialData as T,
    );
  }

  Future<T>? _activeFuture;

  void _subscribe() {
    if (future == _activeFuture) return;
    _activeFuture = future;

    if (future == null) {
      return;
    }

    future!.then((data) {
      if (_activeFuture == future && state.mounted) {
        safeSetState(() {
          target = AsyncSnapshot<T>.withData(ConnectionState.done, data);
        });
      }
    }, onError: (error, stackTrace) {
      if (_activeFuture == future && state.mounted) {
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
}

/// An observer that manages a [Stream].
///
/// It exposes the state of the stream as an [AsyncSnapshot] and automatically
/// handles subscription cancellation.
class StreamObserver<T> extends LifecycleObserver<AsyncSnapshot<T>> {
  /// The stream to observe.
  final Stream<T>? stream;

  /// The initial data to use before the stream emits any value.
  final T? initialData;

  StreamObserver(
    super.state, {
    this.stream,
    this.initialData,
    super.key,
  });

  StreamSubscription<T>? _subscription;

  @override
  AsyncSnapshot<T> buildTarget() {
    _subscribe();
    return AsyncSnapshot<T>.withData(
      ConnectionState.waiting,
      initialData as T,
    );
  }

  void _subscribe() {
    _subscription?.cancel();
    if (stream == null) return;

    _subscription = stream!.listen(
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
  }
}
