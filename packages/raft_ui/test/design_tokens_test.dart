import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/tool/design-source/chrome-oracle.json')
      .existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

/// Swatches whose Chrome bytes no Flutter colour reproduces with source-over
/// (see docs/design-tokens.md "Exceptions"): Chrome truncates the destination
/// term, so a translucent black over the dark canvas lands one level below
/// what any non-negative source can produce, and the out-of-gamut accent edge
/// needs a red above 1.0 before premultiplication.
const _fitExceptions = {
  'elegantDark layer-backdrop canvas',
  'elegantDark field-inset-top canvas',
  'elegantDark button-accent-edge canvas',
  'elegantDark button-accent-edge black',
};

void main() {
  const scopes = {
    'brutal': RaftThemeId.brutal,
    'elegantLight': RaftThemeId.elegantLight,
    'elegantDark': RaftThemeId.elegantDark,
  };
  const fitBackdrops = ['white', 'black', 'canvas'];

  test('opaque tokens equal the Chrome oracle bytes exactly', () {
    final oracle = jsonDecode(
      File('${_repoRoot().path}/tool/design-source/chrome-oracle.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    var compared = 0;
    for (final MapEntry(key: theme, value: id) in scopes.entries) {
      final colors = raftColorMap(RaftTokenSet.of(id));
      final samples = oracle['themes'][theme] as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in samples.entries) {
        final c = colors[key]!;
        if (c.a < 1) continue;
        final rgb = [
          for (final v in [c.r, c.g, c.b]) (v * 255).round(),
        ];
        expect(
          rgb,
          (value['white'] as List).cast<int>(),
          reason: '$theme $key',
        );
        compared++;
      }
    }
    expect(compared, 657);
  });

  test('translucent tokens composite to Chrome bytes in Flutter', () async {
    final oracle = jsonDecode(
      File('${_repoRoot().path}/tool/design-source/chrome-oracle.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final backdropNames = (oracle['backdrops'] as Map).keys
        .cast<String>()
        .toList();
    final misses = <String>{};
    var fitCompared = 0, extraCompared = 0, extraExact = 0;
    for (final MapEntry(key: theme, value: id) in scopes.entries) {
      final set = RaftTokenSet.of(id);
      final colors = raftColorMap(set);
      final backdrop = {
        'white': const Color(0xffffffff),
        'black': const Color(0xff000000),
        'canvas': set.colors.layerCanvas,
        'panel': set.colors.layerPanel,
        'card': set.colors.layerCard,
        'popover': set.colors.layerPopover,
        'canvasMuted': set.colors.layerCanvasMuted,
      };
      final samples = (oracle['themes'][theme] as Map<String, dynamic>).entries
          .where((e) => colors[e.key]!.a > 0 && colors[e.key]!.a < 1)
          .toList();
      final w = backdropNames.length;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var i = 0; i < samples.length; i++) {
        for (var j = 0; j < w; j++) {
          final r = Rect.fromLTWH(j.toDouble(), i.toDouble(), 1, 1);
          canvas.drawRect(r, Paint()..color = backdrop[backdropNames[j]]!);
          canvas.drawRect(r, Paint()..color = colors[samples[i].key]!);
        }
      }
      final image = await recorder.endRecording().toImage(w, samples.length);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var i = 0; i < samples.length; i++) {
        for (var j = 0; j < w; j++) {
          final o = (i * w + j) * 4;
          final got = [for (var ch = 0; ch < 3; ch++) data.getUint8(o + ch)];
          final want = ((samples[i].value as Map)[backdropNames[j]] as List)
              .cast<int>();
          final same = listEquals(got, want);
          if (fitBackdrops.contains(backdropNames[j])) {
            fitCompared++;
            if (!same)
              misses.add('$theme ${samples[i].key} ${backdropNames[j]}');
          } else {
            extraCompared++;
            if (same) extraExact++;
          }
        }
      }
      image.dispose();
    }
    expect(fitCompared, 216);
    expect(misses, _fitExceptions);
    // Other surfaces are not fitted; record how far the fit generalises.
    expect(extraExact / extraCompared, greaterThan(.9));
  });

  test('RaftTokens exposes every generated tier per theme', () {
    for (final (family, dark, id) in [
      (RaftFamily.brutal, false, RaftThemeId.brutal),
      (RaftFamily.elegant, false, RaftThemeId.elegantLight),
      (RaftFamily.elegant, true, RaftThemeId.elegantDark),
    ]) {
      final t = raftTheme(family, dark: dark).extension<RaftTokens>()!;
      final set = RaftTokenSet.of(id);
      expect(t.tokenSet, same(set));
      expect(t.semantic, same(set.colors));
      expect(t.themeShadows, same(set.shadows));
      expect(t.metrics, same(set.metrics));
      expect(t.colors['foreground'], set.colors.foreground);
      expect(t.colors['button-default-fill'], set.components.buttonDefaultFill);
      expect(
        t.colors['color-brutal-yellow-400'],
        RaftPrimitiveColors.brutalYellow400,
      );
    }
  });

  testWidgets('RaftTokens.of resolves the ThemeExtension', (tester) async {
    late RaftTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant, dark: true),
        home: Builder(
          builder: (context) {
            tokens = RaftTokens.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tokens.tokenSet.id, RaftThemeId.elegantDark);
    expect(tokens.metrics.fieldFontSize, 14);
    expect(tokens.metrics.cardTitleLineHeight, 22);
  });

  test('inset shadow layers are separated from BoxShadows', () {
    final xs = RaftThemeShadows.elegantDark.xs;
    expect(xs.layers, hasLength(3));
    expect(xs.inset, hasLength(1));
    expect(xs.inset.single.offset, const Offset(0, 1));
    expect(xs.outer, hasLength(2));
    expect(xs.paintOrder, xs.outer.reversed.toList());
    expect(RaftThemeShadows.brutal.md.outer, [
      BoxShadow(
        color: RaftSemanticColors.brutal.lineStrong,
        offset: const Offset(4, 4),
      ),
    ]);
  });

  test('metrics and Tailwind scale', () {
    expect(RaftThemeMetrics.brutal.fieldFontSize, 16);
    expect(RaftThemeMetrics.brutal.fieldLineHeight, 24);
    expect(RaftThemeMetrics.brutal.cardTitleFontWeight, 700);
    expect(RaftThemeMetrics.elegantLight.headingFontStack.first, 'Inter');
    expect(RaftThemeMetrics.elegantLight.sansFont, 'packages/raft_ui/Geist');
    expect(RaftScale.spacing, 4);
    expect(RaftScale.radius['md'], 6);
    expect(RaftScale.text['sm']!.fontSize, 14);
    expect(RaftScale.text['sm']!.lineHeight, 20);
    expect(RaftScale.ease['slide'], const Cubic(.32, .72, 0, 1));
  });
}
