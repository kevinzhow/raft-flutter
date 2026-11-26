// Flutter provider for the official Raft cross-platform visual parity tool
// (raft-source packages/visual-testing). Writes captures in the provider
// output contract the CLI's diff/report/site read:
//   <result-root>/android/<caseId>.png
//   <result-root>/android/<caseId>.metadata.json
// The provider name is `android` (the CLI's pair precedence knows
// react > android > ios > ohos); metadata records `source: "flutter"`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
    this.fullLengthHeight,
    this.settle = const Duration(milliseconds: 400),
    this.encloseElementCrop = false,
    this.scrollContentCrop = false,
    this.emulatedDeviceScaleFactor = true,
  });

  /// Product widgets exercised (for coverage reports, e.g. `raft_ui:RaftButton`).
  final List<String> widgets;
  final ParityBuilder build;
  final ParityInteraction? interact;
  final String notes;
  final double? fullLengthHeight;
  final Duration settle;

  /// Enclose the element's bounds in whole CSS pixels before applying density.
  final bool encloseElementCrop;

  /// Capture the element through its actual scroll viewport when it extends
  /// under pinned native chrome.
  final bool scrollContentCrop;

  /// False for reference images captured with Chromium's forced device scale.
  final bool emulatedDeviceScaleFactor;
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

  /// Observed input/state for a case that opts into capture qualification.
  final captureEvidence = <String, dynamic>{};

  /// The capture target. Builders wrap the element that corresponds to the
  /// React `capture.selector` with [target]; when they do not, the whole
  /// viewport is captured (correct for `body` selectors).
  final _cleanup = <VoidCallback>[];
  void onDispose(VoidCallback callback) => _cleanup.add(callback);
  void dispose() {
    for (final callback in _cleanup.reversed) {
      callback();
    }
    _cleanup.clear();
  }

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

/// Which theme pack and mode a case renders with.
///
/// Raft is the only look, so the pack is always [raftThemePackId]; the names
/// only choose the brightness. The extension suite names its theme in
/// `props.parityTheme`: the retired family names (`elegant`, `brutal`) still
/// select light and `elegant-dark`, `brutal-dark`, `dark` select dark, so the
/// case ids stay stable.
({String pack, bool dark}) parityThemeFor(
  Map<String, dynamic> visualCase, {
  String? override,
}) {
  ({String pack, bool dark}) named(String name) => switch (name) {
    'brutal-light' ||
    'brutal' ||
    'elegant-light' ||
    'elegant' ||
    'light' ||
    'raft' ||
    'raft-light' => (pack: raftThemePackId, dark: false),
    'brutal-dark' ||
    'elegant-dark' ||
    'dark' ||
    'raft-dark' => (pack: raftThemePackId, dark: true),
    _ => throw ArgumentError.value(name, 'override', 'Unknown parity theme'),
  };
  final props =
      ((visualCase['variants'] as List?)?.firstOrNull as Map?)?['props']
          as Map?;
  final extTheme = props?['parityTheme'];
  // `<look>-case` (raft-case): the brightness follows the case's own
  // `parityTheme` (a name that ends in `dark` renders dark).
  if (override != null && override.endsWith('-case')) {
    final look = override.substring(0, override.length - '-case'.length);
    final dark = extTheme is String && extTheme.endsWith('dark');
    return named('$look-${dark ? 'dark' : 'light'}');
  }
  if (override != null && override.isNotEmpty) return named(override);
  if (extTheme is String) return named(extTheme);
  final theme = visualCase['theme'];
  if (theme == 'dark' || theme == 'light') return named(theme as String);
  return (pack: raftThemePackId, dark: false);
}

/// The selected pack and brightness recorded beside the captured image.
String parityThemeLabel(({String pack, bool dark}) selection) =>
    '${selection.pack}-${selection.dark ? 'dark' : 'light'}';

