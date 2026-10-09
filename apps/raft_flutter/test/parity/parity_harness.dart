// Flutter provider for the official Raft cross-platform visual parity tool
// (raft-source packages/visual-testing). Writes captures in the provider
// output contract the CLI's diff/report/site read:
//   <result-root>/android/<caseId>.png
//   <result-root>/android/<caseId>.metadata.json
// The provider name is `android` (the CLI's pair precedence knows
// react > android > ios > ohos); metadata records `source: "flutter"`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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
    required this.family,
    required this.dark,
  });

  final Map<String, dynamic> caseJson;

  /// shared/*.json keyed by file stem, e.g. `fixtureData`, `tasksFixture`.
  final Map<String, dynamic> fixtures;
  final RaftFamily family;
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
  String get themeId => dark
      ? 'elegant-dark'
      : family == RaftFamily.brutal
      ? 'brutal-light'
      : 'elegant-light';

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

/// Theme the React render host uses for a case id: `.elegant` suffix →
/// elegant-light, otherwise brutal (light). No official case declares dark.
(RaftFamily, bool) parityThemeFor(
  Map<String, dynamic> visualCase, {
  String? override,
}) {
  // Supplemental theme runs preserve each original case/fixture identity.
  // The official run leaves this unset and retains its original 99-case matrix.
  if (override != null && override.isNotEmpty) {
    return switch (override) {
      'brutal-light' => (RaftFamily.brutal, false),
      'elegant-light' => (RaftFamily.elegant, false),
      'elegant-dark' => (RaftFamily.elegant, true),
      _ => throw ArgumentError.value(
        override,
        'override',
        'Unknown parity theme',
      ),
    };
  }
  final id = visualCase['id'] as String;
  final propsTheme =
      (((visualCase['variants'] as List?)?.firstOrNull as Map?)?['props']
          as Map?)?['theme'];
  if (id.endsWith('.elegant') || propsTheme == 'elegant') {
    return (RaftFamily.elegant, false);
  }
  return (RaftFamily.brutal, false);
}

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
  const systemFallbacks = {
    'Noto Sans CJK JP': [
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    ],
    'Noto Sans CJK SC': [
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    ],
    'Noto Color Emoji': ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'],
    // flutter_test has no OS fallback chain. On Android the system resolves
    // emoji through its own fallback; here the theme's trailing `sans-serif`
    // fallback family stands in for it so emoji do not render as tofu.
    'sans-serif': ['/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'],
  };
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
  final (family, dark) = parityThemeFor(
    visualCase,
    override: Platform.environment['PARITY_THEME_OVERRIDE'],
  );
  final ctx = ParityContext(
    caseJson: visualCase,
    fixtures: fixtures,
    family: family,
    dark: dark,
  );
  final size = Size(ctx.width, ctx.height);
  t.view.physicalSize = size * ctx.density;
  t.view.devicePixelRatio = ctx.density;
  addTearDown(t.view.reset);

  final rootKey = GlobalKey(debugLabel: 'parity-root');
  final raft = raftTheme(family, dark: dark);
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
            child: ColoredBox(color: Colors.white, child: child!),
          ),
        ),
      ),
      home: Builder(builder: (context) => mapping.build(ctx)),
    ),
  );
  await t.pump(const Duration(milliseconds: 50));
  if (mapping.interact != null) await mapping.interact!(t, ctx);
  await t.pump(mapping.settle);
  await t.pump(const Duration(milliseconds: 16));
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
  if (ctx.targetUsed && ctx.targetKey.currentContext != null) {
    final box = ctx.targetKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: rootBox);
    final raw = origin & box.size;
    rect = raw.intersect(Offset.zero & size);
    if (rect != raw) targetNote = 'target clamped to viewport like React';
  }
  final pixelRect = Rect.fromLTRB(
    (rect.left * ctx.density).roundToDouble(),
    (rect.top * ctx.density).roundToDouble(),
    (rect.right * ctx.density).roundToDouble(),
    (rect.bottom * ctx.density).roundToDouble(),
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
      'targetPlatform': 'android',
      'density': 'touch',
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
