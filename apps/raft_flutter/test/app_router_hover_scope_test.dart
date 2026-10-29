import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/app_root_router.dart';
import 'package:raft_ui/raft_ui.dart';

class _PrivateObserver extends NavigatorObserver {
  var changes = 0;
  @override
  void didChangeTop(Route<dynamic> top, Route<dynamic>? previous) => changes++;
}

class _Host {
  _Host({RaftHoverDismissController? existing}) {
    router = RaftAppRouter(
      home: (_) => const Scaffold(body: Center(child: Text('Root page'))),
      onLocation: (_) async {},
      onRootBack: () async => false,
      observers: [private, ?existing],
    );
    information = router.informationProvider(Uri(path: '/'));
  }
  final private = _PrivateObserver();
  late final RaftAppRouter router;
  late final PlatformRouteInformationProvider information;

  Widget build({
    RaftHoverDismissController? external,
    bool scoped = true,
    Widget? outer,
  }) => MaterialApp.router(
    theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
    routerDelegate: router,
    routeInformationParser: const RaftAppRouteParser(),
    routeInformationProvider: information,
    builder: (context, child) {
      final content = outer == null
          ? child!
          : Overlay.wrap(
              child: Column(
                children: [
                  outer,
                  Expanded(child: child!),
                ],
              ),
            );
      if (!scoped) return content;
      return external == null
          ? router.withHoverDismiss(content)
          : RaftHoverDismissScope(
              controller: external,
              navigation: router,
              location: () => router.currentConfiguration,
              child: content,
            );
    },
  );

  Navigator navigator(WidgetTester t) =>
      t.widget<Navigator>(find.byKey(router.navigatorKey));

  void push() => router.navigatorKey.currentState!.push<void>(
    MaterialPageRoute(
      builder: (_) => const Scaffold(body: Center(child: Text('Detail page'))),
    ),
  );

  void dispose() {
    information.dispose();
    router.dispose();
  }
}

void main() {
  testWidgets('root router uses the stable controller owned above Router', (
    t,
  ) async {
    final host = _Host();
    addTearDown(host.dispose);
    await t.pumpWidget(host.build());
    await t.pumpAndSettle();
    final first = host.navigator(t);
    final hover = first.observers
        .whereType<RaftHoverDismissController>()
        .single;
    expect(first.observers.first, same(host.private));
    expect(hover.navigator, same(host.router.navigatorKey.currentState));
    var dismissals = 0;
    hover.addListener(() => dismissals++);
    host.router.refresh();
    await t.pump();
    expect(dismissals, 0);
    expect(
      host
          .navigator(t)
          .observers
          .whereType<RaftHoverDismissController>()
          .single,
      same(hover),
    );
    host.router.publish(Uri(path: '/agents'));
    await t.pump();
    expect(dismissals, 1);
    host.push();
    await t.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(dismissals, 2);
    host.router.navigatorKey.currentState!.pop();
    await t.pumpAndSettle();
    expect(dismissals, 3);
    await t.pumpWidget(const SizedBox());
    hover.dismiss();
    expect(dismissals, 3);
  });

  testWidgets('an explicitly provided observer is attached only once', (
    t,
  ) async {
    final external = RaftHoverDismissController();
    final host = _Host(existing: external);
    addTearDown(host.dispose);
    addTearDown(external.dispose);
    await t.pumpWidget(host.build(external: external));
    await t.pumpAndSettle();
    expect(host.navigator(t).observers, [host.private, external]);
    var dismissals = 0;
    external.addListener(() => dismissals++);
    host.push();
    await t.pumpAndSettle();
    expect(dismissals, 1);
    await t.pumpWidget(const SizedBox());
    final before = dismissals;
    external.dismiss();
    expect(dismissals, before + 1);
  });

  testWidgets('a changed scope controller replaces only its observer', (
    t,
  ) async {
    final first = RaftHoverDismissController();
    final second = RaftHoverDismissController();
    final host = _Host();
    addTearDown(host.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await t.pumpWidget(host.build(external: first));
    await t.pumpAndSettle();
    await t.pumpWidget(host.build(external: second));
    await t.pumpAndSettle();
    expect(host.navigator(t).observers, [host.private, second]);
    expect(first.navigator, isNull);
    expect(second.navigator, same(host.router.navigatorKey.currentState));
    var dismissals = 0;
    second.addListener(() => dismissals++);
    final privateBefore = host.private.changes;
    host.push();
    await t.pumpAndSettle();
    expect(dismissals, 1);
    expect(host.private.changes, privateBefore + 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('an unscoped router preserves its existing observer contract', (
    t,
  ) async {
    final host = _Host();
    addTearDown(host.dispose);
    await t.pumpWidget(host.build(scoped: false));
    await t.pumpAndSettle();
    expect(host.navigator(t).observers, [host.private]);
    host.push();
    await t.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final pending in [false, true]) {
    testWidgets(
      '${pending ? 'pending' : 'open'} outer tooltip retires on logical navigation',
      (t) async {
        final host = _Host();
        addTearDown(host.dispose);
        RaftHoverDismissController? outerController;
        final outer = SizedBox(
          height: 60,
          child: Center(
            child: Builder(
              builder: (context) {
                outerController = RaftHoverDismissScope.maybeOf(context);
                return const RaftTooltip(
                  message: 'Outer chrome popup',
                  delay: Duration(milliseconds: 600),
                  child: SizedBox(
                    width: 100,
                    height: 40,
                    child: Text('Outer chrome'),
                  ),
                );
              },
            ),
          ),
        );
        TestGesture? mouse;
        try {
          await t.pumpWidget(host.build(outer: outer));
          await t.pumpAndSettle();
          final controller = host
              .navigator(t)
              .observers
              .whereType<RaftHoverDismissController>()
              .single;
          expect(outerController, same(controller));
          expect(
            find.descendant(
              of: find.byKey(host.router.navigatorKey),
              matching: find.text('Outer chrome'),
            ),
            findsNothing,
          );
          mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(t.getCenter(find.text('Outer chrome')));
          await t.pump(Duration(milliseconds: pending ? 100 : 610));
          if (!pending) await t.pump(const Duration(milliseconds: 200));
          expect(
            find.text('Outer chrome popup'),
            pending ? findsNothing : findsOneWidget,
          );
          host.router.publish(Uri(path: '/agents'));
          await t.pump();
          expect(find.text('Outer chrome popup'), findsNothing);
          host.router.publish(Uri(path: '/'));
          await t.pump(const Duration(seconds: 1));
          expect(find.text('Outer chrome popup'), findsNothing);
          expect(outerController, same(controller));
          await mouse.moveBy(const Offset(1, 0));
          await t.pump(const Duration(milliseconds: 610));
          await t.pump(const Duration(milliseconds: 200));
          expect(find.text('Outer chrome popup'), findsOneWidget);
        } finally {
          await mouse?.removePointer();
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }
      },
    );
  }
}
