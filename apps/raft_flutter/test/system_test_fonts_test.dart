import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/testing/system_fonts.dart';

void main() {
  test('default paths retain the Linux capture font tree', () {
    expect(cjkTestFonts(environment: {}).map((file) => file.path), [
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',
    ]);
    expect(
      systemTestFont('truetype/noto/NotoColorEmoji.ttf', environment: {}).path,
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    );
  });
  test('override preserves layout and reports partially missing faces', () {
    final directory = Directory.systemTemp.createTempSync('raft-test-fonts-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final fonts = cjkTestFonts(
      environment: {'RAFT_TEST_FONT_DIR': directory.path},
    );
    fonts.first.parent.createSync(recursive: true);
    fonts.first.writeAsBytesSync([1]);
    final reason = missingTestFontReason(fonts);
    expect(reason, contains(fonts.last.path));
    expect(reason, isNot(contains(fonts.first.path)));
    expect(reason, contains('RAFT_TEST_FONT_DIR'));
    fonts.last.writeAsBytesSync([2]);
    expect(missingTestFontReason(fonts), isNull);
  });
}
