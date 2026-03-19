import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class WidgetObserversTestWidget extends StatefulWidget {
  final String? focusNodeLabel;
  final bool skipTraversal;
  final int initialPage;
  final double initialScrollOffset;
  final int tabLength;
  final String textValue;

  final bool enableFocus;
  final bool enablePage;

  const WidgetObserversTestWidget({
    super.key,
    this.focusNodeLabel,
    this.skipTraversal = false,
    this.initialPage = 0,
    this.initialScrollOffset = 0,
    this.tabLength = 0,
    this.textValue = '',
    this.enableFocus = false,
    this.enablePage = false,
  });

  @override
  State<WidgetObserversTestWidget> createState() =>
      _WidgetObserversTestWidgetState();
}

class _WidgetObserversTestWidgetState extends State<WidgetObserversTestWidget>
    with TickerProviderStateMixin, LifecycleOwnerMixin {
  FocusNodeObserver? focusObserver;
  PageControllerObserver? pageObserver;
  ScrollControllerObserver? scrollObserver;
  TabControllerObserver? tabObserver;
  TextEditingControllerObserver? textObserver;

  @override
  void initState() {
    super.initState();
    if (widget.enableFocus) {
      focusObserver = FocusNodeObserver(
        this,
        debugLabel: widget.focusNodeLabel,
        skipTraversal: widget.skipTraversal,
      );
    }

    if (widget.enablePage) {
      pageObserver = PageControllerObserver(
        this,
        initialPage: widget.initialPage,
      );
    }

    if (widget.initialScrollOffset > 0) {
      scrollObserver = ScrollControllerObserver(
        this,
        initialScrollOffset: widget.initialScrollOffset,
      );
    }

    if (widget.tabLength > 0) {
      tabObserver = TabControllerObserver(
        this,
        length: widget.tabLength,
      );
    }

    if (widget.textValue.isNotEmpty) {
      textObserver = TextEditingControllerObserver(
        this,
        text: widget.textValue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (pageObserver != null)
          SizedBox(
            height: 100,
            child: PageView(controller: pageObserver!.target),
          ),
        if (focusObserver != null) const SizedBox(key: Key('focusCheck')),
        if (scrollObserver != null)
          Container(height: scrollObserver!.target.initialScrollOffset),
        if (tabObserver != null)
          SizedBox(width: tabObserver!.target.length.toDouble()),
        if (textObserver != null) Text(textObserver!.target.text),
      ],
    );
  }
}

