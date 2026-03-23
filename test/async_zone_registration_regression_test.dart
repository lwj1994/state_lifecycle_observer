import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class _NonMixinWidget extends StatefulWidget {
  const _NonMixinWidget({super.key});

  @override
  State<_NonMixinWidget> createState() => _NonMixinState();
}

class _NonMixinState extends State<_NonMixinWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _AsyncZoneParentObserver extends LifecycleObserver<void> {
  _AsyncZoneParentObserver(
    super.state,
    this.nonMixinState,
  );

  final State nonMixinState;
  LifecycleObserver<void>? asyncChildObserver;
  Object? asyncRegistrationError;

  @override
  void onInitState() {
    super.onInitState();
    Future.microtask(() {
      try {
        asyncChildObserver = _AsyncZoneChildObserver(nonMixinState);
      } catch (error) {
        asyncRegistrationError = error;
      }
    });
  }

  @override
  void buildTarget() {}
}

class _AsyncZoneChildObserver extends LifecycleObserver<void> {
  _AsyncZoneChildObserver(super.state);

  @override
  void buildTarget() {}
}

class _AsyncZoneWidget extends StatefulWidget {
  const _AsyncZoneWidget();

  @override
  State<_AsyncZoneWidget> createState() => _AsyncZoneWidgetState();
}

class _AsyncZoneWidgetState extends State<_AsyncZoneWidget>
    with LifecycleOwnerMixin {
  final GlobalKey<_NonMixinState> childKey = GlobalKey<_NonMixinState>();
  _AsyncZoneParentObserver? parentObserver;

  void triggerRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (parentObserver == null && childKey.currentState != null) {
      parentObserver = _AsyncZoneParentObserver(
        this,
        childKey.currentState!,
      );
    }
    return _NonMixinWidget(key: childKey);
  }
}

class _AsyncDirectParentObserver extends LifecycleObserver<void> {
  _AsyncDirectParentObserver(super.state);

  LifecycleObserver<void>? asyncChildObserver;
  Object? asyncRegistrationError;

  @override
  void onInitState() {
    super.onInitState();
    Future.microtask(() {
      try {
        asyncChildObserver = _AsyncDirectChildObserver(state);
      } catch (error) {
        asyncRegistrationError = error;
      }
    });
  }

  @override
  void buildTarget() {}
}

class _AsyncDirectChildObserver extends LifecycleObserver<void> {
  _AsyncDirectChildObserver(super.state);

  @override
  void buildTarget() {}
}

class _AsyncDirectWidget extends StatefulWidget {
  const _AsyncDirectWidget();

  @override
  State<_AsyncDirectWidget> createState() => _AsyncDirectWidgetState();
}

class _AsyncDirectWidgetState extends State<_AsyncDirectWidget>
    with LifecycleOwnerMixin {
  late final _AsyncDirectParentObserver parentObserver =
      _AsyncDirectParentObserver(this);

  @override
  void initState() {
    super.initState();
    parentObserver;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox();
  }
}

void main() {
  testWidgets(
      'Zone registration rejects observers created asynchronously after callbacks return',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _AsyncZoneWidget(),
      ),
    );

    final state =
        tester.state<_AsyncZoneWidgetState>(find.byType(_AsyncZoneWidget));

    state.triggerRebuild();
    await tester.pump();
    await tester.pump();

    expect(state.parentObserver!.asyncRegistrationError, isStateError);
    expect(state.parentObserver!.asyncChildObserver, isNull);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'direct-owner nested observers also reject async creation after callbacks return',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: _AsyncDirectWidget(),
      ),
    );

    final state =
        tester.state<_AsyncDirectWidgetState>(find.byType(_AsyncDirectWidget));

    await tester.pump();

    expect(state.parentObserver.asyncRegistrationError, isStateError);
    expect(state.parentObserver.asyncChildObserver, isNull);
    expect(tester.takeException(), isNull);
  });
}
