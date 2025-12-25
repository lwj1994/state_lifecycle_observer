import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/src/lifecycle_observer.dart';

/// An observer that listens to a [Listenable] (like [Animation] or [ValueNotifier])
/// and triggers a rebuild when the value changes.
class ListenableObserver extends LifecycleObserver<Listenable> {
  late final Listenable _listenable;
  ListenableObserver(
    super.state, {
    required Listenable listenable,
    super.key,
  }) {
    _listenable = listenable;
    _listenable.addListener(_markNeedsBuild);
  }

  @override
  void onDisposeTarget(Listenable target) {
    target.removeListener(_markNeedsBuild);
  }

  void _markNeedsBuild() {
    // ignore: invalid_use_of_protected_member
    state.setState(() {});
  }

  @override
  Listenable buildTarget() {
    return _listenable;
  }
}

class ScrollControllerObserver extends LifecycleObserver<ScrollController> {
  final double initialScrollOffset;
  final bool keepScrollOffset;
  final String? debugLabel;
  final ScrollControllerCallback? onAttach;
  final ScrollControllerCallback? onDetach;

  ScrollControllerObserver(
    super.state, {
    this.initialScrollOffset = 0.0,
    this.keepScrollOffset = true,
    this.debugLabel,
    this.onAttach,
    this.onDetach,
    super.key,
  });

  @override
  void onDisposeTarget(ScrollController target) {
    target.dispose();
  }

  @override
  ScrollController buildTarget() {
    return ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
      onAttach: onAttach,
      onDetach: onDetach,
    );
  }
}

class TabControllerObserver extends LifecycleObserver<TabController> {
  final int length;
  final int initialIndex;
  final Duration? animationDuration;

  TabControllerObserver(
    super.state, {
    required this.length,
    this.initialIndex = 0,
    this.animationDuration,
    super.key,
  });

  @override
  void onDisposeTarget(TabController target) {
    target.dispose();
  }

  @override
  TabController buildTarget() {
    return TabController(
      length: length,
      vsync: state as TickerProvider,
      initialIndex: initialIndex,
      animationDuration: animationDuration,
    );
  }
}

class TextEditingControllerObserver
    extends LifecycleObserver<TextEditingController> {
  final String? text;
  final TextEditingValue? editingValue;

  TextEditingControllerObserver(
    super.state, {
    this.text,
    this.editingValue,
    super.key,
  });

  factory TextEditingControllerObserver.fromValue(
      State state, TextEditingValue? value) {
    return TextEditingControllerObserver(
      state,
      editingValue: value,
    );
  }

  @override
  void onDisposeTarget(TextEditingController target) {
    target.dispose();
  }

  @override
  TextEditingController buildTarget() {
    if (editingValue != null) {
      return TextEditingController.fromValue(editingValue!);
    } else {
      return TextEditingController(text: text);
    }
  }
}
