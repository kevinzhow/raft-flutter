import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';

/// The pack the app ships, read from disk.
///
/// Prefer the package's own assets; also support the repository-level gate.
String shipPack() => packFile().readAsStringSync();

File packFile() {
  var dir = Directory.current.absolute;
  while (true) {
    for (final relative in [
      'assets/themes/raft.theme.json',
      'packages/raft_theme/assets/themes/raft.theme.json',
    ]) {
      final file = File.fromUri(dir.uri.resolve(relative));
      if (file.existsSync()) return file;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Raft theme assets not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

String packJson({
  Map<String, Object?> light = const {
    'colors': <String, Object?>{'foreground': '#101010'},
  },
  Map<String, Object?>? dark,
  String? extendsId,
  String id = 'test',
}) {
  final modes = {
    'light': light,
    'dark':
        dark ??
        const {
          'colors': <String, Object?>{'foreground': '#f0f0f0'},
        },
  };
  return jsonEncode({
    'format': raftThemePackFormat,
    'id': id,
    'name': {'en': 'Test'},
    'version': '1.0.0',
    if (extendsId != null) 'extends': extendsId,
    'modes': modes,
  });
}

void main() {
  group('the shipped Raft pack', () {
    late RaftThemePack pack;

    setUpAll(() => pack = RaftThemePack.parse(shipPack(), origin: 'raft'));

    test('parses with both modes and no warnings', () {
      expect(pack.id, 'raft');
      expect(pack.builtIn, isTrue);
      expect(pack.warnings, isEmpty);
      for (final mode in [pack.light, pack.dark]) {
        expect(mode.colors, isNotEmpty);
        expect(mode.geometry, isNotEmpty);
        expect(mode.type, isNotEmpty);
        expect(mode.shadows, isNotEmpty);
        expect(mode.options, isNotEmpty);
      }
    });

    test('every option it chooses is a value the catalogue allows', () {
      for (final mode in [pack.light, pack.dark]) {
        for (final entry in mode.options.entries) {
          expect(
            raftStructuralOptions[entry.key],
            isNotNull,
            reason: '${entry.key} is not a contract option',
          );
          expect(
            raftStructuralOptions[entry.key],
            contains(entry.value),
            reason: '${entry.key} = ${entry.value}',
          );
        }
      }
    });

    test('fills the whole type scale and all declared case slots', () {
      expect(pack.light.type.keys.toSet(), raftTypeSlots);
      expect(pack.light.caseTransforms.keys.toSet(), {
        'heading',
        'label',
        'badge',
        'dialogShellTitle',
      });
      expect(pack.light.caseTransforms['label'], RaftCaseTransform.none);
    });

    test(
      'carries the legacy roles and the 0.7.1 roles the ported components read',
      () {
        // Legacy role schema (the vocabulary components already read).
        expect(pack.light.colors['layer-canvas'], isNotNull);
        expect(pack.light.colors['foreground-strong'], isNotNull);
        // 0.7.1 names the ported core components read directly.
        expect(pack.light.colors['sticker-ink'], isNotNull);
        expect(pack.light.colors['layer-frame'], isNotNull);
        expect(pack.light.colors['presence-online'], isNotNull);
      },
    );

    test('a role the Raft look does not paint is fully transparent', () {
      expect(pack.light.colors['field-inset-top'], const Color(0x00000000));
      expect(pack.dark.colors['switch-shadow-bottom'], const Color(0x00000000));
    });

    test('keeps the palette separate from the roles', () {
      expect(pack.light.palette['palette-yellow-400'], isNotNull);
      expect(pack.light.colors.containsKey('palette-yellow-400'), isFalse);
    });

    test('reads the multi-layer and inset shadows of both modes', () {
      final popup = pack.light.shadows['shadow.float']!;
      expect(popup, isNotEmpty);
      final dark = pack.dark.shadows['shadow.float']!;
      expect(dark.any((layer) => layer.inset), isFalse);
      expect(
        pack.light.shadows['xs'],
        isEmpty,
        reason: 'Raft steps xs…md are none',
      );
      expect(pack.dark.shadows['shadow.focusRing'], hasLength(2));
    });
  });

  group('the built-in pack', () {
    test('is available synchronously from the compile-time constant', () {
      final pack = builtInRaftTheme;
      expect(pack.id, 'raft');
      expect(pack.light.colors['layer-canvas'], isNotNull);
      expect(identical(builtInRaftTheme, pack), isTrue);
    });

    test('the constant and the asset carry the same bytes', () {
      expect(raftThemePackJson, shipPack());
    });
  });

  group('resolution', () {
    test('a child takes what it sets and inherits the rest', () {
      final base = RaftThemePack.parse(shipPack());
      final child = RaftThemePack.parse(
        packJson(
          extendsId: 'raft',
          light: {
            'colors': {'foreground': '#123456'},
            'geometry': {'radius.control': 2},
          },
        ),
      );
      final resolved = child.resolveIn({
        'raft': base,
        'test': child,
      }, dark: false);
      expect(resolved.colors['foreground'], const Color(0xFF123456));
      expect(
        resolved.colors['layer-canvas'],
        base.light.colors['layer-canvas'],
      );
      expect(resolved.geometry['radius.control'], 2);
      expect(
        resolved.geometry['radius.chip'],
        base.light.geometry['radius.chip'],
      );
      expect(
        resolved.options['control.edge'],
        base.light.options['control.edge'],
      );
    });

    test('dark resolves separately from light', () {
      final base = RaftThemePack.parse(shipPack());
      final child = RaftThemePack.parse(packJson(extendsId: 'raft'));
      final dark = child.resolveIn({'raft': base, 'test': child}, dark: true);
      expect(dark.colors['foreground'], const Color(0xFFF0F0F0));
      expect(dark.colors['layer-canvas'], base.dark.colors['layer-canvas']);
    });

    test('a loop in extends is rejected', () {
      final a = RaftThemePack.parse(packJson(id: 'a', extendsId: 'b'));
      final b = RaftThemePack.parse(packJson(id: 'b', extendsId: 'a'));
      expect(
        () => a.resolveIn({'a': a, 'b': b}, dark: false),
        throwsA(isA<RaftThemeException>()),
      );
    });
  });

  group('validation', () {
    test('rejects a missing dark mode', () {
      final json = jsonDecode(packJson()) as Map<String, dynamic>;
      (json['modes'] as Map).remove('dark');
      expect(
        () => RaftThemePack.parse(jsonEncode(json)),
        throwsA(isA<RaftThemeException>()),
      );
    });

    test('rejects a misspelled colour role, and names the path', () {
      try {
        RaftThemePack.parse(
          packJson(
            light: {
              'colors': {'foregound': '#101010'},
            },
          ),
          origin: 'brand',
        );
        fail('expected a RaftThemeException');
      } on RaftThemeException catch (error) {
        expect('$error', contains('brand.modes.light.colors.foregound'));
        expect('$error', contains('unknown colour role'));
      }
    });

    test('rejects a misspelled geometry token', () {
      expect(
        () => RaftThemePack.parse(
          packJson(
            light: {
              'geometry': {'radius.contol': 8},
            },
          ),
        ),
        throwsA(isA<RaftThemeException>()),
      );
    });

    test('resolves a palette reference, and rejects an unknown one', () {
      final pack = RaftThemePack.parse(
        packJson(
          light: {
            'palette': {'palette-brand-400': '#ffd440'},
            'colors': {'foreground': '{palette.brand.400}'},
          },
        ),
      );
      expect(pack.light.colors['foreground'], const Color(0xFFFFD440));
      expect(
        () => RaftThemePack.parse(
          packJson(
            light: {
              'colors': {'foreground': '{palette.brand.400}'},
            },
          ),
        ),
        throwsA(isA<RaftThemeException>()),
      );
    });

    test('rejects an unknown option and an unknown value', () {
      expect(
        () => RaftThemePack.parse(
          packJson(
            light: {
              'options': {'control.edge': 'glow'},
            },
          ),
        ),
        throwsA(isA<RaftThemeException>()),
      );
      expect(
        () => RaftThemePack.parse(
          packJson(
            light: {
              'options': {'control.edges': 'ring'},
            },
          ),
        ),
        throwsA(isA<RaftThemeException>()),
      );
    });

    test('names the offending path', () {
      try {
        RaftThemePack.parse(
          packJson(
            light: {
              'colors': {'foreground': 'not-a-colour'},
            },
          ),
          origin: 'brand',
        );
        fail('expected a RaftThemeException');
      } on RaftThemeException catch (error) {
        expect('$error', contains('brand.modes.light.colors.foreground'));
      }
    });

    test('rejects a theme that extends itself and a wrong format', () {
      expect(
        () => RaftThemePack.parse(packJson(extendsId: 'test')),
        throwsA(isA<RaftThemeException>()),
      );
      final wrong = jsonDecode(packJson()) as Map<String, dynamic>
        ..['format'] = 'raft-theme/0';
      expect(
        () => RaftThemePack.parse(jsonEncode(wrong)),
        throwsA(isA<RaftThemeException>()),
      );
    });

    test('warns about an unknown key instead of failing', () {
      final json = jsonDecode(packJson()) as Map<String, dynamic>
        ..['futureKey'] = true;
      final pack = RaftThemePack.parse(jsonEncode(json));
      expect(pack.warnings.single, contains('futureKey'));
    });
  });

  group('colour syntax', () {
    Color parsed(String value) => parseThemeColor(value, where: 'test');

    test('hex, with and without alpha', () {
      expect(parsed('#f00'), const Color(0xFFFF0000));
      expect(parsed('#141111'), const Color(0xFF141111));
      expect(parsed('#141111ad').a, closeTo(0xad / 255, 1e-6));
      expect(parsed('#141111ad').r, closeTo(0x14 / 255, 1e-3));
    });

    test('rgb and rgba, comma or space, with a slash for alpha', () {
      expect(parsed('rgb(20 17 17)'), const Color(0xFF141111));
      expect(parsed('rgba(20, 17, 17, 0.5)').a, closeTo(0.5, 0.005));
      expect(parsed('rgb(20 17 17 / 50%)').a, closeTo(0.5, 0.005));
    });

    test('oklch matches the values raft-ui ships', () {
      // --brand-400 is oklch(0.883 0.162 91.89) -> #ffd441 in raft-ui's own
      // conversion; allow one 8-bit step for the CSS matrices.
      final brand = parsed('oklch(0.883 0.162 91.89)');
      expect((brand.r * 255).round(), closeTo(0xff, 2));
      expect((brand.g * 255).round(), closeTo(0xd4, 3));
      expect((brand.b * 255).round(), closeTo(0x41, 3));
    });

    test('the DTCG form an official tokens.json uses', () {
      final color = parseThemeColor({
        r'$value': {
          'colorSpace': 'oklch',
          'components': [0.1813, 0.005, 17.62],
          'alpha': 0.678,
        },
      }, where: 'test');
      expect(color.a, closeTo(0.678, 0.005));
      expect(color.r, closeTo(0x14 / 255, 1e-3));
    });

    test('rejects anything else', () {
      expect(() => parsed('misty blue'), throwsFormatException);
      expect(() => parsed('#12345'), throwsFormatException);
      expect(() => parsed('hsl(0 100% 50%)'), throwsFormatException);
    });
  });

  group('shadow syntax', () {
    test('none and empty mean no shadow', () {
      expect(parseShadowList('none', where: 't'), isEmpty);
      expect(parseShadowList('', where: 't'), isEmpty);
      expect(parseShadowList(null, where: 't'), isEmpty);
    });

    test('layers, inset and a colour with a comma-free function', () {
      final layers = parseShadowList(
        '0 1px 0 0 #1411110a, inset 0 0 0 1px rgb(255 255 255 / 8%)',
        where: 't',
      );
      expect(layers, hasLength(2));
      expect(layers.first.offset.dy, 1);
      expect(layers.first.blur, 0);
      expect(layers.first.color.a, closeTo(0x0a / 255, 0.005));
      expect(layers.last.inset, isTrue);
      expect(layers.last.spread, 1);
      expect(layers.last.color.a, closeTo(0.08, 0.005));
    });

    test('lengths without px and a missing spread', () {
      final layer = parseShadowList('4px 4px 0 #141111', where: 't').single;
      expect(layer.offset, const Offset(4, 4));
      expect(layer.blur, 0);
      expect(layer.spread, 0);
    });
  });
}
