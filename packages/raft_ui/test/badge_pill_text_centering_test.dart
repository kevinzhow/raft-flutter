import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import '../../../tool/testing/system_fonts.dart';

/// Pill / badge labels must be vertically centred in their capsule and never
/// clipped, at every text scale, for Latin text with descenders and CJK, on
/// the Web line boxes and on the Android Chinese control profile (a 1.3 line
/// that is taller than the recipe's fixed 12px content box).
///
/// `RAFT_PILL_SHOTS=<prefix>` additionally writes one PNG per theme and scale
/// to `/tmp/pill-shots/<prefix>-<theme>-<scale>.png` (owner evidence).
const _labels = ['Claude Code', 'Claude Opus 5.5', 'High', 'gpqy', '默认'];
const _scales = [1.0, 1.3, 2.0];

Future<void> _loadFonts(WidgetTester t) => t.runAsync(() async {
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
  final cjk = FontLoader('Noto Sans CJK JP');
  final generic = FontLoader('sans-serif');
  for (final file in cjkTestFonts()) {
    final data = ByteData.sublistView(file.readAsBytesSync());
    cjk.addFont(Future.value(data));
    generic.addFont(Future.value(data));
  }
  await cjk.load();
  await generic.load();
});

class _Config {
  const _Config(this.name, {this.android = false});
  final String name;

  /// Android + Chinese: [RaftControlTypography] (line 1.3, proportional).
  final bool android;
}

const _configs = [_Config('web'), _Config('android-zh', android: true)];

const _variants = [
  RaftBadgeRecipeVariant.accent,
  RaftBadgeRecipeVariant.primary,
  RaftBadgeRecipeVariant.warning,
  RaftBadgeRecipeVariant.success,
  RaftBadgeRecipeVariant.danger,
];