void main() {
  testWidgets('FocusNodeObserver initializes and disposes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WidgetObserversTestWidget(
        enableFocus: true,
        focusNodeLabel: 'testFocus',
        skipTraversal: true,
      ),
    ));

    final state = tester.state<_WidgetObserversTestWidgetState>(
        find.byType(WidgetObserversTestWidget));

    expect(state.focusObserver, isNotNull);
    expect(state.focusObserver!.target.debugLabel, 'testFocus');
    expect(state.focusObserver!.target.skipTraversal, true);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PageControllerObserver initializes and disposes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WidgetObserversTestWidget(
        enablePage: true,
        initialPage: 2,
      ),
    ));

    final state = tester.state<_WidgetObserversTestWidgetState>(
        find.byType(WidgetObserversTestWidget));

    expect(state.pageObserver, isNotNull);
    expect(state.pageObserver!.target.initialPage, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ScrollControllerObserver initializes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WidgetObserversTestWidget(initialScrollOffset: 50),
    ));
    final state = tester.state<_WidgetObserversTestWidgetState>(
        find.byType(WidgetObserversTestWidget));
    expect(state.scrollObserver!.target.initialScrollOffset, 50.0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TabControllerObserver initializes', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WidgetObserversTestWidget(tabLength: 3),
    ));
    final state = tester.state<_WidgetObserversTestWidgetState>(
        find.byType(WidgetObserversTestWidget));
    expect(state.tabObserver!.target.length, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TextControllerObserver initializes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WidgetObserversTestWidget(textValue: 'Hello'),
    ));
    final state = tester.state<_WidgetObserversTestWidgetState>(
        find.byType(WidgetObserversTestWidget));
    expect(state.textObserver!.target.text, 'Hello');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TextEditingControllerObserver.fromValue creates controller',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TextEditingFromValueTestWidget(),
    ));
    final state = tester.state<_TextEditingFromValueTestWidgetState>(
        find.byType(TextEditingFromValueTestWidget));
    expect(state.textObserver.target.text, 'initial');
    expect(state.textObserver.target.selection,
        const TextSelection.collapsed(offset: 7));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('FocusNodeObserver syncs latest widget properties',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: FocusNodeUpdateTestWidget(
        skipTraversal: false,
        canRequestFocus: true,
        descendantsAreFocusable: true,
      ),
    ));

    final state = tester.state<_FocusNodeUpdateTestWidgetState>(
        find.byType(FocusNodeUpdateTestWidget));

    expect(state.focusObserver.target.skipTraversal, isFalse);
    expect(state.focusObserver.target.canRequestFocus, isTrue);
    expect(state.focusObserver.target.descendantsAreFocusable, isTrue);

    await tester.pumpWidget(const MaterialApp(
      home: FocusNodeUpdateTestWidget(
        skipTraversal: true,
        canRequestFocus: false,
        descendantsAreFocusable: false,
      ),
    ));

    expect(state.focusObserver.target.skipTraversal, isTrue);
    expect(state.focusObserver.target.canRequestFocus, isFalse);
    expect(state.focusObserver.target.descendantsAreFocusable, isFalse);
  });

  testWidgets('FocusNodeObserver syncs latest handler and debugLabel',
      (WidgetTester tester) async {
    KeyEventResult handlerA(FocusNode node, KeyEvent event) =>
        KeyEventResult.handled;
    KeyEventResult handlerB(FocusNode node, KeyEvent event) =>
        KeyEventResult.ignored;

    await tester.pumpWidget(MaterialApp(
      home: FocusNodeCallbackUpdateTestWidget(
        debugLabel: 'alpha',
        onKeyEvent: handlerA,
      ),
    ));

    final state = tester.state<_FocusNodeCallbackUpdateTestWidgetState>(
        find.byType(FocusNodeCallbackUpdateTestWidget));

    expect(state.focusObserver.target.debugLabel, 'alpha');
    expect(identical(state.focusObserver.target.onKeyEvent, handlerA), isTrue);

    await tester.pumpWidget(MaterialApp(
      home: FocusNodeCallbackUpdateTestWidget(
        debugLabel: 'beta',
        onKeyEvent: handlerB,
      ),
    ));

    expect(state.focusObserver.target.debugLabel, 'beta');
    expect(identical(state.focusObserver.target.onKeyEvent, handlerB), isTrue);
  });

  testWidgets('TabControllerObserver recreates controller when getters change',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DynamicTabControllerWidget(
        length: 3,
        initialIndex: 1,
        animationDuration: Duration(milliseconds: 300),
      ),
    ));

    final state = tester.state<_DynamicTabControllerWidgetState>(
        find.byType(DynamicTabControllerWidget));
    final oldController = state.tabObserver.target;

    expect(oldController.length, 3);
    expect(oldController.index, 1);
    expect(oldController.animationDuration, const Duration(milliseconds: 300));

    await tester.pumpWidget(const MaterialApp(
      home: DynamicTabControllerWidget(
        length: 4,
        initialIndex: 2,
        animationDuration: Duration(milliseconds: 500),
      ),
    ));

    expect(state.tabObserver.target, isNot(same(oldController)));
    expect(state.tabObserver.target.length, 4);
    expect(state.tabObserver.target.index, 2);
    expect(
      state.tabObserver.target.animationDuration,
      const Duration(milliseconds: 500),
    );
  });

  testWidgets('TextEditingControllerObserver uses latest getter on key rebuild',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DynamicTextControllerWidget(version: 1, text: 'alpha'),
    ));

    final state = tester.state<_DynamicTextControllerWidgetState>(
        find.byType(DynamicTextControllerWidget));
    final oldController = state.textObserver.target;

    expect(oldController.text, 'alpha');

    await tester.pumpWidget(const MaterialApp(
      home: DynamicTextControllerWidget(version: 2, text: 'beta'),
    ));

    expect(state.textObserver.target.text, 'beta');
    expect(state.textObserver.target, isNot(same(oldController)));
  });
}

