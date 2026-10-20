// Flutter provider for the official Raft cross-platform visual parity tool
// (raft-source packages/visual-testing). Writes captures in the provider
// output contract the CLI's diff/report/site read:
//   <result-root>/android/<caseId>.png
//   <result-root>/android/<caseId>.metadata.json
// The provider name is `android` (the CLI's pair precedence knows
// react > android > ios > ohos); metadata records `source: "flutter"`.
import 'dart:convert';
import 'dart:io';

import '../../../../tool/testing/system_fonts.dart';
import '../support/glyph_clip_scan.dart';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart' show vg;
import 'package:raft_ui/raft_ui.dart';

import 'geometry_dump.dart';

/// Builds the real Flutter widget tree for one official case.
typedef ParityBuilder = Widget Function(ParityContext ctx);

/// Optional post-pump interaction (tap a trigger, open a menu, type text).
typedef ParityInteraction = Future<void> Function(
  WidgetTester t,
  ParityContext ctx,
);

/// One mapped case: the real widget path the Flutter app uses for the
/// surface the React render host shows under the same case id.
class ParityCase {
  const ParityCase({
    required this.widgets,
    required this.build,
    this.interact,
    this.notes = '',
    this.settle = const Duration(milliseconds: 400),
  });

  /// Product widgets exercised (for coverage reports, e.g. `raft_ui:RaftButton`).
  final List<String> widgets;
  final ParityBuilder build;
  final ParityInteraction? interact;
  final String notes;
  final Duration settle;
}

/// Why a case has no Flutter capture. All of these count as NOT COVERED.
enum ParityGap {
  /// Harness work not done yet; a Flutter implementation may exist.
  harnessTodo,

  /// The Flutter app has no implementation of this surface/component.
  noFlutterSurface,

  /// Only a real device/emulator can show this state honestly.
  deviceOnly,

  /// The official React baseline does not show the component (e.g. an empty
  /// fixture), so a Flutter match would be meaningless.
  invalidBaseline,
}

class ParityUncovered {
  const ParityUncovered(this.gap, this.reason);
  final ParityGap gap;
  final String reason;
}

/// Everything a builder may read: the official case JSON, its variant props,
/// the shared fixture JSON files and the resolved Raft theme.
class ParityContext {
  ParityContext({
    required this.caseJson,
    required this.fixtures,
    required this.dark,
  });

  final Map<String, dynamic> caseJson;

  /// shared/*.json keyed by file stem, e.g. `fixtureData`, `tasksFixture`.
  final Map<String, dynamic> fixtures;
  final bool dark;

  /// The capture target. Builders wrap the element that corresponds to the
  /// React `capture.selector` with [target]; when they do not, the whole
  /// viewport is captured (correct for `body` selectors).
  final GlobalKey targetKey = GlobalKey(debugLabel: 'parity-target');
  bool targetUsed = false;

  String get id => caseJson['id'] as String;
  Map<String, dynamic> get variant =>
      Map<String, dynamic>.from((caseJson['variants'] as List).first as Map);
  Map<String, dynamic> get props =>
      Map<String, dynamic>.from((variant['props'] as Map?) ?? const {});
  Map<String, dynamic> get fixtureData =>
      fixtures['fixtureData'] as Map<String, dynamic>;
  Map<String, dynamic> get viewport =>
      Map<String, dynamic>.from(caseJson['viewport'] as Map);
  double get width => (viewport['width'] as num).toDouble();
  double get height => (viewport['height'] as num).toDouble();
  double get density => (viewport['density'] as num? ?? 1).toDouble();
  String get themeId => dark ? 'elegant-dark' : 'elegant-light';

  Widget target(Widget child) {
    targetUsed = true;
    return KeyedSubtree(key: targetKey, child: child);
  }

