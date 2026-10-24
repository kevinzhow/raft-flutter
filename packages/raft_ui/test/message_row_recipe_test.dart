import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_body.dart' show raftBodyEndsInCode;
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/test_themes.dart';

const avatarKey = Key('public-avatar');
const bodyKey = Key('public-body');
const actionKey = Key('public-thread-action');

Widget host({
  bool dark = false,
  bool continuation = false,
  bool coarse = false,
  bool popup = false,
  VoidCallback? action,
  double width = 390,
}) {
  return MaterialApp(
    theme: raftTheme(dark: dark),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 480), devicePixelRatio: 1),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: RaftMessageRow(
              author: 'Public Agent',
              timestamp: '14:30',
              continuation: continuation,
              coarsePointer: coarse,
              popupOpen: popup,
              avatar: const ColoredBox(key: avatarKey, color: Colors.blue),
              content: const Text('Public body', key: bodyKey),
              toolbar: RaftMessageToolbar(
                children: [
                  RaftMessageToolbarAction(
                    key: actionKey,
                    label: 'Reply in Thread',
                    icon: const SizedBox(),
                    onPressed: action ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    testWidgets(
      'header gives up space in the Web order: description, model, name; the clock stays $dark',
      (tester) async {
        var mentions = 0;
        Widget frame(double width) => MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: RaftMessageRow(
                  author: 'Cindy',
                  timestamp: '10:30',
                  onAuthor: () => mentions++,
                  metadata: const SizedBox(
                    key: Key('model'),
                    width: 120,
                    height: 14,
                  ),
                  subtitle: 'Long private description',
                  content: const Text('Body'),
                ),
              ),
            ),
          ),
        );
        double width(Finder finder) => tester.getSize(finder).width;
        final author = find.text('Cindy');
        final time = find.text('10:30');
        final model = find.byKey(const Key('model'));
        final description = find.text('Long private description');
        await tester.pumpWidget(frame(700));
        final naturalAuthorWidth = tester
            .renderObject<RenderBox>(author)
            .getMaxIntrinsicWidth(double.infinity);
        final naturalTimeWidth = tester
            .renderObject<RenderBox>(time)
            .getMaxIntrinsicWidth(double.infinity);
        expect(width(author), naturalAuthorWidth);
        expect(width(model), 120);
        expect(width(description), greaterThan(0));
        // Brutal 8, elegant 6 between the header items.
        expect(
          tester.getTopLeft(model).dx,
          closeTo(tester.getTopRight(author).dx + (6), .01),
        );
        await tester.tap(author);
        await tester.pump();
        expect(mentions, 1);

        // Narrower: the description goes first. Name and model keep their
        // size while the model still fits.
        var narrow = 700.0;
        while (width(description) > 0 && narrow > 200) {
          narrow -= 2;
          await tester.pumpWidget(frame(narrow));
        }
        expect(width(description), 0);
        expect(width(model), closeTo(120, 2.1)); // at most one step short
        expect(width(author), naturalAuthorWidth);

        // Then the model truncates; the name is untouched until it is gone.
        while (width(model) == 120 && narrow > 100) {
          narrow -= 5;
          await tester.pumpWidget(frame(narrow));
        }
        expect(width(model), lessThan(120));
        expect(width(author), naturalAuthorWidth);

        // Finally the name truncates (an ellipsis). The clock is never
        // shortened (Web `shrink-0`).
        while (width(model) > 0 && narrow > 40) {
          narrow -= 5;
          await tester.pumpWidget(frame(narrow));
        }
        while (width(author) == naturalAuthorWidth && narrow > 40) {
          narrow -= 2;
          await tester.pumpWidget(frame(narrow));
        }
        expect(width(model), 0);
        expect(width(author), lessThan(naturalAuthorWidth));
        expect(width(time), naturalTimeWidth);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mounted avatar and content origins match source ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(host(dark: dark));
        // Web v1.21.23 px-2/gap-3 and its default 35px avatar/slot.
        expect(tester.getSize(find.byKey(avatarKey)), const Size(35, 35));
        expect(tester.getTopLeft(find.byKey(avatarKey)), const Offset(8, 10));
        expect(tester.getTopLeft(find.byKey(bodyKey)).dx, 55);
        final body = tester.widget<Text>(find.byKey(bodyKey));
        expect(body.style, isNull);
        final resolved = DefaultTextStyle.of(
          tester.element(find.byKey(bodyKey)),
        ).style;
        expect(resolved.fontSize, 16);
        expect(resolved.height, 24 / 16);
        expect(
          resolved.fontFamily,
          RaftTokens.of(tester.element(find.byKey(bodyKey))).headingFont,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('mounted avatar and content origins at desktop width $dark', (
      tester,
    ) async {
      await tester.pumpWidget(host(dark: dark, width: 1280));
      expect(tester.getSize(find.byKey(avatarKey)), const Size(35, 35));
      expect(tester.getTopLeft(find.byKey(avatarKey)), const Offset(8, 10));
      expect(tester.getTopLeft(find.byKey(bodyKey)).dx, 55);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hover and keyboard focus reveal the source strip $dark', (
      tester,
    ) async {
      var activated = 0;
      await tester.pumpWidget(host(dark: dark, action: () => activated++));
      Opacity strip() => tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(RaftMessageToolbar),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(find.byType(RaftMessageToolbar), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(2, 300));
      await mouse.moveTo(tester.getCenter(find.byKey(bodyKey)));
      await tester.pump();
      expect(strip().opacity, 1);
      final button = find.byKey(actionKey);
      // raft-ui 0.7 messageItem `toolbarButton`: `size-8`.
      expect(tester.getSize(button), Size.square(32));
      await mouse.moveTo(const Offset(2, 300));
      await tester.pump();
      expect(find.byType(RaftMessageToolbar), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(strip().opacity, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('coarse pointer hides strip at both mobile and desktop widths', (
    tester,
  ) async {
    for (final width in [390.0, 1280.0]) {
      await tester.pumpWidget(host(width: width, coarse: true));
      expect(find.byType(RaftMessageToolbar), findsNothing);
      expect(find.byKey(bodyKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'continuation omits avatar/header but keeps body and hidden gutter clock',
    (tester) async {
      await tester.pumpWidget(host(continuation: true));
      expect(find.byKey(avatarKey), findsNothing);
      expect(find.text('Public Agent'), findsNothing);
      expect(find.text('14:30'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(bodyKey)), const Offset(55, 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('popup retains strip without hover or keyboard focus', (
    tester,
  ) async {
    await tester.pumpWidget(host(popup: true));
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(RaftMessageToolbar),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long author stays one header line rather than wrapping metadata',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 390,
              child: RaftMessageRow(
                author: 'Public long author with more characters than the reserved heading can hold',
                timestamp: '14:30',
                content: Text('Body'),
              ),
            ),
          ),
        ),
      );
      final author = tester.widget<Text>(
        find.text(
          'Public long author with more characters than the reserved heading can hold',
        ),
      );
      expect(author.maxLines, 1);
      expect(author.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  // v1.21.23 source: messageItem recipe index.mjs:6596. Group markers
  // still drive body/attachment semantics, but do not add old root padding.
  for (final dark in [false, true]) {
    test('row geometry follows the v1.21.23 messageItem source $dark', () {
      final t = raftTheme(dark: dark).extension<RaftTokens>()!;
      for (final width in [390.0, 767.0, 768.0, 1280.0]) {
        for (final continuation in [false, true]) {
          for (final followedBy in [null, ...RaftMessageFollowedBy.values]) {
            for (final followsSystem in [false, true]) {
              final label =
                  '$dark $width $continuation $followedBy $followsSystem';
              final recipe = RaftMessageRowRecipe(
                t,
                viewportWidth: width,
                continuation: continuation,
                followedBy: followedBy,
                followsSystem: followsSystem,
              );
              expect(
                recipe.padding,
                EdgeInsets.fromLTRB(8, continuation ? 0 : 8, 8, 8),
                reason: label,
              );
              expect(recipe.margin, EdgeInsets.zero, reason: label);
              expect(recipe.gap, 12, reason: label);
              expect(recipe.minimumHeight, 0, reason: label);
              expect(recipe.borderWidth, 0, reason: label);
              expect(recipe.gutterWidth, 35, reason: label);
              expect(recipe.avatarExtent, 35, reason: label);
              expect(recipe.avatarTop, 2, reason: label);
              expect(recipe.headerGap, 6, reason: label);
            }
          }
        }
      }
    });
  }

  test('sizing tiers follow the reader\'s message size', () {
    expect(RaftMessageSizeTier.of(12), RaftMessageSizeTier.sm);
    expect(RaftMessageSizeTier.of(14), RaftMessageSizeTier.md);
    expect(RaftMessageSizeTier.of(16), RaftMessageSizeTier.lg);
    final t = raftTheme().extension<RaftTokens>()!;
    RaftMessageRowRecipe at(RaftMessageSizeTier tier, double width) =>
        RaftMessageRowRecipe(t, viewportWidth: width, sizeTier: tier);
    // Name 12/14/16, meta and time 11/12/14.
    expect([for (final x in RaftMessageSizeTier.values) x.name], [12, 14, 16]);
    expect([for (final x in RaftMessageSizeTier.values) x.meta], [11, 12, 14]);
    expect(at(RaftMessageSizeTier.sm, 1280).author.fontSize, 13);
    expect(at(RaftMessageSizeTier.lg, 1280).time.fontSize, 13);
    // Native recipe defaults35; MessageItem.tsx overrides only lg to34.
    expect(at(RaftMessageSizeTier.md, 1280).avatarExtent, 35);
    expect(at(RaftMessageSizeTier.lg, 1280).avatarExtent, 34);
    expect(at(RaftMessageSizeTier.lg, 390).avatarExtent, 34);
  });

  test('native header source and existing toolbar boundary', () {
    final b = raftTheme().extension<RaftTokens>()!;
    final e = raftTheme().extension<RaftTokens>()!;
    RaftMessageRowRecipe row(RaftTokens t, double w, [bool thread = false]) =>
        RaftMessageRowRecipe(
          t,
          viewportWidth: w,
          rowContext: thread
              ? RaftMessageRowContext.thread
              : RaftMessageRowContext.main,
        );
    // 0.7 header has no reserved padding; timestamp uses ml-auto.
    expect(row(e, 1280).headerReserve, 0);
    expect(row(e, 1280, true).headerReserve, 0);
    expect(row(e, 390, true).headerReserve, 0);
    // Current Web sender is 700; legacy families are covered separately.
    expect(row(e, 1280).author.fontWeight, FontWeight.w700);
    expect(row(b, 1280).author.fontWeight, FontWeight.w700);
    // Elegant notes (meta, time) read `foreground-hint`.
    expect(row(e, 1280).time.color, e.colors['foreground-hint']);
    // Raft: raft-ui 0.7 messageItem toolbar `right-3`. Legacy looks:
    // MessageHoverToolbar `right-2`, `max-md:right-0.5`, brutal `-right-1.5`.
    expect(row(e, 1280).toolbarRight, 12);
    expect(row(b, 1280).toolbarRight, 12);
    expect(row(e, 390).toolbarRight, 12);
    expect(row(b, 390).toolbarRight, 12);
  });

  test('the content ends with Web\'s mb-px only where the Web adds it', () {
    final t = raftTheme().extension<RaftTokens>()!;
    bool px(
      RaftMessageFollowedBy? followedBy, {
      bool attachments = false,
      bool translation = false,
      bool footer = false,
      bool inlineReplies = false,
    }) => RaftMessageRowRecipe(t, viewportWidth: 1280, followedBy: followedBy)
        .trailingPixel(
          attachments: attachments,
          translation: translation,
          footer: footer,
          inlineReplies: inlineReplies,
        );
    expect(px(null, inlineReplies: true), isTrue);
    expect(px(null, footer: true), isFalse);
    expect(px(RaftMessageFollowedBy.group, footer: true), isTrue);
    expect(px(RaftMessageFollowedBy.compact, attachments: true), isTrue);
    expect(px(null, attachments: true), isFalse);
    expect(
      px(RaftMessageFollowedBy.group, attachments: true, translation: true),
      isFalse,
    );
    expect(px(RaftMessageFollowedBy.group), isFalse);
  });

  testWidgets('native followed-by markers retain the uniform root spacing', (
    tester,
  ) async {
    Future<double> height(RaftMessageFollowedBy? followedBy) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 480)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  child: RaftMessageRow(
                    author: 'Cindy',
                    timestamp: '14:30',
                    followedBy: followedBy,
                    content: const Text('Body', key: bodyKey),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(RaftMessageRow)).height;
    }

    final last = await height(null);
    final compact = await height(RaftMessageFollowedBy.compact);
    final group = await height(RaftMessageFollowedBy.group);
    // Native body has no generic bottom margin and root py-2 is uniform.
    expect(last - compact, 0);
    expect(last - group, 0);
  });

  test('a followed body that ends in code keeps Web mb-px', () {
    final t = raftTheme().extension<RaftTokens>()!;
    RaftMessageRowRecipe recipe(RaftMessageFollowedBy? by, bool code) =>
        RaftMessageRowRecipe(
          t,
          viewportWidth: 1280,
          followedBy: by,
          bodyEndsInCode: code,
        );
    expect(recipe(RaftMessageFollowedBy.compact, true).bodyBottomGap, 1);
    expect(recipe(RaftMessageFollowedBy.group, true).bodyBottomGap, 1);
    expect(recipe(RaftMessageFollowedBy.compact, false).bodyBottomGap, 0);
    // Only the mounted followed-by code-tail override contributes1px.
    expect(recipe(null, true).bodyBottomGap, 0);
  });

  test('raftBodyEndsInCode follows the last block', () {
    expect(raftBodyEndsInCode('Text\n\n```dart\nvar a;\n```\n'), isTrue);
    expect(raftBodyEndsInCode('```\ncode\n```'), isTrue);
    expect(raftBodyEndsInCode('```\ncode\n```\n\nafter'), isFalse);
    expect(raftBodyEndsInCode('plain text'), isFalse);
    expect(raftBodyEndsInCode('```mermaid\ngraph TD\n```'), isFalse);
    expect(raftBodyEndsInCode(''), isFalse);
  });
}
