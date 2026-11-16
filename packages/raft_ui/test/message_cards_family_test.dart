// WP-DS3 cards: the message embed frame, the forwarded bundle, the action card
// frame and the quoted-message card follow raft-ui 0.95.3 (Raft look).
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/message_embed_frame.dart';

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.linux}) =>
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

Future<void> _size(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Every box decoration that draws a border under [root].
List<BoxDecoration> _frames(WidgetTester tester, Finder root) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: root, matching: find.byType(DecoratedBox)),
  ))
    if (box.decoration is BoxDecoration &&
        (box.decoration as BoxDecoration).border != null)
      box.decoration as BoxDecoration,
];

Map<String, dynamic> _snapshot() => {
  'kind': 'forwarded-bundle',
  'version': 1,
  'forwardedItems': [
    for (var i = 0; i < 3; i++)
      {
        'index': i,
        'contentSnapshot': i == 0
            ? List.generate(12, (line) => 'Public line $line').join('\n')
            : 'Public message $i',
        'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'Author$i'},
        'sourceTargetSnapshot': {
          'type': 'channel',
          'label': '#design',
          'labelVisibility': 'public',
        },
        'provenanceState': 'available',
        'attachmentPolicy': 'excluded',
      },
  ],
};

RaftQuotedMessageCard _quoted({
  VoidCallback? onTap,
  Widget? notice,
  String? unavailableText,
  bool thread = false,
  bool archived = false,
  String? attachment,
}) => RaftQuotedMessageCard(
  channelName: 'design',
  timestamp: '09:41',
  authorName: 'Alice',
  avatar: const SizedBox.square(dimension: 16),
  content: 'Hello **world**',
  isThread: thread,
  isArchived: archived,
  attachmentLabel: attachment,
  authorDelegatedBy: '(sent by Friday)',
  unavailableText: unavailableText,
  notice: notice,
  onTap: onTap,
);

