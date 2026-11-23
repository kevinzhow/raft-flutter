import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/web_link_open.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter, host;
import 'support/web_preview_fixture.dart';

const _url = 'https://example.test/preview';

Map<String, Object> _button(String label, [String? mode]) => {
  'type': 'Button',
  'props': {
    'label': label,
    'action': {'kind': 'navigate', 'url': _url},
    'open': ?mode,
  },
};

Future<(WorkspaceController, List<String>, MessageAdapter)> _mount(
  WidgetTester tester, {
  bool card = false,
  bool enabled = true,
  ValueChanged<Offset>? onMessageActions,
}) async {
  final (workspace, adapter) = (await tester.runAsync(
    () => webPreviewFixture(flag: false, os: 'linux', desktopBrowser: enabled),
  ))!;
  addTearDown(workspace.dispose);
  final external = <String>[];
  final message = MessagePresentation(
    controller: workspace,
    onExternalLink: external.add,
    message: RaftMessage({
      'id': 'm1',
      'channelId': 'c1',
      'senderType': 'agent',
      'content': '[Preview link]($_url)',
      if (card)
        'actionMetadata': {
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
                'children': ['default', 'tab'],
              },
              'default': _button('Preview card'),
              'tab': _button('External card', 'tab'),
            },
          },
        },
    }),
  );
  await tester.pumpWidget(
    host(
      RaftMessageRow(
        author: 'Fixture sender',
        timestamp: '12:00',
        content: message,
        onActionsAt: onMessageActions,
      ),
    ),
  );
  expect(ChannelSideFlags.of(workspace).desktopBrowser, enabled);
  return (workspace, external, adapter);
}

void main() {
  final linux = TargetPlatformVariant({TargetPlatform.linux});
  testWidgets('a right-click on a link opens only its menu', (tester) async {
    final messageActions = <Offset>[];
    final (workspace, _, _) = await _mount(
      tester,
      onMessageActions: messageActions.add,
    );
    final tabs = WebPreviewStore.of(workspace).browserTabs;
    tabs.open('c1', Uri.parse(_url));
    await tester.tap(
      find.text('Preview link', findRichText: true),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Open beside'), findsOneWidget);
    expect(messageActions, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open beside'), findsNothing);
    expect(tabs.forConversation('c1')?.active.url, Uri.parse(_url));
    await tester.tap(
      find.text('Fixture sender'),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    expect(messageActions, hasLength(1));
  }, variant: linux);

  testWidgets('first-click choice dialog uses the Web width', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Preview link', findRichText: true));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('web-link-choice-dialog')))
          .width,
      400,
    );
  }, variant: linux);

  for (final card in [false, true]) {
    testWidgets('a mounted ${card ? 'card' : 'body'} survives lost authority', (
      tester,
    ) async {
      final (workspace, _) = (await tester.runAsync(
        () => webPreviewFixture(flag: false, os: 'linux', desktopBrowser: true),
      ))!;
      addTearDown(workspace.dispose);
      late StateSetter update;
      var source = 's1';
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MessagePresentation(
                controller: workspace,
                onExternalLink: (_) {},
                message: RaftMessage({
                  'id': 'stable',
                  'sourceServerId': source,
                  'channelId': 'c1',
                  'content': '[Preview link]($_url)',
                  if (card)
                    'actionMetadata': {
                      'kind': 'message-card',
                      'revision': 1,
                      'card': {
                        'version': 1,
                        'root': 'default',
                        'elements': {'default': _button('Preview card')},
                      },
                    },
                }),
              );
            },
          ),
        ),
      );
      final body = find.byType(card ? RaftMessageCard : RaftMessageBody);
      final mounted = tester.element(body);
      update(() => source = 'other-server');
      await tester.pump();
      expect(tester.element(body), same(mounted));
    }, variant: linux);
  }
  testWidgets('Open beside in the link menu overrides the browser preference', (
    tester,
  ) async {
    final (workspace, external, _) = await _mount(tester);
    WebLinkOpenPreferences.instance.write(WebLinkOpenPreference.browser);
    await tester.tap(
      find.text('Preview link', findRichText: true),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open beside'));
    await tester.pumpAndSettle();
    expect(
      WebPreviewStore.of(workspace).browserTabs
          .forConversation('c1')
          ?.active
          .url,
      Uri.parse(_url),
    );
    expect(external, isEmpty);
    expect(
      WebLinkOpenPreferences.instance.value,
      WebLinkOpenPreference.browser,
    );
  }, variant: linux);
  testWidgets('a mounted Markdown link follows a newly enabled browser flag', (
    tester,
  ) async {
    final (workspace, external, adapter) = await _mount(tester, enabled: false);
    final link = find.text('Preview link', findRichText: true);
    Future<void> middleClick() => tester.tap(
      link,
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await middleClick();
    expect(external, isEmpty);
    final flags = ChannelSideFlags.of(workspace);
    adapter.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': ChannelSideFlags.desktopBrowserKey, 'enabled': true},
      ],
    };
    await tester.runAsync(() async {
      final enabled = Completer<void>();
      void changed() {
        if (flags.desktopBrowser && !enabled.isCompleted) enabled.complete();
      }

      flags.addListener(changed);
      try {
        flags.reevaluate();
        await enabled.future.timeout(const Duration(seconds: 3));
      } finally {
        flags.removeListener(changed);
      }
    });
    await tester.pump();
    await middleClick();
    expect(external, [_url]);
  }, variant: linux);
  testWidgets(
    'Web v1.24 automatic cards open beside with the browser preference set',
    (tester) async {
      final (workspace, external, _) = await _mount(tester, card: true);
      WebLinkOpenPreferences.instance.write(WebLinkOpenPreference.browser);
      await tester.tap(find.text('Preview card'));
      await tester.pump();
      expect(
        WebPreviewStore.of(workspace).browserTabs
            .forConversation('c1')
            ?.active
            .url,
        Uri.parse(_url),
      );
      expect(external, isEmpty);
      await tester.tap(find.text('External card'));
      expect(external, [_url]);
    },
    variant: linux,
  );

  for (final card in [false, true]) {
    testWidgets(
      'modified and middle clicks open a ${card ? 'card' : 'link'} externally',
      (tester) async {
        final (workspace, external, _) = await _mount(tester, card: card);
        WebLinkOpenPreferences.instance.write(WebLinkOpenPreference.beside);
        final target = find.text(
          card ? 'Preview card' : 'Preview link',
          findRichText: true,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(target, kind: PointerDeviceKind.mouse);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(
          target,
          kind: PointerDeviceKind.mouse,
          buttons: kMiddleMouseButton,
        );
        expect(external, [_url, _url]);
        expect(
          WebPreviewStore.of(workspace).browserTabs.forConversation('c1'),
          isNull,
        );
      },
      variant: linux,
    );
  }
}
