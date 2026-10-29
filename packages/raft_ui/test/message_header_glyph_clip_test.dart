import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Kevin (macOS, zh): the descenders of "tygg" in a message header were cut
// flat. The header sat in a ClipRect exactly one CSS line tall (Elegant
// `leading-none` = 14px) while the glyphs of the font reach below that line, so
// descenders (and ideograph tops of a fallback face) were clipped. Only the
// horizontal reserve (`pr-24`) may clip; glyph ink must never be cut.
//
// The test compares the vertical ink extent around the baseline of the real
// row with the same strings drawn with nothing around them.

const _pixelRatio = 8.0;

Future<void> _loadFonts() async {
  for (final name in const [
    'SpaceGrotesk',
    'SpaceMono',
    'HankenGrotesk',
    'Geist',
    'GeistMono',
    'Inter',
  ]) {
    // Bundled assets, so the test does not depend on the working directory.
    ByteData data;
    try {
      data = await rootBundle.load('packages/raft_ui/assets/fonts/$name.ttf');
    } on FlutterError {
      data = await rootBundle.load('assets/fonts/$name.ttf');
    }
    await (FontLoader(name)..addFont(Future.value(data))).load();
  }
  if (!_cjkFont.existsSync()) return;
  final cjk = _cjkFont.readAsBytesSync().buffer.asByteData();
  await (FontLoader('ProxyCJK')..addFont(Future.value(cjk))).load();
}

/// Stand-in for PingFang SC (macOS), whose metrics are also taller than the
/// bundled Latin faces. Only the CJK cases need it.
final _cjkFont = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');

/// Vertical ink extent (logical px, top/bottom edge) of everything that
/// differs from [bg] inside [rect]; null when nothing was painted.
(double, double)? _inkRows(ByteData rgba, int width, ui.Rect rect, Color bg) {
  final x0 = (rect.left * _pixelRatio).floor().clamp(0, width);
  final x1 = (rect.right * _pixelRatio).ceil().clamp(0, width);
  final rows = rgba.lengthInBytes ~/ (width * 4);
  final y0 = (rect.top * _pixelRatio).floor().clamp(0, rows);
  final y1 = (rect.bottom * _pixelRatio).ceil().clamp(0, rows);
  final br = (bg.r * 255).round(), bgc = (bg.g * 255).round();
  final bb = (bg.b * 255).round();
  int? first, last;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final o = (y * width + x) * 4;
      final d =
          ((rgba.getUint8(o) - br).abs() +
              (rgba.getUint8(o + 1) - bgc).abs() +
              (rgba.getUint8(o + 2) - bb).abs()) /
          3;
      if (d > 40) {
        first ??= y;
        last = y;
        break;
      }
    }
  }
  if (first == null || last == null) return null;
  return (first / _pixelRatio, (last + 1) / _pixelRatio);
}

