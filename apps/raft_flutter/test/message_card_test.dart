import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_card_read.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, host;

/// Web v1.24 card messages (RFC 082: shared messageCard.ts,
/// messageCardRead.ts, MessageCardBody / MessageCardElements): the stored
/// card is read strictly; anything this client cannot draw shows the
/// message's fallback text.
void main() {
  Map<String, dynamic> metadata({
    Map<String, dynamic>? header,
    Map<String, dynamic>? elements,
    String root = 'root',
    int revision = 1,
  }) => {
    'kind': 'message-card',
    'revision': revision,
    'updatedAt': '2026-11-01T09:00:00.000Z',
    'card': {
      'version': 1,
      'header': ?header,
      'root': root,
      'elements':
          elements ??
          {
            'root': {
              'type': 'Stack',
              'props': {'direction': 'column'},
              'children': ['summary', 'facts', 'meta', 'open', 'docs'],
            },
            'summary': {
              'type': 'Markdown',
              'props': {'content': 'Deploy **done** for `web`'},
            },
            'facts': {
              'type': 'Fields',
              'props': {
                'items': [
                  {'label': 'Version', 'value': 'v1.24.0', 'mono': true},
                  {'label': 'Region', 'value': 'eu-west'},
                ],
              },
            },
            'meta': {
              'type': 'Stack',
              'props': {'direction': 'row'},
              'children': ['state', 'branch'],
            },
            'state': {
              'type': 'Badge',
              'props': {'text': 'Green', 'tone': 'done'},
            },
            'branch': {
              'type': 'Text',
              'props': {'text': 'main', 'mono': true},
            },
            'open': {
              'type': 'Button',
              'props': {
                'label': 'Open',
                'action': {
                  'kind': 'navigate',
                  'url': 'https://deploy.example.com/runs/1',
                },
              },
            },
            'docs': {
              'type': 'Button',
              'props': {
                'label': 'Docs',
                'variant': 'ghost',
                'action': {
                  'kind': 'navigate',
                  'url': 'https://docs.example.com/deploy',
                },
              },
            },
          },
    },
  };

  group('reader', () {
    test('a valid card reads, with its header and buttons', () {
      final read = readMessageCard(
        metadata(
          header: {
            'title': 'Deploy finished',
            'subtitle': 'web · production',
            'tags': [
              {'text': 'Live', 'tone': 'success'},
            ],
          },
        ),
      )!;
      expect(read.header!.title, 'Deploy finished');
      expect(read.header!.tags.single.$2, RaftCardTagTone.success);
      expect(raftCardButtons(read.root).map((b) => b.domain), [
        'deploy.example.com',
        'docs.example.com',
      ]);
    });

    test('anything outside the schema shows the fallback instead', () {
      expect(readMessageCard({'kind': 'action-card'}), isNull);
      expect(readMessageCard({...metadata(), 'revision': 0}), isNull);
      // A prop the schema has no place for.
      expect(
        readMessageCard(
          metadata(
            elements: {
              'root': {
                'type': 'Text',
                'props': {'text': 'x', 'color': 'red'},
              },
            },
          ),
        ),
        isNull,
      );
      // An unknown element type.
      expect(
        readMessageCard(
          metadata(
            elements: {
              'root': {'type': 'Image', 'props': {}},
            },
          ),
        ),
        isNull,
      );
      // An element not reached from the root.
      expect(
        readMessageCard(
          metadata(
            elements: {
              'root': {'type': 'Divider', 'props': {}},
              'stray': {'type': 'Divider', 'props': {}},
            },
          ),
        ),
        isNull,
      );
      // Not a public HTTPS URL.
      for (final url in [
        'http://example.com',
        'https://10.0.0.1/x',
        'https://example.com:8443/x',
        'https://user@example.com',
        'https://example.com/#x',
        'https://localhost/x',
      ]) {
        expect(
          readMessageCard(
            metadata(
              elements: {
                'root': {
                  'type': 'Button',
                  'props': {
                    'label': 'Go',
                    'action': {'kind': 'navigate', 'url': url},
                  },
                },
              },
            ),
          ),
          isNull,
          reason: url,
        );
      }
      // A time that is not strict RFC 3339 UTC.
      expect(
        readMessageCard(
          metadata(
            elements: {
              'root': {
                'type': 'RelativeTime',
                'props': {'at': '2026-02-30T00:00:00Z'},
              },
            },
          ),
        ),
        isNull,
      );
    });
  });

  testWidgets('the card replaces the fallback text in the message body', (
    t,
  ) async {
    final (w, _) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    Future<void> show(Map<String, dynamic> actionMetadata) => t.pumpWidget(
      host(
        MessagePresentation(
          controller: w,
          onExternalLink: (_) {},
          message: RaftMessage({
            'id': 'm1',
            'channelId': 'c1',
            'senderType': 'agent',
            'content': 'Fallback: deploy finished',
            'actionMetadata': actionMetadata,
          }),
        ),
      ),
    );
    await show(metadata(header: {'title': 'Deploy finished'}, revision: 2));
    await t.pump();
    expect(find.byKey(const ValueKey('message-card')), findsOneWidget);
    expect(find.text('Fallback: deploy finished'), findsNothing);
    expect(find.text('Deploy finished'), findsOneWidget);
    expect(find.text('v1.24.0'), findsOneWidget);
    expect(find.text('Green'), findsOneWidget);
    expect(find.text('·'), findsNothing);
    expect(find.text('deploy.example.com'), findsOneWidget);
    expect(find.textContaining('Updated'), findsOneWidget);

    // A card this client cannot read: the fallback text, never a blank card.
    await show({
      'kind': 'message-card',
      'revision': 1,
      'card': {'version': 2},
    });
    await t.pump();
    expect(find.byKey(const ValueKey('message-card')), findsNothing);
    expect(
      find.textContaining('Fallback: deploy finished', findRichText: true),
      findsOneWidget,
    );
  });
}
