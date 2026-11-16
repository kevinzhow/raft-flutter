import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// WP-DS5 data display, raft-ui 0.95.3: Status md is 10px with `primary` = presence-busy; Badge soft / outline
// follow `md:pointer-fine` (20px / sticker with a mouse from 768, 22px / chip otherwise) and solid stays h-5
// sticker; Badge `you` / `busy`; IconTile radius per size; Avatar xs / 2xs badge 7px; Card parts.
const _devices = [
  (TargetPlatform.linux, Size(1024, 768), true),
  (TargetPlatform.android, Size(856, 944), false),
  (TargetPlatform.android, Size(944, 856), false),
  (TargetPlatform.linux, Size(390, 844), false),
];

Future<void> _pump(
  WidgetTester t,
  Widget child, {
  TargetPlatform platform = TargetPlatform.linux,
  Size size = const Size(1024, 768),
  bool dark = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

RaftCssBox _box(WidgetTester t, Finder within) => t.widget<RaftCssBox>(
  find.descendant(of: within, matching: find.byType(RaftCssBox)).first,
);

void main() {
  group('status', () {
    testWidgets('md is the 10px pixel, radius 2, border 1.5', (t) async {
      await _pump(t, const RaftStatus());
      expect(t.getSize(find.byType(RaftStatus)), const Size.square(10));
      expect(RaftStatusSize.md.px, 10);
      expect(RaftStatusSize.md.radius, 2);
      expect(RaftStatusSize.md.border, 1.5);
      expect(RaftStatusDotSize.md.px, 10);
    });

    testWidgets('variant primary is the presence-busy token', (t) async {
      expect(RaftStatusVariant.primary.token, 'presence-busy');
      await _pump(t, const RaftStatus(variant: RaftStatusVariant.primary));
      final ui = RaftUiColors.of(false);
      expect(_box(t, find.byType(RaftStatus)).fill, ui['presence-busy']);
    });

    testWidgets('dot wrappers: status dot 10, attention dot 10 / compact 6', (
      t,
    ) async {
      await _pump(t, const RaftStatusDot());
      expect(t.getSize(find.byType(RaftStatus)), const Size.square(10));
      await _pump(t, const RaftAttentionDot());
      expect(t.getSize(find.byType(RaftStatus)), const Size.square(10));
      await _pump(t, const RaftAttentionDot(compact: true));
      expect(t.getSize(find.byType(RaftStatus)), const Size.square(6));
    });

    testWidgets('a lead status inside a badge is 10px', (t) async {
      await _pump(
        t,
        const RaftBadge(
          label: 'Online',
          appearance: RaftBadgeRecipeAppearance.soft,
          leading: RaftStatus(presence: RaftPresence.online),
        ),
      );
      expect(t.getSize(find.byType(RaftStatus)), const Size.square(10));
    });
  });

  group('badge height and radius follow md:pointer-fine', () {
    for (final (platform, size, mouse) in _devices) {
      testWidgets('$platform ${size.width.toInt()}x${size.height.toInt()}', (
        t,
      ) async {
        for (final appearance in [
          RaftBadgeRecipeAppearance.soft,
          RaftBadgeRecipeAppearance.outline,
        ]) {
          await _pump(
            t,
            RaftBadge(label: 'Beta', appearance: appearance),
            platform: platform,
            size: size,
          );
          expect(t.getSize(find.byType(RaftBadge)).height, mouse ? 20 : 22);
          expect(
            _box(t, find.byType(RaftBadge)).radius,
            mouse ? 4 : 6,
            reason: '$appearance',
          );
        }
        await _pump(
          t,
          const RaftBadge(label: '3'),
          platform: platform,
          size: size,
        );
        expect(t.getSize(find.byType(RaftBadge)).height, 20);
        expect(_box(t, find.byType(RaftBadge)).radius, 4);
      });
    }
  });

  group('icon tile radius per size', () {
    testWidgets('xs 4, sm 6, md 8, lg 10', (t) async {
      for (final (size, radius) in [
        (RaftIconTileSize.xs, 4.0),
        (RaftIconTileSize.sm, 6.0),
        (RaftIconTileSize.md, 8.0),
        (RaftIconTileSize.lg, 10.0),
      ]) {
        await _pump(t, RaftIconTile(glyph: RaftGlyph.bell, size: size));
        final deco =
            t
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(RaftIconTile),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(
          deco.borderRadius,
          BorderRadius.circular(radius),
          reason: '$size',
        );
      }
    });
  });

  group('avatar badge', () {
    testWidgets('xs and 2xs are 7px at offset 2, 3xs 6px', (t) async {
      for (final (size, px, offset) in [
        (RaftAvatarSize.xs, 7.0, 2.0),
        (RaftAvatarSize.xxs, 7.0, 2.0),
        (RaftAvatarSize.xxxs, 6.0, 2.0),
      ]) {
        await _pump(
          t,
          RaftStickerAvatar(size: size, presence: RaftPresence.online),
        );
        expect(
          t.getSize(find.byType(RaftAvatarBadge)),
          Size.square(px),
          reason: '$size',
        );
        expect(size.badgeOffset, offset);
        expect(size.badgeBorder, 1, reason: '$size border');
      }
    });
  });

  group('badge you / busy read the recipe', () {
    for (final dark in [false, true]) {
      testWidgets('solid and soft fills ${dark ? 'dark' : 'light'}', (t) async {
        final ui = RaftUiColors.of(dark);
        Future<RaftCssBox> badge(
          RaftBadgeRecipeAppearance a,
          RaftBadgeStateVariant v,
        ) async {
          await _pump(
            t,
            RaftBadge(label: 'x', appearance: a, stateVariant: v),
            dark: dark,
          );
          return _box(t, find.byType(RaftBadge));
        }

        const solid = RaftBadgeRecipeAppearance.solid;
        const soft = RaftBadgeRecipeAppearance.soft;
        expect((await badge(solid, RaftBadgeStateVariant.you)).fill, ui['you']);
        expect(
          (await badge(solid, RaftBadgeStateVariant.busy)).fill,
          ui['presence-busy'],
        );
        final busySoft = (await badge(soft, RaftBadgeStateVariant.busy)).fill!;
        expect(busySoft.a, 1);
        if (ui['presence-busy-soft'].a == 1) {
          expect(busySoft, ui['presence-busy-soft']);
        }
        // `soft` + `you` has no background in the recipe.
        expect((await badge(soft, RaftBadgeStateVariant.you)).fill!.a, 0);
      });
    }
  });

  group('card parts', () {
    Widget card({bool aboveContent = true}) => const SizedBox(
      width: 360,
      child: RaftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftCardSectionHeader(
              aboveContent: true,
              title: RaftCardTitle(Text('Title')),
              description: RaftCardDescription(Text('Desc')),
              trailing: RaftCardTrailing(SizedBox(width: 20, height: 20)),
            ),
            RaftCardContent(child: SizedBox(height: 10, key: Key('body'))),
            RaftCardFooter(children: [Text('Foot')]),
          ],
        ),
      ),
    );

    for (final (platform, size, mouse) in _devices) {
      testWidgets(
        'paddings and type $platform ${size.width.toInt()}x${size.height.toInt()}',
        (t) async {
          await _pump(t, card(), platform: platform, size: size);
          final header = t.getRect(find.byType(RaftCardSectionHeader));
          final title = t.getRect(find.text('Title'));
          expect(title.left - header.left, 16);
          expect(title.top - header.top, 16);
          final style = t.widget<Text>(find.text('Title'));
          final merged = DefaultTextStyle.of(t.element(find.text('Title')));
          expect(merged.style.fontSize, mouse ? 14 : 16);
          expect(merged.style.fontWeight, FontWeight.w600);
          expect(style.data, 'Title');
          // title line: 24 touch, 22 desktop; description below at row gap 4
          final titleH = t.getSize(find.text('Title')).height;
          expect(titleH, mouse ? 22 : 24);
          final desc = t.getRect(find.text('Desc'));
          expect(desc.top - title.bottom, 4);
          // header pb-0 above content, content p-4, footer border-t px-4 py-3
          final content = t.getRect(find.byType(RaftCardContent));
          expect(content.top, header.bottom);
          final body = t.getRect(find.byKey(const Key('body')));
          expect(body.left - content.left, 16);
          expect(body.top - content.top, 16);
          final foot = t.getRect(find.byType(RaftCardFooter));
          final text = t.getRect(find.text('Foot'));
          expect(text.left - foot.left, 16);
          expect(text.top - foot.top, 1 + 12);
          expect(
            DefaultTextStyle.of(t.element(find.text('Foot'))).style.fontSize,
            12,
          );
        },
      );
    }

    testWidgets('option variant: p-3 header, callout title', (t) async {
      await _pump(
        t,
        const SizedBox(
          width: 360,
          child: RaftCard(
            variant: RaftCardRecipeVariant.option,
            child: RaftCardSectionHeader(
              title: RaftCardTitle(Text('Pick')),
              description: RaftCardDescription(Text('Why')),
            ),
          ),
        ),
        platform: TargetPlatform.android,
      );
      final header = t.getRect(find.byType(RaftCardSectionHeader));
      expect(t.getRect(find.text('Pick')).left - header.left, 12);
      expect(
        DefaultTextStyle.of(t.element(find.text('Pick'))).style.fontWeight,
        FontWeight.w600,
      );
    });

    testWidgets('leading column sits before the text column at gap 16', (
      t,
    ) async {
      await _pump(
        t,
        const SizedBox(
          width: 360,
          child: RaftCard(
            child: RaftCardSectionHeader(
              leading: RaftCardLeading(SizedBox(width: 16, height: 16)),
              title: RaftCardTitle(Text('T')),
            ),
          ),
        ),
      );
      final lead = t.getRect(find.byType(RaftCardLeading));
      expect(t.getRect(find.text('T')).left - lead.right, 16);
      expect(lead.height, greaterThanOrEqualTo(22));
    });
  });
}
