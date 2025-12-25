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
    super.key,
  });

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
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

/// An observer that listens to a [Listenable] (like [Animation] or [ValueNotifier])
/// and triggers a rebuild when the value changes.
///
/// This mimics the behavior of `useAnimation` or `useListenable` in flutter_hooks.
class AnimationObserver<T> extends LifecycleObserver<T> {
  late Animation<T> _animation;

  AnimationObserver(
    super.state, {
    required Animation<T> animation,
    super.key,
  }) {
    _animation = animation;
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
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
  }
}
