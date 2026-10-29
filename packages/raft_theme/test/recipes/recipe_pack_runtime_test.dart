import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_theme/recipes.dart';

const _engine = RaftRecipeEngine([
  RaftUtility('sample', 0, RaftUtilityStatus.resolved, [
    RaftLayer('self', [], 0, [
      RaftDecl('width', CssNum(8, 'px')),
      RaftDecl('opacity', CssNum(.4)),
      RaftDecl('box-shadow', CssKeyword('none')),
    ]),
    RaftLayer('::before', [], 0, [RaftDecl('width', CssNum(4, 'px'))]),
  ]),
], {});

RaftThemeRecipeTokens _tokens({double width = 39, bool dark = false}) =>
    RaftThemeRecipeTokens(
      RaftThemePack.parse(
        jsonEncode({
          'format': 'raft-theme/1',
          'id': 'test-runtime',
          'name': {'en': 'Runtime test'},
          'version': '1.0.0',
          'extends': 'raft',
          'modes': {
            for (final mode in ['light', 'dark'])
              mode: {
                'geometry': {
                  'radius.control': width,
                  'opacity.buttonDisabled': .75,
                },
                'colors': {
                  'layer-panel': mode == 'light' ? '#123456' : '#abcdef',
                },
                'shadows': {
                  'shadow.control': 'inset 2px 3px 4px 5px #123456',
                  'shadow.buttonHover': 'none',
                },
              },
          },
        }),
      ).resolve(dark: dark, base: builtInRaftTheme),
    );

RaftSlotStyle _resolve(
  RaftTokenResolver resolver,
  List<RaftRecipePackBinding> bindings, {
  String variant = 'outline',
  RaftRecipeStates states = RaftRecipeStates.none,
}) => raftResolveRecipe(
  _engine,
  const [
    RaftRecipeAxis('variant', ['outline', 'accent'], 'outline', false),
  ],
  const [
    [0],
  ],
  const [
    [0],
    [0],
  ],
  [variant],
  states,
  resolver,
  recipeName: 'sample',
  slotNames: const ['root'],
  bindings: bindings,
).single;

void main() {
  test('bindings respect axes, state exclusions, slots and pseudo targets', () {
    const bindings = [
      RaftRecipePackBinding(
        'root',
        'width',
        RaftRecipeTokenKind.number,
        'radius.control',
        props: {'variant': 'outline'},
        when: ['hover'],
        unless: ['disabled'],
        target: '::before',
      ),
      RaftRecipePackBinding(
        'other',
        'width',
        RaftRecipeTokenKind.number,
        'radius.control',
      ),
    ];
    for (final variant in ['outline', 'accent']) {
      for (final flags in [
        <String>{},
        {'hover'},
        {'hover', 'disabled'},
      ]) {
        final style = _resolve(
          _tokens(),
          bindings,
          variant: variant,
          states: RaftRecipeStates(flags),
        );
        expect(style.width, 8);
        expect(
          style.before!.width,
          variant == 'outline' && flags.length == 1 ? 39 : 4,
        );
      }
    }
  });

  test('pack colors, unitless values and inset shadows reach slots', () {
    for (final dark in [false, true]) {
      final t = _tokens(dark: dark);
      final style = _resolve(t, const [
        RaftRecipePackBinding(
          'root',
          'background-color',
          RaftRecipeTokenKind.color,
          'layer-panel',
        ),
        RaftRecipePackBinding(
          'root',
          'opacity',
          RaftRecipeTokenKind.number,
          'opacity.buttonDisabled',
          unit: '',
        ),
        RaftRecipePackBinding(
          'root',
          'box-shadow',
          RaftRecipeTokenKind.shadow,
          'shadow.control',
        ),
      ]);
      expect(
        style.backgroundColor!.resolve(t),
        dark ? const Color(0xffabcdef) : const Color(0xff123456),
      );
      expect(style.opacity, .75);
      final layer = style.boxShadow.single as RaftLiteralShadow;
      expect(layer.inset, isTrue);
      expect(
        [layer.offset.dx, layer.offset.dy, layer.blur, layer.spread],
        [2, 3, 4, 5],
      );
      expect(layer.color.resolve(t), const Color(0xff123456));
      expect(
        t.recipeValue(RaftRecipeTokenKind.shadow, 'shadow.absent'),
        isNull,
      );
      expect(t.recipeValue(RaftRecipeTokenKind.color, 'layer-absent'), isNull);
      final cleared = _resolve(t, const [
        RaftRecipePackBinding(
          'root',
          'box-shadow',
          RaftRecipeTokenKind.shadow,
          'shadow.control',
        ),
        RaftRecipePackBinding(
          'root',
          'box-shadow',
          RaftRecipeTokenKind.shadow,
          'shadow.buttonHover',
        ),
        RaftRecipePackBinding(
          'root',
          'width',
          RaftRecipeTokenKind.number,
          'size.absent',
        ),
      ]);
      expect(cleared.boxShadow, isEmpty);
      expect(cleared.width, 8);
    }
  });

  test('pack overrides cannot contaminate source references or caches', () {
    const bindings = [
      RaftRecipePackBinding(
        'root',
        'width',
        RaftRecipeTokenKind.number,
        'radius.control',
      ),
    ];
    final first = _resolve(_tokens(), bindings);
    expect(first.width, 39);
    first.properties['width'] = const CssNum(999, 'px');
    expect(_resolve(_tokens(width: 23), bindings).width, 23);
    expect(
      _resolve(
        RaftThemeRecipeTokens(_tokens().values, bindComponents: false),
        bindings,
      ).width,
      8,
    );
    expect(_resolve(_tokens(), bindings).width, 39);
    final t = _tokens();
    expect(
      RaftThemeRecipeTokens(
        t.values,
        bindComponents: false,
      ).color('layerPanel'),
      t.color('layerPanel'),
    );
    expect(
      RaftThemeRecipeTokens(
        t.values,
        bindComponents: false,
      ).fontFamily('sansFont'),
      t.fontFamily('sansFont'),
    );
    expect(
      RaftInputRecipe.resolve(tokens: t).root.borderRadius,
      BorderRadius.circular(39),
    );
    expect(
      RaftInputRecipe.resolve(
        tokens: RaftThemeRecipeTokens(t.values, bindComponents: false),
      ).root.borderRadius,
      BorderRadius.circular(8),
    );
  });

  test('context snapshots survive copies and descendant extraction', () {
    final flags = <String>{'hover'};
    final style = _resolve(
      _tokens(),
      const [],
      states: RaftRecipeStates(flags, 600, 800, 400),
    );
    flags.clear();
    final copied = style.copyWith(
      properties: {...style.properties, 'width': const CssNum(15, 'px')},
    );
    for (final s in [style, copied, style.before!]) {
      expect(s.context!.recipe, 'sample');
      expect(s.context!.slot, 'root');
      expect(s.context!.props, {'variant': 'outline'});
      expect(s.context!.states.flags, {'hover'});
      expect(s.context!.states.viewportWidth, 600);
    }
    expect(copied.width, 15);
    expect(style.width, 8);
    expect(
      () => style.context!.props['variant'] = 'accent',
      throwsUnsupportedError,
    );
    expect(() => style.context!.states.flags.clear(), throwsUnsupportedError);
  });
}