Map<String, List<String>> paritySystemFonts() => {
  for (final family in cjkStandInFaces.keys)
    family: [
      systemTestFont('opentype/noto/NotoSansCJK-Regular.ttc').path,
      systemTestFont('opentype/noto/NotoSansCJK-Bold.ttc').path,
    ],
  'Noto Color Emoji': [systemTestFont('truetype/noto/NotoColorEmoji.ttf').path],
  // Every generic a recipe declaration can end in, which Chromium resolves
  // through fontconfig and flutter_test resolves to its own box font unless
  // it has a file. `font-mono` is the one that showed it: the channel date
  // divider is mono, so a Japanese date hit `ui-monospace` and drew boxes.
  for (final MapEntry(key: family, value: paths) in genericStandInFonts.entries)
    family: [for (final path in paths) systemTestFont(path).path],
  // flutter_test has no OS fallback chain. On Android the system resolves
  // emoji through its own fallback; here the theme's trailing `sans-serif`
  // fallback family stands in for it so emoji do not render as tofu. One
  // family resolves to one typeface, so this cannot also carry the CJK faces:
  // those are their own families above, ahead of it in every chain.
  'sans-serif': [systemTestFont('truetype/noto/NotoColorEmoji.ttf').path],
};

String? missingParityFontReason() => missingTestFontReason(
  paritySystemFonts().values.expand((paths) => paths).toSet().map(File.new),
);

bool _fontsLoaded = false;
final _loadedFontFamilies = <String>{};

