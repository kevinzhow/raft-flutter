import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lh', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final f in ['HankenGrotesk', 'GeistMono']) {
      final bytes = File('../../packages/raft_ui/assets/fonts/$f.ttf').readAsBytesSync();
      await (FontLoader(f)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
    for (final (f, size, line, w) in [
      ('HankenGrotesk', 12.0, 16.0, 400), ('HankenGrotesk', 14.0, 20.0, 400), ('HankenGrotesk', 16.0, 20.0, 700),
      ('HankenGrotesk', 18.0, 22.5, 700), ('GeistMono', 14.0, 20.0, 400), ('GeistMono', 12.0, 16.0, 400)]) {
      final st = TextStyle(fontFamily: f, fontSize: size, height: line / size, fontWeight: FontWeight.values[w ~/ 100 - 1], leadingDistribution: TextLeadingDistribution.even);
      final p = TextPainter(text: TextSpan(text: 'Hg', style: st), textDirection: TextDirection.ltr)..layout();
      final m = p.computeLineMetrics().first;
      print('$f $size/$line base=${p.computeDistanceToActualBaseline(TextBaseline.alphabetic)} h=${p.height} asc=${m.ascent} desc=${m.descent}');
    }
  });
}
