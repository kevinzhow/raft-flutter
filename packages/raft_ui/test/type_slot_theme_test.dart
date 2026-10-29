import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/page_tokens.dart';

/// The Raft look reads the pack's type slots (`RaftTokens.typeSlot`) and the
/// existing empty-state tokens where it used to repeat the Raft numbers.
///
/// Sources: Web v1.21.23 / raft-ui 0.7.0 `text-headline` 17/22, `text-footnote`
/// 13/18 (Banner `sm`, FormSection title and description), `text-caption`;
/// the built-in values are unchanged, so these tests move a user pack and watch
/// the widgets follow. Elegant and Brutal keep their a57b9dab literals behind
/// their own options.
RaftThemePack _user({
  Map<String, Object?> geometry = const {},
  Map<String, Object?> type = const {},
}) => RaftThemePack.parse(
  jsonEncode({
    'format': 'raft-theme/1',
    'id': 'user:type-slot-fixture',
    'name': 'Type slot fixture',
    'version': '1.0.0',
    'extends': 'raft',
    'modes': {
      'light': {'geometry': geometry, 'type': type},
      'dark': <String, Object?>{},
    },
  }),
);

Widget _host(RaftThemePack pack, Widget child) => MaterialApp(
  theme: raftTheme(pack: pack),
  home: Scaffold(body: child),
);

/// The Material theme animates between two packs; settle it before reading.
Future<void> _mount(WidgetTester t, Widget widget) async {
  await t.pumpWidget(widget);
  await t.pump(const Duration(seconds: 1));
}

double _titleSize(WidgetTester t, String text) =>
    DefaultTextStyle.of(t.element(find.text(text))).style.fontSize ??
    t.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  testWidgets('typeSlot answers the pack, and Raft values for a bare pack', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    late RaftTokens raft, elegant, user;
    Widget probe(RaftThemePack pack, void Function(RaftTokens) take) => _host(
      pack,
      Builder(
        builder: (context) {
          take(RaftTokens.of(context));
          return const SizedBox();
        },
      ),
    );
    await _mount(t, probe(packForThemeId(raftThemePackId), (v) => raft = v));
    await _mount(
      t,
      probe(packForThemeId(elegantThemePackId), (v) => elegant = v),
    );
    await _mount(
      t,
      probe(
        _user(
          type: {
            'headline': [25, 30, 600, 0],
          },
        ),
        (v) => user = v,
      ),
    );
    final headline = RaftTypeScale.headline;
    for (final tokens in [raft, elegant]) {
      expect(tokens.typeSlot('headline').fontSize, headline.fontSize);
      expect(tokens.typeSlot('headline').lineHeight, headline.lineHeight);
      expect(tokens.typeSlot('footnote').fontSize, 13);
    }
    expect(user.typeSlot('headline').fontSize, 25);
    expect(user.typeSlot('headline').lineHeight, 30);
    expect(user.typeSlot('headline').fontWeight, 600);
    expect(user.typeSlot('caption').fontSize, 12);
  });

  testWidgets('the ghost panel header title follows the headline slot', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    Future<double> size(RaftThemePack pack) async {
      await _mount(t, _host(pack, const RaftPanelHeaderBar(title: 'Title')));
      return t
          .widget<Text>(
            find.descendant(
              of: find.byType(RaftCssText),
              matching: find.text('Title'),
            ),
          )
          .style!
          .fontSize!;
    }

    expect(await size(packForThemeId(raftThemePackId)), 17);
    expect(
      await size(
        _user(
          type: {
            'headline': [25, 30, 700, 0],
          },
        ),
      ),
      25,
    );
  });

  testWidgets('Banner sm and the form section follow the footnote slot', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    final pack = _user(
      type: {
        'footnote': [20, 26, 400, 0],
      },
    );
    await _mount(
      t,
      _host(
        pack,
        const RaftBanner(
          description: 'Short banner',
          size: RaftBannerRecipeSize.sm,
        ),
      ),
    );
    expect(_titleSize(t, 'Short banner'), 20);
    late TextStyle section;
    await _mount(
      t,
      _host(
        pack,
        Builder(
          builder: (context) {
            section = RaftTokens.of(context)
                .formSectionTitle(const TextStyle(fontSize: 16));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(section.fontSize, 20);
    expect(section.height! * section.fontSize!, closeTo(26, .001));
    await _mount(
      t,
      _host(
        packForThemeId(raftThemePackId),
        const RaftBanner(
          description: 'Short banner',
          size: RaftBannerRecipeSize.sm,
        ),
      ),
    );
    expect(_titleSize(t, 'Short banner'), 13);
    await _mount(
      t,
      _host(
        packForThemeId(elegantThemePackId),
        const RaftBanner(
          description: 'Short banner',
          size: RaftBannerRecipeSize.sm,
        ),
      ),
    );
    expect(_titleSize(t, 'Short banner'), 12);
  });

  testWidgets('the plain empty state follows the empty-state tokens', (
    t,
  ) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    Widget empty(RaftThemePack pack) => _host(
      pack,
      RaftProductEmptyState(
        title: 'Nothing here',
        description: 'Come back later',
        icon: (context, size, color) => SizedBox.square(dimension: size),
      ),
    );
    await _mount(t, empty(packForThemeId(raftThemePackId)));
    expect(
      t.getSize(find.byKey(const ValueKey('empty-state-icon'))),
      const Size.square(36),
    );
    expect(t.widget<Text>(find.text('Nothing here')).style!.fontSize, 17);
    await _mount(
      t,
      empty(
        _user(
          geometry: {
            'type.emptyTitle.size': 30,
            'type.emptyTitle.line': 36,
            'type.emptyBody.size': 19,
            'type.emptyBody.line': 24,
            'size.emptyGlyph': 50,
          },
        ),
      ),
    );
    expect(
      t.getSize(find.byKey(const ValueKey('empty-state-icon'))),
      const Size.square(50),
    );
    expect(t.widget<Text>(find.text('Nothing here')).style!.fontSize, 30);
    expect(t.widget<Text>(find.text('Come back later')).style!.fontSize, 19);
  });
}
