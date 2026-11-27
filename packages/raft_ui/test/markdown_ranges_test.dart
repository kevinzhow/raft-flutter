import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  test('markdownRanges excludes quoted, linked, and mathematical mentions', () {
    for (final source in [
      '> @Mona',
      '[@Mona](https://example.com)',
      '[@Mona](<@SomeoneElse>)',
      r'$x + @Mona$',
      '`` code ` @Mona ``',
      r'\<@Mona>',
    ]) {
      expect(
        raftStructuredMentionAppears(source, 'Mona'),
        isFalse,
        reason: source,
      );
    }
    for (final source in [
      '[@AnotherLabel](<@Mona>)',
      '> Quoted text\n@Mona',
      '草案@Mona的',
    ]) {
      expect(
        raftStructuredMentionAppears(source, 'Mona'),
        isTrue,
        reason: source,
      );
    }
  });
}
