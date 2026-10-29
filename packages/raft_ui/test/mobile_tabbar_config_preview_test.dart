import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/testing/system_fonts.dart';

import 'package:raft_ui/mobile_tabbar_config_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Future<void> loadFonts(WidgetTester t) => t.runAsync(() async {
  for (final family in [
    'SpaceGrotesk',
    'SpaceMono',
    'HankenGrotesk',
    'Inter',
    'Geist',
    'GeistMono',
  ]) {
    ByteData bytes;
    try {
      bytes = await rootBundle.load(
        'packages/raft_ui/assets/fonts/$family.ttf',
      );
    } on FlutterError {
      bytes = await rootBundle.load('assets/fonts/$family.ttf');
    }
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(bytes))).load();
  }
  // Material's back arrow (RaftMobileBackButton) is an icon-font glyph.
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/home/kevinzhow/flutter-sdks/versions/3.47.8'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
  // The CJK fallback the theme names ('Noto Sans CJK JP'): load the system
  // font so Chinese renders in screenshots instead of tofu.
  final loader = FontLoader('Noto Sans CJK JP');
  var any = false;
  for (final file in cjkTestFonts()) {
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      any = true;
    }
  }
  if (any) await loader.load();
});

final _themes = [('elegant', false), ('elegant-dark', true)];

/// The default (English) Material strings for any locale: the test only
/// needs the Material widgets to build under `zh`.
class _AnyLocale<T> extends LocalizationsDelegate<T> {
  const _AnyLocale(this.load_);
  final Future<T> Function(Locale) load_;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<T> load(Locale locale) => load_(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

final _delegates = <LocalizationsDelegate<dynamic>>[
  _AnyLocale<MaterialLocalizations>(
    (l) => DefaultMaterialLocalizations.delegate.load(const Locale('en')),
  ),
  _AnyLocale<WidgetsLocalizations>(
    (l) => DefaultWidgetsLocalizations.delegate.load(const Locale('en')),
  ),
];

Widget host(bool dark, Locale locale, GlobalKey capture, Widget child) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: RepaintBoundary(
          key: capture,
          child: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: locale,
              delegates: _delegates,
              child: child,
            ),
          ),
        ),
      ),
    );

