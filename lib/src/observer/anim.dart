import 'package:flutter/widgets.dart';
import '../lifecycle_observer.dart';

/// An observer that manages an [AnimationController].
///
/// Wraps [AnimationController] creation and disposal.
/// Supports syncing [duration] and [reverseDuration] on widget updates.
class AnimControllerObserver extends LifecycleObserver<AnimationController> {
  /// A closure to retrieve the latest duration from the widget.
  final Duration? Function() duration;

  /// A closure to retrieve the latest reverse duration from the widget.
  final Duration? Function()? reverseDuration;

  /// The initial value of the animation.
  final double? value;

  /// The lower bound of the animation.
  final double lowerBound;

  /// The upper bound of the animation.
  final double upperBound;

  /// The behavior of the animation.
  final AnimationBehavior animationBehavior;

  /// A debug label for the controller.
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
    super.key,
  });

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    // Sync logic: Compare current controller duration with the latest
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
  AnimationController buildTarget() {
    return AnimationController(
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
  void onDisposeTarget(AnimationController target) {
    target.dispose();
  }
}

/// An observer that listens to an [Animation] and triggers a rebuild
/// when the value changes.
///
/// This mimics the behavior of `useAnimation` in flutter_hooks.
class AnimationObserver<T> extends LifecycleObserver<T> {
  final Animation<T> _animation;

  AnimationObserver(
    super.state, {
    required Animation<T> animation,
    super.key,
  }) : _animation = animation {
    animation.addListener(_markNeedsBuild);
  }

  @override
  T buildTarget() {
    return _animation.value;
  }

  @override
  void onDispose() {
    _animation.removeListener(_markNeedsBuild);
    super.onDispose();
  }

  @override
  void onBuild(BuildContext context) {
    super.onBuild(context);
    target = buildTarget();
  }

  void _markNeedsBuild() {
    safeSetState(() {});
  }
}
