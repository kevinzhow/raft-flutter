import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// The numeric fields of [RaftThemeMetrics] that raft_token_mapping.dart maps.
const _metricFields = {
  'fieldFontSize',
  'fieldFontWeight',
  'fieldLineHeight',
  'cardTitleFontSize',
  'cardTitleFontWeight',
  'cardTitleLineHeight',
};

Map<String, Color> _colors(RaftThemeId id) =>
    id == RaftThemeId.dark ? RaftDark.colors : RaftLight.colors;

void main() {
  final tiers = <String, (List<String>, Map<String, String>)>{
    'semantic': (RaftSemanticColors.cssNames, raftSemanticMapping),
    'product': (RaftProductColors.cssNames, raftProductMapping),
    'component': (RaftComponentColors.cssNames, raftComponentMapping),
    'shadow': (RaftThemeShadows.cssNames, raftShadowMapping),
  };

  group('every RaftTokens field is mapped', () {
    for (final MapEntry(key: tier, value: (names, table)) in tiers.entries) {
      test('$tier: one entry per field, nothing extra', () {
        expect(
          table.keys.toSet().difference(names.toSet()),
          isEmpty,
          reason: 'entries without a field',
        );
        expect(
          names.toSet().difference(table.keys.toSet()),
          isEmpty,
          reason: 'fields without an entry',
        );
        expect(names.toSet(), hasLength(names.length));
      });
    }

    test('metrics: the six numeric fields', () {
      expect(raftMetricMapping.keys.toSet(), _metricFields);
      expect(raftCarriedMetrics.keys.toSet(), _metricFields);
    });

    test('every target is a real 0.7.1 token in both modes', () {
      for (final id in RaftThemeId.values) {
        final colors = _colors(id);
        for (final table in [
          raftSemanticMapping,
          raftProductMapping,
          raftComponentMapping,
        ]) {
          for (final MapEntry(:key, :value) in table.entries) {
            if (value == raftTransparentToken) continue;
            expect(colors, contains(value), reason: '$id $key -> $value');
          }
        }
        final shadows = id == RaftThemeId.dark
            ? RaftDark.shadows
            : RaftLight.shadows;
        for (final MapEntry(:key, :value) in raftShadowMapping.entries) {
          if (value == raftNoShadowToken) continue;
          expect(shadows, contains(value), reason: '$id $key -> $value');
        }
        final metrics = id == RaftThemeId.dark
            ? RaftDark.metrics
            : RaftLight.metrics;
        for (final MapEntry(:key, :value) in raftMetricMapping.entries) {
          expect(metrics, contains(value), reason: '$id $key -> $value');
        }
      }
    });
  });

  test('the token sets carry exactly the mapped 0.7.1 values', () {
    for (final id in RaftThemeId.values) {
      final set = RaftTokenSet.of(id);
      expect(set.id, id);
      final colors = _colors(id);
      void check(Map<String, Color> got, Map<String, String> table) {
        for (final MapEntry(:key, :value) in table.entries) {
          expect(
            got[key],
            value == raftTransparentToken
                ? const Color(0x00000000)
                : colors[value],
            reason: '$id $key -> $value',
          );
        }
      }

      check(set.colors.toCssMap(), raftSemanticMapping);
      check(set.product.toCssMap(), raftProductMapping);
      check(set.components.toCssMap(), raftComponentMapping);
    }
  });

  test('field metrics are the 0.7.1 16/24 tokens; the card title still carries Elegant\'s', () {
    // The tokens are 16/24 fields and 16/24/600 card titles ...
    for (final m in [RaftLight.metrics, RaftDark.metrics]) {
      expect(m['field-font-size'], 16);
      expect(m['field-line-height'], 24);
      expect(m['card-title-line-height'], 24);
      expect(m['card-title-font-weight'], 600);
    }
    // ... the field tokens are applied (Input, Material-hosted fields); the card title structure is still
    // dimensioned for 16/22/500, so those numbers stay.
    for (final id in RaftThemeId.values) {
      final m = RaftTokenSet.of(id).metrics;
      expect(m.fieldFontSize, 16);
      expect(m.fieldLineHeight, 24);
      expect(m.cardTitleFontSize, 16);
      expect(m.cardTitleLineHeight, 22);
      expect(m.cardTitleFontWeight, 500);
    }
  });

  test('renames follow the design system, never the name alone', () {
    // Every old name 0.7.1 deprecates maps to its documented successor ...
    for (final MapEntry(:key, :value) in raftSemanticMapping.entries) {
      final successor = RaftDeprecatedTokenNames.byCssName[key];
      if (successor != null) expect(value, successor, reason: key);
    }
    // ... and `layer-canvas` is the one name that kept its spelling but not its
    // meaning: the old layer-panel (the content paper) is the new layer-canvas,
    // and the old layer-canvas (the page under the panels) has no successor, so
    // it is deliberately folded into the same paper.
    expect(RaftDeprecatedTokenNames.byCssName['layer-panel'], 'layer-canvas');
    expect(RaftDeprecatedTokenNames.byCssName, isNot(contains('layer-canvas')));
    expect(raftSemanticMapping['layer-panel'], 'layer-canvas');
    expect(raftSemanticMapping['layer-canvas'], 'layer-canvas');
    expect(RaftTokenSet.light.colors.layerPanel, RaftLight.layerCanvas);
    expect(RaftTokenSet.dark.colors.layerPanel, RaftDark.layerCanvas);
    expect(RaftTokenSet.dark.colors.layerCanvas, const Color(0xff1b1b19));
    // The new card is lighter than the new canvas in dark (the old one was darker).
    expect(RaftTokenSet.dark.colors.layerCard, RaftDark.layerCard);
  });

  test('colour decisions that were judgement calls', () {
    final light = RaftTokenSet.light;
    // Decision 0001: the attention pink is the lighter #ff99c3.
    expect(light.colors.accent400, const Color(0xffff99c3));
    expect(light.product.brutalPink, RaftLight.attention400);
    // Hue aliases keep their bytes under the role that carries them.
    expect(light.product.brutalLime, const Color(0xffa9d877));
    expect(light.product.brutalOrange, const Color(0xfff8a16f));
    expect(light.product.brutalRed, const Color(0xfff97264));
    expect(light.product.brutalCyan, const Color(0xff27ccf3));
    expect(light.product.brutalCream, const Color(0xfffffaef));
    // Sticker buttons: solid fills carry ink text.
    expect(light.components.buttonDangerFill, RaftLight.danger);
    expect(light.components.buttonDangerForeground, RaftLight.dangerForeground);
    // Stickers do not invert in dark.
    expect(
      RaftTokenSet.dark.components.switchThumb,
      RaftTokenSet.light.components.switchThumb,
    );
    // The dark input ring is the hairline; its inset highlight is not painted.
    expect(RaftTokenSet.dark.components.fieldInsetLine, RaftDark.lineHairline);
    expect(RaftTokenSet.dark.components.fieldInsetTop.a, 0);
  });
}
