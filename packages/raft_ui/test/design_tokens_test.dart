import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/docs/theme-tokens/brutal-light.json')
      .existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

/// Canvas getImageData() stores premultiplied 8-bit; the oracle went through it.
List<int> _readback(Color c) {
  int byte(double v) => (v * 255).round();
  final a = byte(c.a);
  final rgb = [byte(c.r), byte(c.g), byte(c.b)];
  if (a == 255 || a == 0) return [...rgb, a];
  return [
    for (final v in rgb)
      (((v * a / 255).round()) * 255 / a).round().clamp(0, 255),
    a,
  ];
}

void main() {
  const oracleFiles = {
    RaftThemeId.brutal: 'brutal-light',
    RaftThemeId.elegantLight: 'elegant-light',
    RaftThemeId.elegantDark: 'elegant-dark',
  };

  test('generated Dart tokens match the browser oracle within 1/255', () {
    final root = _repoRoot();
    var compared = 0, maxDelta = 0;
    for (final MapEntry(key: id, value: file) in oracleFiles.entries) {
      final oracle =
          jsonDecode(
                File('${root.path}/docs/theme-tokens/$file.json')
                    .readAsStringSync(),
              )['tokens']
              as Map<String, dynamic>;
      final colors = raftColorMap(RaftTokenSet.of(id));
      for (final MapEntry(:key, :value) in oracle.entries) {
        final want = (value['rgba'] as List).cast<int>();
        final got = _readback(colors[key]!);
        expect(got[3], want[3], reason: '$file $key alpha');
        for (var i = 0; i < 3; i++) {
          final d = (got[i] - want[i]).abs();
          if (d > maxDelta) maxDelta = d;
          expect(d, lessThanOrEqualTo(1), reason: '$file $key channel $i');
        }
        compared++;
      }
    }
    expect(compared, 78);
    expect(maxDelta, 1);
  });

  test('authored alpha is preserved exactly', () {
    expect(RaftSemanticColors.elegantDark.ink10.a, .1);
    expect(RaftSemanticColors.brutal.layerBackdrop.a, .65);
    expect(
      RaftSemanticColors.elegantDark.primaryHover.a,
      closeTo(.3448, 1e-12),
    );
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
