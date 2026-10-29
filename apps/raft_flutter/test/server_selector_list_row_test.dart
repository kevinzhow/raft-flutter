import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_ui/raft_ui.dart';

final _servers = [
  RaftRecord({
    'id': 'alpha',
    'name': 'Alpha',
    'slug': 'alpha',
    'avatarUrl': '/avatars/servers/alpha.webp',
  }),
  RaftRecord({'id': 'beta', 'name': 'Beta', 'slug': 'beta'}),
];

Future<void> _mount(
  WidgetTester t, {
  String look = raftThemePackId,
  bool dark = false,
  Size size = const Size(856, 944),
  TargetPlatform platform = TargetPlatform.android,
  bool loading = false,
  Future<void> Function(RaftRecord)? select,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(
        pack: packForThemeId(look),
        dark: dark,
      ).copyWith(platform: platform),
      home: GlobalServerSelector(
        servers: _servers,
        user: RaftRecord({'id': 'owner', 'email': 'owner@parity.invalid'}),
        loading: loading,
        onSelect: select ?? (_) async {},
        onCreate: (_, _) async {},
        onLogout: () async {},
        onRetry: () async {},
      ),
    ),
  );
  await t.pump();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'current server selector uses the source inset row family dark=$dark',
      (t) async {
        addTearDown(t.view.reset);
        await _mount(t, dark: dark);
        final group = t.widget<RaftListRowGroup>(
          find.byKey(const ValueKey('server-selector-list')),
        );
        expect(group.children, hasLength(2));
        // Direct rows let the canonical parent own separators, without page gaps.
        expect(group.children, everyElement(isA<RaftListRow>()));
        expect(find.byType(RaftCard), findsNothing);
        for (final server in _servers) {
          final row = find.byKey(ValueKey('global-server-${server.id}'));
          expect(t.widget(row), isA<RaftListRow>());
          expect(
            find.descendant(of: row, matching: find.byType(RaftListRowBody)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.byType(RaftListRowTitle)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.byType(RaftListRowMeta)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: row, matching: find.byType(RaftListRowChevron)),
            findsOneWidget,
          );
          final avatar = t.widget<RaftAvatarSlot>(
            find.descendant(of: row, matching: find.byType(RaftAvatarSlot)),
          );
          expect(avatar.server, isTrue);
          expect(avatar.agent, isFalse);
          expect(avatar.slot, RaftAvatarSlotContext.surfaceList);
          final content = avatar.content! as RaftAvatarContent;
          expect(content.name, server.string('name'));
          expect(content.kind, RaftAvatarContentKind.server);
          expect(content.uploadedUrl, server.json['avatarUrl']);
          expect(
            find.descendant(
              of: row,
              matching: find.text('/${server.string('slug')}'),
            ),
            findsOneWidget,
          );
        }
        final rows = t
            .widgetList<RaftListRow>(find.byType(RaftListRow))
            .toList();
        expect(rows.map((r) => r.topRule), [false, true]);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final cell in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'server selection preserves owner pending and callback ${cell.$2.name}',
      (t) async {
        addTearDown(t.view.reset);
        final selected = <RaftRecord>[];
        final pending = Completer<void>();
        final kind = cell.$2 == TargetPlatform.linux
            ? PointerDeviceKind.mouse
            : PointerDeviceKind.touch;
        Future<void> select(RaftRecord server) {
          selected.add(server);
          return pending.future;
        }

        await _mount(t, size: cell.$1, platform: cell.$2, select: select);
        await t.tap(
          find.byKey(const ValueKey('global-server-alpha')),
          kind: kind,
        );
        await t.pump();
        expect(selected, [_servers.first]);
        // Pending is owned by the root, not a new local selection state.
        await _mount(
          t,
          size: cell.$1,
          platform: cell.$2,
          loading: true,
          select: select,
        );
        await t.tap(
          find.byKey(const ValueKey('global-server-beta')),
          kind: kind,
        );
        await t.pump();
        expect(selected, [_servers.first]);
        pending.complete();
        await _mount(t, size: cell.$1, platform: cell.$2, select: select);
        await t.tap(
          find.byKey(const ValueKey('global-server-beta')),
          kind: kind,
        );
        await t.pump();
        expect(selected, [_servers.first, _servers.last]);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final mode in [
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
    testWidgets('Frozen selector keeps its original option cards $mode', (
      t,
    ) async {
      addTearDown(t.view.reset);
      await _mount(t, look: mode.$1, dark: mode.$2);
      expect(find.byType(RaftListRowGroup), findsNothing);
      expect(find.byType(RaftCard), findsNWidgets(2));
      expect(find.byType(RaftListRow), findsNothing);
      expect(find.byKey(const ValueKey('global-server-alpha')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
