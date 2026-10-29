import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/recipes.dart';

const _engine = RaftRecipeEngine([
  RaftUtility('base', 0, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 0, [
      RaftDecl('width', CssNum(8, 'px')),
      RaftDecl('background-color', CssVar('--color', null, 'primary400')),
      RaftDecl('font-size', CssVar('--font', null, 'fieldFontSize')),
      RaftDecl('--list', CssSeq([CssNum(1), CssNum(2)])),
    ]),
    RaftLayer('& svg', [], 0, [RaftDecl('width', CssNum(5, 'px'))]),
    RaftLayer('self', ['hover'], 1, [RaftDecl('width', CssNum(12, 'px'))]),
    RaftLayer(
      'self',
      ['width>=600'],
      2,
      [RaftDecl('height', CssNum(20, 'px'))],
    ),
    RaftLayer(
      'self',
      ['height>=700'],
      2,
      [RaftDecl('padding-top', CssNum(3, 'px'))],
    ),
    RaftLayer(
      'self',
      ['container-width>=500'],
      2,
      [RaftDecl('padding-left', CssNum(4, 'px'))],
    ),
  ]),
  RaftUtility('override', 1, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 0, [RaftDecl('width', CssNum(16, 'px'))]),
  ]),
], {});

class _Tokens extends RaftTokenResolver {
  const _Tokens(this.value, this.size);
  final Color value;
  final double size;
  @override
  Color color(String name) => value;
  @override
  double? number(String name) => size;
  @override
  List<BoxShadow> shadow(String name) => const [];
}

RaftSlotStyle _resolve(
  List<int> classes,
  RaftRecipeStates states, [
  RaftTokenResolver? tokens,
]) => raftResolveRecipe(
  _engine,
  const [],
  [classes],
  const [
    [0],
  ],
  const [],
  states,
  tokens,
).single;

Map<String, Object?> _values(RaftSlotStyle style) => {
  'self': {for (final e in style.properties.entries) e.key: e.value.toJson()},
  'targets': {
    for (final e in style.targets.entries)
      e.key: {for (final p in e.value.entries) p.key: p.value.toJson()},
  },
  'classes': style.classes,
};

// Full theme matrix on purpose (theme/token/recipe test): never sampled, see
// package:raft_theme/test_themes.dart.
void main() {
  test('templates reuse cascades and bind the current token resolver', () {
    const states = RaftRecipeStates({'hover', 'dark'});
    const firstTokens = _Tokens(Color(0xFF0000FF), 11);
    const nextTokens = _Tokens(Color(0xFFFF0000), 18);
    final first = _resolve([0], states, firstTokens);
    final entries = _engine.debugTemplateCacheSize;
    final next = _resolve(
      [0],
      const RaftRecipeStates({'dark', 'hover'}),
      nextTokens,
    );
    expect(_engine.debugTemplateCacheSize, entries);
    expect(first.backgroundColor!.resolve(first.tokens!), firstTokens.value);
    expect(next.backgroundColor!.resolve(next.tokens!), nextTokens.value);
    expect(first.fontSize, 11);
    expect(next.fontSize, 18);
  });

  test(
    'mutable caller class and flag collections cannot alter previous keys',
    () {
      final classes = [0], flags = <String>{};
      final states = RaftRecipeStates(flags);
      expect(_resolve(classes, states).width, 8);
      flags.add('hover');
      expect(_resolve(classes, states).width, 12);
      classes.add(1);
      expect(_resolve(classes, states).classes, ['base', 'override']);
      flags.clear();
      expect(_resolve(classes, states).width, 16);
      expect(_resolve([0], RaftRecipeStates.none).width, 8);
    },
  );

  test(
    'viewport, container and state variations equal uncached CSS output',
    () {
      for (final flags in [
        <String>{},
        {'hover'},
        {'disabled', 'dark'},
      ]) {
        for (final width in [599.0, 600.0]) {
          for (final height in [699.0, 700.0]) {
            for (final container in [499.0, 500.0]) {
              final states = RaftRecipeStates(flags, width, height, container);
              expect(
                _values(_resolve([0], states)),
                _values(_engine.resolveSlot([0], states)),
              );
            }
          }
        }
      }
    },
  );

  test('returned maps, classes and nested value lists are isolated', () {
    final first = _resolve([0], RaftRecipeStates.none);
    first.properties['width'] = const CssNum(999, 'px');
    (first.properties['--list']! as CssSeq).items.clear();
    first.targets['& svg']!.clear();
    first.classes.clear();
    final next = _resolve([0], RaftRecipeStates.none);
    expect(next.width, 8);
    expect((next.properties['--list']! as CssSeq).items, hasLength(2));
    expect(next.target('& svg')!.width, 5);
    expect(next.classes, ['base']);
  });

  test('arbitrary viewport values cannot grow the cache beyond its bound', () {
    for (var width = 0; width < 550; width++) {
      _resolve([0], RaftRecipeStates(const {}, width.toDouble()));
    }
    expect(_engine.debugTemplateCacheSize, 512);
    expect(_resolve([0], const RaftRecipeStates({}, 600)).height, 20);
    expect(_engine.debugTemplateCacheSize, 512);
  });

  test(
    'direct engine resolution still accepts runtime-mutated rule tables',
    () {
      final utilities = [..._engine.utilities];
      final engine = RaftRecipeEngine(utilities, {});
      expect(engine.resolveSlot([0], RaftRecipeStates.none).width, 8);
      utilities[0] = const RaftUtility('new', 0, RaftUtilityStatus.resolved, [
        RaftLayer('self', [], 0, [RaftDecl('width', CssNum(99, 'px'))]),
      ]);
      expect(engine.resolveSlot([0], RaftRecipeStates.none).width, 99);
    },
  );
}