Widget _tree(bool dark, double scale, _Config config, GlobalKey capture) {
  const zh = Locale('zh');
  final theme = raftTheme(
    dark: dark,
    locale: config.android ? zh : null,
    platform: config.android ? TargetPlatform.android : null,
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: config.android ? zh : const Locale('en'),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftPanelTextScope(
                child: SizedBox(
                  width: 480,
                  child: Builder(
                    builder: (context) => RepaintBoundary(
                      key: capture,
                      child: ColoredBox(
                        color: RaftTokens.of(context).colors['layer-panel']!,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Agent detail "运行时配置": RaftInfoRow + inline badge.
                              RaftInfoRow(
                                label: 'Runtime',
                                child: RaftInlineBadge(
                                  badge: RaftRecipeBadge(
                                    _labels[0],
                                    appearance: RaftBadgeRecipeAppearance.solid,
                                    variant: RaftBadgeRecipeVariant.information,
                                    trailing: const SizedBox(
                                      width: 6,
                                      height: 6,
                                    ),
                                  ),
                                ),
                              ),
                              for (var i = 1; i < _labels.length; i++)
                                RaftInfoRow(
                                  label: 'Row',
                                  child: RaftInlineBadge(
                                    badge: RaftRecipeBadge(
                                      _labels[i],
                                      variant: _variants[i % _variants.length],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              // Free-standing recipe badges and raft-ui Badge.
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var i = 0; i < _labels.length; i++)
                                    RaftRecipeBadge(
                                      _labels[i],
                                      variant: _variants[i % _variants.length],
                                    ),
                                  for (var i = 0; i < _labels.length; i++)
                                    RaftBadge(
                                      label: _labels[i],
                                      appearance:
                                          RaftBadgeRecipeAppearance.soft,
                                      variant: _variants[i % _variants.length],
                                    ),
                                  RaftBadge(
                                    label: _labels[2],
                                    variant: RaftBadgeRecipeVariant.information,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double _dist(Color a, Color b) {
  double d(double x, double y) => (x - y) * 255;
  return (d(a.r, b.r).abs() + d(a.g, b.g).abs() + d(a.b, b.b).abs()) / 3;
}

/// Ink rows of the label inside [pill], in logical px from the pill's top, as
/// `(firstInkRow, lastInkRow + 1)`; null when no ink was found.
(double, double)? _inkRows(
  ByteData bytes,
  int width,
  double ratio,
  Rect pill,
  Rect text,
  Color ink,
  double radius,
) {
  // Pixels outside the (inset) capsule are page background, not label ink.
  final shape = RRect.fromRectAndRadius(
    pill.deflate(1),
    Radius.circular(radius),
  );
  Color at(double x, double y) {
    final i = ((y * ratio).floor() * width + (x * ratio).floor()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  // Padding area left of the text, at the pill's vertical centre.
  final bg = at(pill.left + 3, pill.center.dy);
  final span = _dist(ink, bg);
  if (span < 20) return null;
  double? first, last;
  const border = 1.0;
  for (var y = pill.top + border; y < pill.bottom - border; y += 1 / ratio) {
    var hit = false;
    for (var x = text.left; x < text.right; x += 1 / ratio) {
      if (shape.contains(Offset(x, y)) && _dist(at(x, y), bg) > span * .45) {
        hit = true;
        break;
      }
    }
    if (hit) {
      first ??= y - pill.top;
      last = y - pill.top + 1 / ratio;
    }
  }
  return first == null ? null : (first, last!);
}

void main() {
  final missing = missingTestFontReason(cjkTestFonts());
  final shots = Platform.environment['RAFT_PILL_SHOTS'];

  for (final (name, dark) in raftThemeMatrix([
    ('elegant-light', false),
    ('elegant-dark', true),
  ], full: true)) {
    for (final config in _configs) {
      for (final scale in _scales) {
        testWidgets('pill labels centred, unclipped: $name ${config.name} '
            '${scale}x', (t) async {
          if (missing != null) {
            markTestSkipped(missing);
            return;
          }
          t.view.physicalSize = const Size(480 * 2, 900 * 2);
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.reset);
          await _loadFonts(t);
          final capture = GlobalKey();
          await t.pumpWidget(_tree(dark, scale, config, capture));
          await t.pumpAndSettle();

          const ratio = 3.0;
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(capture),
          );
          final origin = boundary.localToGlobal(Offset.zero);
          late final ui.Image image;
          late final ByteData bytes;
          await t.runAsync(() async {
            image = await boundary.toImage(pixelRatio: ratio);
            bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
          });

          final pills = <Finder>[
            for (final w in t.widgetList(find.byType(RaftRecipeBadge)))
              find.byWidget(w),
            for (final w in t.widgetList(find.byType(RaftBadge)))
              find.byWidget(w),
          ];
          expect(pills.length, 5 + 5 + 5 + 1);
          final problems = <String>[];
          for (final badge in pills) {
            final pill = t.getRect(
              find
                  .descendant(
                    of: badge,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          (w is Container && w.decoration != null) ||
                          w is RaftCssBox,
                    ),
                  )
                  .first,
            );
            final richFinder = find
                .descendant(of: badge, matching: find.byType(RichText))
                .first;
            final rich = t.widget<RichText>(richFinder);
            // The line box, before RaftCssText's Blink baseline snap (up to a
            // pixel of paint shift that Chromium shares).
            final lineBox =
                t.renderObject<RenderParagraph>(richFinder).parent!
                    as RenderBox;
            final text = lineBox.localToGlobal(Offset.zero) & lineBox.size;
            final label = rich.text.toPlainText();
            final tag =
                '${t.widget(badge).runtimeType} $label '
                '(${pill.height.toStringAsFixed(1)}px pill)';
            if ((text.center.dy - pill.center.dy).abs() > 0.5) {
              problems.add(
                '$tag: text box centre ${text.center.dy - pill.center.dy}px '
                'off the pill centre',
              );
            }
            if (text.top < pill.top - 0.01 || text.bottom > pill.bottom + .01) {
              problems.add('$tag: text box $text leaves the pill $pill');
            }
            // The paragraph keeps its natural height: Flutter clips a
            // paragraph laid out into less than its line box.
            final paragraph = t.renderObject<RenderParagraph>(richFinder);
            final natural = paragraph.getMaxIntrinsicHeight(
              paragraph.size.width,
            );
            if (paragraph.size.height < natural - 0.01) {
              problems.add(
                '$tag: paragraph ${paragraph.size.height} < natural $natural '
                '(descender clipped)',
              );
            }
            final rows = _inkRows(
              bytes,
              image.width,
              ratio,
              pill.shift(-origin),
              text.shift(-origin),
              rich.text.style?.color ?? Colors.black,
              pill.height / 2,
            );
            if (rows == null) {
              problems.add('$tag: no ink found');
            } else {
              // Descenders of line-height-1 faces (brutal) and CJK ink reach
              // the line edge, so the ink may touch the inner edge; a label
              // clipped to a shorter box is caught by the paragraph check.
              final ink = rows.$2 - rows.$1;
              if (ink < rich.text.style!.fontSize! * 0.5) {
                problems.add('$tag: only ${ink}px of ink (label clipped away)');
              }
            }
          }
          // An inline badge never overflows the box it was allotted.
          for (final inline in t.widgetList(find.byType(RaftInlineBadge))) {
            final box = t.getRect(find.byWidget(inline));
            final pill = t.getRect(
              find
                  .descendant(
                    of: find.byWidget(inline),
                    matching: find.byType(RaftRecipeBadge),
                  )
                  .first,
            );
            if (pill.top < box.top - .01 || pill.bottom > box.bottom + .01) {
              problems.add('inline badge pill $pill leaves its box $box');
            }
          }

          if (shots != null && config.android) {
            await t.runAsync(() async {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('/tmp/pill-shots/$shots-$name-$scale.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
            });
          }
          image.dispose();
          expect(problems, isEmpty, reason: problems.join('\n'));
        });
      }
    }
  }
}