/// Loads every font the app bundles (FontManifest.json: raft_ui families and
/// MaterialIcons) plus the system CJK/emoji families the theme names as
/// fallbacks, so text is never rendered with the Ahem test font.
Future<List<String>> loadParityFonts() async {
  if (_fontsLoaded) return List.unmodifiable(_loadedFontFamilies);
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
      loaded.add(bare);
    }
  }
  final systemFallbacks = paritySystemFonts();
  for (final MapEntry(key: family, value: paths) in systemFallbacks.entries) {
    final files = paths.map(File.new).where((f) => f.existsSync()).toList();
    if (files.isEmpty) continue;
    final loader = FontLoader(family);
    for (final file in files) {
      final face = cjkStandInFaces[family];
      loader.addFont(
        face != null
            ? Future.value(cjkTestFontData(file, face))
            : file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
    loaded.add(family);
  }
  _loadedFontFamilies.addAll(loaded);
  _fontsLoaded = true;
  return List.unmodifiable(_loadedFontFamilies);
}

Future<Uint8List?> _captureScrollableElement(
  WidgetTester tester,
  RenderRepaintBoundary root,
  RenderBox target,
  ScrollPosition position,
  Size pixels,
  double density,
) async {
  final viewport = RenderAbstractViewport.of(target) as RenderBox;
  Rect bounds(RenderBox box) =>
      box.localToGlobal(Offset.zero, ancestor: root) & box.size;
  final clip = bounds(viewport).intersect(Offset.zero & root.size);
  final original = position.pixels;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final frames = <ui.Image>[];
  try {
    if (bounds(target).top < clip.top) {
      position.jumpTo(
        math.max(
          position.minScrollExtent,
          original + bounds(target).top - clip.top,
        ),
      );
      await tester.pump();
    }
    for (var next = 0; next < pixels.height;) {
      final origin = bounds(target).topLeft * density;
      final top = origin.dy.floor() + next;
      final bottom = math.min(
        origin.dy.floor() + pixels.height.toInt(),
        (clip.bottom * density).floor(),
      );
      if (top < (clip.top * density).floor() || bottom <= top) {
        throw StateError(
          'The scroll viewport cannot reveal the full capture target',
        );
      }
      final frame = (await tester.runAsync(
        () => root.toImage(pixelRatio: density),
      ))!;
      frames.add(frame);
      final height = (bottom - top).toDouble();
      canvas.drawImageRect(
        frame,
        Rect.fromLTWH(
          origin.dx.floorToDouble(),
          top.toDouble(),
          pixels.width,
          height,
        ),
        Rect.fromLTWH(0, next.toDouble(), pixels.width, height),
        Paint()..filterQuality = FilterQuality.none,
      );
      next += bottom - top;
      if (next < pixels.height) {
        position.jumpTo(
          math.min(
            position.maxScrollExtent,
            position.pixels + bottom / density - clip.top,
          ),
        );
        await tester.pump();
      }
    }
    return await tester.runAsync(() async {
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        pixels.width.toInt(),
        pixels.height.toInt(),
      );
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
  } finally {
    if (recorder.isRecording) recorder.endRecording().dispose();
    for (final frame in frames) {
      frame.dispose();
    }
    if (position.pixels != original) {
      position.jumpTo(original);
      await tester.pump();
    }
  }
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
  // Keep the reference's CSS paint policy local to the case.
  final previousBorderSnap = RaftBorderSnap.emulatedDeviceScaleFactor;
  RaftBorderSnap.emulatedDeviceScaleFactor = mapping.emulatedDeviceScaleFactor;
  addTearDown(
    () => RaftBorderSnap.emulatedDeviceScaleFactor = previousBorderSnap,
  );
  final selection = parityThemeFor(
    visualCase,
    override: Platform.environment['PARITY_THEME_OVERRIDE'],
  );
  final dark = selection.dark;
  final ctx = ParityContext(
    caseJson: visualCase,
    fixtures: fixtures,
    dark: dark,
  );
  try {
    final locale = raftDisplayLanguages[ctx.props['displayLanguage']]?.$1;
    final size = Size(ctx.width, mapping.fullLengthHeight ?? ctx.height);
    t.view.physicalSize = size * ctx.density;
    t.view.devicePixelRatio = ctx.density;
    addTearDown(t.view.reset);

    final rootKey = GlobalKey(debugLabel: 'parity-root');
    final raft = raftTheme(
      dark: dark,
      pack: packForThemeId(selection.pack),
      locale: locale,
      textLocale: locale,
    );
    final tokens = raft.extension<RaftTokens>()!;
    final selectedFonts = {
      'heading': tokens.headingFont,
      'sans': tokens.bodyFont,
      'mono': tokens.monoFont,
    };
    final missingFonts = selectedFonts.values.toSet().difference(
      _loadedFontFamilies,
    );
    if (missingFonts.isNotEmpty) {
      throw StateError(
        'Parity theme fonts were not loaded: ${missingFonts.join(', ')}',
      );
    }
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
        locale: locale ?? const Locale('en'),
        supportedLocales: raftDisplayLanguages.values.map((entry) => entry.$1),
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
    RenderBox? scrollTarget;
    // Extension cases name the Flutter widget that corresponds to the React
    // capture.selector (`capture.androidKey`, a ValueKey<String>).
    final androidKey =
        (visualCase['capture'] as Map?)?['androidKey'] as String?;
    final keyed = androidKey == null
        ? null
        : find.byKey(ValueKey(androidKey)).evaluate().firstOrNull;
    if (androidKey != null && keyed == null) {
      throw StateError(
        'case ${ctx.id}: capture.androidKey $androidKey missing',
      );
    }
    final targetContext = keyed ?? ctx.targetKey.currentContext;
    if (mapping.encloseElementCrop && targetContext == null) {
      throw StateError(
        'case ${ctx.id}: CSS enclosure requires an element target',
      );
    }
    if ((keyed != null || ctx.targetUsed) && targetContext != null) {
      final box = targetContext.findRenderObject()! as RenderBox;
      final origin = box.localToGlobal(Offset.zero, ancestor: rootBox);
      final raw = origin & box.size;
      rect = raw.intersect(Offset.zero & size);
      if (rect != raw) targetNote = 'target clamped to viewport like React';
      if (mapping.scrollContentCrop) {
        final viewport = RenderAbstractViewport.maybeOf(box);
        if (viewport case final RenderBox viewportBox) {
          final bounds =
              viewportBox.localToGlobal(Offset.zero, ancestor: rootBox) &
              viewportBox.size;
          if (raw.top < bounds.top || raw.bottom > bounds.bottom) {
            scrollTarget = box;
            rect = raw;
            targetNote =
                'full element reconstructed through its scroll viewport';
          }
        }
      }
    }
    // Playwright encloses fractional element bounds in CSS pixels before
    // applying density. Use that crop for keyed extensions and opted-in cases.
    final enclose = keyed != null || mapping.encloseElementCrop;
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

    final png = scrollTarget != null
        ? await _captureScrollableElement(
            t,
            rootBox,
            scrollTarget,
            Scrollable.of(targetContext!).position,
            pixelRect.size,
            ctx.density,
          )
        : await t.runAsync(() async {
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
            final picture = recorder.endRecording();
            final cropped = await picture.toImage(
              pixelRect.width.toInt(),
              pixelRect.height.toInt(),
            );
            picture.dispose();
            final bytes = await cropped.toByteData(
              format: ui.ImageByteFormat.png,
            );
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
      'theme': parityThemeLabel(selection),
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
      'fontLoading': {
        'selected': selectedFonts,
        'registered': _loadedFontFamilies.toList()..sort(),
      },
      'typography': _typographyProbes(targetContext ?? rootKey.currentContext),
      'styleTokens': _styleTokenProbes(targetContext ?? rootKey.currentContext),
      if (ctx.captureEvidence.isNotEmpty) 'fixtureState': ctx.captureEvidence,
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
  } finally {
    try {
      // Complete modal route futures before removing their owners.
      for (final nav in t.stateList<NavigatorState>(find.byType(Navigator))) {
        nav.popUntil((route) => route.isFirst);
      }
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      await t.pumpWidget(const SizedBox.shrink());
      // Popping the phone detail route can mount the underlying composer
      // for one frame. Drain its deferred one-shot work after disposal.
      await t.pump(Duration.zero);
    } finally {
      ctx.dispose();
    }
  }
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
    // `finder`: a control that carries no ValueKey (control-state cases,
    // tool/parity-ext/build-states-cases.py): {text|tooltip|label|key, nth?, in?}.
    final finderSpec = raw['finder'] as Map?;
    Finder? locate({bool skipOffstage = true}) => finderSpec != null
        ? parityFinder(finderSpec, skipOffstage: skipOffstage)
        : key == null
        ? null
        : find.byKey(ValueKey<String>(key), skipOffstage: skipOffstage);
    final visibleTarget = locate();
    // A built sliver child outside the viewport is omitted by the default
    // finder. Playwright scrolls that action into view before clicking it.
    final offscreenTap =
        raw['type'] == 'tap' &&
        raw['scroll'] != false &&
        visibleTarget != null &&
        visibleTarget.evaluate().isEmpty;
    final target = offscreenTap ? locate(skipOffstage: false) : visibleTarget;
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
        if (raw['scroll'] == 'if-needed') {
          await _revealForClick(t, target!.first);
        } else if (raw['scroll'] == 'fully-visible') {
          await _revealIfClipped(t, target!.first);
          expect(target.first.hitTestable(), findsOneWidget);
        } else if (raw['scroll'] != false) {
          await t.ensureVisible(target!.first);
        }
        await t.pump();
        // Finding an offstage widget does not authorize a capture of it: the
        // scroll must make this real action reachable by pointer input.
        if (offscreenTap && target!.hitTestable().evaluate().isEmpty) {
          throw StateError(
            'androidInteractions target $key is not hittable after scrolling',
          );
        }
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
        if (raw['scroll'] == 'if-needed') {
          await _revealForClick(t, byText.first);
        } else {
          await t.ensureVisible(byText.first);
        }
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
        if (raw['scroll'] == 'if-needed') {
          await _revealForClick(t, target!.first);
        } else if (raw['scroll'] == 'fully-visible') {
          await _revealIfClipped(t, target!.first);
        } else {
          await t.ensureVisible(target!.first);
        }
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
      case 'hold':
        // Pointer down on the control and no release: the pressed state.
        mouse ??= await t.createGesture(kind: PointerDeviceKind.mouse);
        try {
          await mouse.addPointer(location: Offset.zero);
        } on AssertionError {
          // The mouse device is already added.
        }
        await mouse.moveTo(t.getCenter(target!.first));
        await mouse.down(t.getCenter(target.first));
        addTearDown(() async {
          try {
            await mouse?.up();
          } on Object {
            // Already released.
          }
        });
      case 'focus':
        // Keyboard focus ring on the control (the Web case calls locator.focus() after no pointer use).
        final previousHighlight = FocusManager.instance.highlightStrategy;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = previousHighlight,
        );
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        FocusNode? node;
        // A keyed control can wrap its button in a keyboard listener Focus.
        // Prefer the interactive detector, not that listener's focus node.
        for (final e
            in find
                .descendant(
                  of: target!.first,
                  matching: find.byType(FocusableActionDetector),
                  matchRoot: true,
                )
                .evaluate()) {
          final detector = e.widget as FocusableActionDetector;
          final n = detector.focusNode;
          if (detector.enabled && n != null && n.canRequestFocus) {
            node = n;
            break;
          }
        }
        for (final e
            in find
                .descendant(of: target.first, matching: find.byType(Focus))
                .evaluate()) {
          if (node != null) break;
          final n = (e.widget as Focus).focusNode ?? Focus.maybeOf(e);
          if (n != null && n.canRequestFocus) {
            node = n;
            break;
          }
        }
        node ??= Focus.maybeOf(t.element(target.first));
        // Exercise keyboard modality as the focus-state case promises. A
        // prior editor tap is pointer modality; changing Flutter's highlight
        // strategy alone does not make it a keyboard interaction.
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        node?.requestFocus();
        await t.pump();
      case 'tab':
        // Keyboard focus: Tab `count` times (the Web case presses Tab the same number of times).
        for (var i = 0; i < ((raw['count'] as num?) ?? 1).toInt(); i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump(const Duration(milliseconds: 50));
        }
      case 'mark':
        // Crop marker over the control (plus `pad`), the counterpart of the
        // Web `mark` interaction: the capture selector / androidKey is `states-crop`.
        await t.pump(const Duration(milliseconds: 300));
        final markPad = ((raw['pad'] as num?) ?? 6).toDouble();
        final markRect = t.getRect(target!.first).inflate(markPad);
        final overlay = t.state<OverlayState>(find.byType(Overlay).first);
        final marker = OverlayEntry(
          builder: (_) => Positioned.fromRect(
            rect: markRect,
            child: const IgnorePointer(
              child: SizedBox.expand(key: ValueKey('states-crop')),
            ),
          ),
        );
        overlay.insert(marker);
        addTearDown(() {
          // Unmounting the widget does not remove the entry's overlay ownership.
          marker.remove();
          marker.dispose();
        });
      case 'key':
        final name = raw['key'] as String;
        final logical = switch (name) {
          'arrowDown' => LogicalKeyboardKey.arrowDown,
          'arrowUp' => LogicalKeyboardKey.arrowUp,
          'enter' => LogicalKeyboardKey.enter,
          'escape' => LogicalKeyboardKey.escape,
          'tab' => LogicalKeyboardKey.tab,
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

Future<void> _revealForClick(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _revealIfClipped(WidgetTester tester, Finder target) async {
  final box = tester.renderObject<RenderBox>(target);
  final viewport = RenderAbstractViewport.of(box) as RenderBox;
  final position = box.localToGlobal(Offset.zero, ancestor: viewport);
  final fullyVisible =
      (Offset.zero & viewport.size).contains(position) &&
      position.dy + box.size.height <= viewport.size.height;
  if (!fullyVisible) {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  }
}

/// The widget a control-state interaction names without a ValueKey:
/// `{text}`, `{tooltip}`, `{label}` (semantics label), `{key}`; `in` scopes it under a keyed
/// ancestor, `nth` picks one of several matches.
Finder parityFinder(Map spec, {bool skipOffstage = true}) {
  Finder base = spec['text'] != null
      ? find.text(spec['text'] as String, skipOffstage: skipOffstage)
      : spec['tooltip'] != null
      ? find.byTooltip(spec['tooltip'] as String, skipOffstage: skipOffstage)
      : spec['label'] != null
      ? find.bySemanticsLabel(
          spec['label'] as String,
          skipOffstage: skipOffstage,
        )
      : find.byKey(ValueKey(spec['key'] as String), skipOffstage: skipOffstage);
  final scope = spec['in'] as String?;
  if (scope != null) {
    base = find.descendant(
      of: find.byKey(ValueKey(scope), skipOffstage: skipOffstage),
      matching: base,
      skipOffstage: skipOffstage,
    );
  }
  final nth = (spec['nth'] as num?)?.toInt();
  return nth == null ? base : base.at(nth);
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
          'fontFamilyFallback': style.fontFamilyFallback,
          'fontSize': fontSize,
          'fontWeight': (style.fontWeight ?? FontWeight.w400).value,
          'fontVariations': [
            for (final variation
                in style.fontVariations ?? const <FontVariation>[])
              {'axis': variation.axis, 'value': variation.value},
          ],
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
