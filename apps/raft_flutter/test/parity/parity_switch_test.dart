// Runtime theme-switch isolation (owner scope 2026-10-24): "styles leak between themes".
//
// For each case and every ordered pair of looks (raft / elegant / brutal x light / dark) the case is pumped in look A,
// the app theme is switched to look B at runtime exactly like the app root does (the same MaterialApp is rebuilt with
// the new `theme` / `darkTheme` / `themeMode`, the case's widgets keep their State), settled, and rasterised; the result
// is compared byte for byte (raw RGBA) with a fresh launch in look B. Any difference is a leak: something the switch did
// not re-resolve (a token cached in a State, a static, an implicit animation that kept the old value).
//
// Driven by tool/parity-ext/theme-isolation (a plain `flutter test` skips it).
//
// Env:
//   PARITY_SHARED_DIR    raft-source packages/visual-testing/shared (the case fixtures)
//   PARITY_SWITCH_OUT    output directory (leaks.jsonl + <case>/<from>__<to>.{switched,fresh,diff}.png for every leak)
//   PARITY_MANIFEST      case manifest (official + extension cases merged by the driver)
//   PARITY_EXT_FIXTURES  extension fixture directory
//   PARITY_SWITCH_CASES  comma list of case ids
//   PARITY_SWITCH_LOOKS  comma list (default: all six)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart' show vg;
import 'package:raft_flutter/features/sidebar_conversation_finder.dart';
import 'package:raft_ui/raft_ui.dart';

import '../flutter_test_config.dart' show RaftTestBinding;
import 'case_map.dart';
import 'parity_harness.dart';

typedef _Look = ({String pack, bool dark});

const _allLooks = <String>[
  'raft-light',
  'raft-dark',
  'elegant-light',
  'elegant-dark',
  'brutal-light',
  'brutal-dark',
];

_Look _look(String name) {
  final parts = name.split('-');
  final pack = switch (parts.first) {
    'raft' => raftThemePackId,
    'elegant' => elegantThemePackId,
    'brutal' => brutalThemePackId,
    _ => throw ArgumentError.value(name, 'look'),
  };
  return (pack: pack, dark: parts.last == 'dark');
}

