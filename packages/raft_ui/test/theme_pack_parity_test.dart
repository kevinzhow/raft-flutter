import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart';
import 'package:raft_ui/raft_ui.dart';

/// The pack claims to be exactly the Raft look the app already paints. This is
/// the machine proof of that claim: every role, radius, type slot and shadow
/// the pack carries must equal what `raft_ui` resolves from the 0.7.1 tokens.
///
/// If a value here has to change, the pack generator or the tokens moved —
/// find out which before touching the expectation.
void main() {
  late RaftThemePack pack;

  setUpAll(() => pack = builtInRaftTheme);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    // Resolved inside each test: at declaration time setUpAll has not run yet.
    RaftTokenSet tokenSet() =>
        RaftTokenSet.of(dark ? RaftThemeId.dark : RaftThemeId.light);
    RaftModeValues values() => dark ? pack.dark : pack.light;

    test('$mode: every legacy colour role matches the token set', () {
      final resolved = tokenSet();
      final roles = <String, Color>{
        ...resolved.colors.toCssMap(),
        ...resolved.product.toCssMap(),
        ...resolved.components.toCssMap(),
      };
      expect(roles, hasLength(159));
      for (final entry in roles.entries) {
        expect(
          values().colors[entry.key],
          entry.value,
          reason: '${entry.key} in $mode',
        );
      }
    });

    test('$mode: the 0.7.1 names the ported components read match too', () {
      // The 0.7.1-only names live in the raw token maps, not in the legacy
      // role tiers that raftColorMap exposes.
      final colors = dark ? RaftDark.colors : RaftLight.colors;
      for (final role in const [
        'sticker-ink',
        'sticker-paper',
        'sticker-edge',
        'layer-frame',
        'foreground-on-frame',
        'fill-frame-pressed',
        'presence-online',
        'task-status-in-progress',
      ]) {
        expect(values().colors[role], colors[role], reason: '$role in $mode');
      }
    });

    test('$mode: radii match the design system', () {
      expect(values().geometry['radius.sticker'], RaftRadius.sticker);
      expect(values().geometry['radius.chip'], RaftRadius.chip);
      expect(values().geometry['radius.control'], RaftRadius.control);
      expect(values().geometry['radius.container'], RaftRadius.container);
      expect(values().geometry['radius.dialog'], RaftRadius.dialog);
    });

    test('$mode: the type scale matches RaftTypeScale', () {
      for (final entry in RaftTypeScale.byName.entries) {
        final slot = entry.key;
        final style = entry.value;
        final spec = values().type[slot];
        expect(spec, isNotNull, reason: 'slot $slot');
        expect(spec!.size, style.fontSize, reason: '$slot size');
        expect(
          spec.line,
          closeTo(style.fontSize * style.height, 0.001),
          reason: '$slot line',
        );
      }
    });
  }

  test('shadows match the generated 0.7.1 shadow tokens', () {
    List<List<Object?>> tuple(List<RaftShadowSpec> layers) => [
      for (final layer in layers)
        [
          layer.inset,
          layer.offset.dx,
          layer.offset.dy,
          layer.blur,
          layer.spread,
          // Compare at 8-bit precision: both sides come from the same source.
          (layer.color.toARGB32() & 0xFFFFFF),
        ],
    ];
    List<List<Object?>> tokenLayers(RaftShadow shadow) => [
      for (final layer in shadow.layers)
        [
          layer.inset,
          layer.offset.dx,
          layer.offset.dy,
          layer.blur,
          layer.spread,
          (layer.color.toARGB32() & 0xFFFFFF),
        ],
    ];

    expect(pack.light.shadows['xs'], isEmpty);
    expect(pack.light.shadows['sm'], isEmpty);
    expect(pack.light.shadows['md'], isEmpty);
    expect(
      tuple(pack.light.shadows['shadow.float']!),
      tokenLayers(RaftLight.elevationFloat),
    );
    expect(
      tuple(pack.dark.shadows['shadow.float']!),
      tokenLayers(RaftDark.elevationFloat),
    );
    expect(
      tuple(pack.light.shadows['shadow.sticker']!),
      tokenLayers(RaftLight.elevationSticker),
    );
    expect(
      tuple(pack.light.shadows['shadow.focusRing']!),
      tokenLayers(RaftLight.focusRing),
    );
    expect(pack.light.shadows['shadow.control'], isEmpty);
  });
}
