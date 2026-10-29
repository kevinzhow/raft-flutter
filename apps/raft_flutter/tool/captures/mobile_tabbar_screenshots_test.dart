// Run from apps/raft_flutter with RAFT_TABBAR_EVIDENCE_DIR set:
//   ../../tool/flutter test tool/captures/mobile_tabbar_screenshots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/testing/system_fonts.dart';

import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';

import '../../../../packages/raft_ui/test/task_typography_test.dart'
    show loadTaskFonts;
import '../../test/app_global_server_selector_test.dart' show RootFixture;

/// Evidence renders of the real app (zh, 390x844): written only when
/// RAFT_TABBAR_EVIDENCE_DIR is set, otherwise a no-op.
final evidence = Platform.environment['RAFT_TABBAR_EVIDENCE_DIR'];

Map<String, dynamic> row(String kind, int i, {int unread = 2}) => {
  'kind': kind,
  if (kind == 'thread') ...{
    'threadChannelId': 'thread-$i',
    'parentChannelId': 'ca',
    'parentChannelName': 'general-a',
    'parentMessageId': 'parent$i',
    'parentMessagePreview': '这周的发布计划确认了吗？',
    'latestActivityMessageId': 'm$i',
    'latestActivityPreview': '确认了，周四上线，今晚冻结代码。',
    'latestActivitySenderType': 'user',
    'latestActivitySenderId': 'bob',
    'latestActivitySenderName': 'Bob',
    'lastActivityAt': '2026-10-10T01:00:00Z',
    'replyCount': 3,
    'isFollowing': true,
  } else ...{
    'channelId': kind == 'dm' ? 'dm$i' : 'ca',
    'channelName': kind == 'dm' ? 'Bob' : 'general-a',
    'lastMessageId': 'm$i',
    'lastMessagePreview': kind == 'dm' ? '你有空看一下设计稿吗？' : '新版本已经部署到预发环境。',
    'lastMessageSenderType': 'user',
    'lastMessageSenderId': 'bob',
    'lastMessageSenderName': 'Bob',
    'lastMessageAt': '2026-10-10T01:00:00Z',
  },
  'latestActivitySeq': '$i',
  'readState': {
    'kind': 'present',
    'maxReadSeq': '0',
    'readStateVersion': 1,
    'latestActivity': {'messageId': 'm$i', 'seq': '$i'},
  },
  'unreadCount': unread,
  'firstUnreadMessageId': unread > 0 ? 'first' : null,
  'hasMention': false,
};

const computer = <String, dynamic>{
  'id': 'computer-a',
  'name': 'Build Computer',
  'description': '共享开发机',
  'isComputer': true,
  'status': 'online',
  'computerVersion': '1.0.44',
  'computerUpgradeAvailable': true,
  'hostname': 'fixture-host',
  'userId': 'alice',
  'runtimes': ['codex'],
};

final fullBar = jsonEncode({
  'order': ['chat', 'tasks', 'activity', 'computers', 'members'],
  'enabled': ['chat', 'tasks', 'activity', 'computers'],
});
const activityBar = '["chat","tasks","activity"]';

Future<void> capture(WidgetTester t, String name) async {
  RenderObject? object = t
      .element(find.byKey(const Key('workspace-mobile-navigation')))
      .findRenderObject();
  while (object != null &&
      !(object is RenderRepaintBoundary &&
          object.hasSize &&
          object.size.height >= 800)) {
    object = object.parent;
  }
  expect(object, isA<RenderRepaintBoundary>());
  await t.runAsync(() async {
    final image = await (object! as RenderRepaintBoundary).toImage(
      pixelRatio: 2,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final theme in ['brutal', 'elegant-light']) {
    testWidgets('$theme tab bar evidence', (t) async {
      final missingFonts = missingTestFontReason(cjkTestFonts());
      if (missingFonts != null) {
        markTestSkipped(missingFonts);
        return;
      }

      await loadTaskFonts(t);
      await t.runAsync(() async {
        // Android's production theme uses the native generic family
        // ('sans-serif'); the test engine has no OS font manager, so register
        // the system Noto Sans CJK faces (Latin + Han) as that family.
        for (final face in ['Regular', 'Bold']) {
          final file = systemTestFont('opentype/noto/NotoSansCJK-$face.ttc');
          await (FontLoader('sans-serif')..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              ))
              .load();
        }
        for (final (alias, asset) in [
          ('monospace', 'packages/raft_ui/assets/fonts/GeistMono.ttf'),
          ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
        ]) {
          await (FontLoader(alias)..addFont(rootBundle.load(asset))).load();
        }
      });
      t.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
      t.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
      addTearDown(t.platformDispatcher.clearAllTestValues);

      Future<RootFixture> mount(
        String bar, {
        int unread = 2,
        String path = '/s/alpha',
      }) async {
        final f = RootFixture();
        f.overrides['GET /servers/a/machines'] = (_) => {
          'machines': [computer],
          'latestComputerVersion': '1.0.45',
        };
        f.overrides['GET /channels/inbox'] = (_) => {
          'items': [
            row('channel', 5, unread: unread),
            row('thread', 6),
            row('dm', 7, unread: 0),
          ],
          'totalCount': 3,
          'totalUnreadCount': unread,
          'hasMore': false,
        };
        await f.mount(
          t,
          theme,
          390,
          uri: Uri.parse(path),
          preferences: {MobileTabbarStore.preferenceKey: bar},
        );
        t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
        addTearDown(t.view.resetPadding);
        await t.pump(const Duration(seconds: 3));
        await f.flush(t);
        return f;
      }

      Future<void> tap(RootFixture f, String id) async {
        await t.tap(find.byKey(Key('mobile-tab-$id')));
        await f.flush(t);
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      if (evidence == null) return;
      // Wired bar: Home, Tasks, Activity, Computers, Settings.
      var f = await mount(fullBar);
      await capture(t, '$theme-01-bar-home');
      await tap(f, 'activity');
      await capture(t, '$theme-02-activity-root');
      await tap(f, 'computers');
      await capture(t, '$theme-03-computers-root');
      await f.close(t);

      // Badge / Home entry design for Kevin.
      f = await mount(activityBar, unread: 3);
      await capture(t, '$theme-10-home-activity-in-bar-badge-3');
      await tap(f, 'activity');
      await capture(t, '$theme-12-activity-selected-badge-3');
      await f.close(t);
      f = await mount(activityBar, unread: 120);
      await capture(t, '$theme-11-home-activity-in-bar-badge-120');
      await f.close(t);
      f = await mount('["chat","tasks","members"]', unread: 3);
      await capture(t, '$theme-13-home-default-bar-activity-entry');
      await f.close(t);
    });
  }
}