  /// Fixed-size frame identical to the React render host's
  /// `<div data-visual-case style={{width, height, padding, background}}>`.
  Widget frame({
    required double width,
    required double height,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color background = Colors.white,
    required Widget child,
  }) => Align(
    alignment: Alignment.topLeft,
    child: target(
      ClipRect(
        child: Container(
          width: width,
          height: height,
          color: background,
          padding: padding,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    ),
  );
}

/// Whether the case renders dark. There is one Raft look: every case renders
/// light unless a supplemental run asks for `elegant-dark` / `dark`. The
/// historical `brutal-light` / `elegant-light` overrides still name the light
/// look so older capture scripts keep working.
bool parityThemeFor(Map<String, dynamic> visualCase, {String? override}) {
  // Supplemental theme runs preserve each original case/fixture identity.
  // The official run leaves this unset and retains its original 99-case matrix.
  if (override != null && override.isNotEmpty) {
    return switch (override) {
      'brutal-light' || 'elegant-light' || 'light' => false,
      'elegant-dark' || 'dark' => true,
      _ => throw ArgumentError.value(
        override,
        'override',
        'Unknown parity theme',
      ),
    };
  }
  final props =
      ((visualCase['variants'] as List?)?.firstOrNull as Map?)?['props']
          as Map?;
  // Extension suite cases name their theme explicitly (tool/parity-ext).
  final extTheme = props?['parityTheme'];
  if (extTheme is String) return parityThemeFor(visualCase, override: extTheme);
  return false;
}

Map<String, List<String>> paritySystemFonts() => {
  'Noto Sans CJK JP': [
    systemTestFont('opentype/noto/NotoSansCJK-Regular.ttc').path,
    systemTestFont('opentype/noto/NotoSansCJK-Bold.ttc').path,
  ],
  'Noto Sans CJK SC': [
    systemTestFont('opentype/noto/NotoSansCJK-Regular.ttc').path,
    systemTestFont('opentype/noto/NotoSansCJK-Bold.ttc').path,
  ],
  'Noto Color Emoji': [systemTestFont('truetype/noto/NotoColorEmoji.ttf').path],
  // `ui-sans-serif, system-ui` (the hands-feedback Feedback workspace):
  // Chromium resolves it through fontconfig, which is Noto Sans on the
  // capture host; product code names `system-ui` (raftSystemUiFont), which
  // a device resolves to its own UI face.
  'system-ui': [
    systemTestFont('truetype/noto/NotoSans-Regular.ttf').path,
    systemTestFont('truetype/noto/NotoSans-Bold.ttf').path,
  ],
  // flutter_test has no OS fallback chain. On Android the system resolves
  // emoji through its own fallback; here the theme's trailing `sans-serif`
  // fallback family stands in for it so emoji do not render as tofu.
  'sans-serif': [systemTestFont('truetype/noto/NotoColorEmoji.ttf').path],
};

String? missingParityFontReason() => missingTestFontReason(
  paritySystemFonts().values.expand((paths) => paths).toSet().map(File.new),
);

bool _fontsLoaded = false;

/// Loads every font the app bundles (FontManifest.json: raft_ui families and
/// MaterialIcons) plus the system CJK/emoji families the theme names as
/// fallbacks, so text is never rendered with the Ahem test font.
Future<List<String>> loadParityFonts() async {
  if (_fontsLoaded) return const [];
  final loaded = <String>[];
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final loader = FontLoader(family);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    loaded.add(family);
    // MaterialIcons is declared as `MaterialIcons`; raft_ui families as
    // `packages/raft_ui/<Family>`. Register bare aliases too so a widget that
    // names the bare family resolves to the same bytes.
    if (family.startsWith('packages/')) {
      final bare = family.split('/').last;
      final alias = FontLoader(bare);
      for (final font
          in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
        alias.addFont(rootBundle.load(font['asset'] as String));
      }
      await alias.load();
    }
  }
  final systemFallbacks = paritySystemFonts();
  for (final MapEntry(key: family, value: paths) in systemFallbacks.entries) {
    final files = paths.map(File.new).where((f) => f.existsSync()).toList();
    if (files.isEmpty) continue;
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
    loaded.add(family);
  }
  _fontsLoaded = true;
  return loaded;
}

/// Pumps one case at its official viewport/density, captures the target rect
/// from the full-viewport raster (like Playwright's clipped page screenshot,
/// so portals/overlays above the target are included) and writes PNG +
/// metadata in the official provider contract.
Future<Map<String, dynamic>> captureParityCase(
  WidgetTester t, {
  required Map<String, dynamic> visualCase,
  required ParityCase mapping,
  required Map<String, dynamic> fixtures,
  required Directory outputDir,
  required Map<String, dynamic> runInfo,
}) async {
  final dark = parityThemeFor(
    visualCase,
    override: Platform.environment['PARITY_THEME_OVERRIDE'],
  );
  final ctx = ParityContext(
    caseJson: visualCase,
    fixtures: fixtures,
    dark: dark,
  );
  final size = Size(ctx.width, ctx.height);
  t.view.physicalSize = size * ctx.density;
  t.view.devicePixelRatio = ctx.density;
  addTearDown(t.view.reset);

  final rootKey = GlobalKey(debugLabel: 'parity-root');
  final raft = raftTheme(dark: dark);
  // Playwright screenshots default to caret: "hide"; hide Flutter's text
  // caret the same way so a focused field is not a spurious diff.
  final theme = raft.copyWith(
    textSelectionTheme: raft.textSelectionTheme.copyWith(
      cursorColor: const Color(0x00000000),
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme,
      builder: (context, child) => MediaQuery(
        // React uses Playwright animations:"disabled": infinite pulses are
        // captured at their initial frame, finite transitions at rest. Use
        // the product's reduced-motion contract for the same Flutter state.
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
    ),
  );
  await t.pump(const Duration(milliseconds: 50));
  await _androidInteractions(t, visualCase);
  if (mapping.interact != null) await mapping.interact!(t, ctx);
  await t.pump(mapping.settle);
  await t.pump(const Duration(milliseconds: 16));
  // Opt-in audit (see support/glyph_clip_scan.dart): append every clip that
  // sits inside a paragraph's glyph ink to this JSON-lines file.
  final scanFile = Platform.environment['PARITY_GLYPH_CLIP_SCAN'];
  if (scanFile != null) {
    for (final f in scanGlyphClips(t)) {
      File(scanFile).writeAsStringSync(
        '${json.encode({'case': visualCase['id'], ...f.toJson()})}\n',
        mode: FileMode.append,
      );
    }
  }
  // SVG compilation uses a real isolate. Advancing the test's fake clock
  // cannot finish it; await the renderer's actual decode before capturing.
  await t.runAsync(
    () => vg.waitForPendingDecodes().timeout(const Duration(seconds: 10)),
  );
  await t.pump();
  // Never write a capture of a build/layout error screen.
  final error = t.takeException();
  if (error != null) {
    throw StateError('case ${ctx.id} threw while rendering: $error');
  }

  final rootBox =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // Playwright captures with caret: "hide". Product fields may set their own
  // cursorColor (bypassing the theme override above), so hide every caret on
  // the render objects for this frame only; the zero-duration pump repaints
  // without advancing the blink timer or rebuilding the fields.
  void hideCarets(RenderObject node) {
    if (node is RenderEditable) node.cursorColor = const Color(0x00000000);
    node.visitChildren(hideCarets);
  }

  hideCarets(rootBox);
  await t.pump();
  Rect rect = Offset.zero & size;
  String? targetNote;
  // Extension cases name the Flutter widget that corresponds to the React
  // capture.selector (`capture.androidKey`, a ValueKey<String>).
  final androidKey = (visualCase['capture'] as Map?)?['androidKey'] as String?;
  final keyed = androidKey == null
      ? null
      : find.byKey(ValueKey(androidKey)).evaluate().firstOrNull;
  if (androidKey != null && keyed == null) {
    throw StateError('case ${ctx.id}: capture.androidKey $androidKey missing');
  }
  final targetContext = keyed ?? ctx.targetKey.currentContext;
  if ((keyed != null || ctx.targetUsed) && targetContext != null) {
    final box = targetContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: rootBox);
    final raw = origin & box.size;
    rect = raw.intersect(Offset.zero & size);
    if (rect != raw) targetNote = 'target clamped to viewport like React';
  }
  // Extension element crops (`capture.androidKey`) follow Playwright's
  // element screenshot, which captures the CSS-pixel rect enclosing a
  // fractional box (floor / ceil in CSS px, then scaled: a card at
  // y = 296.5 on a 3x page starts at device row 888, not 889); official
  // crops keep their rounding.
  final enclose = keyed != null;
  final d = ctx.density;
  final pixelRect = enclose
      ? Rect.fromLTRB(
          rect.left.floorToDouble() * d,
          rect.top.floorToDouble() * d,
          rect.right.ceilToDouble() * d,
          rect.bottom.ceilToDouble() * d,
        )
      : Rect.fromLTRB(
          (rect.left * d).roundToDouble(),
          (rect.top * d).roundToDouble(),
          (rect.right * d).roundToDouble(),
          (rect.bottom * d).roundToDouble(),
        );

  final png = await t.runAsync(() async {
    final full = await rootBox.toImage(pixelRatio: ctx.density);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & pixelRect.size,
      Paint()..color = Colors.white,
    );
    canvas.drawImageRect(
      full,
      pixelRect,
      Offset.zero & pixelRect.size,
      Paint()..filterQuality = FilterQuality.none,
    );
    final cropped = await recorder.endRecording().toImage(
      pixelRect.width.toInt(),
      pixelRect.height.toInt(),
    );
    final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
    full.dispose();
    cropped.dispose();
    return bytes!.buffer.asUint8List();
  });