// Helper widget for TextEditingControllerObserver.fromValue test
class TextEditingFromValueTestWidget extends StatefulWidget {
  const TextEditingFromValueTestWidget({super.key});

  @override
  State<TextEditingFromValueTestWidget> createState() =>
      _TextEditingFromValueTestWidgetState();
}

class _TextEditingFromValueTestWidgetState
    extends State<TextEditingFromValueTestWidget> with LifecycleOwnerMixin {
  late final textObserver = TextEditingControllerObserver(
    this,
    editingValue: const TextEditingValue(
      text: 'initial',
      selection: TextSelection.collapsed(offset: 7),
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

// Helper widget for FocusNode property update test
class FocusNodeUpdateTestWidget extends StatefulWidget {
  final bool skipTraversal;
  final bool canRequestFocus;
  final bool descendantsAreFocusable;

  const FocusNodeUpdateTestWidget({
    super.key,
    required this.skipTraversal,
    required this.canRequestFocus,
    required this.descendantsAreFocusable,
  });

  @override
  State<FocusNodeUpdateTestWidget> createState() =>
      _FocusNodeUpdateTestWidgetState();
}

class _FocusNodeUpdateTestWidgetState extends State<FocusNodeUpdateTestWidget>
    with LifecycleOwnerMixin {
  late final focusObserver = FocusNodeObserver(
    this,
    skipTraversalGetter: () => widget.skipTraversal,
    canRequestFocusGetter: () => widget.canRequestFocus,
    descendantsAreFocusableGetter: () => widget.descendantsAreFocusable,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Focus(
      focusNode: focusObserver.target,
      child: const SizedBox(),
    );
  }
}

class FocusNodeCallbackUpdateTestWidget extends StatefulWidget {
  final String? debugLabel;
  final FocusOnKeyEventCallback? onKeyEvent;

  const FocusNodeCallbackUpdateTestWidget({
    super.key,
    required this.debugLabel,
    required this.onKeyEvent,
  });

  @override
  State<FocusNodeCallbackUpdateTestWidget> createState() =>
      _FocusNodeCallbackUpdateTestWidgetState();
}

class _FocusNodeCallbackUpdateTestWidgetState
    extends State<FocusNodeCallbackUpdateTestWidget> with LifecycleOwnerMixin {
  late final focusObserver = FocusNodeObserver(
    this,
    debugLabelGetter: () => widget.debugLabel,
    onKeyEventGetter: () => widget.onKeyEvent,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Focus(
      focusNode: focusObserver.target,
      child: const SizedBox(),
    );
  }
}

class DynamicTabControllerWidget extends StatefulWidget {
  final int length;
  final int initialIndex;
  final Duration? animationDuration;

  const DynamicTabControllerWidget({
    super.key,
    required this.length,
    required this.initialIndex,
    required this.animationDuration,
  });

  @override
  State<DynamicTabControllerWidget> createState() =>
      _DynamicTabControllerWidgetState();
}

class _DynamicTabControllerWidgetState extends State<DynamicTabControllerWidget>
    with TickerProviderStateMixin, LifecycleOwnerMixin {
  late final tabObserver = TabControllerObserver(
    this,
    length: widget.length,
    lengthGetter: () => widget.length,
    initialIndex: widget.initialIndex,
    initialIndexGetter: () => widget.initialIndex,
    animationDuration: widget.animationDuration,
    animationDurationGetter: () => widget.animationDuration,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

class DynamicTextControllerWidget extends StatefulWidget {
  final int version;
  final String text;

  const DynamicTextControllerWidget({
    super.key,
    required this.version,
    required this.text,
  });

  @override
  State<DynamicTextControllerWidget> createState() =>
      _DynamicTextControllerWidgetState();
}

class _DynamicTextControllerWidgetState
    extends State<DynamicTextControllerWidget> with LifecycleOwnerMixin {
  late final textObserver = TextEditingControllerObserver(
    this,
    textGetter: () => widget.text,
    key: () => widget.version,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(textObserver.target.text);
  }
}