Future<void> shot(WidgetTester t, GlobalKey capture, String name) =>
    t.runAsync(() async {
      final render =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('../../.local/mobile-tabbar-config/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });

/// True when any laid-out paragraph under [root] ellipsized or wrapped past
/// its maxLines.
bool anyTruncated(WidgetTester t, Finder root) {
  var truncated = false;
  void visit(Element e) {
    final r = e.renderObject;
    if (r is RenderParagraph && r.didExceedMaxLines) truncated = true;
    e.visitChildren(visit);
  }

  t.element(root).visitChildren(visit);
  return truncated;
}

void main() {
  const zh = Locale('zh'), en = Locale('en');
  for (final (name, dark) in raftThemeMatrix(_themes)) {
    for (final (loc, locale) in [('zh', zh), ('en', en)]) {
      if (loc == 'en' && dark) continue;
      for (final (page, build) in <(String, Widget Function())>[
        ('settings-root-new', mobileSettingsRootBottomBarPreview),
        ('settings-root-current', mobileSettingsRootCurrentPreview),
        ('config-default', mobileTabbarConfigDefaultPreview),
        ('config-gesture-inset', mobileTabbarConfigGesturePreview),
        ('config-buttons-inset', mobileTabbarConfigButtonsPreview),
        ('config-limit', mobileTabbarConfigFullPreview),
        ('config-minimum', mobileTabbarConfigMinimumPreview),
      ]) {
        testWidgets('$page $name $loc', (t) async {
          final missingFonts = missingTestFontReason(cjkTestFonts());
          if (missingFonts != null) {
            markTestSkipped(missingFonts);
            return;
          }

          t.view.physicalSize = const Size(390 * 3, 844 * 3);
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          await loadFonts(t);
          final capture = GlobalKey();
          await t.pumpWidget(host(dark, locale, capture, build()));
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull);
          expect(anyTruncated(t, find.byType(Scaffold)), isFalse);
          await shot(t, capture, '$page-$name-$loc');
        });
      }

      testWidgets('five items fit 360dp $name $loc', (t) async {
        final missingFonts = missingTestFontReason(cjkTestFonts());
        if (missingFonts != null) {
          markTestSkipped(missingFonts);
          return;
        }

        t.view.physicalSize = const Size(360 * 3, 120 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await loadFonts(t);
        final capture = GlobalKey();
        await t.pumpWidget(
          host(dark, locale, capture, mobileTabbarFiveItemsPreview()),
        );
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        expect(find.byType(RaftMobileNav), findsOneWidget);
        expect(anyTruncated(t, find.byType(RaftMobileNav)), isFalse);
        await shot(t, capture, 'five-items-360-$name-$loc');
      });
    }
  }

  testWidgets('limit, minimum and reorder behaviour', (t) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await loadFonts(t);
    final capture = GlobalKey();
    await t.pumpWidget(
      host(false, en, capture, mobileTabbarConfigDefaultPreview()),
    );
    await t.pump(const Duration(milliseconds: 300));
    RaftSwitch sw(String id) =>
        t.widget<RaftSwitch>(find.byKey(ValueKey('mobile-tabbar-switch-$id')));
    int navItems() => t.widgetList(find.byType(RaftMobileNavItem)).length;
    // Both labelled and icon-only bars retain the large-content label.
    Finder preview(String id) => find.descendant(
      of: find.byKey(const Key('mobile-tabbar-preview')),
      matching: find.byWidgetPredicate(
        (w) => w is RaftLargeContentViewer && w.label == id,
      ),
    );

    // Default: Home, Tasks, Members + Settings -> 4 of 5; nothing disabled.
    expect(preview('Home'), findsOneWidget);
    expect(preview('Computers'), findsNothing);
    for (final id in ['chat', 'tasks', 'members', 'computers', 'activity']) {
      expect(sw(id).enabled, isTrue, reason: id);
    }
    expect(find.text('4 / 5'), findsOneWidget);

    // Turning Computers on reaches the limit: off tabs lock.
    await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-computers')));
    await t.pump();
    expect(preview('Computers'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(sw('activity').enabled, isFalse);
    expect(sw('members').enabled, isTrue);
    expect(find.byKey(const Key('mobile-tabbar-notice')), findsOneWidget);

    // Turn Members off: Activity unlocks.
    await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-members')));
    await t.pump();
    expect(sw('activity').enabled, isTrue);
    await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-activity')));
    await t.pump();
    expect(preview('Activity'), findsOneWidget);

    // Down to one tab: it cannot be turned off.
    for (final id in ['tasks', 'computers', 'activity']) {
      await t.tap(find.byKey(ValueKey('mobile-tabbar-switch-$id')));
      await t.pump();
    }
    expect(sw('chat').enabled, isFalse);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(preview('Settings'), findsOneWidget);

    // Reset restores today's bar.
    await t.tap(find.text('Reset to Default'));
    await t.pump();
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('Reset to Default'), findsNothing);

    // Reorder: drag Members' handle above Tasks.
    final handle = find.bySemanticsLabel('Reorder Members');
    expect(handle, findsNothing, reason: 'semantics disabled in this test');
    final members = find.byKey(const ValueKey('mobile-tabbar-row-members'));
    final tasks = find.byKey(const ValueKey('mobile-tabbar-row-tasks'));
    final start = t.getTopLeft(members) + const Offset(12, 24);
    final gesture = await t.startGesture(start);
    await t.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -30));
    await t.pump();
    await gesture.moveBy(const Offset(0, -40));
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();
    expect(t.getTopLeft(members).dy, lessThan(t.getTopLeft(tasks).dy));
    expect(navItems(), 0); // preview items render as RaftControl, not widgets
  });
}