  final id = ctx.id;
  final imageFile = File('${outputDir.path}/$id.png');
  final roundedRect = {
    'x': rect.left.round(),
    'y': rect.top.round(),
    'width': rect.width.round(),
    'height': rect.height.round(),
  };
  final metadata = <String, dynamic>{
    'provider': 'android',
    'providerType': 'flutter-widget-test',
    'source': 'flutter',
    'caseId': id,
    'variantId': ctx.variant['id'],
    'theme': ctx.themeId,
    'image': 'visual-testing-results/android/$id.png',
    'viewport': ctx.viewport,
    'selector': (visualCase['capture'] as Map?)?['selector'],
    'crop': {
      'mode': (visualCase['capture'] as Map?)?['crop'] ?? 'element',
      'contract':
          (visualCase['capture'] as Map?)?['contract'] ?? 'component-bounds',
      'rect': roundedRect,
      'targetRect': roundedRect,
      'outset': null,
      'note': ?targetNote,
    },
    'flutter': {
      'widgets': mapping.widgets,
      if (mapping.notes.isNotEmpty) 'notes': mapping.notes,
      'targetPlatform': defaultTargetPlatform.name,
      // A touch host is a platform property, not a pixel-density one: phone
      // cases can be density 1 and must still report touch.
      'density': switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => 'touch',
        _ => 'desktop',
      },
      'renderer': 'flutter_test host raster (not a device screenshot)',
      'animationPolicy':
          'reduced-motion at rest; matches React animations:disabled',
      'vectorDecodePolicy':
          'await actual pending vector decodes before capture',
      ...runInfo,
    },
    'typography': _typographyProbes(
      ctx.targetUsed ? ctx.targetKey.currentContext : rootKey.currentContext,
    ),
    'styleTokens': _styleTokenProbes(
      ctx.targetUsed ? ctx.targetKey.currentContext : rootKey.currentContext,
    ),
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
  };
  await t.runAsync(() async {
    await imageFile.writeAsBytes(png!);
    await File('${outputDir.path}/$id.metadata.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));
    if (parityGeometryDumpEnabled) {
      await File('${outputDir.path}/$id.geometry.txt')
          .writeAsString(parityGeometryDump(rootBox, rect, rootBox));
    }
  });
  return metadata;
}

