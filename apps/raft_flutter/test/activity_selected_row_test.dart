import 'dart:async';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/app_services_fixture.dart';

// Persistent selected state of the desktop Activity master list, driven
// through the mounted WorkspaceView: the row whose item is open in the
// preview is marked, and it follows the location only.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  Map<String, dynamic> row(
    String id,
    String name, {
    int unread = 0,
    String? preview,
  }) => {
    'kind': 'channel',
    'channelId': id,
    'channelName': name,
    'lastMessagePreview': preview ?? 'Preview $name',
    'unreadCount': unread,
    'firstUnreadMessageId': unread > 0 ? 'first-$id' : null,
    'lastMessageId': 'last-$id',
  };
  late List<Map<String, dynamic>> inbox = [
    row('c', 'design', unread: 1),
    row('c2', 'random'),
  ];
  final channelRows = [
    RaftChannel({
      'id': 'c',
      'serverId': 's',
      'name': 'design',
      'type': 'channel',
      'joined': true,
    }),
    RaftChannel({
      'id': 'c2',
      'serverId': 's',
      'name': 'random',
      'type': 'channel',
      'joined': true,
    }),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'slug': 'fixture', 'name': 'Fixture'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {
      'messages': [message('$id-tail', id, 1)],
      'threadSummariesByParentMessageId': {},
    };
  }

  Map<String, dynamic> message(String id, String channel, int seq) => {
    'id': id,
    'channelId': channel,
    'serverId': 's',
    'seq': '$seq',
    'content': 'Public $id',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/messages/search') {
      return {
        'results': [
          {
            ...message('hit', 'c', 1),
            'content': 'Selected public hit',
            'channelName': 'design',
            'senderName': 'Public sender',
          },
          {
            ...message('hit2', 'c2', 1),
            'content': 'Other public hit',
            'channelName': 'random',
            'senderName': 'Public sender',
          },
        ],
        'hasMore': false,
      };
    }
    if (path == '/channels/inbox') {
      return {
        'items': [for (final row in inbox) Map<String, dynamic>.of(row)],
      };
    }
    for (final row in channelRows) {
      if (path == '/channels/${row.id}') return row.json;
    }
    if (path.startsWith('/messages/context/')) {
      final id = path.split('/').last;
      return {
        'messages': [message(id, '${query?['channelId'] ?? 'c'}', 1)],
      };
    }
    if (path == '/channels/threads/followed') return {'threads': []};
    if (path == '/channels/unread') return {'channels': {}};
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '1', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

Future<(WorkspaceController, _Client)> _mount(
  WidgetTester t,
  RaftFamily family,
  bool dark, {
  Locale? locale,
  GlobalKey? capture,
  void Function(_Client)? seed,
}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final client = _Client()..selectServer('s');
  seed?.call(client);
  final w = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 's',
      'slug': 'fixture',
      'name': 'Fixture',
      'role': 'owner',
    })
    ..channels = client.channelRows
    ..channel = client.channelRows.first
    ..section = 'chat';
  w.messageDomain.ledger.switchServer('s');
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  final workspace = withAppServices(
    WorkspaceView(
      controller: w,
      appearance: RaftAppearance(
        mode: dark ? ThemeMode.dark : ThemeMode.light,
        light: family,
      ),
      onAppearance: (_) async {},
      onLogout: () async {},
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(family, dark: dark).copyWith(
        // Hover-revealed row actions: a desktop pointer, not touch density.
        platform: capture == null ? null : TargetPlatform.linux,
      ),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: capture == null
          ? workspace
          : RepaintBoundary(key: capture, child: workspace),
    ),
  );
  await t.pumpAndSettle();
  return (w, client);
}

Future<void> _rail(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('rail-$id')));
  await t.pumpAndSettle();
}

