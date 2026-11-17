import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/appearance_section.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_card_read.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'message_presentation_test.dart' show host;
import 'support/fake_webview.dart';
import 'support/web_preview_fixture.dart';

/// Web v1.24 web links: an action card button `open: "beside"`
/// (MessageCardBody), a plain web link in a message (MessageWebLink,
/// webLinkOpenPreference, WebLinkChoiceDialog) and Settings › Appearance ›
/// How web links open (HowWebLinksOpenSetting).
class _Storage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

Map<String, dynamic> _button(String url, {String? open, String label = 'Go'}) =>
    {
      'type': 'Button',
      'props': {
        'label': label,
        'action': {'kind': 'navigate', 'url': url},
        'open': ?open,
      },
    };

Map<String, dynamic> _card(Map<String, Map<String, dynamic>> buttons) => {
  'kind': 'message-card',
  'revision': 1,
  'updatedAt': '2026-11-01T09:00:00.000Z',
  'card': {
    'version': 1,
    'root': 'root',
    'elements': {
      'root': {
        'type': 'Stack',
        'props': {'direction': 'row'},
        'children': buttons.keys.toList(),
      },
      ...buttons,
    },
  },
};

const _review = 'https://deploy.example.com/runs/1';
const _docs = 'https://docs.example.com/deploy';

