@Tags(['look-elegant', 'look-brutal'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

/// The built-in family packs (Elegant, Brutal) must parse through the real
/// parser and resolve against the built-in Raft pack, exactly as a theme
/// selected at runtime would. A generated JSON file that no one parses is not a
/// theme; these tests are what make `build_family_packs.py` output trustworthy.
String _readPack(String relative) {
  var dir = Directory.current.absolute;
  while (true) {
    for (final candidate in [relative, 'packages/raft_theme/$relative']) {
      final file = File.fromUri(dir.uri.resolve(candidate));
      if (file.existsSync()) return file.readAsStringSync();
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('$relative not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

const _families = <String, String>{
  'elegant': 'assets/themes/elegant.theme.json',
  'brutal': 'assets/themes/brutal.theme.json',
};

/// Raft plus both families, keyed by id, so `extends: "raft"` resolves.
Map<String, RaftThemePack> _registry() => {
  raftThemePackId: RaftThemePack.parse(
    raftThemePackJson,
    origin: raftThemePackId,
  ),
  for (final entry in _families.entries)
    entry.key: RaftThemePack.parse(_readPack(entry.value), origin: entry.key),
};

void main() {
  group('built-in family packs', () {
    for (final entry in _families.entries) {
      final id = entry.key;

      test('$id parses and extends raft', () {
        final pack = RaftThemePack.parse(_readPack(entry.value), origin: id);
        expect(pack.id, id);
        expect(pack.extendsId, 'raft');
        expect(pack.builtIn, isTrue);
        // A pack that failed validation would still parse but carry warnings;
        // a misspelled option or token surfaces here rather than at runtime.
        expect(pack.warnings, isEmpty, reason: '$id: ${pack.warnings}');
      });

      test('$id defines both modes', () {
        final pack = RaftThemePack.parse(_readPack(entry.value), origin: id);
        // The contract requires dark to exist so a theme can never silently
        // fall back to the default look when the system turns dark.
        expect(pack.light.colors, isNotEmpty);
        expect(pack.dark.colors, isNotEmpty);
      });

      test('$id resolves against raft for every known colour role', () {
        final registry = _registry();
        final base = registry[raftThemePackId]!;
        final pack = registry[id]!;
        for (final dark in [false, true]) {
          final resolved = pack.resolveIn(registry, dark: dark);
          final baseRoles = dark ? base.dark.colors : base.light.colors;
          // Every role the Raft pack defines must resolve to a colour: the
          // family either sets it or inherits it. A hole here would paint
          // transparent where Raft paints ink.
          for (final role in baseRoles.keys) {
            expect(
              resolved.colors[role],
              isNotNull,
              reason: '$id ${dark ? 'dark' : 'light'}: role "$role" unresolved',
            );
          }
        }
      });

      test('$id sets every structural option the contract defines', () {
        final pack = RaftThemePack.parse(_readPack(entry.value), origin: id);
        for (final dark in [false, true]) {
          final options = dark ? pack.dark.options : pack.light.options;
          // Assert against the contract's own vocabulary rather than a count:
          // a hardcoded 20 would need editing whenever an option is added, and
          // silently pass if one were dropped.
          expect(
            options.keys.toSet(),
            raftStructuralOptions.keys.toSet(),
            reason: '$id ${dark ? 'dark' : 'light'} options',
          );
        }
      });
    }

    test('families differ from raft and from each other', () {
      final registry = _registry();
      final raft = registry[raftThemePackId]!;
      final elegant = registry['elegant']!;
      final brutal = registry['brutal']!;

      final raftLight = raft.resolveIn(registry, dark: false);
      final elegantLight = elegant.resolveIn(registry, dark: false);
      final brutalLight = brutal.resolveIn(registry, dark: false);

      // The whole point of the packs: they must not resolve back to Raft.
      expect(
        elegantLight.colors['foreground'],
        isNot(raftLight.colors['foreground']),
      );
      expect(elegantLight.options['avatar.shape'], 'circle');
      expect(brutalLight.options['avatar.shape'], 'square');
      expect(elegantLight.options['control.edge'], 'ring');
      expect(brutalLight.options['control.edge'], 'inkBorder');
      // Rounded vs square is the clearest geometric tell between the families.
      expect(
        elegantLight.geometry['radius.control'],
        greaterThan(brutalLight.geometry['radius.control']!),
      );
    });

    test(
      'brutal dark is the whole Elegant dark look, not its light reskinned',
      () {
        // The old app forced the family to Elegant whenever dark was on
        // (a57b9dab theme.dart:102), so Brutal at night was Elegant: colours,
        // radii, strokes and options together. Rendering Brutal+dark on that
        // commit returns exactly the Elegant+dark tokens, which is what this
        // pins. A pack that merely darkened Brutal's light values would pass a
        // colour-only check and fail here.
        final registry = _registry();
        final brutal = registry['brutal']!;
        final elegant = registry['elegant']!;

        final brutalDark = brutal.resolveIn(registry, dark: true);
        final elegantDark = elegant.resolveIn(registry, dark: true);

        expect(brutalDark.colors, elegantDark.colors);
        expect(brutalDark.geometry, elegantDark.geometry);
        expect(brutalDark.options, elegantDark.options);

        // And it is genuinely not Brutal's light look.
        final brutalLight = brutal.resolveIn(registry, dark: false);
        expect(brutalDark.colors, isNot(brutalLight.colors));
        expect(brutalDark.options, isNot(brutalLight.options));
        // Radius is the clearest structural tell: Brutal light is square (0),
        // Elegant dark is rounded (6).
        expect(brutalLight.geometry['radius.control'], 0);
        expect(brutalDark.geometry['radius.control'], 6);
      },
    );
  });
}
