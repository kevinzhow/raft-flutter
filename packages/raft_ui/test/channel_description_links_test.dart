// Web ChannelDescription / ChatPanel regularTitleSuffix: the channel header
// renders http(s) links in the description as tappable links and shows the
// muted bell after the title.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/channel_description_links.dart';

RaftDescriptionSegment text(String v) => RaftDescriptionSegment.text(v);
RaftDescriptionSegment link(String v) => RaftDescriptionSegment.link(v);

void main() {
  group('segmentation (Web segmentChannelDescription)', () {
    test('keeps punctuation and rejects incomplete schemes', () {
      expect(
        raftSegmentChannelDescription(
          'See https://example.com/path?q=1，then http:// and https://.',
        ),
        [
          text('See '),
          link('https://example.com/path?q=1'),
          text('，then http:// and https://.'),
        ],
      );
    });

    test('a closing bracket without an opener is not part of the link', () {
      expect(
        raftSegmentChannelDescription(
          'Guide: https://docs.example.com/guide_(v2)). Ask in www.example.com.',
        ),
        [
          text('Guide: '),
          link('https://docs.example.com/guide_(v2)'),
          text('). Ask in www.example.com.'),
        ],
      );
    });

    test('a URL stops before adjacent CJK text and non-URL separators', () {
      for (final (description, linkText) in [
        ('https://raft.dev是官网', 'https://raft.dev'),
        ('链接https://raft.dev/docs、PRD', 'https://raft.dev/docs'),
        ('周报：https://notion.so/weekly|每周一更新', 'https://notion.so/weekly'),
        ('看 https://a.com——然后', 'https://a.com'),
        ('看 https://a.com…然后', 'https://a.com'),
      ]) {
        final segments = raftSegmentChannelDescription(description);
        expect(segments.where((s) => s.link).map((s) => s.value).toList(), [
          linkText,
        ], reason: description);
        expect(segments.map((s) => s.value).join(), description);
      }
    });

    test('plain text, empty text and several links', () {
      expect(raftSegmentChannelDescription('no links here'), [
        text('no links here'),
      ]);
      expect(raftSegmentChannelDescription(''), isEmpty);
      expect(
        raftSegmentChannelDescription('a http://one.io, b https://two.io!'),
        [
          text('a '),
          link('http://one.io'),
          text(', b '),
          link('https://two.io'),
          text('!'),
        ],
      );
    });
  });

  Widget host(Widget header) => MaterialApp(
    theme: raftTheme(RaftFamily.elegant),
    home: Scaffold(body: SizedBox(width: 700, child: header)),
  );

  testWidgets('a description link is tappable and reports its URL', (t) async {
    final opened = <String>[];
    await t.pumpWidget(
      host(
        RaftChannelHeader(
          name: 'docs',
          description: 'Read https://docs.example.com/guide first',
          onOpenLink: opened.add,
        ),
      ),
    );
    final meta = find.byKey(const ValueKey('channel-description-links'));
    expect(meta, findsOneWidget);
    await t.tapOnText(
      find.textRange.ofSubstring('https://docs.example.com/guide'),
    );
    expect(opened, ['https://docs.example.com/guide']);
    // Tapping the plain part does nothing.
    await t.tapOnText(find.textRange.ofSubstring('Read'));
    expect(opened, hasLength(1));
  });

  testWidgets('without a link handler the description is plain text', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const RaftChannelHeader(
          name: 'docs',
          description: 'Read https://docs.example.com/guide first',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('channel-description-links')),
      findsNothing,
    );
  });

  testWidgets('a muted channel shows the bell after the title, with Archived', (
    t,
  ) async {
    await t.pumpWidget(host(const RaftChannelHeader(name: 'docs')));
    expect(
      find.byKey(const ValueKey('channel-activity-muted-badge')),
      findsNothing,
    );
    await t.pumpWidget(
      host(
        const RaftChannelHeader(
          name: 'docs',
          mutedLabel: 'Activity muted. Direct mentions can still notify you.',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('channel-activity-muted-badge')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('channel-archived-badge')), findsNothing);
    await t.pumpWidget(
      host(
        const RaftChannelHeader(
          name: 'docs',
          archivedLabel: 'Archived',
          mutedLabel: 'Activity muted. Direct mentions can still notify you.',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('channel-activity-muted-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('channel-archived-badge')),
      findsOneWidget,
    );
    // The bell sits right of the Archived badge.
    expect(
      t
          .getTopLeft(
            find.byKey(const ValueKey('channel-activity-muted-badge')),
          )
          .dx,
      greaterThan(
        t.getTopRight(find.byKey(const ValueKey('channel-archived-badge'))).dx,
      ),
    );
  });
}
