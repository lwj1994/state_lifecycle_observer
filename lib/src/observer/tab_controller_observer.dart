import 'package:flutter/material.dart';
import '../lifecycle_observer.dart';

class TabControllerObserver extends LifecycleObserver<TabController> {
  final int length;
  final int initialIndex;
  final Duration? animationDuration;

  TabControllerObserver(
    super.state, {
    required this.length,
    this.initialIndex = 0,
    this.animationDuration,
  });

  @override
  void onInit() {
    target = TabController(
      length: length,
      vsync: state as TickerProvider,
      initialIndex: initialIndex,
      animationDuration: animationDuration,
    );
  }

  @override
  void onDispose() {
    target.dispose();
  }
}
