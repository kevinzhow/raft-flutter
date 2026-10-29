import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/testing/system_fonts.dart';

import 'package:raft_ui/activity_selected_previews.dart';
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
  // The theme's CJK fallback: load the system font so zh renders.
  final loader = FontLoader('Noto Sans CJK JP');
  // Badge text inherits the generic `sans-serif` fallback.
  final generic = FontLoader('sans-serif');
  var any = false;
  for (final file in cjkTestFonts()) {
    if (file.existsSync()) {
      final data = ByteData.sublistView(file.readAsBytesSync());
      loader.addFont(Future.value(data));
      generic.addFont(Future.value(data));
      any = true;
    }
  }
  if (any) {
    await loader.load();
    await generic.load();
  }
});

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

Widget host(bool dark, GlobalKey capture, Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: RepaintBoundary(
      key: capture,
      child: Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: const Locale('zh'),
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
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = Platform.environment['ACTIVITY_SELECTED_OUT'];
      final file = File('${dir ?? '../../.local/activity-selected'}/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });

final _themes = [('elegant-light', false), ('elegant-dark', true)];

void main() {
  for (final (name, dark) in raftThemeMatrix(_themes)) {
    testWidgets('selected Activity row states $name', (t) async {
      final missingFonts = missingTestFontReason(cjkTestFonts());
      if (missingFonts != null) {
        markTestSkipped(missingFonts);
        return;
      }

      t.view.physicalSize = const Size(480 * 2, 640 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await loadFonts(t);
      final capture = GlobalKey();
      await t.pumpWidget(host(dark, capture, const ActivitySelectedRows()));
      await t.pumpAndSettle();
      Finder row(int i) => find.byKey(ValueKey('activity-selected-row-$i'));
      expect(
        t
            .widgetList<RaftConversationCard>(find.byType(RaftConversationCard))
            .map((c) => c.selected),
        [false, false, false, true, true, false],
      );
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(row(2)));
      await t.pumpAndSettle();
      await shot(t, capture, 'states/$name-1-hover-row');
      await mouse.moveTo(t.getCenter(row(3)));
      await t.pumpAndSettle();
      await shot(t, capture, 'states/$name-2-hover-selected');
      await mouse.removePointer();
      await t.pumpAndSettle();
      await shot(t, capture, 'states/$name-3-rest');
      expect(t.takeException(), isNull);
    });
  }
}
