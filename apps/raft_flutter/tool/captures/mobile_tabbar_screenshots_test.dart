// Run from apps/raft_flutter with RAFT_TABBAR_EVIDENCE_DIR set:
//   ../../tool/flutter test tool/captures/mobile_tabbar_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/testing/system_fonts.dart';

import '../../../../packages/raft_ui/test/task_typography_test.dart'
    show loadTaskFonts;
import '../../test/app_global_server_selector_test.dart' show RootFixture;
import '../../test/support/server_tab.dart';

/// Evidence renders of the real app (zh or en, 390 wide, light and dark): written only when
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

Future<void> capture(WidgetTester t, String name) async {
  // The outermost full-screen boundary, so overlays (the server popover) are in.
  RenderObject? object = t
      .element(find.byKey(const Key('workspace-mobile-navigation')))
      .findRenderObject();
  RenderRepaintBoundary? screen;
  for (; object != null; object = object.parent) {
    if (object is RenderRepaintBoundary &&
        object.hasSize &&
        object.size.height >= 800) {
      screen = object;
    }
  }
  expect(screen, isNotNull);
  await t.runAsync(() async {
    final image = await screen!.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final theme in ['light', 'dark']) {
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
      // RAFT_TABBAR_LOCALE=en matches the Web reference captures (English).
      final locale = Platform.environment['RAFT_TABBAR_LOCALE'] == 'en'
          ? const Locale('en', 'US')
          : const Locale('zh', 'CN');
      t.platformDispatcher.localesTestValue = [locale];
      t.platformDispatcher.localeTestValue = locale;
      addTearDown(t.platformDispatcher.clearAllTestValues);

      Future<RootFixture> mount({
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
        await f.mount(t, theme, 390, uri: Uri.parse(path));
        // Web reference: 390x844 viewport, no safe-area insets.
        t.view.padding = FakeViewPadding.zero;
        t.view.physicalSize = const Size(390, 844);
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
      // Wired bar (Web v1.24): Home, Activity, Tasks, Search + the server tab.
      var f = await mount();
      await capture(t, '$theme-01-bar-home');
      await tap(f, 'activity');
      await capture(t, '$theme-02-activity-root');
      await tap(f, 'search');
      await capture(t, '$theme-03-search-root');
      await tap(f, 'tasks');
      await capture(t, '$theme-05-tasks-root');
      // Home band open state: the WorkspaceButton's server switcher.
      await tap(f, 'home');
      await t.tap(find.byKey(const Key('mobile-server-selector')));
      await f.flush(t);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await capture(t, '$theme-06-home-switcher-open');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await openServerPopover(t, flush: f.flush);
      await capture(t, '$theme-04-server-popover');
      await f.close(t);
    });
  }
}
