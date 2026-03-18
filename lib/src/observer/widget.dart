import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/src/lifecycle_observer.dart';

/// An observer that manages a [ScrollController].
class ScrollControllerObserver extends LifecycleObserver<ScrollController> {
  /// The initial scroll offset.
  final double _initialScrollOffsetValue;
  final double Function()? _initialScrollOffsetGetter;

  /// Whether to keep the scroll offset on state preservation.
  final bool _keepScrollOffsetValue;
  final bool Function()? _keepScrollOffsetGetter;

  /// Debug label for the controller.
  final String? _debugLabelValue;
  final String? Function()? _debugLabelGetter;

  /// Callback when a position is attached.
  final ScrollControllerCallback? _onAttachValue;
  final ScrollControllerCallback? Function()? _onAttachGetter;

  /// Callback when a position is detached.
  final ScrollControllerCallback? _onDetachValue;
  final ScrollControllerCallback? Function()? _onDetachGetter;

  ScrollControllerObserver(
    super.state, {
    double initialScrollOffset = 0.0,
    double Function()? initialScrollOffsetGetter,
    bool keepScrollOffset = true,
    bool Function()? keepScrollOffsetGetter,
    String? debugLabel,
    String? Function()? debugLabelGetter,
    ScrollControllerCallback? onAttach,
    ScrollControllerCallback? Function()? onAttachGetter,
    ScrollControllerCallback? onDetach,
    ScrollControllerCallback? Function()? onDetachGetter,
    super.key,
  })  : _initialScrollOffsetValue = initialScrollOffset,
        _initialScrollOffsetGetter = initialScrollOffsetGetter,
        _keepScrollOffsetValue = keepScrollOffset,
        _keepScrollOffsetGetter = keepScrollOffsetGetter,
        _debugLabelValue = debugLabel,
        _debugLabelGetter = debugLabelGetter,
        _onAttachValue = onAttach,
        _onAttachGetter = onAttachGetter,
        _onDetachValue = onDetach,
        _onDetachGetter = onDetachGetter;

  double get initialScrollOffset =>
      _initialScrollOffsetGetter?.call() ?? _initialScrollOffsetValue;

  bool get keepScrollOffset =>
      _keepScrollOffsetGetter?.call() ?? _keepScrollOffsetValue;

  String? get debugLabel => _debugLabelGetter?.call() ?? _debugLabelValue;

  ScrollControllerCallback? get onAttach =>
      _onAttachGetter?.call() ?? _onAttachValue;

  ScrollControllerCallback? get onDetach =>
      _onDetachGetter?.call() ?? _onDetachValue;

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
///
/// The [state] parameter must be a [State] that mixes in [TickerProvider]
/// (e.g., [SingleTickerProviderStateMixin] or [TickerProviderStateMixin]).
class TabControllerObserver extends LifecycleObserver<TabController> {
  /// The total number of tabs.
  final int _lengthValue;
  final int Function()? _lengthGetter;

  /// The initial index of the selected tab.
  final int _initialIndexValue;
  final int Function()? _initialIndexGetter;

  /// The duration of the tab transition animation.
  final Duration? _animationDurationValue;
  final Duration? Function()? _animationDurationGetter;

  TabControllerObserver(
    super.state, {
    required int length,
    int Function()? lengthGetter,
    int initialIndex = 0,
    int Function()? initialIndexGetter,
    Duration? animationDuration,
    Duration? Function()? animationDurationGetter,
    super.key,
  })  : assert(
            state is TickerProvider,
            'TabControllerObserver requires State to mixin TickerProvider '
            '(e.g., SingleTickerProviderStateMixin or TickerProviderStateMixin)'),
        _lengthValue = length,
        _lengthGetter = lengthGetter,
        _initialIndexValue = initialIndex,
        _initialIndexGetter = initialIndexGetter,
        _animationDurationValue = animationDuration,
        _animationDurationGetter = animationDurationGetter;

  int get length => _lengthGetter?.call() ?? _lengthValue;

  int get initialIndex => _initialIndexGetter?.call() ?? _initialIndexValue;

  Duration? get animationDuration =>
      _animationDurationGetter?.call() ?? _animationDurationValue;

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
  final String? _textValue;
  final String? Function()? _textGetter;

  /// The initial editing value.
  final TextEditingValue? _editingValueValue;
  final TextEditingValue? Function()? _editingValueGetter;

