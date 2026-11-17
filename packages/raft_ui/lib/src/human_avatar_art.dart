import 'dart:typed_data';

import 'human_avatar_data.dart';
import 'human_avatar_layer.dart';
import 'human_avatar_recipe.dart';

/// Port of Web shared `composeHumanAvatar` (humanAvatar.ts): the layers a
/// recipe draws, in draw order (base, expression, hair, then accessories by
/// ascending z), each non-transparent cell painting its role colour over the
/// ones below, on the recipe's background.
class RaftHumanAvatarPixels {
  const RaftHumanAvatarPixels(this.size, this.background, this.pixels);

  final int size;

  /// 0xAARRGGBB of the background square.
  final int background;

  /// Row-major `size * size` colours; 0 shows the background.
  final Uint32List pixels;
}

final Map<String, RaftHumanAvatarLayer> _layerIndex = {
  for (final l in raftHumanAvatarLayers) '${l.layer}:${l.option}': l,
};
final _gridCache = <RaftHumanAvatarLayer, Uint8List>{};

Uint8List _grid(RaftHumanAvatarLayer layer) =>
    _gridCache[layer] ??= layer.grid(raftHumanAvatarSize);

int _hex(String css) => 0xFF000000 | int.parse(css.substring(1), radix: 16);

/// role index (0-35) -> colour, for [recipe]; roles with no colour are absent.
Map<int, int> _roleColors(RaftHumanAvatarRecipe recipe) {
  final skin = RaftHumanAvatarField.skin.artOption(
    recipe[RaftHumanAvatarField.skin],
  );
  final hair = RaftHumanAvatarField.hairColor.artOption(
    recipe[RaftHumanAvatarField.hairColor],
  );
  final out = <int, int>{};
  raftHumanAvatarRoleColors.forEach((role, source) {
    final split = source.split(':');
    final String? css = split[0] == 'palette'
        ? switch (split[1]) {
            'skin' => raftHumanAvatarSkinPalette[skin],
            'hair' => raftHumanAvatarHairPalette[hair],
            _ => null,
          }
        : raftHumanAvatarFixedColors[split[1]];
    if (css != null) out[int.parse(role, radix: 36)] = _hex(css);
  });
  return out;
}

List<RaftHumanAvatarLayer> _recipeLayers(RaftHumanAvatarRecipe recipe) {
  RaftHumanAvatarLayer? find(String layer, String? option) =>
      option == null ? null : _layerIndex['$layer:$option'];
  String? art(RaftHumanAvatarField f) => f.artOption(recipe[f]);
  final accessories = [
    find('accessory', art(RaftHumanAvatarField.head)),
    find('accessory', art(RaftHumanAvatarField.face)),
  ].whereType<RaftHumanAvatarLayer>().toList()..sort((a, b) => a.z - b.z);
  return [
    ?find('base', 'default'),
    ?find('expression', art(RaftHumanAvatarField.expression)),
    ?find('hair', art(RaftHumanAvatarField.hair)),
    ...accessories,
  ];
}

RaftHumanAvatarPixels composeRaftHumanAvatar(RaftHumanAvatarRecipe recipe) {
  const size = raftHumanAvatarSize;
  final colors = _roleColors(recipe);
  final pixels = Uint32List(size * size);
  for (final layer in _recipeLayers(recipe)) {
    final grid = _grid(layer);
    for (var i = 0; i < grid.length; i++) {
      final role = grid[i];
      if (role == 0) continue;
      final color = colors[role];
      if (color != null) pixels[i] = color;
    }
  }
  final background =
      raftHumanAvatarBackgroundPalette[RaftHumanAvatarField.background
          .artOption(recipe[RaftHumanAvatarField.background])];
  return RaftHumanAvatarPixels(size, _hex(background ?? '#ffd440'), pixels);
}

/// The art's own hair colour for a `hairColor` option id (ARGB), for the
/// builder's swatches.
int raftHumanAvatarHairSwatch(String hairColorId) => _hex(
  raftHumanAvatarHairPalette[RaftHumanAvatarField.hairColor.artOption(
        hairColorId,
      )] ??
      '#141111',
);
