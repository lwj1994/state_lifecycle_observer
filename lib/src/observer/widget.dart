import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/src/lifecycle_observer.dart';

/// An observer that manages a [ScrollController].
class ScrollControllerObserver extends LifecycleObserver<ScrollController> {
  /// The initial scroll offset.
  final double initialScrollOffset;

  /// Whether to keep the scroll offset on state preservation.
  final bool keepScrollOffset;

  /// Debug label for the controller.
  final String? debugLabel;

  /// Callback when a position is attached.
  final ScrollControllerCallback? onAttach;

  /// Callback when a position is detached.
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

/// An observer that manages a [TabController].
class TabControllerObserver extends LifecycleObserver<TabController> {
  /// The total number of tabs.
  final int length;

  /// The initial index of the selected tab.
  final int initialIndex;

  /// The duration of the tab transition animation.
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

/// An observer that manages a [TextEditingController].
class TextEditingControllerObserver
    extends LifecycleObserver<TextEditingController> {
  /// The initial text value.
  final String? text;

  /// The initial editing value.
  final TextEditingValue? editingValue;

  TextEditingControllerObserver(
    super.state, {
    this.text,
    this.editingValue,
    super.key,
  });

  /// Creates a [TextEditingControllerObserver] from a starting value.
  factory TextEditingControllerObserver.fromValue(
    State state, {
    required TextEditingValue value,
  }) {
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

/// An observer that manages a [FocusNode].
class FocusNodeObserver extends LifecycleObserver<FocusNode> {
  /// A debug label for the focus node.
  final String? debugLabel;

  /// Callback for handling key events.
  final FocusOnKeyEventCallback? onKeyEvent;

  /// Whether to skip traversal for this node.
  final bool skipTraversal;

  /// Whether this node can request focus.
  final bool canRequestFocus;

  /// Whether descendants of this node are focusable.
  final bool descendantsAreFocusable;

  FocusNodeObserver(
    super.state, {
    this.debugLabel,
    this.onKeyEvent,
    this.skipTraversal = false,
    this.canRequestFocus = true,
    this.descendantsAreFocusable = true,
    super.key,
  });

  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (target.skipTraversal != skipTraversal) {
      target.skipTraversal = skipTraversal;
    }
    if (target.canRequestFocus != canRequestFocus) {
      target.canRequestFocus = canRequestFocus;
    }
    if (target.descendantsAreFocusable != descendantsAreFocusable) {
      target.descendantsAreFocusable = descendantsAreFocusable;
    }
  }

  @override
  void onDisposeTarget(FocusNode target) {
    target.dispose();
  }

  @override
  FocusNode buildTarget() {
    return FocusNode(
      debugLabel: debugLabel,
      onKeyEvent: onKeyEvent,
      skipTraversal: skipTraversal,
      canRequestFocus: canRequestFocus,
      descendantsAreFocusable: descendantsAreFocusable,
    );
  }
}

/// An observer that manages a [PageController].
class PageControllerObserver extends LifecycleObserver<PageController> {
  /// The initial page index.
  final int initialPage;

  /// Whether to keep the page state.
  final bool keepPage;

  /// The fraction of the viewport that each page should occupy.
  final double viewportFraction;

  PageControllerObserver(
    super.state, {
    this.initialPage = 0,
    this.keepPage = true,
    this.viewportFraction = 1.0,
    super.key,
  });

  @override
  void onDisposeTarget(PageController target) {
    target.dispose();
  }

  @override
  PageController buildTarget() {
    return PageController(
      initialPage: initialPage,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
    );
  }
}
