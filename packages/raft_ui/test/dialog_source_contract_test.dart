import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Source: @botiverse/raft-ui 0.7.0 Dialog + DialogSurface, and pinned Web
// components/ui/DialogCard.tsx. Geometry is the source contract, not a golden
// from the earlier Flutter implementation.
Future<void> mount(
  WidgetTester t,
  Widget child, {
  Size size = const Size(1280, 800),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(() => t.pumpWidget(const SizedBox()));
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await t.pumpAndSettle();
}

Finder surface() => find
    .descendant(
      of: find.byType(RaftDialog),
      matching: find.byType(RaftRecipeBox),
    )
    .first;

void main() {
  testWidgets('DialogSurface draws its source seam once', (t) async {
    await mount(t, const RaftDialog(title: 'Review', content: Text('Body')));
    final box = t.widget<RaftRecipeBox>(surface());
    final tokens = RaftTokens.of(t.element(surface())).recipeTokens;
    final rings = box.style
        .cssShadows(tokens)
        .where((s) => !s.inset && s.blur == 0 && s.spread == 1);
    expect(
      rings.length,
      1,
      reason: 'ring-1 belongs to DialogSurface; no second compatibility ring',
    );
  });
  testWidgets('a body without a header receives first-child top padding', (
    t,
  ) async {
    await mount(
      t,
      const RaftDialog(content: SizedBox(key: Key('body'), height: 20)),
    );
    expect(
      t.getRect(find.byKey(const Key('body'))).top - t.getRect(surface()).top,
      20,
    );
  });
  testWidgets('footer directly after header has the source top gap', (t) async {
    await mount(
      t,
      const RaftDialog(
        title: 'Review',
        showClose: false,
        actions: [SizedBox(key: Key('action'), width: 30, height: 20)],
      ),
    );
    final header = t.getRect(find.byType(RaftDialogHeader));
    expect(t.getRect(find.byKey(const Key('action'))).top - header.bottom, 20);
  });
  testWidgets('Web DialogCard uses twenty pixel content inset', (t) async {
    await mount(
      t,
      RaftModalBackdrop(
        child: RaftDialogCard(
          title: 'Review',
          onClose: () {},
          child: const SizedBox(key: Key('card-body'), height: 20),
        ),
      ),
    );
    final card = find.byType(RaftDialogCard);
    expect(
      t.getRect(find.byKey(const Key('card-body'))).left - t.getRect(card).left,
      20,
    );
  });
  testWidgets('generic form uses the same dialog header inset', (t) async {
    await mount(
      t,
      RaftFormDialog(
        title: 'Review settings',
        fields: const [RaftFormField('name', 'Name', initial: 'Team')],
        onSubmit: (_) async {},
      ),
    );
    final title = find.text('Review settings');
    final surface = find.ancestor(
      of: title,
      matching: find.byType(RaftDialogSurface),
    );
    expect(surface, findsOneWidget);
    expect(t.getRect(title).left - t.getRect(surface).left, 20);
    expect(
      (t.widget<Text>(title).style ??
              DefaultTextStyle.of(t.element(title)).style)
          .fontSize,
      17,
    );
  });
  testWidgets('current Web centered Dialog has no entrance motion', (t) async {
    BuildContext? page;
    await mount(
      t,
      Builder(
        builder: (c) {
          page = c;
          return const Text('Page');
        },
      ),
    );
    showRaftDialog<void>(
      context: page!,
      builder: (_) => const RaftDialog(title: 'Review', content: Text('Body')),
    );
    await t.pump();
    final route = ModalRoute.of(t.element(find.byType(RaftDialog)))!;
    expect(route.transitionDuration, Duration.zero);
    await t.pumpAndSettle();
  });

  testWidgets('alert header and footer use the alert sibling selector', (
    t,
  ) async {
    await mount(
      t,
      const RaftAlertDialog(
        title: 'Review',
        actions: [SizedBox(key: Key('alert-action'), width: 20, height: 20)],
      ),
    );
    expect(
      t.getRect(find.byKey(const Key('alert-action'))).top -
          t.getRect(find.byType(RaftDialogHeader)).bottom,
      20,
    );
  });

  testWidgets(
    'wide bar form resolves its bounds and separators from the source',
    (t) async {
      await mount(
        t,
        const RaftDialog(
          size: RaftDialogSize.wide,
          bar: true,
          title: 'Edit agent',
          content: SizedBox.expand(key: Key('wide-body')),
          actions: [SizedBox(width: 40, height: 20)],
        ),
      );
      expect(t.getSize(surface()), const Size(896, 760));
      expect(t.getSize(find.byType(RaftDialogHeader)).height, 56);
      final header = t.widget<RaftRecipeBox>(
        find
            .descendant(
              of: find.byType(RaftDialogHeader),
              matching: find.byType(RaftRecipeBox),
            )
            .first,
      );
      expect(header.style.borderWidth.bottom, 1);
      final body = t.widget<RaftRecipeBox>(
        find
            .descendant(
              of: find.byType(RaftDialogBody),
              matching: find.byType(RaftRecipeBox),
            )
            .first,
      );
      expect(body.style.padding, EdgeInsets.zero);
      final footer = t.widget<RaftRecipeBox>(
        find
            .descendant(
              of: find.byType(RaftDialogFooter),
              matching: find.byType(RaftRecipeBox),
            )
            .first,
      );
      expect(footer.style.borderWidth.top, 1);
      expect(
        footer.style.padding,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'wide bar title grows and the body scrolls in a narrow large-text window',
    (t) async {
      await mount(
        t,
        RaftDialog(
          size: RaftDialogSize.wide,
          bar: true,
          title: 'Review the release settings',
          content: ListView(
            children: [for (var i = 0; i < 20; i++) Text('Section $i')],
          ),
          actions: [RaftButton(label: 'Save', onPressed: () {})],
        ),
        size: const Size(390, 844),
        scale: 3.1,
      );
      expect(t.getSize(surface()).width, 358);
      expect(t.getSize(find.byType(RaftDialogHeader)).height, greaterThan(56));
      await t.scrollUntilVisible(find.text('Section 19'), 400);
      expect(find.text('Section 19').hitTestable(), findsOneWidget);
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'migrated Material alerts use the canonical source surface in Raft',
    (t) async {
      await mount(
        t,
        const RaftAlertDialog(
          legacy: RaftLegacyAlert.material,
          title: Text('Review'),
          content: Text('Body'),
        ),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(RaftDialogSurface), findsOneWidget);
      expect(t.getRect(find.text('Body')).left - t.getRect(surface()).left, 20);
    },
  );
}
