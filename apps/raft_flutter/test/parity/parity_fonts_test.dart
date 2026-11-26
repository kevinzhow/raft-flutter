import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../../../tool/testing/system_fonts.dart';
import 'parity_harness.dart';

/// flutter_test has no system fonts, and resolves a family it does not know to
/// its own box-drawing test font rather than skipping it. So any family a text
/// style can name swallows the glyph unless the harness has a file for it, and
/// the capture shows tofu a user never sees.
///
/// A style reaches a family two ways, and both have to be covered. The locale
/// chain `RaftTokens.fontFallback` appends is one. The other is the recipe
/// declaration itself, which ends in CSS generics: `font-mono` is
/// `ui-monospace, monospace`, and that is the one that shipped a defect — the
/// channel date divider is mono, so a Japanese date resolved `ui-monospace`
/// first and drew boxes for 月, 日, 金 and 曜.
Directory _repoRoot() {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/packages/raft_theme').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('repository root not found');
    dir = parent;
  }
  return dir;
}

/// Every CSS keyword a generated recipe names in a font declaration.
Set<String> _recipeFontKeywords() {
  final dir = Directory('${_repoRoot().path}/packages/raft_theme/lib/recipes');
  // `CssVar('--sans-font', CssList([CssKeyword('system-ui'),...]), 'sansFont')`
  final declaration = RegExp(
    r"CssVar\('--[\w-]*font[\w-]*',\s*(.+?)\)\s*,\s*'",
  );
  final keyword = RegExp(r"CssKeyword\('([^']+)'\)");
  final found = <String>{};
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.g.dart')) continue;
    final text = file.readAsStringSync();
    for (final match in declaration.allMatches(text)) {
      for (final name in keyword.allMatches(match.group(1)!)) {
        found.add(name.group(1)!);
      }
    }
  }
  return found;
}

void main() {
  test('the harness has a file for every family a locale chain names', () {
    final registered = paritySystemFonts().keys.toSet();
    final named = <String>{};
    for (final locale in [
      const Locale('en'),
      const Locale('ru'),
      const Locale('ja'),
      const Locale('ko'),
      const Locale('zh', 'CN'),
      const Locale('zh', 'TW'),
    ]) {
      named.addAll(
        raftTheme(textLocale: locale).extension<RaftTokens>()!.fontFallback,
      );
    }
    expect(
      named.difference(registered),
      isEmpty,
      reason:
          'these families have no file in the capture harness, so text '
          'that needs them captures as tofu boxes',
    );
  });

  test('the harness has a file for every generic a recipe declares', () {
    final keywords = _recipeFontKeywords();
    expect(
      keywords,
      contains('ui-monospace'),
      reason:
          'the scan found no mono declaration, so it is not reading the '
          'recipes any more and this guard proves nothing',
    );
    expect(
      keywords.difference(paritySystemFonts().keys.toSet()),
      isEmpty,
      reason:
          'a recipe font declaration ends in one of these, and the '
          'harness has no file for it, so it draws boxes instead of handing '
          'the character on to the CJK families the chain appends',
    );
  });

  test('a generic stand-in carries no CJK, so CJK falls past it', () {
    // If one of these covered CJK it would answer first and pin every script
    // to a Latin face, which is the opposite failure.
    for (final paths in genericStandInFonts.values) {
      for (final path in paths) {
        expect(
          path,
          isNot(contains('CJK')),
          reason: 'a generic must hand CJK on, not claim it',
        );
      }
    }
  });

  test('each regional CJK family resolves to its own face', () {
    for (final region in ['JP', 'KR', 'SC', 'TC']) {
      expect(cjkStandInFaces['Noto Sans CJK $region'], 'Noto Sans CJK $region');
    }
    // A device family stands in with the script it actually carries there.
    expect(cjkStandInFaces['PingFang SC'], 'Noto Sans CJK SC');
  });
}