void main() {
  for (final (dark) in raftThemeMatrix([(false), (true)], full: true)) {
    for (final (label, author, timestamp, cjk) in const [
      ('latin descenders', 'tygg', '23:16 gypq', false),
      ('cjk author', '张三丰丽', '23:16', true),
      ('tall latin descenders', 'Cindy gy', '23:16 gypq', true),
    ]) {
      testWidgets(
        'header glyph ink is not clipped $label ${dark ? 'dark' : 'light'}',
        (t) async {
          if (cjk && !_cjkFont.existsSync()) return;
          await t.runAsync(_loadFonts);
          // Flutter's test engine has no system font fallback. The CJK cases
          // use the taller proxy face for all glyphs, including Latin, and
          // retain it as fallback for every control's text.
          final primary = cjk ? 'ProxyCJK' : 'Geist';
          final theme = raftTheme(
            dark: dark,
            systemFonts: cjk,
            systemFontFamilies: RaftFontFamilies(
              body: primary,
              heading: primary,
              mono: 'GeistMono',
              fallback: const ['ProxyCJK'],
            ),
          );
          final tokens = theme.extension<RaftTokens>()!;
          final recipe = RaftMessageRowRecipe(tokens, viewportWidth: 800);
          final key = GlobalKey();
          final bg = theme.scaffoldBackgroundColor;
          Widget host(Widget child) => MaterialApp(
            theme: theme,
            home: Scaffold(
              backgroundColor: bg,
              body: DefaultTextStyle.merge(
                style: TextStyle(
                  fontFamilyFallback: cjk ? const ['ProxyCJK'] : null,
                ),
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: bg,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          Future<(ByteData, int)> shot() async {
            late ui.Image image;
            await t.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              image = await boundary.toImage(pixelRatio: _pixelRatio);
            });
            late ByteData bytes;
            await t.runAsync(() async {
              bytes = (await image.toByteData())!;
            });
            final width = image.width;
            image.dispose();
            return (bytes, width);
          }

          // Ink extent relative to the paragraph baseline: (above, below).
          (double, double) inkAroundBaseline(
            ByteData bytes,
            int width,
            Finder text,
          ) {
            final paragraph = t.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)).first,
            );
            final origin = paragraph.localToGlobal(Offset.zero);
            // ignore: invalid_use_of_protected_member
            final fromTop = paragraph.computeDistanceToActualBaseline(
              TextBaseline.alphabetic,
            );
            final baseline = origin.dy + fromTop;
            final rect = Rect.fromLTRB(
              origin.dx,
              origin.dy - 12,
              origin.dx + paragraph.size.width,
              origin.dy + paragraph.size.height + 12,
            );
            final rows = _inkRows(bytes, width, rect, bg)!;
            return (baseline - rows.$1, rows.$2 - baseline);
          }

          // Reference: the same strings with the same styles, nothing around
          // them that could clip.
          await t.pumpWidget(
            host(
              DefaultTextHeightBehavior(
                textHeightBehavior: raftCssTextHeightBehavior,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      author,
                      key: const ValueKey('ref-a'),
                      style: recipe.author,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      timestamp,
                      key: const ValueKey('ref-t'),
                      style: recipe.time,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
          final (refBytes, refWidth) = await shot();
          final refAuthor = inkAroundBaseline(
            refBytes,
            refWidth,
            find.byKey(const ValueKey('ref-a')),
          );
          final refTime = inkAroundBaseline(
            refBytes,
            refWidth,
            find.byKey(const ValueKey('ref-t')),
          );

          await t.pumpWidget(
            host(
              SizedBox(
                width: 650,
                child: RaftMessageRow(
                  author: author,
                  timestamp: timestamp,
                  onAuthor: () {},
                  content: const SizedBox(height: 20, width: 200),
                ),
              ),
            ),
          );
          await t.pump();
          final (rowBytes, rowWidth) = await shot();
          final rowAuthor = inkAroundBaseline(
            rowBytes,
            rowWidth,
            find.byKey(const ValueKey('message-author')),
          );
          final rowTime = inkAroundBaseline(
            rowBytes,
            rowWidth,
            find.text(timestamp).first,
          );
          // Paint-clip metadata also governs semantics visibility and the
          // text-fit audit. It must contain the reference glyph ink, even
          // when a short CSS line box has taller fallback-font descenders.
          for (final (text, ink) in [
            (find.byKey(const ValueKey('message-author')), refAuthor),
            (find.text(timestamp).first, refTime),
          ]) {
            final paragraph = t.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)).first,
            );
            final origin = paragraph.localToGlobal(Offset.zero);
            // ignore: invalid_use_of_protected_member
            final baseline =
                origin.dy +
                paragraph.computeDistanceToActualBaseline(
                  TextBaseline.alphabetic,
                );
            RenderObject child = paragraph;
            for (
              var parent = child.parent;
              parent != null;
              child = parent, parent = parent.parent
            ) {
              if (parent is! RenderClipRect) continue;
              final clip = parent.describeApproximatePaintClip(child);
              if (clip == null) continue;
              final global = MatrixUtils.transformRect(
                parent.getTransformTo(null),
                clip,
              );
              expect(global.top, lessThanOrEqualTo(baseline - ink.$1 + .14));
              expect(
                global.bottom,
                greaterThanOrEqualTo(baseline + ink.$2 - .14),
              );
            }
          }
          // ignore: avoid_print
          print(
            '${dark ? 'dark' : 'light'} $label author ref=$refAuthor row=$rowAuthor | '
            'time ref=$refTime row=$rowTime',
          );
          const eps = 1 / _pixelRatio + 0.01; // one device pixel
          for (final (name, ref, row) in [
            ('author', refAuthor, rowAuthor),
            ('time', refTime, rowTime),
          ]) {
            expect(
              row.$1,
              greaterThanOrEqualTo(ref.$1 - eps),
              reason: '$name top',
            );
            expect(
              row.$2,
              greaterThanOrEqualTo(ref.$2 - eps),
              reason: '$name bottom',
            );
          }
        },
      );
    }
  }
}
