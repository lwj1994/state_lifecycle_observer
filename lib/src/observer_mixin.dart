import 'package:flutter/widgets.dart';
import 'lifecycle_observer.dart';

mixin LifecycleObserverMixin<T extends StatefulWidget> on State<T>
    implements StateWithObservers {
  // Use raw LifecycleObserver to allow any observer type.
  final List<LifecycleObserver> _observers = [];

  @override
  void registerObserver(LifecycleObserver observer) {
    _observers.add(observer);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Automatically trigger sync logic in all observers.
    for (var observer in _observers) {
      observer.onUpdate();
    }
  }

  @override
  void dispose() {
    for (var observer in _observers) {
      observer.onDispose();
    }
    _observers.clear();
    super.dispose();
  }

  /// Manually call this method in your `build` method.
  ///
  /// This triggers `onBuild` for all registered observers.
  @override
  @mustCallSuper
  Widget build(BuildContext context) {
    for (var observer in _observers) {
      observer.onBuild(context);
    }
    return Container();
  }
}