/// Keys of every Activity row currently painted as selected.
List<String> _selected(WidgetTester t) => [
  for (final card in t.widgetList<RaftConversationCard>(
    find.byType(RaftConversationCard),
  ))
    if (card.selected) (card.key! as ValueKey<String>).value,
];

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ])) {
    testWidgets(
      'desktop Activity selected row follows the open preview $family/$dark',
      (t) async {
        final (w, client) = await _mount(t, family, dark);
        w.setForeground(true);
        await _rail(t, 'activity');
        Finder row(String id) => find.byKey(ValueKey('activity-channel-$id'));
        // Full-width list, nothing open: nothing is selected.
        expect(w.location.content, isNull);
        expect(_selected(t), isEmpty);

        // First click highlights that row and no other, in the same frame
        // the preview opens.
        await t.tap(row('c'));
        expect(w.location.content?.id, 'c');
        await t.pump();
        expect(_selected(t), ['activity-channel-c']);
        await t.pumpAndSettle();
        expect(_selected(t), ['activity-channel-c']);

        // Selecting another row moves the highlight.
        await t.pump(const Duration(seconds: 1));
        await t.tap(row('c2'));
        await t.pump();
        expect(_selected(t), ['activity-channel-c2']);
        await t.pumpAndSettle();
        expect(_selected(t), ['activity-channel-c2']);

        // A refresh that reorders the list and adds an item keeps the
        // highlight on the same item id.
        final before = [t.getTopLeft(row('c')).dy, t.getTopLeft(row('c2')).dy];
        expect(before[0], lessThan(before[1]));
        client.inbox = [
          client.row('c3', 'newcomer', unread: 1),
          client.row('c2', 'random'),
          client.row('c', 'design'),
        ];
        client.stream.add(
          RaftEvent('message:new', client.message('live-1', 'c3', 2)),
        );
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpAndSettle();
        expect(row('c3'), findsOneWidget);
        expect(
          t.getTopLeft(row('c')).dy,
          greaterThan(t.getTopLeft(row('c2')).dy),
        );
        expect(_selected(t), ['activity-channel-c2']);

        // Closing the preview clears it.
        await t.tap(find.byTooltip('Close detail'));
        await t.pumpAndSettle();
        expect(w.location.content, isNull);
        expect(_selected(t), isEmpty);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'final desktop Activity screenshot $family/$dark',
      skip: Platform.environment['ACTIVITY_SELECTED_OUT'] == null,
      (t) async {
        await t.runAsync(loadParityFonts);
        final capture = GlobalKey();
        final (w, client) = await _mount(
          t,
          family,
          dark,
          locale: const Locale('zh'),
          capture: capture,
          seed: (c) {
            for (final (i, name) in ['产品设计', '工程'].indexed) {
              c.channelRows[i] = RaftChannel({
                'id': c.channelRows[i].id,
                'serverId': 's',
                'name': name,
                'type': 'channel',
                'joined': true,
              });
            }
            c.inbox = [
              c.row('c', '产品设计', unread: 2, preview: 'Alice: 新的评审清单已经更新到文档里了'),
              c.row('c2', '工程', preview: 'Bob: 桌面端的列表滚动问题已经修好了'),
              c.row('c3', '运营', preview: 'Dana: 十月增长数据复盘，留存曲线比上个月好了不少'),
              c.row('c4', '设计', unread: 1, preview: 'Fiona: 图标库已经整理完，合并了重复的图标'),
              c.row('c5', '市场', preview: 'Evan: 下周发布会的物料清单确认了'),
            ];
          },
        );
        w.setForeground(true);
        await _rail(t, 'activity');
        await t.tap(find.byKey(const ValueKey('activity-channel-c2')));
        await t.pumpAndSettle();
        expect(_selected(t), ['activity-channel-c2']);
        await t.runAsync(() async {
          final render =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final theme = dark
              ? 'elegant-dark'
              : family == RaftFamily.brutal
              ? 'brutal-light'
              : 'elegant-light';
          final file = File(
            '${Platform.environment['ACTIVITY_SELECTED_OUT']}/final-$theme.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
        });
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
