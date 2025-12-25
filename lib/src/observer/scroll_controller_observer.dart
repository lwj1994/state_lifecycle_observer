import 'package:flutter/widgets.dart';
import '../lifecycle_observer.dart';

class ScrollControllerObserver extends LifecycleObserver<ScrollController> {
  final double initialScrollOffset;
  final bool keepScrollOffset;
  final String? debugLabel;

  ScrollControllerObserver(
    super.state, {
    this.initialScrollOffset = 0.0,
    this.keepScrollOffset = true,
    this.debugLabel,
  });

  @override
  void onInit() {
    target = ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }

  @override
  void onDispose() {
    target.dispose();
  }
}
