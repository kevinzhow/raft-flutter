import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, host;

const _url = 'https://tickets.example.org/123';
const _app = {'id': 'tickets', 'name': 'Tickets', 'icon': null};
const _prompt = {
  'prompts': [
    {'url': _url, 'app': _app},
  ],
};
const _answer = {
  'items': [
    {
      'kind': 'v3',
      'app': _app,
      'url': _url,
      'ticket': 'ticket',
      'actions': [
        {'action_id': 'resolve', 'handle': 'signed-handle'},
      ],
      'preview': {
        'version': 3,
        'items': [
          {'type': 'inline', 'title': 'Ticket 123'},
          {
            'type': 'card',
            'placement': 'block',
            'title': 'Printer ticket',
            'business_revision': 'first',
            'card': {
              'root': 'root',
              'elements': {
                'root': {
                  'type': 'Stack',
                  'props': {},
                  'children': ['status', 'resolve'],
                },
                'status': {
                  'type': 'Badge',
                  'props': {'text': 'Open', 'tone': 'warning'},
                },
                'resolve': {
                  'type': 'Button',
                  'props': {
                    'label': 'Resolve',
                    'action': {
                      'kind': 'execute',
                      'action_id': 'resolve',
                      'undoWindowMs': 5000,
                    },
                  },
                },
              },
            },
          },
        ],
      },
    },
  ],
};

