import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

/// The built-in family packs (Elegant, Brutal) must parse through the real
/// parser and resolve against the built-in Raft pack, exactly as a theme
/// selected at runtime would. A generated JSON file that no one parses is not a
/// theme; these tests are what make `build_family_packs.py` output trustworthy.
String _readPack(String relative) {
  var dir = Directory.current.absolute;
  while (!File('${dir.path}/$relative').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('$relative not found above ${Directory.current.path}');
    }
    dir = parent;
  }
  return File('${dir.path}/$relative').readAsStringSync();
}

const _families = <String, String>{
  'elegant': 'packages/raft_theme/assets/themes/elegant.theme.json',
  'brutal': 'packages/raft_theme/assets/themes/brutal.theme.json',
};

/// Raft plus both families, keyed by id, so `extends: "raft"` resolves.
Map<String, RaftThemePack> _registry() => {
  raftThemePackId: RaftThemePack.parse(raftThemePackJson, origin: raftThemePackId),
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

      test('$id sets the 20 structural options', () {
        final pack = RaftThemePack.parse(_readPack(entry.value), origin: id);
        for (final dark in [false, true]) {
          final options = dark ? pack.dark.options : pack.light.options;
          expect(options, hasLength(20),
              reason: '$id ${dark ? 'dark' : 'light'} options');
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
      expect(elegantLight.colors['foreground'],
          isNot(raftLight.colors['foreground']));
      expect(elegantLight.options['avatar.shape'], 'circle');
      expect(brutalLight.options['avatar.shape'], 'square');
      expect(elegantLight.options['control.edge'], 'ring');
      expect(brutalLight.options['control.edge'], 'inkBorder');
      // Rounded vs square is the clearest geometric tell between the families.
      expect(elegantLight.geometry['radius.control'],
          greaterThan(brutalLight.geometry['radius.control']!));
    });

    test('brutal has no dark variant of its own', () {
      // The contract states Brutal dark equals its light; the generator writes
      // the same column twice, so the two modes must be identical.
      final brutal = RaftThemePack.parse(_readPack(_families['brutal']!),
          origin: 'brutal');
      expect(brutal.dark.colors, brutal.light.colors);
      expect(brutal.dark.options, brutal.light.options);
      expect(brutal.dark.geometry, brutal.light.geometry);
    });
  });
}
