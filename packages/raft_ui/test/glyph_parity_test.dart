// Pixel parity of RaftIcon against lucide-react painted by Chromium.
//
// The reference grid (tool/glyph_parity/reference/chromium.png) is produced by
// `tool/glyph-parity --refresh-reference` from lucide-react's own SSR markup;
// this test paints the same grid with RaftIcon and compares every cell. Run
// `tool/glyph-parity` to also write tool/glyph_parity/results.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

final _dir = Directory('../../tool/glyph_parity');

// Ceilings for the committed reference (Chromium 147, flutter_tester); measured
// values are in tool/glyph_parity/results.json (overall mean ink delta ~0.16,
// worst cell ~2.5). Deltas are 8-bit channel differences over "ink" pixels
// (pixels either raster covers). A wrong geometry (e.g. square-check instead
// of square-check-big) scores 30+ and an unscaled stroke width >0.1 coverage.
const _maxMeanInk = 1.0;
const _maxCellMeanInk = 6.0;
const _maxCoverageDelta = 0.02;

void main() {
  testWidgets('RaftIcon matches lucide-react rasterized by Chromium', (
    tester,
  ) async {
    final spec =
        jsonDecode(File('${_dir.path}/samples.json').readAsStringSync())
            as Map<String, dynamic>;
    final reference =
        jsonDecode(
              File('${_dir.path}/reference/manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final sizes = (spec['sizes'] as List).cast<num>().map((s) => s.toDouble());
    final pitch = (spec['pitch'] as num).toInt();
    final inset = (spec['inset'] as num).toDouble();
    final samples = (spec['samples'] as List).cast<Map<String, dynamic>>();
    final probes = {
      for (final s in (reference['samples'] as List).cast<Map>())
        if (s['nodes'] != null) s['id'] as String: s['nodes'] as List,
    };
    final width = pitch * sizes.length, height = pitch * samples.length;
    tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const black = Color(0xFF000000);
    Widget cell(Map<String, dynamic> sample, double size) {
      final f = (sample['flutter'] as Map?) ?? const {};
      final strokeWidth = (f['strokeWidth'] as num?)?.toDouble() ?? 2;
      if (sample['probe'] != null) {
        final nodes = [
          for (final n in probes[sample['id']]!.cast<List>())
            (n[0] as String, (n[1] as Map).cast<String, String>()),
        ];
        return CustomPaint(
          size: Size.square(size),
          painter: RaftGlyphPainter.debugNodes(nodes, color: black),
        );
      }
      return RaftIcon(
        RaftGlyph.values.byName(sample['glyph'] as String),
        size: size,
        color: black,
        strokeWidth: strokeWidth,
        absoluteStrokeWidth: f['absoluteStrokeWidth'] == true,
        filled: f['filled'] as bool?,
      );
    }

    final boundary = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Stack(
              children: [
                for (final (row, sample) in samples.indexed)
                  for (final (col, size) in sizes.indexed)
                    Positioned(
                      left: col * pitch + inset,
                      top: row * pitch + inset,
                      width: size,
                      height: size,
                      child: cell(sample, size),
                    ),
              ],
            ),
          ),
        ),
      ),
    );

    late Uint8List flutterPixels, referencePixels;
    late ByteData flutterPng;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      flutterPixels = (await image.toByteData())!.buffer.asUint8List();
      flutterPng = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final codec = await ui.instantiateImageCodec(
        File('${_dir.path}/reference/chromium.png').readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, width);
      expect(frame.image.height, height);
      referencePixels = (await frame.image.toByteData())!.buffer.asUint8List();
    });

    // Per cell: channel deltas over the pitch x pitch square.
    final rows = <Map<String, Object>>[];
    var inkSum = 0.0, inkCount = 0, worst = 0;
    for (final (row, sample) in samples.indexed) {
      for (final (col, size) in sizes.indexed) {
        var maxDelta = 0, sum = 0, ink = 0, inkDelta = 0;
        var coverageF = 0.0, coverageR = 0.0;
        for (var y = row * pitch; y < (row + 1) * pitch; y++) {
          for (var x = col * pitch; x < (col + 1) * pitch; x++) {
            final i = (y * width + x) * 4;
            var d = 0;
            for (var c = 0; c < 3; c++) {
              d = math.max(
                d,
                (flutterPixels[i + c] - referencePixels[i + c]).abs(),
              );
            }
            final f = 255 - flutterPixels[i], r = 255 - referencePixels[i];
            coverageF += f / 255;
            coverageR += r / 255;
            maxDelta = math.max(maxDelta, d);
            sum += d;
            if (f > 0 || r > 0) {
              ink++;
              inkDelta += d;
            }
          }
        }
        final meanInk = ink == 0 ? 0.0 : inkDelta / ink;
        final coverageDelta = coverageR == 0
            ? 0.0
            : (coverageF - coverageR).abs() / coverageR;
        inkSum += inkDelta;
        inkCount += ink;
        worst = math.max(worst, maxDelta);
        rows.add({
          'id': sample['id'] as String,
          'size': size,
          'max': maxDelta,
          'meanCell': double.parse((sum / (pitch * pitch)).toStringAsFixed(3)),
          'meanInk': double.parse(meanInk.toStringAsFixed(3)),
          'coverageDelta': double.parse(coverageDelta.toStringAsFixed(4)),
        });
      }
    }
    final meanInk = inkSum / inkCount;
    final out = Platform.environment['GLYPH_PARITY_OUT'];
    if (out != null) {
      final summary = {
        'reference': 'tool/glyph_parity/reference/chromium.png',
        'chromium': reference['chromium'],
        'samples': samples.length,
        'sizes': sizes.toList(),
        'cells': rows.length,
        'overall': {
          'max': worst,
          'meanInk': double.parse(meanInk.toStringAsFixed(3)),
          'meanCell': double.parse(
            (rows.fold<double>(0, (a, r) => a + (r['meanCell']! as double)) /
                    rows.length)
                .toStringAsFixed(3),
          ),
          'worstCellMeanInk': rows
              .map((r) => r['meanInk']! as double)
              .reduce(math.max),
          'worstCoverageDelta': rows
              .map((r) => r['coverageDelta']! as double)
              .reduce(math.max),
        },
        'cellsDetail': rows,
      };
      File(out).writeAsStringSync(
        '${const JsonEncoder.withIndent(' ').convert(summary)}\n',
      );
      File(
        '${File(out).parent.path}/glyph-parity-flutter.png',
      ).writeAsBytesSync(flutterPng.buffer.asUint8List());
    }
    expect(meanInk, lessThan(_maxMeanInk), reason: 'mean ink delta');
    for (final r in rows) {
      expect(
        r['meanInk']! as double,
        lessThan(_maxCellMeanInk),
        reason: '${r['id']} @${r['size']} mean ink delta',
      );
      expect(
        r['coverageDelta']! as double,
        lessThan(_maxCoverageDelta),
        reason: '${r['id']} @${r['size']} ink coverage',
      );
    }
  });
}