/// Generic `capture.androidInteractions` of extension cases, the Flutter
/// counterpart of the React `capture.interactions` (tap/hover a keyed widget,
/// enter text, wait).
Future<void> _androidInteractions(
  WidgetTester t,
  Map<String, dynamic> visualCase,
) async {
  final steps = (visualCase['capture'] as Map?)?['androidInteractions'];
  if (steps is! List) return;
  TestGesture? mouse;
  for (final raw in steps.cast<Map>()) {
    final key = raw['type'] == 'key' ? null : raw['key'] as String?;
    final target = key == null ? null : find.byKey(ValueKey(key));
    // Like Playwright's actionability wait: the target may appear after the
    // fixture reads settle (up to 2s of fake time).
    for (
      var i = 0;
      i < 40 && target != null && target.evaluate().isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 50));
    }
    if (target != null && target.evaluate().isEmpty) {
      throw StateError('androidInteractions target $key missing');
    }
    switch (raw['type']) {
      case 'tap':
        // Playwright scrolls a click target into view first (after the
        // page's reads settle, since late rows move it).
        await t.pump(const Duration(milliseconds: 300));
        // `scroll: false`: the target is already on screen, where Playwright
        // does not scroll either (ensureVisible would align it to the top).
        if (raw['scroll'] != false) await t.ensureVisible(target!.first);
        await t.pump();
        if (raw['mouse'] == true) {
          // Playwright clicks with a mouse: a touch tap would also raise the
          // text-selection handles of a field the dialog focuses.
          await t.tapAt(
            t.getCenter(target!.first),
            kind: PointerDeviceKind.mouse,
          );
        } else {
          await t.tap(target!.first, warnIfMissed: false);
        }
      case 'tapText':
        // Taps the first widget showing exactly this text (menu items and
        // buttons that carry no key), scrolled into view like a click.
        final byText = find.text(raw['text'] as String);
        for (var i = 0; i < 40 && byText.evaluate().isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        // A lazy list builds only what is near the viewport: scroll the list
        // keyed `in` until the text exists (Playwright scrolls to the element).
        final list = raw['in'] as String?;
        if (byText.evaluate().isEmpty && list != null) {
          await t.scrollUntilVisible(
            byText,
            300,
            scrollable: find
                .descendant(
                  of: find.byKey(ValueKey(list)),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        if (byText.evaluate().isEmpty) {
          throw StateError('androidInteractions text ${raw['text']} missing');
        }
        await t.pump(const Duration(milliseconds: 300));
        await t.ensureVisible(byText.first);
        await t.pump();
        await t.tap(byText.first, warnIfMissed: false);
      case 'secondaryTap':
        // Native right click at the element centre, or at (x, y) from its
        // top-left like Playwright's `position`.
        await t.pump(const Duration(milliseconds: 300));
        final box = t.getRect(target!.first);
        // `row`: the keyed item carries the sidebar row's trailing margin
        // (4 Brutal / 2 Elegant); Playwright clicks the button's own centre.
        final rowMargin = raw['row'] == true
            ? ((visualCase['variants'] as List).first
                          as Map)['props']['parityTheme'] ==
                      'brutal-light'
                  ? 2.0
                  : 1.0
            : 0.0;
        final at = raw['x'] == null
            ? box.center - Offset(0, rowMargin)
            : box.topLeft +
                  Offset(
                    (raw['x'] as num).toDouble(),
                    (raw['y'] as num? ?? 0).toDouble(),
                  );
        await t.tapAt(
          at,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
      case 'longPress':
        // Native touch long press (the phone's way to open a row menu),
        // at the element centre or at (x, y) from its top-left.
        await t.pump(const Duration(milliseconds: 300));
        final lpBox = t.getRect(target!.first);
        final lpMargin = raw['row'] == true
            ? ((visualCase['variants'] as List).first
                          as Map)['props']['parityTheme'] ==
                      'brutal-light'
                  ? 2.0
                  : 1.0
            : 0.0;
        await t.longPressAt(
          raw['x'] == null
              ? lpBox.center - Offset(0, lpMargin)
              : lpBox.topLeft +
                    Offset(
                      (raw['x'] as num).toDouble(),
                      (raw['y'] as num? ?? 0).toDouble(),
                    ),
        );
      case 'reveal':
        // Playwright's element screenshot scrolls the element into view
        // first: do the same for a keyed target below the fold.
        await t.pump(const Duration(milliseconds: 300));
        await t.ensureVisible(target!.first);
        await t.pump();
      case 'hover':
        mouse ??= await t.createGesture(kind: PointerDeviceKind.mouse);
        try {
          await mouse.addPointer(location: Offset.zero);
        } on AssertionError {
          // A right click earlier in the case already added the mouse device.
        }
        await mouse.moveTo(t.getCenter(target!.first));
      case 'scroll':
        // Counterpart of the React `scroll` interaction (wheel over the
        // target; y < 0 scrolls the list up): drag the content down by |dy|.
        await t.drag(target!.first, Offset(0, -(raw['dy'] as num).toDouble()));
      case 'enter':
        await t.enterText(target!.first, raw['value'] as String);
      case 'enterText':
        // Types into the field under the keyed widget (a keyed search input).
        await t.enterText(
          find
              .descendant(
                of: target!.first,
                matching: find.byType(EditableText),
              )
              .first,
          raw['text'] as String,
        );
      case 'key':
        final name = raw['key'] as String;
        final logical = switch (name) {
          'arrowDown' => LogicalKeyboardKey.arrowDown,
          'arrowUp' => LogicalKeyboardKey.arrowUp,
          'enter' => LogicalKeyboardKey.enter,
          'escape' => LogicalKeyboardKey.escape,
          _ => throw StateError('unknown androidInteraction key $name'),
        };
        await t.sendKeyEvent(logical);
      case 'wait':
        await t.pump(Duration(milliseconds: (raw['ms'] as num).toInt()));
      default:
        throw StateError('unknown androidInteraction $raw');
    }
    await t.pump(const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 300));
  }
}

String _hex(Color? c) {
  if (c == null) return '';
  final argb = c.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final a = argb >> 24;
  return a == 0xFF
      ? '#$rgb'
      : '#$rgb${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

List<Map<String, dynamic>> _typographyProbes(BuildContext? context) {
  final out = <Map<String, dynamic>>[];
  final root = context?.findRenderObject();
  if (root == null) return out;
  void visit(RenderObject node) {
    if (out.length >= 24) return;
    if (node is RenderParagraph) {
      final span = node.text;
      final text = span.toPlainText().trim();
      final style = span.style ?? (span is TextSpan ? span.style : null);
      if (text.isNotEmpty && style != null) {
        final fontSize = style.fontSize ?? 14;
        out.add({
          'selector': 'RenderParagraph[${out.length}]',
          'text': text.length > 60 ? '${text.substring(0, 60)}…' : text,
          'fontFamily': (style.fontFamily ?? '').replaceFirst(
            'packages/raft_ui/',
            '',
          ),
          'fontSize': fontSize,
          'fontWeight': (style.fontWeight ?? FontWeight.w400).value,
          'lineHeight': style.height == null
              ? null
              : double.parse((style.height! * fontSize).toStringAsFixed(2)),
          'letterSpacing': style.letterSpacing ?? 0,
          'color': _hex(style.color),
        });
      }
    }
    node.visitChildren(visit);
  }

  visit(root);
  return out;
}

List<Map<String, dynamic>> _styleTokenProbes(BuildContext? context) {
  final out = <Map<String, dynamic>>[];
  final root = context?.findRenderObject();
  if (root == null) return out;
  void visit(RenderObject node) {
    if (out.length >= 16) return;
    if (node is RenderDecoratedBox && node.decoration is BoxDecoration) {
      final d = node.decoration as BoxDecoration;
      final border = d.border;
      final side = border is Border ? border.top : null;
      if (d.color != null || side != null || d.boxShadow != null) {
        out.add({
          'selector': 'RenderDecoratedBox[${out.length}]',
          'size':
              '${node.size.width.toStringAsFixed(1)}x${node.size.height.toStringAsFixed(1)}',
          if (d.color != null) 'backgroundColor': _hex(d.color),
          if (side != null && side.width > 0) 'borderColor': _hex(side.color),
          if (side != null && side.width > 0) 'borderWidth': side.width,
          if (d.borderRadius != null) 'borderRadius': d.borderRadius.toString(),
          if (d.boxShadow != null && d.boxShadow!.isNotEmpty)
            'shadow': d.boxShadow!
                .map(
                  (s) =>
                      '${s.offset.dx}px ${s.offset.dy}px ${s.blurRadius} ${_hex(s.color)}',
                )
                .join(', '),
        });
      }
    }
    node.visitChildren(visit);
  }

  visit(root);
  return out;
}