void main() {
  for (final (platform, size) in [
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets('allow, render and undo a card on $platform at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (workspace, transport) = (await tester.runAsync(
        () => fixture('member'),
      ))!;
      addTearDown(workspace.dispose);
      var allowed = false;
      transport.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'interactive_link_cards', 'enabled': true},
        ],
      };
      transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
          allowed ? _answer : _prompt;
      transport
              .routes['POST /integrations/clients/tickets/link-preview-consent'] =
          (_) {
            allowed = true;
            return {'app': _app};
          };
      final view = MessagePresentation(
        controller: workspace,
        message: RaftMessage({
          'id': 'm1',
          'channelId': 'c1',
          'senderType': 'human',
          'content': 'Please check $_url',
        }),
        onExternalLink: (_) {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme().copyWith(platform: platform),
          home: RaftToastHost(child: Scaffold(body: view)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Allow'), findsOneWidget);
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(find.text('Allow'), findsNothing);
      expect(find.text('Ticket 123'), findsOneWidget);
      expect(find.text('Printer ticket'), findsOneWidget);
      await tester.tap(find.text('Resolve'));
      await tester.pump();
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Resolve'), findsOneWidget);
      expect(
        transport.calls.where(
          (request) => request.path == '/link-cards/execute',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(view));
      await tester.pumpAndSettle();
      expect(find.text('Allow'), findsNothing);
      expect(find.text('Printer ticket'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('decline leaves a plain link after returning to the message', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('member'),
    ))!;
    addTearDown(workspace.dispose);
    var declined = false;
    transport.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [],
    };
    transport.routes['GET /messages/m1/app-link-previews'] = (_) =>
        declined ? {'previews': []} : _prompt;
    transport
            .routes['POST /integrations/clients/tickets/link-preview-decline'] =
        (_) {
          declined = true;
          return {'app': _app};
        };
    final view = host(
      MessagePresentation(
        controller: workspace,
        message: RaftMessage({'id': 'm1', 'channelId': 'c1', 'content': _url}),
        onExternalLink: (_) {},
      ),
    );
    await tester.pumpWidget(view);
    await tester.pumpAndSettle();
    expect(find.text('Don’t allow'), findsOneWidget);
    await tester.tap(find.text('Don’t allow'));
    await tester.pumpAndSettle();
    expect(declined, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(view);
    await tester.pumpAndSettle();
    expect(find.text('Don’t allow'), findsNothing);
    expect(find.textContaining(_url, findRichText: true), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed consent can be retried without a duplicate prompt', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('member'),
    ))!;
    addTearDown(workspace.dispose);
    var allowed = false;
    var attempts = 0;
    transport.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [],
    };
    transport.routes['GET /messages/m1/app-link-previews'] = (_) => allowed
        ? {
            'previews': [
              {'url': _url, 'appName': 'Tickets', 'title': 'Ticket 123'},
            ],
          }
        : _prompt;
    transport
            .routes['POST /integrations/clients/tickets/link-preview-consent'] =
        (_) {
          if (++attempts == 1) throw StateError('Fixture network error');
          allowed = true;
          return {'app': _app};
        };
    await tester.pumpWidget(host(_message(workspace)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(find.text('Allow'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Ticket 123'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'confirmation can cancel, then accept and follow server progress',
    (tester) async {
      final (workspace, transport) = (await tester.runAsync(
        () => fixture('member'),
      ))!;
      addTearDown(workspace.dispose);
      transport.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'interactive_link_cards', 'enabled': true},
        ],
      };
      transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
          appLinkTestAnswer(confirm: true);
      transport.routes['POST /link-cards/prepare'] = (request) {
        expect(request.data, {
          'handle': 'signed-handle',
          'claimed': {'business_revision': 'first'},
        });
        return {
          'prepared_action_id': 'b8ef58e6-a811-4a30-b0a8-6fb24fc7e71a',
          'prepared_digest': 'a' * 64,
          'description': {
            'title': 'Close ticket?',
            'body': 'Mark this printer ticket resolved.',
            'confirm_label': 'Close ticket',
            'cancel_label': 'Keep open',
          },
        };
      };
      transport.routes['POST /link-cards/execute'] = (request) {
        expect(request.data['prepared_digest'], 'a' * 64);
        expect(request.data['client_request_id'], isA<String>());
        return {
          'operation_id': '9cddde84-f69f-4d9e-8de7-b0df120ea843',
          'state': 'accepted',
        };
      };
      var statusReads = 0;
      transport.routes['POST /link-cards/status'] = (request) {
        expect(
          request.data['operation_id'],
          '9cddde84-f69f-4d9e-8de7-b0df120ea843',
        );
        if (statusReads++ == 0) {
          return {
            'operation_id': 'dca364ec-7ce3-4b60-80a8-75889d34af5d',
            'state': 'done',
            'receipt_revision': 2,
          };
        }
        return {
          'operation_id': '9cddde84-f69f-4d9e-8de7-b0df120ea843',
          'state': 'done',
          'receipt_revision': 2,
          'app_result': {
            'toast': {
              'tone': 'success',
              'text': 'The printer ticket is closed.',
            },
          },
        };
      };
      await tester.pumpWidget(host(RaftToastHost(child: _message(workspace))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Close ticket?'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Close ticket?'), findsNothing);
      expect(
        transport.calls.where(
          (request) => request.path == '/link-cards/execute',
        ),
        isEmpty,
      );
      await tester.tap(find.text('Resolve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Close ticket'));
      await tester.pump();
      await tester.pump();
      expect(find.text('In progress'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(statusReads, 1);
      expect(find.text('In progress'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('In progress'), findsNothing);
      expect(find.text('The printer ticket is closed.'), findsOneWidget);
      expect(
        transport.calls.where(
          (request) => request.path == '/link-cards/execute',
        ),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a translated message keeps its original app link block', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('member'),
    ))!;
    addTearDown(workspace.dispose);
    transport.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'interactive_link_cards', 'enabled': true},
      ],
    };
    transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
        appLinkTestAnswer();
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) =>
              _message(workspace).body(context, content: '请查看工单。'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final prose = find.text('请查看工单。', findRichText: true);
    final card = find.text('Printer ticket');
    expect(prose, findsOneWidget);
    expect(card, findsOneWidget);
    expect(
      tester.getTopLeft(card).dy,
      greaterThan(tester.getTopLeft(prose).dy),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an Artifact link alone does not request an app preview', (
    tester,
  ) async {
    final (workspace, transport) = (await tester.runAsync(
      () => fixture('member'),
    ))!;
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      host(
        MessagePresentation(
          controller: workspace,
          message: RaftMessage({
            'id': 'm1',
            'channelId': 'c1',
            'senderType': 'human',
            'content': 'https://artifacts.raft.build/pt_9cddde84-f69f-4d9e-8de7-b0df120ea843',
          }),
          onExternalLink: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      transport.calls.where(
        (call) =>
            call.path.endsWith('/app-link-previews') ||
            call.path.endsWith('/link-cards/read'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final touch in [false, true]) {
    testWidgets('hover availability follows input, touch=$touch', (
      tester,
    ) async {
      final (workspace, transport) = (await tester.runAsync(
        () => fixture('member'),
      ))!;
      addTearDown(workspace.dispose);
      transport.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'interactive_link_cards', 'enabled': true},
        ],
      };
      transport.routes['POST /messages/m1/link-cards/read'] = (_) =>
          appLinkTestAnswer(hover: true, handles: false);
      final opened = <String>[];
      await tester.pumpWidget(
        host(
          RaftInteractionScope(
            interaction: touch
                ? RaftInteraction.touchMode
                : RaftInteraction.pointerMode,
            child: _message(workspace, open: opened.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chip = find.text('Ticket 123');
      expect(chip, findsOneWidget);
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(600, 300));
      await pointer.moveTo(tester.getCenter(chip));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      if (touch) {
        expect(find.text('Printer ticket'), findsNothing);
        await tester.tap(chip);
      } else {
        expect(find.text('Printer ticket'), findsOneWidget);
        await tester.tap(find.text('Open in browser'));
      }
      expect(opened, [_url]);
      expect(
        transport.calls.where(
          (request) => request.path == '/link-cards/execute',
        ),
        isEmpty,
      );
      await pointer.removePointer();
      await tester.pumpWidget(const SizedBox());
    });
  }
}

MessagePresentation _message(
  WorkspaceController workspace, {
  ValueChanged<String>? open,
}) => MessagePresentation(
  controller: workspace,
  message: RaftMessage({
    'id': 'm1',
    'channelId': 'c1',
    'senderType': 'human',
    'content': 'Please check $_url',
  }),
  onExternalLink: open ?? (_) {},
);

Map<String, dynamic> appLinkTestAnswer({
  bool confirm = false,
  bool hover = false,
  bool handles = true,
  bool overflow = false,
}) {
  final row = (_answer['items']! as List).single as Map;
  final preview = row['preview'] as Map;
  final items = preview['items'] as List;
  final card = items.last as Map;
  final tree = card['card'] as Map;
  final elements = tree['elements'] as Map;
  final resolve = elements['resolve'] as Map;
  final props = resolve['props'] as Map;
  return {
    'items': [
      {
        ...row,
        if (!handles) 'actions': [],
        'preview': {
          ...preview,
          'items': [
            items.first,
            {
              ...card,
              'placement': hover ? 'hover' : 'block',
              'card': {
                ...tree,
                'elements': {
                  ...elements,
                  if (overflow) ...{
                    'root': {
                      ...(elements['root'] as Map),
                      'children': ['status', 'resolve', 'source'],
                    },
                    'source': {
                      'type': 'Button',
                      'props': {
                        'label': 'Open ticket',
                        'action': {'kind': 'navigate', 'url': _url},
                      },
                    },
                  },
                  'resolve': {
                    ...resolve,
                    'props': {
                      ...props,
                      if (confirm)
                        'action': {
                          'kind': 'execute',
                          'action_id': 'resolve',
                          'confirm': 'prepare',
                        },
                    },
                  },
                },
              },
            },
          ],
        },
      },
    ],
  };
}
