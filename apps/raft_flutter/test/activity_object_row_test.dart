import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/activity_object_row.dart';
import 'package:raft_flutter/features/activity_object_text.dart';
import 'package:raft_flutter/features/activity_row_host.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/activity_row_harness.dart';

// C40: an Artifact's Activity row (Web `ObjectInboxRow.tsx`,
// `artifactActivityRow.ts`). There is no live object row in the fixture, so the
// rows here are built from the shared contract's fields (`activityObjectsContract`).
Map<String, dynamic> objectRow({
  String eventKind = 'comment',
  String reason = 'following',
  Map<String, dynamic>? preview,
  Map<String, dynamic>? target,
  int unread = 0,
  Map<String, dynamic>? unreadParts,
  bool mention = false,
  Map<String, dynamic>? home,
  String? title = 'Q4 roadmap',
}) => {
  'kind': 'object',
  'objectKind': 'artifact',
  'objectId': 'art1',
  'summary': {'title': title, 'kind': 'html', 'latestVersion': 3},
  'home': home ?? {'kind': 'channel', 'label': 'launch-week', 'channelId': 'c1'},
  'latestEvent': {
    'eventKind': eventKind,
    'reason': reason,
    'actor': {'type': 'user', 'id': 'u2', 'name': 'Judith'},
    'at': '2026-11-17T15:20:00',
  },
  'preview': preview,
  'target': target,
  'unreadCount': unread,
  'unreadParts': unreadParts,
  'hasMention': mention,
  'isFollowing': true,
  'lastActivityAt': fixedNow
      .subtract(const Duration(minutes: 12))
      .toString()
      .replaceFirst(' ', 'T'),
  'doneFrontierSeq': '9',
};

Future<void> _pump(
  WidgetTester tester,
  RowFixture f,
  Map<String, dynamic> row, {
  bool dark = false,
  ActivityRowHost? host,
  Size size = const Size(1440, 900),
  TargetPlatform platform = TargetPlatform.linux,
  // The test font is a full em wide: the line needs room to show its home.
  double width = 900,
}) async {
  useFixedClock();
  await pumpRowApp(
    tester,
    ActivityObjectRow(row: row, host: host ?? f.host()),
    dark: dark,
    size: size,
    platform: platform,
    width: width,
  );
}

String _label(WidgetTester tester) =>
    tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).semanticLabel;

