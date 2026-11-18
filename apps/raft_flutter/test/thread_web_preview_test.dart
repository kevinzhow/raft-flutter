import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/fake_webview.dart';
import 'thread_overlay_history_test.dart'
    show
        frames,
        message,
        openThreadFromBadge,
        overlayFixture,
        taskRow,
        threadTimeline;

void main() {
  testWidgets(
    'a thread link opens beside its channel and preserves the thread',
    (t) async {
      const url = 'https://docs.example.com/thread';
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      final browser = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(launcher, (
        call,
      ) async {
        if (call.method == 'launch') {
          browser.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launcher,
          null,
        ),
      );
      WebViewPlatform.instance = FakeWebView();
      FakeWebView.reset();
      final f = await overlayFixture(
        t,
        width: 1680,
        task: taskRow('task-parent'),
      );
      f.client.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': ChannelSideFlags.webPreviewKey, 'enabled': true},
        ],
      };
      final store = WebPreviewStore.of(f.w);
      store.platform = const WebPreviewPlatform(operatingSystem: 'macos');
      ChannelSideFlags.of(f.w).reevaluate();
      DevicePreferences.adopt(await SharedPreferences.getInstance());
      addTearDown(DevicePreferences.reset);
      WebLinkOpenPreferences.instance.write(WebLinkOpenPreference.beside);
      expect(
        WebLinkOpenPreferences.instance.value,
        WebLinkOpenPreference.beside,
      );
      f.client.routes['GET /messages/channel/t1'] = (_) => {
        'messages': [
          {...message('r1', 't1', 1), 'content': '[Thread guide]($url)'},
        ],
      };
      try {
        await openThreadFromBadge(t, f);
        expect(webPreviewAvailable(f.w), isTrue);
        expect(f.w.messageDomain.presentation.mainPresented, isTrue);
        expect(f.w.threadChannelId, 't1');
        final thread = threadTimeline();
        final link = find.descendant(
          of: thread,
          matching: find.text('Thread guide', findRichText: true),
        );
        expect(link.hitTestable(), findsOneWidget);
        final paragraph = t.renderObject<RenderParagraph>(link);
        final glyphs = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 12),
        );
        await t.tapAt(
          paragraph.localToGlobal(glyphs.first.toRect().center),
          kind: PointerDeviceKind.mouse,
        );
        await frames(t);
        final panel = find.byKey(const ValueKey('web-preview'));
        expect(
          panel.hitTestable(),
          findsOneWidget,
          reason: 'browser: $browser, preview: ${store.page?.url}',
        );
        expect(FakeWebView.loads, [url]);
        expect(browser, isEmpty);
        expect(store.page?.conversationId, 'c1');
        expect(f.w.location.thread?.itemId, 'p1');
        expect(thread, findsOneWidget);
        await t.tap(find.byKey(const ValueKey('web-preview-close')));
        await frames(t);
        expect(panel, findsNothing);
        expect(link.hitTestable(), findsOneWidget);
        expect(f.w.location.thread?.itemId, 'p1');
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await frames(t);
      }
    },
  );
}
