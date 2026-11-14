// Official cases owned by this file (Web v1.24.0 sharedCases.json, React
// host packages/web/visual-testing/MessageCardCases.tsx):
//   components.message-card.header
//   components.message-card.header.dark
//   components.message-card.fields.phone
//   components.message-card.markdown
//
// RFC 082 v2.0 card messages: the real card renderer reading each card
// through the app's stored-card reader, inside the case's frame (a 36px
// placeholder avatar, "Hands" and 09:12, then the card), 640px wide (390px
// on the phone case) with 16px padding and 16px between cards, as the React
// host draws it.
import 'package:flutter/material.dart';
import 'package:raft_flutter/features/message_card_read.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

Map<String, dynamic> _column(List<String> children) => {
  'type': 'Stack',
  'props': <String, dynamic>{},
  'children': children,
};
Map<String, dynamic> _text(String value, [String tone = 'default']) => {
  'type': 'Text',
  'props': {'text': value, 'tone': tone},
};

final _headerCards = [
  {
    'version': 1,
    'header': {
      'title': 'Play rejected this submission: 1.20.0',
      'subtitle': 'Raft Android · Google Play · production',
      'tags': [
        {'text': 'Failed', 'tone': 'danger'},
        {'text': 'Policy issue', 'tone': 'warning'},
        {'text': 'Android', 'tone': 'neutral'},
      ],
    },
    'root': 'root',
    'elements': {
      'root': _column(['note']),
      'note': _text('Resubmit after the target API fix.'),
    },
  },
  {
    'version': 1,
    'header': {
      'title': 'Deploy to production: web 2026.11.05',
      'subtitle': '3 of 4 regions',
      'tags': [
        {'text': 'Rolling out', 'tone': 'info'},
        {'text': 'Healthy', 'tone': 'success'},
        {'text': 'Web', 'tone': 'neutral'},
      ],
    },
    'root': 'root',
    'elements': {
      'root': _column(['note']),
      'note': _text('eu-west is next.', 'muted'),
    },
  },
];

final _fieldsCard = {
  'version': 1,
  'header': {
    'title': 'TestFlight build ready',
    'tags': [
      {'text': 'Ready', 'tone': 'success'},
    ],
  },
  'root': 'facts',
  'elements': {
    'facts': {
      'type': 'Fields',
      'props': {
        'items': [
          {'label': 'Version', 'value': '1.20.0 (12000003)', 'mono': true},
          {
            'label': 'Groups',
            'value': 'Internal, Botiverse beta testers, External reviewers',
          },
          {'label': 'Uploaded', 'value': '2026-11-05 09:12 UTC', 'mono': true},
          {
            'label': 'Commit',
            'value': '4e4bcbd15d8f0c2a91b7e3d64f5a0c1e9b2d7f36',
            'mono': true,
          },
          {
            'label': 'What to test',
            'value': 'Sign in with Apple, push notifications after a cold start, and the new card messages in a thread.',
          },
        ],
      },
    },
  },
};

final _markdownCard = {
  'version': 1,
  'root': 'root',
  'elements': {
    'root': _column(['notes', 'rule', 'open']),
    'notes': {
      'type': 'Markdown',
      'props': {
        'content': [
          'Google says the **target API level** is too low for new submissions.',
          '',
          '- raise `targetSdk` to 35 in `app/build.gradle.kts`',
          '- rebuild and upload **1.20.1**',
          '  - keep the release notes',
          '- ask @artin before resubmitting',
          '',
          '> Your app currently targets API level 34 and must target at least API level 35.',
          '',
          'See [the target API policy](https://support.google.com/googleplay/android-developer/answer/11926878).',
        ].join('\n'),
      },
    },
    'rule': {'type': 'Divider', 'props': <String, dynamic>{}},
    'open': {
      'type': 'Button',
      'props': {
        'label': 'Open in Play Console',
        'action': {
          'kind': 'navigate',
          'url': 'https://play.google.com/console/',
        },
      },
    },
  },
};

List<Map<String, dynamic>> _cardsFor(String id) => switch (id) {
  'components.message-card.fields.phone' => [_fieldsCard],
  'components.message-card.markdown' => [_markdownCard],
  _ => _headerCards,
};

ParityCase _case(String id) => ParityCase(
  widgets: const ['raft_ui:RaftMessageCard', 'raft_flutter:readMessageCard'],
  notes: 'MessageCardCases.tsx frame around the real card renderer.',
  build: (ctx) => Builder(
    builder: (context) {
      final t = RaftTokens.of(context);
      final ui = t.ui;
      final phone = id.endsWith('.phone');
      return ColoredBox(
        color: ui.layerCanvas,
        child: Align(
          alignment: Alignment.topLeft,
          child: ctx.target(
            SizedBox(
              width: phone ? 390 : 640,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, card) in _cardsFor(id).indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ui.fillMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Hands',
                                        style: t
                                            .scale(
                                              RaftTypeScale.callout,
                                              color: ui.foreground,
                                            )
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const TextSpan(text: '  '),
                                      TextSpan(
                                        text: '09:12',
                                        style: t.scale(
                                          RaftTypeScale.caption,
                                          color: ui.foregroundHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                () {
                                  final read = readMessageCard({
                                    'kind': 'message-card',
                                    'card': card,
                                    'revision': 1,
                                    'updatedAt': '2026-11-05T09:12:00.000Z',
                                  });
                                  if (read == null) {
                                    throw StateError('$id: card $i unreadable');
                                  }
                                  return RaftMessageCard(
                                    header: read.header,
                                    root: read.root,
                                    relativeTime: (_) => '',
                                    duration: (_, _) => '',
                                  );
                                }(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  ),
);

final Map<String, ParityCase> messageCardCases = {
  for (final id in [
    'components.message-card.header',
    'components.message-card.header.dark',
    'components.message-card.fields.phone',
    'components.message-card.markdown',
  ])
    id: _case(id),
};