void main() {
  group('sentence and excerpt (artifactActivityRow.ts)', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$mode a comment with text: "{actor}: {text}", the home after', (
        tester,
      ) async {
        final f = RowFixture();
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          objectRow(preview: {'text': 'Can you check row 3?', 'truncated': false}),
          dark: dark,
        );
        expect(find.text('Q4 roadmap'), findsOneWidget);
        expect(find.text('Judith: '), findsOneWidget);
        expect(find.text('Can you check row 3?'), findsOneWidget);
        expect(find.text('#launch-week'), findsNothing);
        expect(find.text('· #launch-week'), findsOneWidget);
        expect(
          _label(tester),
          'Q4 roadmap Judith: Can you check row 3? · #launch-week 12 minutes ago',
        );
      });

      testWidgets('$mode a comment of images alone says "Image" / "3 images"', (
        tester,
      ) async {
        final f = RowFixture();
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          objectRow(preview: {'text': '', 'images': 1}),
          dark: dark,
        );
        expect(find.text('Image'), findsOneWidget);
        await _pump(
          tester,
          f,
          objectRow(preview: {'text': '', 'images': 3}),
          dark: dark,
        );
        expect(find.text('3 images'), findsOneWidget);
      });
    }

    testWidgets('no preview: the sentence per event kind', (tester) async {
      final f = RowFixture();
      addTearDown(f.dispose);
      for (final (row, sentence) in [
        (objectRow(reason: 'mentioned'), 'Judith mentioned you'),
        (objectRow(), 'Judith commented'),
        (objectRow(eventKind: 'comment_edited'), 'Judith edited a comment'),
        (objectRow(eventKind: 'version', target: {'version': 4}), 'Judith published v4'),
        (
          {...objectRow(eventKind: 'version'), 'summary': {'title': 'T', 'kind': 'html'}},
          'Judith published a new version',
        ),
        (objectRow(eventKind: 'other'), 'Judith updated it'),
        (
          objectRow(eventKind: 'review', target: {'review': {'id': 'r1', 'comments': 3}}),
          'Judith reviewed it (3 comments)',
        ),
        (
          objectRow(
            eventKind: 'review',
            reason: 'mentioned',
            target: {'review': {'id': 'r1', 'comments': 1}},
          ),
          'Judith mentioned you in a review (1 comment)',
        ),
      ]) {
        await _pump(tester, f, row);
        expect(find.text(sentence), findsOneWidget, reason: sentence);
      }
    });

    test('news: only what the line does not already say', () {
      // New comments alone: the newest one's text, then the count when more.
      final one = objectRow(
        preview: {'text': 'hi'},
        unread: 1,
        unreadParts: {'versions': 0, 'comments': 1},
      );
      expect(artifactActivityNews(one), isEmpty);
      final three = objectRow(
        preview: {'text': 'hi'},
        unread: 3,
        unreadParts: {'versions': 0, 'comments': 3},
      );
      expect(artifactActivityNews(three), [(part: 'comments', count: 3)]);
      // New versions alone: the line says the version.
      final version = objectRow(
        eventKind: 'version',
        unread: 1,
        unreadParts: {'versions': 1, 'comments': 0},
      );
      expect(artifactActivityNews(version), isEmpty);
      // Both: the comment leads, then "1 new version".
      final both = objectRow(
        eventKind: 'version',
        preview: {'text': 'see v4'},
        unread: 2,
        unreadParts: {'versions': 1, 'comments': 1},
      );
      expect(artifactActivityExcerpt(both), isNotNull);
      expect(artifactActivityNews(both), [(part: 'versions', count: 1)]);
      // A read row, or a server that does not split it, adds nothing.
      expect(artifactActivityNews(objectRow(unread: 0)), isEmpty);
      expect(artifactActivityNews(objectRow(unread: 2)), isEmpty);
    });

    testWidgets('"· 3 new comments" after the line, the count and @ in the marks', (
      tester,
    ) async {
      final f = RowFixture();
      addTearDown(f.dispose);
      await _pump(
        tester,
        f,
        objectRow(
          preview: {'text': 'hi'},
          unread: 3,
          unreadParts: {'versions': 0, 'comments': 3},
          mention: true,
        ),
      );
      expect(find.text('· 3 new comments'), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-mention-badge')), findsOneWidget);
      final count = find.byKey(const ValueKey('conversation-card-new-badge'));
      expect(find.descendant(of: count, matching: find.text('3')), findsOneWidget);
      expect(tester.widget<RaftInboxItem>(find.byType(RaftInboxItem)).unread, isTrue);
    });

    testWidgets('no home for a server, public or deleted conversation; DM home is @peer', (
      tester,
    ) async {
      final f = RowFixture();
      addTearDown(f.dispose);
      await _pump(tester, f, objectRow(home: {'kind': 'server', 'label': ''}));
      expect(find.byKey(const ValueKey('object-card-home')), findsNothing);
      await _pump(
        tester,
        f,
        objectRow(home: {'kind': 'dm', 'label': 'bob', 'peerDisplayName': 'Bobby'}),
      );
      expect(find.text('· @Bobby'), findsOneWidget);
    });

    testWidgets('an untitled Artifact', (tester) async {
      final f = RowFixture();
      addTearDown(f.dispose);
      await _pump(tester, f, objectRow(title: '  '));
      expect(find.text('Untitled Artifact'), findsOneWidget);
    });
  });

  group('actions', () {
    for (final (name, size, platform) in rowEnvs) {
      final touch = platform == TargetPlatform.android;
      testWidgets('$name: Done only; open asks the host; no read toggle', (
        tester,
      ) async {
        final f = RowFixture();
        addTearDown(f.dispose);
        await _pump(
          tester,
          f,
          objectRow(unread: 1),
          host: f.host(withObjectOpen: true),
          size: size,
          platform: platform,
        );
        final phone = touch && size.width == 390;
        expect(find.byType(RaftInboxRowDone), phone ? findsNothing : findsOneWidget);
        expect(
          find.byKey(const ValueKey('activity-object-art1')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('inbox-item-open')));
        await tester.pump();
        expect(f.calls.objects.single['objectId'], 'art1');
        expect(f.calls.opened, 0);
        if (!phone) {
          expect(
            tester.widget<RaftInboxRowDone>(find.byType(RaftInboxRowDone)).semanticLabel,
            'Mark Q4 roadmap as Done',
          );
        }
      });
    }

    testWidgets('without an object opener the page\'s open runs', (tester) async {
      final f = RowFixture();
      addTearDown(f.dispose);
      await _pump(tester, f, objectRow());
      await tester.tap(find.byKey(const ValueKey('inbox-item-open')));
      await tester.pump();
      expect(f.calls.opened, 1);
    });
  });

  group('narrow line', () {
    testWidgets('home truncates first, then the text to about a dozen characters', (
      tester,
    ) async {
      useFixedClock();
      final f = RowFixture();
      addTearDown(f.dispose);
      final row = objectRow(
        preview: {'text': 'Check the numbers'},
        home: {'kind': 'channel', 'label': 'channel-name'},
      );
      double widthOf(String key) => tester.getSize(find.byKey(ValueKey(key))).width;
      Future<void> at(double width) => pumpRowApp(
        tester,
        ActivityObjectRow(row: row, host: f.host()),
        width: width,
        size: const Size(1000, 600),
      );
      await at(800);
      final fullText = widthOf('object-card-text');
      final fullHome = widthOf('object-card-home');
      await at(520);
      expect(widthOf('object-card-home'), lessThan(fullHome));
      expect(widthOf('object-card-text'), fullText);
      await at(420);
      expect(find.byKey(const ValueKey('object-card-home')), findsNothing);
      // 12 characters at least, down from the text's own width.
      expect(widthOf('object-card-text'), lessThan(fullText));
      expect(widthOf('object-card-text'), greaterThanOrEqualTo(12 * 14));
    });
  });
}
