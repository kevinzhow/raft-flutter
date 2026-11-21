import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_flutter/features/artifacts/artifact_models.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/artifacts/artifact_viewer_page.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity/parity_harness.dart' show loadParityFonts;
import '../support/artifact_fake_client.dart';

const _path = '/artifacts/$artifactId/comments';

Map<String, Object?> comment(
  String id,
  String text, {
  String? replyTo,
  bool resolved = false,
}) => {
  'id': id,
  'createdAt': '2026-11-19T03:00:00Z',
  'resolvedAt': resolved ? '2026-11-19T03:00:01Z' : null,
  'author': artifactActor(),
  'body': [
    {'type': 'text', 'text': text},
  ],
  'target': {'scope': 'artifact'},
  'version': 1,
  'replyTo': replyTo,
};

void main() {
  late ArtifactFakeClient client;
  late WorkspaceController workspace;
  late List<Map<String, Object?>> comments;

  setUp(() {
    comments = [comment('root', 'Initial comment')];
    client = ArtifactFakeClient();
    workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
    client.answers['GET /artifacts/$artifactId'] = (_) => {
      ...artifactViewerJson(),
      'viewer': artifactActor(),
      'capabilities': {'comment': true, 'delete': true},
    };
    client.answers['GET $_path'] = (_) => {
      'comments': comments,
      'olderCursor': null,
    };
  });

  tearDown(() async {
    workspace.dispose();
    await client.dispose();
  });

  Future<void> open(
    WidgetTester tester,
    Size size,
    TargetPlatform platform, {
    DateTime Function()? commentClock,
    bool dark = false,
    ArtifactLinkTarget target = const ArtifactLinkTarget(artifactId),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: platform),
        home: Scaffold(
          body: ArtifactWorkspaceViewer(
            session: ArtifactSession.of(workspace),
            target: target,
            page: size.width < 768,
            onClose: () {},
            operatingSystem: 'linux',
            commentClock: commentClock,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final openComments = find.byKey(const ValueKey('artifact-comments-trigger'));
  final composer = find.byKey(const ValueKey('artifact-comment-input'));
  final send = find.byKey(const ValueKey('artifact-comment-send'));

  for (final (size, platform, lineHeight) in [
    (const Size(390, 844), TargetPlatform.android, 22.0),
    (const Size(1280, 900), TargetPlatform.linux, 20.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('Artifact self mention uses the inline reference recipe at '
          '${size.width}px (dark: $dark)', (tester) async {
        await tester.runAsync(loadParityFonts);
        comments = [
          {
            ...comment('root', ''),
            'body': [
              {'type': 'text', 'text': 'For '},
              {'type': 'mention', 'actor': artifactActor('Review Owner')},
              {'type': 'text', 'text': ' and '},
              {
                'type': 'mention',
                'actor': {...artifactActor('Review Peer'), 'id': 'u2'},
              },
              {'type': 'text', 'text': '.'},
            ],
          },
        ];
        await open(tester, size, platform, dark: dark);
        await tester.tap(openComments.hitTestable());
        await tester.pumpAndSettle();

        final chip = find.byType(RaftReferenceChip);
        expect(chip, findsOneWidget);
        final label = find.descendant(
          of: chip,
          matching: find.text('@Review Owner'),
        );
        expect(tester.widget<Text>(label).style?.fontWeight, FontWeight.w600);
        expect(tester.widget<Text>(label).style?.fontSize, 12.25);
        // A running-text chip takes 6px on each side. The inset ring
        // paints inside that box and contributes no layout width.
        expect(
          tester.getSize(chip).width - tester.getSize(label).width,
          closeTo(12, .01),
        );
        expect(tester.getSize(chip).width, closeTo(106.22, .75));
        expect(tester.getSize(chip).height, lineHeight);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pump();
          expect(
            find.bySemanticsLabel(RegExp('@Review Owner')),
            findsOneWidget,
          );
        } finally {
          semantics.dispose();
        }
        expect(
          find.textContaining(' and @Review Peer.', findRichText: true),
          findsOneWidget,
        );
      });
    }
  }

  testWidgets('renders structured mentions in discussion and preserves edits', (
    tester,
  ) async {
    Map<String, Object?> mention(Map<String, Object?> actor) => {
      'type': 'mention',
      'actor': actor,
    };
    final viewer = mention(artifactActor('Review Owner')..['name'] = 'owner');
    final peer = mention({
      'type': 'agent',
      'id': 'u1',
      'name': 'peer',
      'displayName': 'Review Peer',
    });
    final fallback = mention({
      'type': 'user',
      'id': 'u2',
      'name': 'fallback',
      'displayName': '',
    });
    final posted = {
      ...comment('root', ''),
      'body': [
        {'type': 'text', 'text': 'For '},
        viewer,
        {'type': 'text', 'text': ' and @owner'},
      ],
    };
    comments = [
      posted,
      {
        ...comment('reply', '', replyTo: 'root'),
        'body': [peer],
      },
    ];
    client.answers['GET /artifacts/$artifactId/review/drafts'] = (_) => {
      'drafts': [
        {
          ...comment('draft', ''),
          'body': [fallback],
        },
      ],
    };
    client.answers['PATCH $_path/root'] = (_) => {
      'comment': {
        ...posted,
        'editedAt': '2026-11-19T03:05:00Z',
        'body': [
          {'type': 'text', 'text': 'For '},
          viewer,
          {'type': 'text', 'text': ' and @owner, updated'},
        ],
      },
      'notified': [],
    };

    await open(tester, const Size(1280, 900), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    expect(find.text('@Review Owner'), findsOneWidget);
    expect(find.text('@Review Peer'), findsOneWidget);
    expect(find.text('@fallback'), findsOneWidget);
    expect(find.text('D'), findsNWidgets(2));
    expect(
      find.textContaining(' and @owner', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<RaftReferenceChip>(find.byType(RaftReferenceChip))
          .map((chip) => (chip.label, chip.appearance.kind)),
      contains(('@Review Owner', RaftReferenceKind.selfMention)),
    );
    expect(
      tester
          .widgetList<RaftReferenceChip>(find.byType(RaftReferenceChip))
          .where(
            (chip) => chip.appearance.kind == RaftReferenceKind.selfMention,
          )
          .map((chip) => chip.label),
      ['@Review Owner'],
    );

    await tester.tap(find.byKey(const ValueKey('artifact-comment-more-root')));
    await tester.pumpAndSettle();
    final menu = find.text('Edit').hitTestable();
    await tester.tap(menu.last);
    await tester.pumpAndSettle();
    final editor = find.descendant(
      of: composer,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(editor).controller.text,
      'For @owner and @owner',
    );
    await tester.enterText(composer, 'For @owner and @owner, updated');
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('@Review Owner'), findsOneWidget);
    expect(
      find.textContaining('@owner, updated', findRichText: true),
      findsOneWidget,
    );
    expect(
      client.bodies['PATCH $_path/root'],
      containsPair('body', [
        {'type': 'text', 'text': 'For '},
        {
          'type': 'mention',
          'actor': {'type': 'user', 'id': 'u1'},
        },
        {'type': 'text', 'text': ' and @owner, updated'},
      ]),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('renders a structured mention in a review opened from Activity', (
    tester,
  ) async {
    client.answers['GET /artifacts/$artifactId?version=1'] =
        client.answers['GET /artifacts/$artifactId']!;
    client.answers['GET $_path?review=review-1'] = (_) => {
      'comments': const [],
      'olderCursor': null,
      'review': {
        'body': [
          {'type': 'text', 'text': 'Reviewed with '},
          {'type': 'mention', 'actor': artifactActor('Review Owner')},
        ],
      },
    };
    await open(
      tester,
      const Size(1280, 900),
      TargetPlatform.linux,
      target: const ArtifactLinkTarget.activity(
        artifactId,
        1,
        reviewId: 'review-1',
      ),
    );
    expect(client.requests, contains('GET $_path?review=review-1'));
    expect(find.text('@Review Owner'), findsOneWidget);
    expect(find.text('Initial comment'), findsNothing);
    await tester.tap(find.text('Show all comments'));
    await tester.pumpAndSettle();
    expect(find.text('@Review Owner'), findsNothing);
    expect(find.text('Initial comment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('opens, replies and closes on ${size.width} × ${size.height}', (
      tester,
    ) async {
      client.answers['POST $_path'] = (_) => {
        'comment': comment('reply', 'My reply', replyTo: 'root'),
        'notified': [],
      };
      await open(tester, size, platform);
      await tester.tap(openComments);
      await tester.pumpAndSettle();
      expect(find.text('Initial comment'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      await tester.enterText(composer, 'My reply');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('My reply'), findsOneWidget);
      expect(client.bodies['POST $_path'], containsPair('replyTo', 'root'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('My reply'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('card matches the authored entry spacing and active surface', (
    tester,
  ) async {
    await tester.runAsync(loadParityFonts);
    comments = [
      {
        ...comment('root', 'Edited comment'),
        'author': artifactActor('Review Owner'),
        'editedAt': '2026-11-19T03:01:00Z',
      },
      {
        ...comment('reply', 'Reply text', replyTo: 'root'),
        'author': {...artifactActor('Review Peer'), 'id': 'u2'},
      },
      {
        ...comment('resolved', 'Resolved comment', resolved: true),
        'resolvedBy': artifactActor(),
      },
    ];
    client.answers['GET /artifacts/$artifactId/review/drafts'] = (_) => {
      'drafts': [comment('draft', 'Private draft')],
    };
    await open(
      tester,
      const Size(1280, 900),
      TargetPlatform.linux,
      commentClock: () => DateTime.utc(2026, 11, 19, 3, 5),
    );
    await tester.tap(openComments.hitTestable());
    await tester.pumpAndSettle();

    final root = find.byKey(const ValueKey('root'));
    final draft = find.byKey(const ValueKey('draft'));
    Finder within(Finder card, Finder content) =>
        find.descendant(of: card, matching: content);
    final avatar = within(root, find.byType(RaftAvatar)).first;
    final author = within(root, find.text('Review Owner'));
    final time = within(root, find.text('5 minutes ago')).first;
    final edited = within(root, find.text('edited'));
    final body = within(root, find.text('Edited comment'));

    BoxDecoration surface(Finder card) =>
        tester
                .widget<DecoratedBox>(
                  within(card, find.byType(DecoratedBox)).first,
                )
                .decoration
            as BoxDecoration;

    expect(tester.getSize(avatar), const Size.square(19));
    expect(within(avatar, find.text('R')), findsOneWidget);
    expect(tester.getTopLeft(body).dx, tester.getTopLeft(avatar).dx);
    expect(tester.getTopLeft(author).dx - tester.getTopRight(avatar).dx, 8);
    expect(
      tester.getCenter(edited).dy,
      closeTo(tester.getCenter(time).dy, .01),
    );

    final restingBorder = (surface(root).border as Border).top;
    expect(surface(root).boxShadow, isEmpty);
    await tester.tap(body.hitTestable());
    await tester.pumpAndSettle();
    final active = surface(root);
    expect(tester.widget<RaftCommentCard>(root).active, isTrue);
    final activeBorder = (active.border as Border).top;
    expect(activeBorder.width, 1);
    expect(activeBorder.color, isNot(restingBorder.color));
    expect(
      active.boxShadow?.map((layer) => (layer.offset.dy, layer.spreadRadius)),
      unorderedEquals([(1.0, 0.0), (12.0, -12.0)]),
    );
    final blurred = active.boxShadow!.singleWhere(
      (layer) => layer.offset.dy == 12,
    );
    expect(blurred.blurSigma, closeTo(16, .0001));

    final disclosure = find.text('Resolved (1)').hitTestable();
    expect(disclosure, findsOneWidget);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    final resolved = find.byKey(const ValueKey('resolved'));
    expect(tester.widget<RaftCommentCard>(resolved).active, isFalse);
    expect(surface(resolved).boxShadow, isEmpty);
    expect(tester.widget<RaftCommentCard>(draft).privateDraft, isTrue);
    expect(surface(draft).boxShadow, isEmpty);
    expect(within(draft, find.byType(RaftAvatar)), findsNothing);

    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    await tester.pumpAndSettle();
    final commentList = within(
      find.byKey(const ValueKey('artifact-comments-panel')),
      find.byType(ListView),
    );
    await tester.scrollUntilVisible(
      author,
      160,
      scrollable: within(commentList, find.byType(Scrollable)).first,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(avatar), const Size.square(19));
    expect(
      tester.getTopLeft(edited).dy,
      greaterThan(tester.getTopLeft(author).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('applies peer activity and resolves or reopens a thread', (
    tester,
  ) async {
    client.answers['POST $_path/root/resolve'] = (_) => {
      'comment': {
        ...comment('root', 'Initial comment', resolved: true),
        'resolvedBy': artifactActor(),
        'resolvedAt': '2026-11-19T03:05:00Z',
      },
      'note': null,
      'changed': true,
    };
    client.answers['POST $_path/root/reopen'] = (_) => {
      'comment': comments.first,
      'note': null,
      'changed': true,
    };
    await open(
      tester,
      const Size(1200, 850),
      TargetPlatform.linux,
      commentClock: () => DateTime.utc(2026, 11, 19, 3, 5),
    );
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    comments = [...comments, comment('peer', 'Peer reply', replyTo: 'root')];
    client.ingress.add(RaftEvent('activity:changed', {'serverId': 's1'}));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsOneWidget);
    expect(find.text('5 minutes ago'), findsNWidgets(2));
    await tester.tap(find.text('Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsNothing);
    await tester.tap(find.text('Resolved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Peer reply'), findsOneWidget);
    final footer = find.text('Resolved by Developer · this minute');
    expect(footer, findsOneWidget);
    expect(
      tester.getTopLeft(footer).dy,
      greaterThan(tester.getBottomLeft(find.text('Peer reply')).dy),
    );
    await tester.tap(find.text('Reopen'));
    await tester.pumpAndSettle();
    expect(find.text('Resolved (1)'), findsNothing);
  });
  testWidgets('Escape leaves the comment list open after starting an edit', (
    tester,
  ) async {
    await open(tester, const Size(1200, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artifact-comment-more-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Initial comment'), findsOneWidget);
    expect(client.requests, isNot(contains('PATCH $_path/root')));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('retains a typed mention and retries a refused send', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'unrelated-previous-format': 'keep',
    });
    await DevicePreferences.load();
    client.answers['POST /mentions/audience'] = (_) => {
      'candidates': [
        {
          'id': 'a1',
          'type': 'agent',
          'name': 'helper',
          'displayName': 'Helper',
        },
      ],
    };
    client.answers['GET /artifacts/$artifactId/will-notify'] = (_) => {
      'recipients': [],
    };
    client.answers['POST $_path'] = (_) => RaftApiException.response(
      'Failed',
      status: 503,
      body: {'code': 'UNAVAILABLE'},
    );
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    await tester.enterText(composer, '@help');
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artifact-mention-a1')));
    await tester.pumpAndSettle();
    expect(find.text('Will notify: Helper'), findsNothing);
    expect(tester.getSemantics(composer).hint, contains('Will notify: Helper'));
    await tester.tap(find.byKey(const ValueKey('artifact-comments-close')));
    await tester.pumpAndSettle();
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    expect(find.text('@helper '), findsOneWidget);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't send the comment. Try again."), findsOneWidget);
    expect(
      client.bodies['POST $_path'],
      containsPair('body', [
        {
          'type': 'mention',
          'actor': {'type': 'agent', 'id': 'a1'},
        },
        {'type': 'text', 'text': ' '},
      ]),
    );
    expect(
      client.bodies['POST /mentions/audience'],
      containsPair('audience', {
        'kind': 'object',
        'app': 'artifacts',
        'objectKind': 'artifact',
        'objectId': artifactId,
      }),
    );
    client.answers['POST $_path'] = (_) => {
      'comment': comment('sent', 'Delivered'),
      'notified': [],
    };
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text("Couldn't send the comment. Try again."), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    await tester.tap(openComments);
    await tester.pumpAndSettle();
    expect(find.text('@helper '), findsNothing);
    expect(
      DevicePreferences.current!.getString('unrelated-previous-format'),
      'keep',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('flag off hides the discussion and skips its reads', (
    tester,
  ) async {
    client.enabled = false;
    await open(tester, const Size(1000, 850), TargetPlatform.linux);
    expect(openComments, findsNothing);
    expect(client.requests, isNot(contains('GET $_path')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
