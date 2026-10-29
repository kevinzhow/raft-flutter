import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_servers.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show frames;
import 'support/human_login_fake.dart';

const _servers = [
  HumanLoginServer(id: 'alpha', slug: 'alpha', name: 'Alpha'),
  HumanLoginServer(id: 'beta', slug: 'beta', name: 'Beta'),
];
const _client = HumanLoginClient(clientId: 'fixture-app', name: 'Fixture App');
HumanLoginLookup _lookup(int count) => HumanLoginLookup([
  for (final server in _servers.take(count)) HumanLoginRow(server, _client),
]);
const _select = ValueKey('human-login-server-select');

class _PendingAuthorize extends FakeHumanLoginApi {
  _PendingAuthorize() : super(servers: _servers);
  final gate = Completer<void>();
  int started = 0;
  @override
  Future<dynamic> authorize(Map<String, Object?> body) async {
    started++;
    await gate.future;
    return super.authorize(body);
  }
}

Future<void> _field(
  WidgetTester t, {
  String look = raftThemePackId,
  bool dark = false,
  int count = 2,
  String selected = 'alpha',
  bool enabled = true,
  ValueChanged<String>? onSelect,
}) => t.pumpWidget(
  MaterialApp(
    theme: raftTheme(pack: packForThemeId(look), dark: dark),
    home: Scaffold(
      body: HumanLoginServerField(
        lookup: _lookup(count),
        selectedId: selected,
        enabled: enabled,
        onSelect: onSelect ?? (_) {},
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'plain server field uses source Select for one or many dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(856, 944);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        for (final count in [1, 2]) {
          final changes = <String>[];
          await _field(t, dark: dark, count: count, onSelect: changes.add);
          final select = t.widget<RaftSelectField<String>>(find.byKey(_select));
          expect(select.items.map((i) => (i.value, i.label)), [
            for (final server in _servers.take(count))
              (server.id, server.label),
          ]);
          expect(select.value, 'alpha');
          expect(select.label, 'Raft Server');
          expect(select.placeholder, 'Raft Server');
          expect(
            select.onChanged,
            isNotNull,
            reason: 'source keeps even one option in Select',
          );
          select.onChanged!(null);
          expect(
            changes,
            isEmpty,
            reason: 'source ignores null, value stays with owner',
          );
          expect(find.byType(RaftCard), findsNothing);
          expect(find.byType(RaftRadioGroup<String>), findsNothing);
        }
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final cell in [
    (const Size(856, 944), TargetPlatform.android, PointerDeviceKind.touch),
    (const Size(390, 844), TargetPlatform.linux, PointerDeviceKind.mouse),
  ]) {
    testWidgets('actual Select choice and pending revocation ${cell.$2.name}', (
      t,
    ) async {
      t.view.physicalSize = cell.$1;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var enabled = true, selected = 'alpha';
      final changes = <String>[];
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(raftThemePackId))
              .copyWith(platform: cell.$2),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return HumanLoginServerField(
                  lookup: _lookup(2),
                  selectedId: selected,
                  enabled: enabled,
                  onSelect: (value) => setState(() {
                    changes.add(value);
                    selected = value;
                  }),
                );
              },
            ),
          ),
        ),
      );
      expect(find.byKey(_select), findsOneWidget);
      await t.tap(find.byKey(_select), kind: cell.$3);
      await t.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsOneWidget);
      update(() => enabled = false);
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      await t.tap(find.byKey(_select), kind: cell.$3);
      await t.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      expect(changes, isEmpty);
      update(() => enabled = true);
      await t.pump();
      await t.tap(find.byKey(_select), kind: cell.$3);
      await t.pump();
      await t.tap(
        find.byKey(const ValueKey('human-login-server-beta')),
        kind: cell.$3,
      );
      await t.pump();
      expect(changes, ['beta']);
      expect(
        t.widget<RaftSelectField<String>>(find.byKey(_select)).value,
        'beta',
      );
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'real human login sheet disables server Select during authorization',
    (t) async {
      t.view.physicalSize = const Size(856, 944);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final api = _PendingAuthorize();
      Uri? result;
      addTearDown(() async {
        if (!api.gate.isCompleted) api.gate.complete();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(raftThemePackId)),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showHumanLoginSheet(
                  context,
                  api: api,
                  request: HumanLoginRequest.fromSetupUri(
                    Uri.parse(
                      'https://app.example.com/login-with-raft/setup?client_id=artifact-share&return_to=https%3A%2F%2Fartifacts.example.com%2Fauth%2Fcallback&scope=openid+profile',
                    ),
                  ),
                );
              },
              child: const Text('Open login'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open login'));
      await frames(t, 25);
      expect(find.byKey(_select), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('human-login-continue')));
      await frames(t);
      expect(api.started, 1);
      expect(
        t.widget<RaftSelectField<String>>(find.byKey(_select)).onChanged,
        isNull,
      );
      await t.tap(find.byKey(_select));
      await t.pump();
      expect(find.byKey(const ValueKey('raft-select-popup')), findsNothing);
      api.gate.complete();
      await frames(t, 25);
      expect(api.authorizations.single['serverId'], 'alpha');
      expect(result, isNotNull);
      expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final mode in [
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
    testWidgets('Frozen plain server choice keeps old cards $mode', (t) async {
      await _field(t, look: mode.$1, dark: mode.$2);
      expect(find.byKey(_select), findsNothing);
      expect(find.byType(RaftRadioGroup<String>), findsOneWidget);
      expect(find.byType(RaftCard), findsNWidgets(2));
    });
  }
}
