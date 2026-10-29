@Tags(['look-elegant', 'look-brutal'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

void main() {
  test('Brutal dark resolves all three Elegant families and stacks', () {
    final b = builtInBrutalTheme.resolve(dark: true, base: builtInRaftTheme);
    final e = builtInElegantTheme.resolve(dark: true, base: builtInRaftTheme);
    for (final role in ['sans', 'heading', 'mono']) {
      expect(b.fonts[role]!.family, e.fonts[role]!.family);
      expect(b.fonts[role]!.stack, e.fonts[role]!.stack);
      expect(b.fonts[role]!.asset, e.fonts[role]!.asset);
    }
  });
  test('built-in timestamp references retain whole Elegant night mode', () {
    expect(
      builtInRaftTheme.resolve(dark: false).fontRefs['font.messageTime'],
      'mono',
    );
    expect(
      builtInElegantTheme.resolve(dark: false).fontRefs['font.messageTime'],
      'sans',
    );
    expect(
      builtInBrutalTheme.resolve(dark: false).fontRefs['font.messageTime'],
      'mono',
    );
    expect(
      builtInBrutalTheme.resolve(dark: true).fontRefs['font.messageTime'],
      'sans',
    );
  });
  test('built-in subtitle references preserve the original font families', () {
    expect(
      builtInRaftTheme.resolve(dark: false).fontRefs['font.messageSubtitle'],
      'sans',
    );
    expect(
      builtInElegantTheme.resolve(dark: false).fontRefs['font.messageSubtitle'],
      'sans',
    );
    expect(
      builtInBrutalTheme.resolve(dark: false).fontRefs['font.messageSubtitle'],
      'mono',
    );
    expect(
      builtInBrutalTheme.resolve(dark: true).fontRefs['font.messageSubtitle'],
      'sans',
    );
  });
  test('the original Brutal mono family is Geist Mono', () {
    expect(builtInBrutalTheme.fonts['mono']!.family, 'Geist Mono');
  });
}