  TextEditingControllerObserver(
    super.state, {
    String? text,
    String? Function()? textGetter,
    TextEditingValue? editingValue,
    TextEditingValue? Function()? editingValueGetter,
    super.key,
  })  : _textValue = text,
        _textGetter = textGetter,
        _editingValueValue = editingValue,
        _editingValueGetter = editingValueGetter;

  String? get text => _textGetter?.call() ?? _textValue;

  TextEditingValue? get editingValue =>
      _editingValueGetter?.call() ?? _editingValueValue;

  /// Creates a [TextEditingControllerObserver] from a starting value.
  // coverage:ignore-start
  factory TextEditingControllerObserver.fromValue(
    State state, {
    required TextEditingValue value,
  }) {
    return TextEditingControllerObserver(
      state,
      editingValue: value,
    );
  }
  // coverage:ignore-end

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
  final String? _debugLabelValue;
  final String? Function()? _debugLabelGetter;

  /// Callback for handling key events.
  final FocusOnKeyEventCallback? _onKeyEventValue;
  final FocusOnKeyEventCallback? Function()? _onKeyEventGetter;

  /// Whether to skip traversal for this node.
  final bool _skipTraversalValue;
  final bool Function()? _skipTraversalGetter;

  /// Whether this node can request focus.
  final bool _canRequestFocusValue;
  final bool Function()? _canRequestFocusGetter;

  /// Whether descendants of this node are focusable.
  final bool _descendantsAreFocusableValue;
  final bool Function()? _descendantsAreFocusableGetter;

  FocusNodeObserver(
    super.state, {
    String? debugLabel,
    String? Function()? debugLabelGetter,
    FocusOnKeyEventCallback? onKeyEvent,
    FocusOnKeyEventCallback? Function()? onKeyEventGetter,
    bool skipTraversal = false,
    bool Function()? skipTraversalGetter,
    bool canRequestFocus = true,
    bool Function()? canRequestFocusGetter,
    bool descendantsAreFocusable = true,
    bool Function()? descendantsAreFocusableGetter,
    super.key,
  })  : _debugLabelValue = debugLabel,
        _debugLabelGetter = debugLabelGetter,
        _onKeyEventValue = onKeyEvent,
        _onKeyEventGetter = onKeyEventGetter,
        _skipTraversalValue = skipTraversal,
        _skipTraversalGetter = skipTraversalGetter,
        _canRequestFocusValue = canRequestFocus,
        _canRequestFocusGetter = canRequestFocusGetter,
        _descendantsAreFocusableValue = descendantsAreFocusable,
        _descendantsAreFocusableGetter = descendantsAreFocusableGetter;

  String? get debugLabel => _debugLabelGetter?.call() ?? _debugLabelValue;

  FocusOnKeyEventCallback? get onKeyEvent =>
      _onKeyEventGetter?.call() ?? _onKeyEventValue;

  bool get skipTraversal => _skipTraversalGetter?.call() ?? _skipTraversalValue;

  bool get canRequestFocus =>
      _canRequestFocusGetter?.call() ?? _canRequestFocusValue;

  bool get descendantsAreFocusable =>
      _descendantsAreFocusableGetter?.call() ?? _descendantsAreFocusableValue;

  // coverage:ignore-start
  @override
  void onDidUpdateWidget() {
    super.onDidUpdateWidget();
    if (currentKey != key?.call()) {
      return;
    }
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
  // coverage:ignore-end

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
  final int _initialPageValue;
  final int Function()? _initialPageGetter;

  /// Whether to keep the page state.
  final bool _keepPageValue;
  final bool Function()? _keepPageGetter;

  /// The fraction of the viewport that each page should occupy.
  final double _viewportFractionValue;
  final double Function()? _viewportFractionGetter;

  PageControllerObserver(
    super.state, {
    int initialPage = 0,
    int Function()? initialPageGetter,
    bool keepPage = true,
    bool Function()? keepPageGetter,
    double viewportFraction = 1.0,
    double Function()? viewportFractionGetter,
    super.key,
  })  : _initialPageValue = initialPage,
        _initialPageGetter = initialPageGetter,
        _keepPageValue = keepPage,
        _keepPageGetter = keepPageGetter,
        _viewportFractionValue = viewportFraction,
        _viewportFractionGetter = viewportFractionGetter;

  int get initialPage => _initialPageGetter?.call() ?? _initialPageValue;

  bool get keepPage => _keepPageGetter?.call() ?? _keepPageValue;

  double get viewportFraction =>
      _viewportFractionGetter?.call() ?? _viewportFractionValue;

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
