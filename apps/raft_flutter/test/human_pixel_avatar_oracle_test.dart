import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Pixel equality with Web: test/fixtures/human_avatar/*.png are Chromium
/// renders of the shared renderHumanAvatarSvg (an <img> with
/// image-rendering: pixelated, DPR 1), written by
/// tool/gen_human_avatar_oracle.mjs. The painter must draw the same bytes at
/// every size, including the ones that do not divide 112.
void main() {
  final dir = Directory('test/fixtures/human_avatar');
  final manifest = jsonDecode(
    File('${dir.path}/recipes.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final sizes = (manifest['sizes'] as List).cast<int>();
  final recipes = (manifest['recipes'] as Map).cast<String, String>();

  Future<Uint8List> decodePng(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  }

  for (final entry in recipes.entries) {
    for (final size in sizes) {
      testWidgets('${entry.key} at $size px is Web\'s pixels', (tester) async {
        final recipe = RaftHumanAvatarRecipe.read(entry.value)!;
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: SizedBox.square(
                  dimension: size.toDouble(),
                  child: CustomPaint(
                    painter: RaftHumanPixelPainter(
                      raftHumanAvatarImage(recipe),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        late Uint8List ours, web;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          expect(image.width, size);
          ours = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          web = await decodePng('${dir.path}/${entry.key}_$size.png');
        });
        expect(ours.length, web.length);
        var different = 0, worst = 0;
        for (var i = 0; i < ours.length; i += 4) {
          var d = 0;
          for (var c = 0; c < 3; c++) {
            d = d > (ours[i + c] - web[i + c]).abs()
                ? d
                : (ours[i + c] - web[i + c]).abs();
          }
          if (d != 0) different++;
          if (d > worst) worst = d;
        }
        expect(
          different,
          0,
          reason:
              '$different of ${size * size} pixels differ from Web (largest channel delta $worst)',
        );
      });
    }
  }
}
