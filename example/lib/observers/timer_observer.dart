import 'dart:async';

import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class TimerObserver extends LifecycleObserver<Timer?> {
  final Duration duration;
  final void Function(Timer timer)? onTimerCallback;

  TimerObserver(super.state, {required this.duration, this.onTimerCallback});

  @override
  Timer? buildTarget() {
    return Timer.periodic(duration, (timer) {
      onTimerCallback?.call(timer);
    });
  }

  @override
  void onDisposeTarget(Timer? target) {
    target?.cancel();
  }
}
