import 'package:flutter/widgets.dart';
import '../lifecycle_observer.dart';

/// An observer that manages an [AnimationController].
///
/// Wraps [AnimationController] creation and disposal.
/// Supports syncing [duration] and [reverseDuration] on widget updates.
///
/// The [state] parameter must be a [State] that mixes in [TickerProvider]
/// (e.g., [SingleTickerProviderStateMixin] or [TickerProviderStateMixin]).
class AnimControllerObserver extends LifecycleObserver<AnimationController> {
  /// A closure to retrieve the latest duration from the widget.
  final Duration? Function() duration;

  /// A closure to retrieve the latest reverse duration from the widget.
  final Duration? Function()? reverseDuration;

  /// The initial value of the animation.
  final double? _valueValue;
  final double? Function()? _valueGetter;

  /// The lower bound of the animation.
  final double _lowerBoundValue;
  final double Function()? _lowerBoundGetter;

  /// The upper bound of the animation.
  final double _upperBoundValue;
  final double Function()? _upperBoundGetter;

  /// The behavior of the animation.
  final AnimationBehavior _animationBehaviorValue;
  final AnimationBehavior Function()? _animationBehaviorGetter;

  /// A debug label for the controller.
  final String? _debugLabelValue;
  final String? Function()? _debugLabelGetter;

  AnimControllerObserver(
    super.state, {
    required this.duration,
    this.reverseDuration,
    double? value,
    double? Function()? valueGetter,
    double lowerBound = 0.0,
    double Function()? lowerBoundGetter,
    double upperBound = 1.0,
    double Function()? upperBoundGetter,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
    AnimationBehavior Function()? animationBehaviorGetter,
    String? debugLabel,
    String? Function()? debugLabelGetter,
    super.key,
  })  : assert(
            state is TickerProvider,
            'AnimControllerObserver requires State to mixin TickerProvider '
            '(e.g., SingleTickerProviderStateMixin or TickerProviderStateMixin)'),
        _valueValue = value,
        _valueGetter = valueGetter,
        _lowerBoundValue = lowerBound,
        _lowerBoundGetter = lowerBoundGetter,
        _upperBoundValue = upperBound,
        _upperBoundGetter = upperBoundGetter,
        _animationBehaviorValue = animationBehavior,
        _animationBehaviorGetter = animationBehaviorGetter,
        _debugLabelValue = debugLabel,
        _debugLabelGetter = debugLabelGetter;

  double? get value => _valueGetter?.call() ?? _valueValue;

  double get lowerBound => _lowerBoundGetter?.call() ?? _lowerBoundValue;

  double get upperBound => _upperBoundGetter?.call() ?? _upperBoundValue;

  AnimationBehavior get animationBehavior =>
      _animationBehaviorGetter?.call() ?? _animationBehaviorValue;

  String? get debugLabel => _debugLabelGetter?.call() ?? _debugLabelValue;

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
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
  final Animation<T>? _animationValue;
  final Animation<T> Function()? _animationGetter;
  Animation<T>? _currentAnimation;

  AnimationObserver(
    super.state, {
    Animation<T>? animation,
    Animation<T> Function()? animationGetter,
    super.key,
  })  : assert(
          animation != null || animationGetter != null,
          'AnimationObserver requires either animation or animationGetter.',
        ),
        _animationValue = animation,
        _animationGetter = animationGetter;

  Animation<T> get _animation => _animationGetter?.call() ?? _animationValue!;

  @override
  void onInitState() {
    super.onInitState();
    _currentAnimation = _animation;
    _currentAnimation!.addListener(_markNeedsBuild);
  }

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
    final nextAnimation = _animation;
    if (!identical(_currentAnimation, nextAnimation)) {
      _currentAnimation?.removeListener(_markNeedsBuild);
      _currentAnimation = nextAnimation;
      _currentAnimation!.addListener(_markNeedsBuild);
      target = buildTarget();
    }
  }

  @override
  T buildTarget() {
    return _animation.value;
  }

  @override
  void onDisposeTarget(T target) {
    _currentAnimation?.removeListener(_markNeedsBuild);
    _currentAnimation = null;
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
