import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_row_recipe.dart';
import 'package:raft_ui/src/recipe_surface.dart';
import 'package:raft_ui/src/recipes/message_item.g.dart';
import 'package:raft_ui/src/recipes/recipe_runtime.dart';
import 'package:raft_ui/src/theme.dart';
import 'package:raft_ui/test_themes.dart';

const avatarKey = Key('public-avatar');
const bodyKey = Key('public-body');
const actionKey = Key('public-thread-action');

Widget host(
  RaftFamily family, {
  bool dark = false,
  bool continuation = false,
  bool coarse = false,
  bool popup = false,
  VoidCallback? action,
  double width = 390,
}) {
  return MaterialApp(
    theme: raftTheme(family, dark: dark),
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
                    label: 'Reply in thread',
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
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ], full: true)) {
    testWidgets(
      'header gives up space in the Web order: description, model, name; the clock stays $family/$dark',
      (tester) async {
        var mentions = 0;
        Widget frame(double width) => MaterialApp(
          theme: raftTheme(family, dark: dark),
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
          closeTo(
            tester.getTopRight(author).dx +
                (family == RaftFamily.brutal ? 8 : 6),
            .01,
          ),
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
      'mounted avatar and content origins match source $family/$dark',
      (tester) async {
        await tester.pumpWidget(host(family, dark: dark));
        final brutal = family == RaftFamily.brutal;
        // Web v1.21.12 (raft-ui 0.5.52): the avatar reads 28 below 768
        // (32 above), centred in the 32/36 slot; brutal has no row margin
        // and shifts the image 3px down (`--mi-avatar-shift`).
        expect(tester.getSize(find.byKey(avatarKey)), const Size(28, 28));
        expect(
          tester.getTopLeft(find.byKey(avatarKey)),
          Offset(brutal ? 10 : 10, brutal ? 17 : 16),
        );
        expect(tester.getTopLeft(find.byKey(bodyKey)).dx, brutal ? 52 : 48);
        final body = tester.widget<Text>(find.byKey(bodyKey));
        expect(body.style, isNull);
        final resolved = DefaultTextStyle.of(
          tester.element(find.byKey(bodyKey)),
        ).style;
        expect(resolved.fontSize, 14);
        expect(resolved.height, 20 / 14);
        expect(
          resolved.fontFamily,
          RaftTokens.of(tester.element(find.byKey(bodyKey))).headingFont,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mounted avatar and content origins at desktop width $family/$dark',
      (tester) async {
        await tester.pumpWidget(host(family, dark: dark, width: 1280));
        final brutal = family == RaftFamily.brutal;
        expect(tester.getSize(find.byKey(avatarKey)), const Size(32, 32));
        expect(
          tester.getTopLeft(find.byKey(avatarKey)),
          Offset(brutal ? 10 : 10, brutal ? 17 : 20),
        );
        expect(tester.getTopLeft(find.byKey(bodyKey)).dx, brutal ? 56 : 56);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hover and keyboard focus reveal the source strip $family/$dark',
      (tester) async {
        var activated = 0;
        await tester.pumpWidget(
          host(family, dark: dark, action: () => activated++),
        );
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
        expect(
          tester.getSize(button),
          Size.square(family == RaftFamily.brutal ? 24 : 28),
        );
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
      },
    );
  }

  testWidgets('coarse pointer hides strip at both mobile and desktop widths', (
    tester,
  ) async {
    for (final width in [390.0, 1280.0]) {
      await tester.pumpWidget(
        host(RaftFamily.elegant, width: width, coarse: true),
      );
      expect(find.byType(RaftMessageToolbar), findsNothing);
      expect(find.byKey(bodyKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'continuation omits avatar/header but keeps body and hidden gutter clock',
    (tester) async {
      await tester.pumpWidget(host(RaftFamily.elegant, continuation: true));
      expect(find.byKey(avatarKey), findsNothing);
      expect(find.text('Public Agent'), findsNothing);
      expect(find.text('14:30'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(bodyKey)), const Offset(48, 7));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('popup retains strip without hover or keyboard focus', (
    tester,
  ) async {
    await tester.pumpWidget(host(RaftFamily.elegant, popup: true));
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
          theme: raftTheme(RaftFamily.elegant),
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

  // The recipe is hand-written (it carries the mounted MessageItem.tsx
  // overrides); every geometry value it owns is pinned to the generated raft-ui
  // 0.5.52 `messageItem` recipe, so a raft-ui upgrade cannot drift silently.
  for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
    test('row geometry equals the generated messageItem recipe $family', () {
      final t = raftTheme(family).extension<RaftTokens>()!;
      final theme = family == RaftFamily.brutal
          ? RaftRecipeTheme.brutal
          : RaftRecipeTheme.elegant;
      for (final width in [390.0, 767.0, 768.0, 1280.0]) {
        for (final continuation in [false, true]) {
          for (final followedBy in [null, ...RaftMessageFollowedBy.values]) {
            for (final followsSystem in [false, true]) {
              final label =
                  '$family width=$width continuation=$continuation '
                  'followedBy=$followedBy followsSystem=$followsSystem';
              final recipe = RaftMessageRowRecipe(
                t,
                viewportWidth: width,
                continuation: continuation,
                followedBy: followedBy,
                followsSystem: followsSystem,
              );
              final s = RaftMessageItemRecipe.resolve(
                theme: theme,
                compact: continuation,
                states: RaftRecipeStates({
                  if (followedBy != null) 'data-followed-by=${followedBy.name}',
                  if (followsSystem) 'data-follows-system',
                }, width),
                tokens: t.recipeTokens,
              );
              expect(recipe.padding, s.root.padding, reason: label);
              expect(recipe.margin, s.root.margin, reason: label);
              expect(recipe.gap, s.root.columnGap, reason: label);
              expect(recipe.minimumHeight, s.root.minHeight, reason: label);
              expect(recipe.borderWidth, s.root.borderWidth.top, reason: label);
              expect(recipe.gutterWidth, s.gutter.width, reason: label);
              expect(recipe.gutterWidth, s.avatarSlot.width, reason: label);
              final avatar = s.avatarSlot.target(
                '& [data-slot=avatar][data-size=md]',
              )!;
              expect(recipe.avatarExtent, avatar.width, reason: label);
              expect(recipe.avatarExtent, avatar.height, reason: label);
              expect(recipe.avatarTop - 2, avatar.margin.top, reason: label);
              expect(recipe.headerGap, s.header.columnGap, reason: label);
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
    final t = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
    RaftMessageRowRecipe at(RaftMessageSizeTier tier, double width) =>
        RaftMessageRowRecipe(t, viewportWidth: width, sizeTier: tier);
    // Name 12/14/16, meta and time 11/12/14.
    expect([for (final x in RaftMessageSizeTier.values) x.name], [12, 14, 16]);
    expect([for (final x in RaftMessageSizeTier.values) x.meta], [11, 12, 14]);
    expect(at(RaftMessageSizeTier.sm, 1280).author.fontSize, 12);
    expect(at(RaftMessageSizeTier.lg, 1280).time.fontSize, 14);
    // `--mi-avatar` 2rem, 34px on the large tier; `--mi-avatar-narrow` 28.
    expect(at(RaftMessageSizeTier.md, 1280).avatarExtent, 32);
    expect(at(RaftMessageSizeTier.lg, 1280).avatarExtent, 34);
    expect(at(RaftMessageSizeTier.lg, 390).avatarExtent, 28);
  });

  test('header reserve, name weight and toolbar edge follow v1.21.12', () {
    final b = raftTheme(RaftFamily.brutal).extension<RaftTokens>()!;
    final e = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
    RaftMessageRowRecipe row(RaftTokens t, double w, [bool thread = false]) =>
        RaftMessageRowRecipe(
          t,
          viewportWidth: w,
          rowContext: thread
              ? RaftMessageRowContext.thread
              : RaftMessageRowContext.main,
        );
    // `--mi-hdr-pr: 2.5rem` on the thread panel's row wrapper.
    expect(row(e, 1280).headerReserve, 96);
    expect(row(e, 1280, true).headerReserve, 40);
    expect(row(e, 390, true).headerReserve, 40);
    // Elegant sender 600 (was 500); brutal stays 700.
    expect(row(e, 1280).author.fontWeight, FontWeight.w600);
    expect(row(b, 1280).author.fontWeight, FontWeight.w700);
    // Elegant notes (meta, time) read `foreground-hint`.
    expect(row(e, 1280).time.color, e.colors['foreground-hint']);
    // MessageHoverToolbar `right-2`, `max-md:right-0.5`, brutal `-right-1.5`.
    expect(row(e, 1280).toolbarRight, 8);
    expect(row(b, 1280).toolbarRight, 8);
    expect(row(e, 390).toolbarRight, 2);
    expect(row(b, 390).toolbarRight, -6);
  });

  test('the content ends with Web\'s mb-px only where the Web adds it', () {
    final t = raftTheme(RaftFamily.elegant).extension<RaftTokens>()!;
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

  testWidgets(
    'a followed-by row collapses its body margin and bottom padding',
    (tester) async {
      Future<double> height(RaftMessageFollowedBy? followedBy) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
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
      // Elegant wide: padding-bottom 12 + body margin 6 at the list end,
      // 2 + 0 before a continuation, 6 + 0 before a new group.
      expect(last - compact, 16);
      expect(last - group, 12);
    },
  );
}
