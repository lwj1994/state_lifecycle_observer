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
    skipTraversal: widget.skipTraversal,
    canRequestFocus: widget.canRequestFocus,
    descendantsAreFocusable: widget.descendantsAreFocusable,
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