void main() {
  RaftTestBinding.showShadows();
  SidebarFinderLayer.hiddenForParity = true;
  final env = Platform.environment;
  final sharedDir = env['PARITY_SHARED_DIR'];
  final outRoot = env['PARITY_SWITCH_OUT'];
  if (sharedDir == null || outRoot == null) {
    test(
      'theme switch isolation (set PARITY_SHARED_DIR/PARITY_SWITCH_OUT)',
      () {},
      skip: true,
    );
    return;
  }
  final missingFonts = missingParityFontReason();
  if (missingFonts != null) {
    test(
      'theme switch isolation requires system test fonts',
      () {},
      skip: missingFonts,
    );
    return;
  }
  final manifest = json.decode(
    File(env['PARITY_MANIFEST']!).readAsStringSync(),
  ) as Map<String, dynamic>;
  final fixtures = <String, dynamic>{};
  for (final file in Directory(sharedDir).listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.endsWith('.json')) {
      fixtures[name.substring(0, name.length - 5)] = json.decode(
        file.readAsStringSync(),
      );
    }
  }
  final extFixtures = env['PARITY_EXT_FIXTURES'];
  if (extFixtures != null) {
    for (final file in Directory(extFixtures).listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name.endsWith('.json')) {
        fixtures['ext:${name.substring(0, name.length - 5)}'] = json.decode(
          file.readAsStringSync(),
        );
      }
    }
  }
  fixtures['markdownTasksFixture'] = json.decode(
    File('../../tool/reference-patches/markdown-tasks.json').readAsStringSync(),
  );
  fixtures['markdownSyntheticSlice1Fixture'] = json.decode(
    File('../../tool/reference-patches/markdown-synthetic-slice1.json')
        .readAsStringSync(),
  );
  fixtures['notificationCenterFixture'] = json.decode(
    File('../../tool/reference-patches/notification-center.json')
        .readAsStringSync(),
  );

  final wanted = (env['PARITY_SWITCH_CASES'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final looks = (env['PARITY_SWITCH_LOOKS'] ?? _allLooks.join(','))
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final cases = [
    for (final c in (manifest['cases'] as List).cast<Map<String, dynamic>>())
      if (wanted.contains(c['id'])) c,
  ];
  final out = Directory(outRoot)..createSync(recursive: true);
  final report = File('${out.path}/leaks.jsonl');

  setUpAll(() async {
    await loadParityFonts();
  });

  for (final visualCase in cases) {
    final id = visualCase['id'] as String;
    final mapping = parityCases[id];
    if (mapping == null) continue;
    testWidgets('theme switch $id', (t) async {
      final viewport = Map<String, dynamic>.from(visualCase['viewport'] as Map);
      final size = Size(
        (viewport['width'] as num).toDouble(),
        (viewport['height'] as num).toDouble(),
      );
      final density = (viewport['density'] as num? ?? 1).toDouble();
      t.view.physicalSize = size * density;
      t.view.devicePixelRatio = density;
      addTearDown(t.view.reset);
      final rootKey = GlobalKey(debugLabel: 'switch-root');

      Widget app(_Look look) {
        final ctx = ParityContext(
          caseJson: visualCase,
          fixtures: fixtures,
          dark: look.dark,
        );
        final pack = packForThemeId(look.pack);
        ThemeData themed(bool dark) => raftTheme(dark: dark, pack: pack);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // The app root passes both themes and the mode (app_root.dart MaterialApp.router).
          theme: themed(false),
          darkTheme: themed(true),
          themeMode: look.dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(
              key: rootKey,
              child: RaftTooltipProvider(
                delay: const Duration(milliseconds: 600),
                child: ColoredBox(color: Colors.white, child: child),
              ),
            ),
          ),
          home: Builder(builder: (context) => mapping.build(ctx)),
        );
      }

      Future<void> settle() async {
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(mapping.settle);
        await t.pump(
          const Duration(milliseconds: 600),
        ); // AnimatedTheme and the implicit animations of the case
        // The case's own async content (fixture reads that time out, retries) reaches its steady state in both paths.
        await t.pump(const Duration(seconds: 6));
        await t.runAsync(
          () => vg.waitForPendingDecodes().timeout(const Duration(seconds: 10)),
        );
        await t.pump();
        final error = t.takeException();
        if (error != null) throw StateError('case $id threw: $error');
      }

      Future<ui.Image> raster() async {
        final box =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        void hideCarets(RenderObject node) {
          if (node is RenderEditable) {
            node.cursorColor = const Color(0x00000000);
          }
          node.visitChildren(hideCarets);
        }

        hideCarets(box);
        await t.pump();
        return (await t.runAsync(() => box.toImage(pixelRatio: density)))!;
      }

      Future<Uint8List> rgba(ui.Image image) async => (await t.runAsync(
        () async =>
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
                .asUint8List(),
      ))!;

      Future<void> png(ui.Image image, String path) async {
        final bytes = await t.runAsync(
          () async =>
              (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                  .asUint8List(),
        );
        File(path)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
      }

      // Warm-up launch, discarded: the first render in a process runs one-time work (static services, first fixture
      // reads) that later renders do not repeat; it must not make the first fresh image differ from the others.
      for (var warm = 0; warm < 2; warm++) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(_look(looks.first)));
        await settle();
        await t.pumpWidget(app(_look(looks.first)));
        await settle();
      }
      // Fresh launches first: one tree per look, disposed before the next.
      final fresh = <String, Uint8List>{};
      final freshImage = <String, ui.Image>{};
      // The first fresh render of a process differs from every later one in some cases (one-time async work),
      // so the first look is launched twice and only the second image counts.
      for (final name in [looks.first, ...looks]) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(_look(name)));
        await settle();
        // Same timeline as the switched path (launch, settle, one more rebuild, settle): the case's own async
        // content (fixture reads that fail or finish later) must not read as a theme leak.
        await t.pumpWidget(app(_look(name)));
        await settle();
        final image = await raster();
        freshImage[name] = image;
        fresh[name] = await rgba(image);
      }
      var leaks = 0;
      for (final to in looks) {
        for (final from in looks) {
          if (from == to) continue;
          await t.pumpWidget(const SizedBox());
          await t.pumpWidget(app(_look(from)));
          await settle();
          // The runtime switch: the same MaterialApp element, new themes and mode.
          await t.pumpWidget(app(_look(to)));
          await settle();
          final switchedImage = await raster();
          final switched = await rgba(switchedImage);
          final want = fresh[to]!;
          final other = fresh[from]!;
          if (switched.length != want.length) {
            report.writeAsStringSync(
              '${json.encode({'case': id, 'from': from, 'to': to, 'sizeMismatch': true})}\n',
              mode: FileMode.append,
            );
            leaks++;
            continue;
          }
          var diff = 0,
              stale = 0,
              minX = 1 << 30,
              minY = 1 << 30,
              maxX = -1,
              maxY = -1;
          final width = switchedImage.width;
          for (var i = 0; i < want.length; i += 4) {
            if (switched[i] == want[i] &&
                switched[i + 1] == want[i + 1] &&
                switched[i + 2] == want[i + 2] &&
                switched[i + 3] == want[i + 3]) {
              continue;
            }
            diff++;
            final px = i ~/ 4;
            final x = px % width, y = px ~/ width;
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
            // The pixel still shows the look the app was switched away from.
            if (switched[i] == other[i] &&
                switched[i + 1] == other[i + 1] &&
                switched[i + 2] == other[i + 2]) {
              stale++;
            }
          }
          if (diff == 0) continue;
          leaks++;
          final stem = '${out.path}/$id/${from}__$to';
          await png(switchedImage, '$stem.switched.png');
          await png(freshImage[to]!, '$stem.fresh.png');
          report.writeAsStringSync(
            '${json.encode({
              'case': id,
              'from': from,
              'to': to,
              'differentPixels': diff,
              'totalPixels': want.length ~/ 4,
              'staleFromPixels': stale,
              'bbox': [minX, minY, maxX, maxY],
              'density': density,
              'switched': '$stem.switched.png',
              'fresh': '$stem.fresh.png',
            })}\n',
            mode: FileMode.append,
          );
        }
      }
      File('${out.path}/done.jsonl').writeAsStringSync(
        // `distinctLooks`: how many of the fresh renders differ from each other. A case that paints the same in every
        // look cannot show a leak, so the number says how meaningful a clean result is.
        '${json.encode({
          'case': id,
          'pairs': looks.length * (looks.length - 1),
          'leaks': leaks,
          'distinctLooks': {for (final b in fresh.values) base64.encode(b.sublist(0, b.length > 4096 ? 4096 : b.length)) + b.length.toString() + b.fold<int>(0, (h, v) => (h * 31 + v) & 0x7fffffff).toString()}.length,
        })}\n',
        mode: FileMode.append,
      );
      for (final image in freshImage.values) {
        image.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
