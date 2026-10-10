import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/page_alignment_fixtures.dart';
import 'package:raft_flutter/features/resource_cards.dart';
import 'package:raft_flutter/features/resource_view.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final mutations = <String>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    mutations.add('$method $path');
    return {};
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> directoryAgents = [];
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (server?.string('role') == 'guest') {
      return {'tasks': [], 'saved': [], 'items': [], 'hasMore': false};
    }
    if (path == '/tasks/server') {
      return {
        'tasks': (pageTasksFixture['tasks'] as List)
            .where(
              (row) =>
                  query?['status'] == null || query?['status'] == row['status'],
            )
            .toList(),
        'next_cursor': null,
      };
    }
    if (path == '/channels/saved') {
      return {...pageSavedFixture, 'hasMore': false};
    }
    if (path == '/channels/inbox') return pageActivityFixture;
    if (path.endsWith('/members')) {
      return [
        {'userId': 'visual-user', 'displayName': 'artin'},
      ];
    }
    if (path == '/agents') return directoryAgents;
    return {};
  }
}

void main() {
  late _Client client;
  late _Workspace w;
  setUp(() {
    client = _Client()
      ..user = RaftRecord({'id': 'visual-user', 'displayName': 'artin'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'channel-design', 'name': 'design', 'joined': true}),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });
  Future<void> mount(
    WidgetTester t,
    String section,
    Size size, {
    bool dark = false,
    Future<void> Function(String, String?)? onMessage,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant, dark: dark),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: section,
            onMessage: onMessage ?? (_, _) async {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'desktop starts on Board and terminal groups remain reachable without revealing cards',
    (t) async {
      await mount(t, 'tasks', const Size(1200, 800));
      final dynamic state = t.state(find.byType(ResourceView));
      expect(state.taskLayout, 'board');
      expect(find.text('Publish the visual parity report'), findsNothing);
      expect(find.byKey(const ValueKey('task-group-done')), findsOneWidget);
      final horizontal = find.byType(SingleChildScrollView).first;
      await t.drag(horizontal, const Offset(-650, 0));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('task-group-done')));
      await t.tap(find.byKey(const ValueKey('task-group-done')));
      await t.pumpAndSettle();
      expect(find.text('Publish the visual parity report'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'phone starts grouped List with source metadata and no overflow',
    (t) async {
      await mount(t, 'tasks', const Size(390, 844));
      final dynamic state = t.state(find.byType(ResourceView));
      expect(state.taskLayout, 'list');
      expect(find.text('Publish the visual parity report'), findsNothing);
      expect(
        find.text('Align the tabbar capture crops between React and Android'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Saved resolves current directory names and pixel avatars inside source mini frames',
    (t) async {
      final savedAgent = (pageSavedFixture['saved'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((row) => row['senderType'] == 'agent');
      w.directoryAgents = [
        {
          'id': savedAgent['senderId'],
          'name': 'current-agent',
          'displayName': 'Current Agent',
          'avatarUrl': 'pixel:robot',
        },
      ];
      await mount(t, 'saved', const Size(390, 844));
      final card = find.byKey(ValueKey('saved-${savedAgent['messageId']}'));
      expect(
        find.descendant(of: card, matching: find.text('Current Agent')),
        findsOneWidget,
      );
      final avatar = find.descendant(
        of: card,
        matching: find.byType(RaftAvatarSlot),
      );
      expect(t.getSize(avatar), const Size(14, 14));
      final pixels = find.descendant(
        of: avatar,
        matching: find.byType(RaftPixelAvatar),
      );
      expect(t.widget<RaftPixelAvatar>(pixels).avatarKey, 'robot');
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(card, findsNothing);
      expect(find.byType(RaftPixelAvatar), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Saved paints readable dark cards and removing a save does not navigate',
    (t) async {
      var navigated = false;
      await mount(
        t,
        'saved',
        const Size(342, 620),
        dark: true,
        onMessage: (_, _) async {
          navigated = true;
        },
      );
      final body = find.text(
        'Captured the Android visual artifact for #product:f8e569cb and queued React parity.',
      );
      final ink = t.widget<Text>(body).style!.color!;
      final card = t.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('saved-msg-saved-visual-1')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        ink.computeLuminance(),
        greaterThan(card.color!.computeLuminance() + .3),
      );
      expect(find.text('5 saved items'), findsOneWidget);
      await t.tap(find.byType(RaftSavedToggle).first);
      await t.pumpAndSettle();
      expect(client.mutations, ['DELETE /channels/saved/msg-saved-visual-1']);
      expect(navigated, false);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Activity wraps title after an inline source icon without indenting continuation',
    (t) async {
      await mount(t, 'activity', const Size(342, 620));
      expect(find.byTooltip('Filters'), findsNothing);
      final card = find.byKey(
        const ValueKey('activity-thread-thread-msg-agent-reply'),
      );
      final icon = find.descendant(
        of: card,
        matching: find.byType(RaftThreadIcon),
      );
      expect(t.getSize(icon), const Size(13, 13));
      expect(find.byType(RaftDirectMessageIcon), findsOneWidget);
      final title = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.textSpan?.toPlainText().contains(
                    'Captured the Android visual artifact',
                  ) ??
                  false),
        ),
      );
      final rich = find.descendant(of: title, matching: find.byType(RichText));
      final paragraph = t.renderObject<RenderParagraph>(rich);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: 1,
          extentOffset: paragraph.text.toPlainText().length,
        ),
      );
      final lineTops = boxes.map((box) => box.top).toSet().toList()..sort();
      expect(lineTops, hasLength(2));
      expect(boxes.first.left, 19);
      expect(
        boxes.firstWhere((box) => box.top == lineTops.last).left,
        0,
        reason: 'The second line uses the whole title column.',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Activity prefers authoritative unread/mention destination and old card cannot navigate after revocation',
    (t) async {
      final calls = <String>[];
      await mount(
        t,
        'activity',
        const Size(390, 844),
        onMessage: (c, m) async {
          calls.add('$c:$m');
        },
      );
      final finder = find.byKey(
        const ValueKey('activity-thread-thread-msg-agent-reply'),
      );
      final retired = t.widget<RaftConversationCard>(finder).onOpen;
      await t.tap(finder);
      await t.pumpAndSettle();
      expect(calls, ['channel-design:msg-visual-activity-reply']);
      // Source markRead: the opened row's 2 unread leave the header total.
      expect(find.text('3 active · 1 unread'), findsOneWidget);
      w.server = RaftRecord({'id': 's', 'role': 'guest'});
      w.notifyListeners();
      await t.pumpAndSettle();
      retired();
      await t.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(finder, findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'retained Board status mutation cannot affect a changed role or channel membership',
    (t) async {
      await mount(t, 'tasks', const Size(1200, 800));
      final card = t.widget<RaftTaskCard>(
        find.byKey(const ValueKey('task-msg-task-visual-214')),
      );
      final mutate = card.onStatus!;
      w.channels = [];
      w.notifyListeners();
      await t.pumpAndSettle();
      mutate('in_progress');
      await t.pumpAndSettle();
      expect(client.mutations, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  test('relative-time unit boundaries match source Math.round and numeric:auto words', () {
    final now = DateTime.utc(2026, 6, 22, 3);
    expect(
      resourceRelativeTime('2026-06-22T02:30:00Z', now: now),
      '30 minutes ago',
    );
    expect(resourceRelativeTime('2026-06-21T03:00:00Z', now: now), 'yesterday');
    expect(
      resourceRelativeTime('2026-06-22T03:00:00Z', now: now),
      'this minute',
    );
    expect(resourceRelativeTime('invalid', now: now), '');
    expect(
      resourceRelativeTime('2026-06-22T02:30:00Z', now: now, chinese: true),
      '30 分钟前',
    );
  });
}
