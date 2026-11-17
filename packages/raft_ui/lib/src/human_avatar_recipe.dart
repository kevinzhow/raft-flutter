import 'dart:math' as math;

// A person's built pixel avatar, stored as the options they chose, never as an
// image: `avatarUrl = "pixel-human:v1:<background>.<skin>.<hair>.<hairColor>.
// <expression>.<head>.<face>"`. Port of Web packages/shared/src/humanAvatar.ts
// (recipe format, strict parse for storing, lenient read for drawing). The art
// is human_avatar_data.dart (generated), drawn by human_pixel_avatar.dart.

const raftHumanAvatarScheme = 'pixel-human:';
const _prefix = 'pixel-human:v1:';
const _autoSuffix = '/auto';
const _maxValueLength = 128;
final _valuePattern = RegExp(r'^pixel-human:v[0-9]{1,3}:[a-z0-9.]*(?:/auto)?$');

/// The recipe's fields in wire order. Append only (Web HUMAN_AVATAR_FIELDS).
enum RaftHumanAvatarField {
  background(
    ['yellow', 'pink', 'sky', 'mint', 'lilac', 'cream'],
    {
      'yellow': 'yellow',
      'pink': 'pink',
      'sky': 'sky',
      'mint': 'mint',
      'lilac': 'lilac',
      'cream': 'cream',
    },
    'yellow',
  ),
  skin(
    ['1', '2', '3', '4', '5'],
    {'1': '1', '2': '2', '3': '3', '4': '4', '5': '5'},
    '2',
  ),
  hair(
    ['short', 'side', 'long', 'bun', 'curly', 'buzz'],
    {
      'short': 'short',
      'side': 'side part',
      'long': 'long',
      'bun': 'bun',
      'curly': 'curly',
      'buzz': 'buzz',
    },
    'short',
  ),
  hairColor(
    ['ink', 'brown', 'blonde', 'ginger', 'grey'],
    {
      'ink': 'ink',
      'brown': 'brown',
      'blonde': 'blonde',
      'ginger': 'ginger',
      'grey': 'grey',
    },
    'ink',
  ),
  expression(
    ['wink', 'grin', 'oh', 'smirk', 'happy', 'calm', 'blush'],
    {
      'wink': 'wink',
      'grin': 'grin',
      'oh': 'oh',
      'smirk': 'smirk',
      'happy': 'happy',
      'calm': 'calm',
      'blush': 'blush',
    },
    'wink',
  ),
  head(
    ['none', 'cap', 'beanie', 'headphones'],
    {
      'none': null,
      'cap': 'cap',
      'beanie': 'beanie',
      'headphones': 'headphones',
    },
    'cap',
  ),
  face(['none', 'glasses'], {'none': null, 'glasses': 'glasses'}, 'none');

  const RaftHumanAvatarField(this.ids, this._art, this.defaultId);

  /// Option ids in display order. Stable: stored values hold them.
  final List<String> ids;
  final Map<String, String?> _art;

  /// The art's default for this field (DEFAULT_HUMAN_AVATAR_RECIPE).
  final String defaultId;

  /// The art option [id] draws (humanAvatarLayers.json); null draws nothing.
  String? artOption(String id) => _art[id];
}

/// One known id per field. Build one with [RaftHumanAvatarRecipe.read] /
/// [parse] / [withOption]; an unknown id never gets in.
class RaftHumanAvatarRecipe {
  const RaftHumanAvatarRecipe._(this._ids);

  final List<String> _ids;

  /// yellow, cap, short black hair, wink: what a field that can't be read
  /// draws, and where the builder starts over a photo.
  static final defaults = RaftHumanAvatarRecipe._(
    List.unmodifiable([
      for (final f in RaftHumanAvatarField.values) f.defaultId,
    ]),
  );

  String operator [](RaftHumanAvatarField field) => _ids[field.index];

  /// The recipe with one field changed; an id that is not one of the field's
  /// ids changes nothing (Web `applyOption`).
  RaftHumanAvatarRecipe withOption(RaftHumanAvatarField field, Object? id) {
    if (id is! String || !field.ids.contains(id)) return this;
    return RaftHumanAvatarRecipe._(
      List.unmodifiable([..._ids]..[field.index] = id),
    );
  }

