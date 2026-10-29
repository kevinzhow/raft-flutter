import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

const cancelKey = Key('footer-cancel');
const submitKey = Key('footer-submit');
const footerKey = Key('agent-footer');

Future<void> host(
  WidgetTester t, {
  RaftThemePack? pack,
  bool dark = false,
  double width = 360,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.linux,
  Size size = const Size(1280, 800),
  List<Widget> children = const [
    SizedBox(key: cancelKey, width: 80, height: 40),
    SizedBox(key: submitKey, width: 100, height: 40),
  ],
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(pack: pack, dark: dark, platform: platform),
      builder: (context, child) => RaftTextScaling(child: child!),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: RaftAgentDialogFooter(key: footerKey, children: children),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  // Pinned Web db5e399f CreateAgentDialog.tsx:1848 and
  // AgentDetailPanel.tsx:2295 both use `flex flex-wrap justify-end gap-2`.
  // raft-ui 0.7.0's generated Dialog footer resolves the same gap to 8px.
  for (final dark in [false, true]) {
    testWidgets('agent actions retain the Web gap and trailing edge $dark', (
      t,
    ) async {
      await host(t, dark: dark);
      final cancel = t.getRect(find.byKey(cancelKey));
      final submit = t.getRect(find.byKey(submitKey));
      final footer = t.getRect(find.byKey(footerKey));
      expect(submit.left - cancel.right, 8);
      expect(submit.right, footer.right);
      expect(cancel.left, footer.right - 100 - 8 - 80);
      expect(t.takeException(), isNull);
    });
  }

  for (final width in [360.0, 160.0]) {
    testWidgets('agent footer follows explicit Dialog gap at width $width', (
      t,
    ) async {
      final pack = RaftThemePack.parse(
        jsonEncode({
          'format': raftThemePackFormat,
          'id': 'user:agent-footer',
          'name': {'en': 'Agent footer override'},
          'version': '1',
          'extends': 'raft',
          'modes': {
            'light': {
              'geometry': {'space.dialogFooterGap': 14},
            },
            'dark': {},
          },
        }),
      );
      await host(t, pack: pack, width: width);
      final cancel = t.getRect(find.byKey(cancelKey));
      final submit = t.getRect(find.byKey(submitKey));
      expect(
        width == 360 ? submit.left - cancel.right : submit.top - cancel.bottom,
        14,
      );
      expect(t.takeException(), isNull);
    });
  }

  for (final look in [
    (id: elegantThemePackId, dark: false),
    (id: elegantThemePackId, dark: true),
    (id: brutalThemePackId, dark: false),
  ]) {
    testWidgets('frozen agent footer stays gap-3 ${look.id}/${look.dark}', (
      t,
    ) async {
      await host(t, pack: packForThemeId(look.id), dark: look.dark);
      final cancel = t.getRect(find.byKey(cancelKey));
      final submit = t.getRect(find.byKey(submitKey));
      expect(submit.left - cancel.right, 12);
      final wrap = t.widget<Wrap>(
        find.descendant(of: find.byKey(footerKey), matching: find.byType(Wrap)),
      );
      expect(wrap.runSpacing, 12);
      expect(t.takeException(), isNull);
    });
  }

  for (final scenario in [
    (
      name: 'narrow mouse window',
      size: const Size(390, 844),
      width: 180.0,
      scale: 1.0,
      platform: TargetPlatform.linux,
    ),
    (
      name: 'large-text phone',
      size: const Size(390, 844),
      width: 318.0,
      scale: 3.1,
      platform: TargetPlatform.iOS,
    ),
    (
      name: 'large-text touch foldable',
      size: const Size(856, 944),
      width: 318.0,
      scale: 3.1,
      platform: TargetPlatform.android,
    ),
  ]) {
    testWidgets('wrapped agent actions stay reachable: ${scenario.name}', (
      t,
    ) async {
      var cancelled = 0, submitted = 0;
      await host(
        t,
        size: scenario.size,
        width: scenario.width,
        scale: scenario.scale,
        platform: scenario.platform,
        children: [
          RaftAgentDialogButton(
            key: cancelKey,
            label: 'Cancel',
            onPressed: () => cancelled++,
          ),
          RaftAgentDialogButton(
            key: submitKey,
            label: 'Create Agent',
            primary: true,
            onPressed: () => submitted++,
          ),
        ],
      );
      final cancel = t.getRect(find.byKey(cancelKey));
      final submit = t.getRect(find.byKey(submitKey));
      final footer = t.getRect(find.byKey(footerKey));
      expect(submit.top - cancel.bottom, 8);
      for (final rect in [cancel, submit]) {
        expect(rect.left, greaterThanOrEqualTo(footer.left));
        expect(rect.right, lessThanOrEqualTo(footer.right));
      }
      if (scenario.scale > 1) {
        expect(cancel.height, greaterThan(44));
      }
      expect(find.byKey(cancelKey).hitTestable(), findsOneWidget);
      expect(find.byKey(submitKey).hitTestable(), findsOneWidget);
      await t.tap(find.byKey(cancelKey));
      await t.pump();
      await t.tap(find.byKey(submitKey));
      await t.pump();
      expect(cancelled, 1);
      expect(submitted, 1);
      expect(t.takeException(), isNull);
    });
  }
}