void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(() {
    FakeWebView.reset();
    WebLinkOpenPreferences.instance.write(null);
  });

  test('the reader keeps open: "beside" on the button', () {
    final read = readMessageCard(
      _card({
        'a': _button(_review, open: 'beside'),
        'b': _button(_docs, open: 'tab'),
        'c': _button('https://docs.example.com/other'),
      }),
    )!;
    expect(raftCardButtons(read.root).map((b) => b.beside), [
      true,
      false,
      false,
    ]);
  });

  group('a card button that opens beside', () {
    Future<(WorkspaceController, List<String>)> mount(
      WidgetTester t, {
      bool flag = true,
      String os = 'android',
      String channelId = 'c1',
      String url = _review,
    }) async {
      final (w, _) = (await t.runAsync(
        () => webPreviewFixture(flag: flag, os: os),
      ))!;
      addTearDown(w.dispose);
      final external = <String>[];
      await t.pumpWidget(
        host(
          MessagePresentation(
            controller: w,
            onExternalLink: external.add,
            message: RaftMessage({
              'id': 'm1',
              'channelId': channelId,
              'senderType': 'agent',
              'content': 'Fallback',
              'actionMetadata': _card({
                'review': _button(url, open: 'beside', label: 'Review'),
                'docs': _button(_docs, label: 'Docs'),
              }),
            }),
          ),
        ),
      );
      await t.pump();
      return (w, external);
    }

    final panelIcon = find.byWidgetPredicate(
      (w) => w is RaftIcon && w.glyph == RaftGlyph.panelRight,
    );

    testWidgets('opens the page in the side area, not the browser', (t) async {
      final (w, external) = await mount(t);
      expect(panelIcon, findsOneWidget, reason: 'the beside button\'s mark');
      await t.tap(find.text('Review'));
      await t.pump();
      expect(
        WebPreviewStore.of(w).page,
        const WebPreviewPage(url: _review, conversationId: 'c1'),
      );
      expect(external, isEmpty);
    });

    testWidgets('is announced as opening beside the conversation', (t) async {
      final semantics = t.ensureSemantics();
      await mount(t);
      expect(
        find.bySemanticsLabel(
          'Review · deploy.example.com, opens beside the conversation',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets(
      'a button that does not say beside opens the browser as before',
      (t) async {
        final (w, external) = await mount(t);
        await t.tap(find.text('Docs'));
        await t.pump();
        expect(external, [_docs]);
        expect(WebPreviewStore.of(w).page, isNull);
        expect(
          find.byKey(const ValueKey('web-link-choice-dialog')),
          findsNothing,
          reason:
              'the web-link choice is about links in text, not card buttons',
        );
      },
    );

    for (final (why, flag, os, channel) in [
      ('web preview off', false, 'android', 'c1'),
      ('Linux has no WebView', true, 'linux', 'c1'),
      ('Windows has no WebView', true, 'windows', 'c1'),
    ]) {
      testWidgets('$why: the browser opens, with the ordinary arrow', (
        t,
      ) async {
        final (w, external) = await mount(
          t,
          flag: flag,
          os: os,
          channelId: channel,
        );
        expect(panelIcon, findsNothing, reason: why);
        await t.tap(find.text('Review'));
        await t.pump();
        expect(external, [_review], reason: why);
        expect(WebPreviewStore.of(w).page, isNull, reason: why);
      });
    }

    testWidgets('no channel on screen to open beside: the browser opens', (
      t,
    ) async {
      final (w, external) = await mount(t, channelId: 'c2');
      await t.tap(find.text('Review'));
      await t.pump();
      expect(external, [_review]);
      expect(WebPreviewStore.of(w).page, isNull);
    });

    testWidgets('a page Raft doesn\'t show falls back to the browser', (
      t,
    ) async {
      final (w, external) = await mount(
        t,
        url: 'https://app.raft.build/pricing',
      );
      await t.tap(find.text('Review'));
      await t.pump();
      expect(external, ['https://app.raft.build/pricing']);
      expect(WebPreviewStore.of(w).page, isNull);
    });
  });

  group('a web link in a message', () {
    late WorkspaceController w;
    late List<String> external;
    late MessagePresentation presentation;

    Future<void> mount(
      WidgetTester t, {
      bool flag = true,
      String os = 'android',
      String channelId = 'c1',
    }) async {
      _link = _news;
      w = (await t.runAsync(() => webPreviewFixture(flag: flag, os: os)))!.$1;
      addTearDown(w.dispose);
      external = [];
      presentation = MessagePresentation(
        controller: w,
        onExternalLink: external.add,
        message: RaftMessage({
          'id': 'm1',
          'channelId': channelId,
          'content': 'a link',
        }),
      );
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => presentation.open(context, _link),
                child: const Text('click'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> click(WidgetTester t, [String href = _news]) async {
      _link = href;
      await t.tap(find.text('click'));
      await t.pumpAndSettle();
    }

    final dialog = find.byKey(const ValueKey('web-link-choice-dialog'));

    testWidgets(
      'the first click asks; Open beside is remembered and opens it',
      (t) async {
        await mount(t);
        await click(t);
        expect(dialog, findsOneWidget);
        expect(find.text('Open links in Raft?'), findsOneWidget);
        expect(
          external,
          isEmpty,
          reason: 'nothing opens until the person chooses',
        );
        await t.tap(find.byKey(const ValueKey('web-link-choice-beside')));
        await t.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
          WebLinkOpenPreferences.instance.value,
          WebLinkOpenPreference.beside,
        );
        expect(WebPreviewStore.of(w).page?.url, _link);
        expect(external, isEmpty);
        // Remembered: the next click opens beside without asking.
        WebPreviewStore.of(w).close();
        await click(t);
        expect(dialog, findsNothing);
        expect(WebPreviewStore.of(w).page?.url, _link);
        expect(external, isEmpty);
      },
    );

    testWidgets('Use my browser is remembered and opens the browser', (
      t,
    ) async {
      await mount(t);
      await click(t);
      await t.tap(find.byKey(const ValueKey('web-link-choice-browser')));
      await t.pumpAndSettle();
      expect(
        WebLinkOpenPreferences.instance.value,
        WebLinkOpenPreference.browser,
      );
      expect(external, [_link]);
      expect(WebPreviewStore.of(w).page, isNull);
      await click(t);
      expect(dialog, findsNothing);
      expect(external, [_link, _link]);
    });

    testWidgets('dismissing opens the browser this time and asks again', (
      t,
    ) async {
      await mount(t);
      await click(t);
      expect(dialog, findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(external, [_link]);
      expect(WebLinkOpenPreferences.instance.value, isNull);
      expect(WebPreviewStore.of(w).page, isNull);
      await click(t);
      expect(dialog, findsOneWidget, reason: 'nothing was remembered');
    });

    testWidgets(
      'a plain http link asks too, then opens the browser (never shown)',
      (t) async {
        await mount(t);
        await click(t, 'http://insecure.example.com/');
        expect(dialog, findsOneWidget);
        await t.tap(find.byKey(const ValueKey('web-link-choice-beside')));
        await t.pumpAndSettle();
        expect(external, ['http://insecure.example.com/']);
        expect(WebPreviewStore.of(w).page, isNull);
      },
    );

    for (final (why, flag, os, channel, href) in [
      ('web preview off', false, 'android', 'c1', _news),
      ('Linux', true, 'linux', 'c1', _news),
      ('Windows', true, 'windows', 'c1', _news),
      ('no channel on screen', true, 'android', 'c2', _news),
      ('a Raft page', true, 'android', 'c1', 'https://app.raft.build/x'),
      ('mailto', true, 'android', 'c1', 'mailto:a@example.com'),
    ]) {
      testWidgets('$why: no question, the link opens as it always did', (
        t,
      ) async {
        await mount(t, flag: flag, os: os, channelId: channel);
        await click(t, href);
        expect(dialog, findsNothing, reason: why);
        expect(external, [href], reason: why);
        expect(WebPreviewStore.of(w).page, isNull, reason: why);
        expect(WebLinkOpenPreferences.instance.value, isNull, reason: why);
      });
    }

    testWidgets('a remembered "in your browser" never asks or shows', (
      t,
    ) async {
      await mount(t);
      WebLinkOpenPreferences.instance.write(WebLinkOpenPreference.browser);
      await click(t);
      expect(dialog, findsNothing);
      expect(external, [_link]);
    });
  });

  group('Settings › Appearance › How web links open', () {
    final row = find.byKey(const ValueKey('how-web-links-open-setting'));

    Future<WorkspaceController> mount(
      WidgetTester t, {
      bool flag = true,
      String os = 'android',
    }) async {
      final (w, _) = (await t.runAsync(
        () => webPreviewFixture(flag: flag, os: os),
      ))!;
      addTearDown(w.dispose);
      await t.pumpWidget(
        host(
          SingleChildScrollView(child: HowWebLinksOpenSetting(controller: w)),
        ),
      );
      await t.pump();
      return w;
    }

    testWidgets('shows where a page can open beside the conversation', (
      t,
    ) async {
      for (final os in ['android', 'ios', 'macos']) {
        await mount(t, os: os);
        expect(row, findsOneWidget, reason: os);
        expect(find.text('How web links open'), findsOneWidget, reason: os);
        expect(find.text('Ask on the first click'), findsOneWidget, reason: os);
        await t.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('is hidden on Linux and Windows and with web preview off', (
      t,
    ) async {
      for (final (flag, os) in [
        (true, 'linux'),
        (true, 'windows'),
        (false, 'android'),
      ]) {
        await mount(t, flag: flag, os: os);
        expect(row, findsNothing, reason: '$os flag=$flag');
        expect(find.text('How web links open'), findsNothing);
        await t.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('choosing writes the device preference', (t) async {
      await mount(t);
      await t.tap(find.byKey(const ValueKey('how-web-links-open-select')));
      await t.pumpAndSettle();
      await t.tap(find.text('In your browser').last);
      await t.pumpAndSettle();
      expect(
        WebLinkOpenPreferences.instance.value,
        WebLinkOpenPreference.browser,
      );
      expect(find.text('Ask on the first click'), findsNothing);
      expect(
        DevicePreferences.current!.getString(WebLinkOpenPreferences.key),
        'browser',
      );
    });

    testWidgets('sits in the Appearance page after the display switches', (
      t,
    ) async {
      final (w, _) = (await t.runAsync(webPreviewFixture))!;
      addTearDown(w.dispose);
      final store = PersonalPresentationStore(storage: _Storage());
      addTearDown(store.dispose);
      await store.bind('https://fixture.invalid', 'u');
      await t.pumpWidget(
        host(
          SingleChildScrollView(
            child: RaftAppearanceSection(
              appearance: const RaftAppearance(),
              onAppearance: (_) {},
              presentation: store,
              webLinks: HowWebLinksOpenSetting(controller: w),
            ),
          ),
        ),
      );
      await t.pump();
      expect(row, findsOneWidget);
      expect(
        t.getTopLeft(row).dy,
        greaterThan(
          t.getTopLeft(find.byKey(const ValueKey('appearance-hide-empty'))).dy,
        ),
      );
    });
  });
}

const _news = 'https://news.example.com/story';
String _link = _news;