  /// The stored value. [auto] marks one the Server picked.
  String serialize({bool auto = false}) =>
      '$_prefix${_ids.join('.')}${auto ? _autoSuffix : ''}';

  /// Strict, for storing and validating: the recipe when [value] is exactly a
  /// v1 recipe this build knows, else null (Web `parseHumanAvatarRecipe`).
  static RaftHumanAvatarRecipe? parse(String value) {
    final parts = isHumanAvatarUrl(value) ? _v1Parts(value) : null;
    if (parts == null || parts.length != RaftHumanAvatarField.values.length) {
      return null;
    }
    final ids = <String>[];
    for (final field in RaftHumanAvatarField.values) {
      final id = parts[field.index];
      if (!field.ids.contains(id)) return null;
      ids.add(id);
    }
    return RaftHumanAvatarRecipe._(List.unmodifiable(ids));
  }

  /// Lenient, for drawing: null when [value] is not a built avatar at all;
  /// otherwise a full recipe. A missing or unknown field draws its default,
  /// extra trailing fields are ignored, another version draws the defaults
  /// (Web `readHumanAvatarRecipe`).
  static RaftHumanAvatarRecipe? read(String? value) {
    if (value == null || !isHumanAvatarUrl(value)) return null;
    final parts = _v1Parts(value) ?? const <String>[];
    return RaftHumanAvatarRecipe._(
      List.unmodifiable([
        for (final field in RaftHumanAvatarField.values)
          field.index < parts.length && field.ids.contains(parts[field.index])
              ? parts[field.index]
              : field.defaultId,
      ]),
    );
  }

  /// A random look (Web `randomHumanAvatarRecipe`): half wear something on the
  /// head, about a third glasses, so most faces show. [random] is injectable.
  static RaftHumanAvatarRecipe randomLook([math.Random? random]) {
    final r = random ?? math.Random();
    String pick(List<String> ids) =>
        ids[math.min(ids.length - 1, (r.nextDouble() * ids.length).floor())];
    String optional(RaftHumanAvatarField f, double chance) =>
        r.nextDouble() < chance
        ? pick([
            for (final id in f.ids)
              if (id != 'none') id,
          ])
        : 'none';
    // Evaluation order follows Web: the five picks, then head, then face.
    final background = pick(RaftHumanAvatarField.background.ids);
    final skin = pick(RaftHumanAvatarField.skin.ids);
    final hair = pick(RaftHumanAvatarField.hair.ids);
    final hairColor = pick(RaftHumanAvatarField.hairColor.ids);
    final expression = pick(RaftHumanAvatarField.expression.ids);
    final head = optional(RaftHumanAvatarField.head, .5);
    final face = optional(RaftHumanAvatarField.face, .3);
    return RaftHumanAvatarRecipe._(
      List.unmodifiable([
        background,
        skin,
        hair,
        hairColor,
        expression,
        head,
        face,
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RaftHumanAvatarRecipe && other.serialize() == serialize();
  @override
  int get hashCode => serialize().hashCode;
}

/// True when [value] is a built pixel avatar (any version, any fields): a short
/// value of the `pixel-human:` scheme in its own alphabet (Web
/// `isHumanAvatarUrl`).
bool isHumanAvatarUrl(String? value) =>
    value != null &&
    value.length <= _maxValueLength &&
    _valuePattern.hasMatch(value);

/// True when the avatar is one the Server picked, not one the person built.
bool isAutoHumanAvatarUrl(String? value) =>
    isHumanAvatarUrl(value) && value!.endsWith(_autoSuffix);

/// The v1 fields of a value of this version, or null for another version.
List<String>? _v1Parts(String value) {
  if (!value.startsWith(_prefix)) return null;
  final end = value.endsWith(_autoSuffix)
      ? math.max(_prefix.length, value.length - _autoSuffix.length)
      : value.length;
  return value.substring(_prefix.length, end).split('.');
}
