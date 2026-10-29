import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/archived_channels_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/screens/screen_fixture.dart';

Map<String, dynamic> _channel(
  String id,
  String name, {
  String type = 'channel',
  String? archivedAt,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'serverId': 's',
  'joined': true,
  'archivedAt': ?archivedAt,
};

class _Fixture {
  _Fixture({String role = 'owner', this.locale = const Locale('en')}) {
    client = ScreenFixtureClient(
      (method, path, query) {
        requests.add('$method $path');
        if (failUnarchive && path.endsWith('/unarchive')) {
          throw RaftApiException.response(
            'Channel name is taken',
            status: 409,
            body: {'error': 'Channel name is taken'},
          );
        }
        if (method == 'POST' && path.endsWith('/unarchive')) {
          return hold?.future ?? <String, dynamic>{};
        }
        if (method == 'GET' && path == '/channels') return after ?? rows;
        if (path == '/channels/dm') return <dynamic>[];
        return <String, dynamic>{};
      },
      user: {'id': 'alice', 'preferredTimezone': 'UTC'},
      server: 's',
    );
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's', 'name': 'S', 'slug': 's', 'role': role});
    w.channels = [for (final r in rows) RaftChannel(r)];
    addTearDown(w.dispose);
  }
  final Locale locale;
  late final ScreenFixtureClient client;
  late final WorkspaceController w;
  final requests = <String>[];
  bool failUnarchive = false;
  Completer<Object?>? hold;
  List<Map<String, dynamic>>? after;
  final rows = [
    _channel('general', 'general'),
    _channel('old', 'launch-retro', archivedAt: '2026-06-10T09:00:00.000Z'),
    _channel(
      'priv',
      'design-private',
      type: 'private',
      archivedAt: '2026-06-02T15:30:00.000Z',
    ),
    _channel(
      'joint',
      'partner-sync',
      type: 'joint',
      archivedAt: '2026-05-21T11:15:00.000Z',
    ),
    _channel('dm', 'dm-x', type: 'dm', archivedAt: '2026-06-11T09:00:00.000Z'),
  ];

  Future<void> mount(WidgetTester t, {double width = 1000}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArchivedChannelsSection(controller: w),
          ),
        ),
      ),
    );
  }
}

RaftSettingsSectionHeader? _header(WidgetTester t) {
  final found = find.byType(RaftSettingsSectionHeader);
  return found.evaluate().isEmpty
      ? null
      : t.widget<RaftSettingsSectionHeader>(found);
}

void main() {
  testWidgets('lists archived channels newest first without direct messages', (
    t,
  ) async {
    final f = _Fixture();
    await f.mount(t);
    expect(_header(t)?.label, 'Archived channels');
    expect(_header(t)?.count, 3);
    final names = [
      for (final id in ['old', 'priv', 'joint'])
        t.getTopLeft(find.byKey(ValueKey('archived-channel-row-$id'))).dy,
    ];
    expect(names, orderedEquals([...names]..sort()));
    expect(find.text('#launch-retro'), findsOneWidget);
    expect(find.text('#design-private'), findsOneWidget);
    expect(find.text('#partner-sync'), findsOneWidget);
    expect(find.text('#dm-x'), findsNothing);
    expect(find.text('#general'), findsNothing);
    expect(find.textContaining('Public channel · Archived Jun 10, 2026'), findsOneWidget);
    expect(find.textContaining('Private channel · Archived Jun 2, 2026'), findsOneWidget);
    expect(find.textContaining('Joint channel · Archived May 21, 2026'), findsOneWidget);
  });

  testWidgets('hidden without the capability, while loading, or when nothing is archived', (
    t,
  ) async {
    var f = _Fixture(role: 'member');
    await f.mount(t);
    expect(_header(t), isNull);

    f = _Fixture();
    f.w.loading = true;
    await f.mount(t);
    expect(_header(t), isNull);

    f = _Fixture();
    f.w.channels = [RaftChannel(f.rows.first)];
    await f.mount(t);
    expect(_header(t), isNull);
  });

  testWidgets('Unarchive restores the channel and the row leaves the list', (
    t,
  ) async {
    final f = _Fixture();
    f.after = [
      for (final r in f.rows)
        if (r['id'] != 'priv')
          r
        else
          {...r}..remove('archivedAt'),
    ];
    await f.mount(t);
    await t.tap(find.byKey(const ValueKey('archived-channel-unarchive-priv')));
    await t.pumpAndSettle();
    expect(f.requests, contains('POST /channels/priv/unarchive'));
    expect(f.requests.where((r) => r == 'GET /channels'), isNotEmpty);
    expect(find.text('#design-private'), findsNothing);
    expect(find.text('#launch-retro'), findsOneWidget);
    expect(_header(t)?.count, 2);
  });

  testWidgets('a failed Unarchive shows the server message and keeps the row', (
    t,
  ) async {
    final f = _Fixture()..failUnarchive = true;
    await f.mount(t);
    await t.tap(find.byKey(const ValueKey('archived-channel-unarchive-old')));
    await t.pumpAndSettle();
    expect(find.text('Channel name is taken'), findsOneWidget);
    expect(find.text('#launch-retro'), findsOneWidget);
    // The buttons are usable again.
    expect(
      t
          .widget<RaftSettingsRecipeButton>(
            find.byKey(const ValueKey('archived-channel-unarchive-old')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('every Unarchive is disabled while one request is in flight', (
    t,
  ) async {
    final f = _Fixture()..hold = Completer<Object?>();
    await f.mount(t);
    await t.tap(find.byKey(const ValueKey('archived-channel-unarchive-old')));
    await t.pump();
    for (final id in ['old', 'priv', 'joint']) {
      expect(
        t
            .widget<RaftSettingsRecipeButton>(
              find.byKey(ValueKey('archived-channel-unarchive-$id')),
            )
            .onPressed,
        isNull,
      );
    }
    expect(find.text('Unarchiving…'), findsOneWidget);
    f.hold!.complete(<String, dynamic>{});
    await t.pumpAndSettle();
  });

  testWidgets('opening a row selects that channel', (t) async {
    final f = _Fixture();
    await f.mount(t);
    await t.tap(find.text('#partner-sync'));
    await t.pump();
    expect(f.w.channel?.id, 'joint');
    expect(f.w.section, 'chat');
  });

  testWidgets('narrow screens stack a full-width button, Chinese uses the Web catalog', (
    t,
  ) async {
    final f = _Fixture(locale: const Locale('zh', 'CN'));
    await f.mount(t, width: 390);
    expect(_header(t)?.label, 'Archived channels');
    expect(find.textContaining('已归档频道', findRichText: true), findsOneWidget);
    expect(find.textContaining('公开频道 · 归档于'), findsOneWidget);
    final row = t.getRect(find.byKey(const ValueKey('archived-channel-row-old')));
    final button = t.getRect(
      find.byKey(const ValueKey('archived-channel-unarchive-old')),
    );
    expect(button.width, greaterThan(row.width - 40));
  });
}
