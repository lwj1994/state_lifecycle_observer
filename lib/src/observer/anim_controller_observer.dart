import 'package:flutter/widgets.dart';
import '../lifecycle_observer.dart';

class AnimControllerObserver extends LifecycleObserver<AnimationController> {
  /// A closure to retrieve the latest duration from the widget.
  final Duration? Function() duration;
  final Duration? Function()? reverseDuration;
  final double? value;
  final double lowerBound;
  final double upperBound;
  final AnimationBehavior animationBehavior;
  final String? debugLabel;

  AnimControllerObserver(
    super.state, {
    required this.duration,
    this.reverseDuration,
    this.value,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
    this.animationBehavior = AnimationBehavior.normal,
    this.debugLabel,
  });

  @override
  void onInit() {
    // Initialize the controller with the initial duration.
    // We assume state implements TickerProvider.
    target = AnimationController(
      vsync: state as TickerProvider,
      duration: duration(),
      reverseDuration: reverseDuration?.call(),
      value: value,
      lowerBound: lowerBound,
      upperBound: upperBound,
      animationBehavior: animationBehavior,
      debugLabel: debugLabel,
    );
  }

  @override
  void onUpdate() {
    // Sync logic: Compare current controller duration with the latest picker value.
    final latestDuration = duration();
    if (target.duration != latestDuration) {
      target.duration = latestDuration;
    }

    if (reverseDuration != null) {
      final latestReverseDuration = reverseDuration!();
      if (target.reverseDuration != latestReverseDuration) {
        target.reverseDuration = latestReverseDuration;
      }
    }
  }

  @override
  void onDispose() {
    target.dispose();
  }
}