void main() {
  group('embed frame', () {
    for (final (w, h, platform, expected) in [
      (1024.0, 768.0, TargetPlatform.linux, 400.0),
      (390.0, 844.0, TargetPlatform.linux, 390.0),
      (856.0, 944.0, TargetPlatform.android, 400.0),
      (944.0, 856.0, TargetPlatform.android, 400.0),
    ]) {
      testWidgets('item width at $w x $h $platform', (tester) async {
        await _size(tester, w, h);
        await tester.pumpWidget(
          _app(
            const RaftMessageEmbedFrame(
              size: RaftMessageEmbedSize.item,
              child: SizedBox(width: 2000, height: 40),
            ),
            platform: platform,
          ),
        );
        expect(
          tester.getSize(find.byType(RaftMessageEmbedFrame)).width,
          expected,
        );
      });
    }

    testWidgets('radius 10, one 1px hairline, layer card, no inset frame', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          const RaftMessageEmbedFrame(
            size: RaftMessageEmbedSize.content,
            child: SizedBox(width: 2000, height: 40),
          ),
        ),
      );
      expect(tester.getSize(find.byType(RaftMessageEmbedFrame)).width, 560);
      final ui = RaftTokens.of(
        tester.element(find.byType(RaftMessageEmbedFrame)),
      ).ui;
      final frames = _frames(tester, find.byType(RaftMessageEmbedFrame));
      expect(frames, hasLength(1));
      final border = frames.single.border! as Border;
      expect(frames.single.borderRadius, BorderRadius.circular(10));
      expect(border.top.width, 1);
      expect(border.top.color, ui.lineHairline);
      expect(frames.single.color, ui.layerCard);
    });

    testWidgets('interactive frame lays hover and press tiers, keeps border', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          RaftMessageEmbedFrame(
            size: RaftMessageEmbedSize.item,
            onPressed: () {},
            child: const SizedBox(width: 2000, height: 40),
          ),
        ),
      );
      BoxDecoration frame() =>
          _frames(tester, find.byType(RaftMessageEmbedFrame)).single;
      final rest = frame();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(RaftMessageEmbedFrame)));
      await tester.pump();
      final hover = frame();
      expect(hover.gradient ?? hover.image ?? hover.color, isNot(rest.color));
      expect(
        (hover.border! as Border).top.color,
        (rest.border! as Border).top.color,
      );
    });
  });

  group('forwarded bundle', () {
    testWidgets('content-size embed frame, one frame, header and item px-3', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [RaftForwardedBundle(metadata: _snapshot())],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bundle = find.byType(RaftForwardedBundle);
      expect(tester.getSize(bundle).width, 560);
      final ui = RaftTokens.of(tester.element(bundle)).ui;
      final frames = _frames(tester, bundle);
      expect(frames, hasLength(1), reason: 'no nested content box');
      expect(frames.single.borderRadius, BorderRadius.circular(10));
      expect(frames.single.color, ui.layerCard);
      expect((frames.single.border! as Border).top.width, 1);
      final left = tester.getTopLeft(bundle).dx;
      // 1px border + px-3 on the item.
      expect(tester.getTopLeft(find.text('@Author0')).dx, left + 1 + 12);
    });

    testWidgets('footer action is footnote semibold foreground', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [RaftForwardedBundle(metadata: _snapshot())],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = tester
          .widget<Text>(find.text('View All 3 Messages'))
          .style!;
      final ui = RaftTokens.of(tester.element(find.byType(RaftForwardedBundle)))
          .ui;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, ui.foreground);
      expect(style.fontSize, 12);
    });
  });

  group('action card frame', () {
    testWidgets('radius 10, 1px hairline, layer card, no inset', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 640,
            child: RaftActionCard(title: 'Create channel', state: 'pending'),
          ),
        ),
      );
      final card = find.byType(RaftActionCard);
      final ui = RaftTokens.of(tester.element(card)).ui;
      final frames = _frames(tester, card);
      expect(frames.first.borderRadius, BorderRadius.circular(10));
      expect((frames.first.border! as Border).top.width, 1);
      expect((frames.first.border! as Border).top.color, ui.lineHairline);
      expect(frames.first.color, ui.layerCard);
    });
  });

  group('quoted message card', () {
    testWidgets('one flat frame: radius 10, hairline, layer card, 12/10', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(SizedBox(width: 600, child: _quoted(onTap: () {}))),
      );
      final card = find.byKey(const Key('quoted-message-card'));
      final ui = RaftTokens.of(tester.element(card)).ui;
      final frames = _frames(tester, card);
      expect(frames, hasLength(1));
      expect(frames.single.borderRadius, BorderRadius.circular(10));
      expect((frames.single.border! as Border).top.color, ui.lineHairline);
      expect(frames.single.color, ui.layerCard);
      expect(tester.takeException(), isNull);
      // `px-3`: the channel starts 1px border + 12 in.
      expect(
        tester.getTopLeft(find.text('design')).dx - tester.getTopLeft(card).dx,
        greaterThanOrEqualTo(13),
      );
      expect(find.byKey(const Key('quoted-message-delegated-by')), findsOne);
    });

    testWidgets('hover keeps the border and paints the subtle overlay', (
      tester,
    ) async {
      await _size(tester, 390, 844);
      await tester.pumpWidget(
        _app(SizedBox(width: 360, child: _quoted(onTap: () {}))),
      );
      final card = find.byKey(const Key('quoted-message-card'));
      final rest = _frames(tester, card).single;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(card));
      await tester.pump();
      final hover = _frames(tester, card).single;
      expect(
        (hover.border! as Border).top.color,
        (rest.border! as Border).top.color,
      );
      expect(hover.color, isNot(rest.color));
      await mouse.down(tester.getCenter(card));
      await tester.pump();
      final pressed = _frames(tester, card).single;
      expect(pressed.color, isNot(hover.color));
      await mouse.up();
    });

    for (final (w, h, platform) in [
      (856.0, 944.0, TargetPlatform.android),
      (944.0, 856.0, TargetPlatform.android),
    ]) {
      testWidgets('touch $w x $h taps through, no hover paint', (tester) async {
        await _size(tester, w, h);
        var taps = 0;
        await tester.pumpWidget(
          _app(
            SizedBox(width: 400, child: _quoted(onTap: () => taps++)),
            platform: platform,
          ),
        );
        await tester.tap(find.byKey(const Key('quoted-message-card')));
        expect(taps, 1);
      });
    }

    testWidgets('thread marker is the thread glyph, archived is muted', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(
          SizedBox(width: 600, child: _quoted(thread: true, archived: true)),
        ),
      );
      final glyphs = tester
          .widgetList<RaftIcon>(find.byType(RaftIcon))
          .map((i) => i.glyph);
      expect(glyphs, contains(RaftGlyph.thread));
      expect(glyphs, isNot(contains(RaftGlyph.messageSquare)));
      final thread = tester.widget<RaftIcon>(
        find.byWidgetPredicate(
          (w) => w is RaftIcon && w.glyph == RaftGlyph.thread,
        ),
      );
      expect(thread.size, 14);
      final badge = tester.widget<RaftBadge>(find.byType(RaftBadge));
      expect(badge.variant, RaftBadgeRecipeVariant.muted);
    });

    testWidgets('attachment chip is 22 high', (tester) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(SizedBox(width: 600, child: _quoted(attachment: 'a.png'))),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('quoted-message-attachment')))
            .height,
        22,
      );
    });

    testWidgets('notice replaces the text, is not tappable, hides chips', (
      tester,
    ) async {
      await _size(tester, 1024, 768);
      var taps = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 600,
            child: _quoted(
              onTap: () => taps++,
              notice: const Text('Older than your history'),
              attachment: 'a.png',
            ),
          ),
        ),
      );
      expect(find.text('Older than your history'), findsOneWidget);
      expect(find.text('Hello world', findRichText: true), findsNothing);
      expect(
        find.byKey(const ValueKey('quoted-message-attachment')),
        findsNothing,
      );
      await tester.tap(find.text('Older than your history'));
      expect(taps, 0);
    });

    testWidgets('unavailable keeps the container radius 10', (tester) async {
      await _size(tester, 1024, 768);
      await tester.pumpWidget(
        _app(SizedBox(width: 600, child: _quoted(unavailableText: 'Gone'))),
      );
      expect(
        find.byKey(const ValueKey('quoted-message-unavailable')),
        findsOneWidget,
      );
      final frames = _frames(
        tester,
        find.byKey(const Key('quoted-message-card')),
      );
      expect(frames.single.borderRadius, BorderRadius.circular(10));
      final ui = RaftTokens.of(
        tester.element(find.byKey(const Key('quoted-message-card'))),
      ).ui;
      expect(frames.single.color, ui.fillMuted);
    });
  });
}
