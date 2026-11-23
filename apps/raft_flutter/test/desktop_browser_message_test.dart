import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_flutter/features/web_link_open.dart';

import 'message_presentation_test.dart' show host;
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

Future<(WorkspaceController, List<String>)> _mount(
  WidgetTester tester, {
  bool card = false,
}) async {
  final (workspace, _) = (await tester.runAsync(
    () => webPreviewFixture(flag: false, os: 'linux', desktopBrowser: true),
  ))!;
  addTearDown(workspace.dispose);
  final external = <String>[];
  await tester.pumpWidget(
    host(
      MessagePresentation(
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
      ),
    ),
  );
  expect(ChannelSideFlags.of(workspace).desktopBrowser, isTrue);
  return (workspace, external);
}

void main() {
  final linux = TargetPlatformVariant({TargetPlatform.linux});
  testWidgets('Open beside in the link menu overrides the browser preference', (
    tester,
  ) async {
    final (workspace, external) = await _mount(tester);
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
  testWidgets(
    'a default card opens beside and an explicit tab opens externally',
    (tester) async {
      final (workspace, external) = await _mount(tester, card: true);
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
        final (workspace, external) = await _mount(tester, card: card);
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
