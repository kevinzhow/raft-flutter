import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// `RaftPanelIconButton` follows `panelAction.surface` (contract section 4).
///
/// Raft: raft-ui 0.7.0 `PanelAction` (`panelActionBase`: `h-11 min-w-11` for touch,
/// `h-8 min-w-8` for pointer input, `rounded-control`, svg `22px` / `18px`), read from the
/// pack. Elegant and Brutal keep the a57b9dab `Button icon-sm outline`.
Widget _host(
  RaftThemePack pack, {
  bool dark = false,
  TargetPlatform platform = TargetPlatform.android,
  VoidCallback? onPressed,
}) => MaterialApp(
  themeAnimationDuration: Duration.zero,
  theme: raftTheme(
    pack: pack,
    dark: dark,
    platform: platform,
  ).copyWith(platform: platform),
  home: Scaffold(
    body: Center(
      child: RaftPanelIconButton(
        glyph: RaftGlyph.ellipsisVertical,
        tooltip: 'More',
        onPressed: onPressed,
      ),
    ),
  ),
);

RaftThemePack _user(Map<String, Object?> geometry) => RaftThemePack.parse(
  jsonEncode({
    'format': 'raft-theme/1',
    'id': 'user:panel-icon-fixture',
    'name': 'Panel icon fixture',
    'version': '1.0.0',
    'extends': 'raft',
    'modes': {
      'light': {'geometry': geometry},
      'dark': <String, Object?>{},
    },
  }),
);

Size _glyph(WidgetTester t) =>
    Size.square(t.widget<RaftIcon>(find.byType(RaftIcon)).size);

double _radius(WidgetTester t) {
  final box = t
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(RaftPanelIconButton),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((b) => b.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.borderRadius != null);
  return (box.borderRadius! as BorderRadius).topLeft.x;
}

void main() {
  Future<void> viewport(WidgetTester t, double width) async {
    t.view.physicalSize = Size(width, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Raft: touch is 44/22 and pointer is 32/18 independent of width',
    (t) async {
      await viewport(t, 390);
      await t.pumpWidget(
        _host(packForThemeId(raftThemePackId), onPressed: () {}),
      );
      expect(t.getSize(find.byType(RaftPanelIconButton)), const Size(44, 44));
      expect(_glyph(t), const Size.square(22));
      expect(_radius(t), 8);
      for (final (platform, width, extent, glyph) in [
        (TargetPlatform.android, 856.0, 44.0, 22.0),
        (TargetPlatform.android, 944.0, 44.0, 22.0),
        (TargetPlatform.linux, 390.0, 32.0, 18.0),
        (TargetPlatform.linux, 800.0, 32.0, 18.0),
      ]) {
        await viewport(t, width);
        await t.pumpWidget(
          _host(
            packForThemeId(raftThemePackId),
            platform: platform,
            onPressed: () {},
          ),
        );
        expect(
          t.getSize(find.byType(RaftPanelIconButton)),
          Size.square(extent),
        );
        expect(_glyph(t), Size.square(glyph));
      }
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a user pack moves the Raft panel action', (t) async {
    await viewport(t, 390);
    await t.pumpWidget(
      _host(
        _user({
          'size.control.lg': 60,
          'size.buttonGlyph.iconLg': 30,
          'radius.control': 25,
        }),
        onPressed: () {},
      ),
    );
    expect(t.getSize(find.byType(RaftPanelIconButton)), const Size(60, 60));
    expect(_glyph(t), const Size.square(30));
    expect(_radius(t), 25);
    expect(t.takeException(), isNull);
  });

  testWidgets('product artwork keeps the 18px / 22px glyph box', (t) async {
    addTearDown(() => t.pumpWidget(const SizedBox()));
    for (final (platform, width, glyph) in [
      (TargetPlatform.linux, 390.0, 18.0),
      (TargetPlatform.android, 856.0, 22.0),
    ]) {
      await viewport(t, width);
      await t.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: raftTheme(
            pack: packForThemeId(raftThemePackId),
            platform: platform,
          ).copyWith(platform: platform),
          home: Scaffold(
            body: Center(
              child: RaftPanelIconButton(
                icon: (size, color) =>
                    SizedBox.square(key: const Key('art'), dimension: size),
                tooltip: 'Direct Message',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byKey(const Key('art'))), Size.square(glyph));
    }
  });

  for (final id in [elegantThemePackId, brutalThemePackId]) {
    testWidgets('$id keeps the a57b9dab outline Button icon-sm', (t) async {
      for (final width in [390.0, 800.0]) {
        await viewport(t, width);
        await t.pumpWidget(_host(packForThemeId(id), onPressed: () {}));
        expect(t.getSize(find.byType(RaftPanelIconButton)), const Size(28, 28));
        expect(_glyph(t), const Size.square(14));
      }
      expect(t.takeException(), isNull);
    });
  }
}
