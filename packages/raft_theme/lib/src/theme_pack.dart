import 'dart:convert';
import 'dart:ui' show Color;

import 'color_value.dart';
import 'contract_names.g.dart';
import 'shadow_value.dart';

/// The file format this parser reads.
const String raftThemePackFormat = 'raft-theme/1';

/// A theme file the app cannot use. Carries the JSON path of the offending
/// entry, because "invalid theme" alone is not something a designer can fix.
class RaftThemeException implements Exception {
  RaftThemeException(this.message, {this.where});

  final String message;
  final String? where;

  @override
  String toString() => where == null ? message : '$where: $message';
}

/// Text casing a theme may apply to a role. It changes display only — the
/// strings themselves never change, so this does not override copy rules.
enum RaftCaseTransform { none, uppercase, lowercase }

/// One readable slot of the type scale.
class RaftTypeStyleSpec {
  const RaftTypeStyleSpec({
    required this.size,
    required this.line,
    required this.weight,
    this.trackingEm = 0,
  });

  final double size;
  final double line;
  final double weight;

  /// Letter spacing in em, as CSS writes it (`-0.01`).
  final double trackingEm;

  @override
  bool operator ==(Object other) =>
      other is RaftTypeStyleSpec &&
      other.size == size &&
      other.line == line &&
      other.weight == weight &&
      other.trackingEm == trackingEm;

  @override
  int get hashCode => Object.hash(size, line, weight, trackingEm);
}

/// A font family a theme asks for. [asset] is set when the pack ships the
/// font file itself; otherwise [family] must be a family the app bundles.
class RaftFontSpec {
  const RaftFontSpec({required this.family, this.stack = const [], this.asset});

  final String family;
  final List<String> stack;
  final String? asset;
}

/// Everything one mode (light or dark) resolves to. A pack may set any subset;
/// [mergedWith] fills the rest from the theme it extends.
class RaftModeValues {
  const RaftModeValues({
    this.colors = const {},
    this.palette = const {},
    this.geometry = const {},
    this.type = const {},
    this.fontRefs = const {},
    this.fonts = const {},
    this.caseTransforms = const {},
    this.shadows = const {},
    this.options = const {},
  });

  final Map<String, Color> colors;
  final Map<String, Color> palette;
  final Map<String, double> geometry;
  final Map<String, RaftTypeStyleSpec> type;

  /// Component font tokens reference existing font families per mode.
  final Map<String, String> fontRefs;

  /// Optional per-mode overrides of the pack's existing font families.
  final Map<String, RaftFontSpec> fonts;
  final Map<String, RaftCaseTransform> caseTransforms;
  final Map<String, List<RaftShadowSpec>> shadows;
  final Map<String, String> options;

  RaftModeValues mergedWith(RaftModeValues base) => RaftModeValues(
    colors: {...base.colors, ...colors},
    palette: {...base.palette, ...palette},
    geometry: {...base.geometry, ...geometry},
    type: {...base.type, ...type},
    fontRefs: {...base.fontRefs, ...fontRefs},
    fonts: {...base.fonts, ...fonts},
    caseTransforms: {...base.caseTransforms, ...caseTransforms},
    shadows: {...base.shadows, ...shadows},
    options: {...base.options, ...options},
  );
}

/// The structural options a pack may choose from, and the values each accepts.
///
/// This is the single source of truth for §4 of `docs/theme-contract.md`: a
/// pack that names an option the app does not implement, or a value that
/// option does not have, fails to load instead of silently keeping a default.
const Map<String, Set<String>> raftStructuralOptions = {
  'control.edge': {'inkBorder', 'ring', 'none'},
  'sticker.ring': {'none', 'dieCut'},
  'emphasis.fill': {'solid', 'soft'},
  'press.effect': {'overlay', 'scale', 'offsetShadow'},
  'iconButton.surface': {'generic', 'raised'},
  'control.sheen': {'none', 'gradient'},
  'avatar.shape': {'square', 'circle'},
  'indicator.border': {'none', 'ink'},
  'switch.shape': {'pill', 'square'},
  'checkbox.mark': {'fillCheck', 'strokeCheck', 'thickStroke'},
  'field.style': {'border', 'inset'},
  'tabs.selected': {'sticker', 'tint', 'underline'},
  'segmented.selected': {'sticker', 'tint'},
  // Whether the segments sit inside a rounded, padded track (raft-ui 0.7.1) or
  // are separate segments separated by a gap (the pre-theme app).
  'segmented.frame': {'framed', 'separate'},
  'sidebar.mobileSurface': {'canvas', 'sidebar'},
  'resource.surface': {'canvas', 'sidebar'},
  'resource.rows': {'flat', 'cards'},
  'resource.badge': {'sticker', 'pill'},
  'resource.markRead': {'ghost', 'outline'},
  'listGroup.frame': {'plain', 'framed'},
  'task.status': {'square', 'symbol'},
  'searchResult.selection': {'flat', 'card'},
  'messageReference.chipLayout': {'fixed', 'intrinsic'},
  'messageMenu.reactionDivider': {'shown', 'hidden'},
  'messageHeader.timePosition': {'trailing', 'inline'},
  'messageHeader.align': {'baseline', 'center'},
  'panelAction.surface': {'ghost', 'outline'},
  'mobileNav.style': {'floatingCapsule', 'docked'},
  'mobileNav.labels': {'iconsOnly', 'withLabels'},
  'mobileNav.selection': {'iconSticker', 'cell'},
  'mobileNav.boxLayout': {'css', 'natural'},
  'mobileNav.textLayout': {'css', 'natural'},
  'header.layout': {'overlay', 'inFlow'},
  'panel.edge': {'seam', 'border'},
  'nav.selection': {'sticker', 'softFill', 'outline'},
  'tooltip.arrow': {'yes', 'no'},
  'code.innerBorder': {'dashed', 'solid'},
  'spinner.style': {'pixel', 'ring'},
  'dialog.close': {'ghost', 'outline'},
  'dialog.cancelSurface': {'ghost', 'outline'},
  'banner.iconAlignment': {'start', 'center'},
  'banner.iconColor': {'foreground', 'intent'},
  'confirm.slug': {'chip', 'text'},
  'confirm.explanation': {'dangerBanner', 'plain'},
  'spinner.ringShape': {'sweep', 'quarter'},
  'spinner.foreground': {'inherited', 'fixed'},
  'button.disabledSurface': {'muted', 'opacity'},
  'button.xsLine': {'fixed', 'inherited'},
  'button.hoverSurface': {'overlay', 'variant'},
  'button.linkDecoration': {'underline', 'none'},
  'button.linkPadding': {'none', 'size'},
  // Page lane (Web v1.21.23 pages; tool/theme-adapters/pages_lane.py).
  'auth.submitSize': {'xl', 'lg'},
  'auth.links': {'underlined', 'hover'},
  'standalone.surface': {'sidebar', 'canvas'},
  'standalone.buttonSize': {'lg', 'md'},
  'auth.fieldLabel': {'tokens', 'recipe'},
  'publicServer.sidebar': {'shared', 'legacy'},
  'publicServer.banner': {'stacked', 'row'},
  'publicServer.channelTile': {'sticker', 'plain'},
  'panelTabs.style': {'sticker', 'underline'},
  'agentWorkspace.look': {'web23', 'legacy'},
  'pageHeader.icon': {'none', 'tile'},
  'taskBoard.column': {'flat', 'card'},
  'taskModal.head': {'web23', 'legacy'},
  'emptyState.look': {'plain', 'recipe'},
  'skeleton.look': {'fill', 'ink'},
  'activity.loadingCards': {'edge', 'inset'},
  'search.failure': {'banner', 'card'},
  'appearance.layout': {'web23', 'legacy'},
  'formSection.look': {'web23', 'legacy'},
  'formField.label': {'tokens', 'recipe'},
  'rootError.look': {'web23', 'legacy'},
  'onboarding.heading': {'web23', 'legacy'},
  'onboarding.preview': {'sticker', 'brutal'},
  'publicServer.confirmTitle': {'question', 'action'},
  'publicServer.accountTime': {'yes', 'no'},
  'agentActivity.look': {'web23', 'legacy'},
};

/// The type-scale slots a pack may fill (§3.4 of the contract).
const Set<String> raftTypeSlots = {
  'hero',
  'display',
  'title',
  'headline',
  'body',
  'subhead',
  'callout',
  'footnote',
  'caption',
  'label',
  'mono-meta',
  'mono-code',
};

/// A parsed `raft-theme/1` file.
class RaftThemePack {
  RaftThemePack({
    required this.id,
    required this.name,
    required this.version,
    required this.light,
    required this.dark,
    this.extendsId,
    this.builtIn = false,
    this.author,
    this.fonts = const {},
    this.warnings = const [],
  });

  /// Parse and validate one pack. Throws [RaftThemeException] for anything the
  /// app cannot honour; returns the pack plus [warnings] for things it can
  /// (unknown keys, which a newer pack version may add).
  static RaftThemePack parse(String source, {String origin = 'theme'}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw RaftThemeException(
        'not valid JSON: ${error.message}',
        where: origin,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw RaftThemeException('a theme pack is a JSON object', where: origin);
    }
    final warnings = <String>[];
    _checkKeys(decoded, _packKeys, origin, warnings);

    if (decoded['format'] != raftThemePackFormat) {
      throw RaftThemeException(
        'format must be "$raftThemePackFormat"',
        where: '$origin.format',
      );
    }
    final id = _string(decoded, 'id', origin);
    final version = _string(decoded, 'version', origin);
    final name = _localisedName(decoded['name'], '$origin.name');
    final modes = decoded['modes'];
    if (modes is! Map)
      throw RaftThemeException('modes is required', where: origin);
    RaftModeValues? readMode(Object? raw, String where) {
      try {
        return _mode(raw, where);
      } on FormatException catch (error) {
        // A value that will not parse is still the theme's fault, not the
        // app's: report it as a theme error and keep the path it carries.
        throw RaftThemeException(error.message);
      }
    }

    final light = readMode(modes['light'], '$origin.modes.light');
    final dark = readMode(modes['dark'], '$origin.modes.dark');
    if (light == null)
      throw RaftThemeException('modes.light is required', where: origin);
    if (dark == null)
      throw RaftThemeException('modes.dark is required', where: origin);

    final fonts = _fonts(decoded['fonts'], '$origin.fonts');

    final extendsId = decoded['extends'];
    if (extendsId != null && extendsId is! String) {
      throw RaftThemeException(
        'extends must be a theme id',
        where: '$origin.extends',
      );
    }
    if (extendsId == id) {
      throw RaftThemeException(
        'a theme cannot extend itself',
        where: '$origin.extends',
      );
    }
    final builtIn = decoded['builtIn'];
    if (builtIn != null && builtIn is! bool) {
      throw RaftThemeException(
        'builtIn must be true or false',
        where: '$origin.builtIn',
      );
    }
    return RaftThemePack(
      id: id,
      name: name,
      version: version,
      extendsId: extendsId as String?,
      builtIn: builtIn as bool? ?? false,
      author: decoded['author'] is String ? decoded['author'] as String : null,
      fonts: fonts,
      light: light,
      dark: dark,
      warnings: warnings,
    );
  }

  final String id;
  final Map<String, String> name;
  final String version;
  final String? extendsId;
  final bool builtIn;
  final String? author;
  final Map<String, RaftFontSpec> fonts;
  final RaftModeValues light;
  final RaftModeValues dark;
  final List<String> warnings;

  /// This pack's values for [dark], with everything it does not set taken from
  /// [base] (the theme named by [extendsId]).
  RaftModeValues resolve({required bool dark, RaftThemePack? base}) {
    final selected = dark ? this.dark : light;
    // A mode overrides the pack; omitted families continue through its base.
    final own = selected.mergedWith(RaftModeValues(fonts: fonts));
    if (base == null) return own;
    return own.mergedWith(base.resolve(dark: dark));
  }

  /// Follow the `extends` chain through [byId] and resolve [dark].
  RaftModeValues resolveIn(
    Map<String, RaftThemePack> byId, {
    required bool dark,
  }) {
    final seen = <String>{id};
    RaftThemePack? base;
    var cursor = extendsId == null ? null : byId[extendsId];
    while (cursor != null) {
      if (!seen.add(cursor.id)) {
        throw RaftThemeException(
          'the extends chain loops through "${cursor.id}"',
        );
      }
      base = cursor;
      cursor = cursor.extendsId == null ? null : byId[cursor.extendsId];
    }
    return resolve(dark: dark, base: base);
  }
}

const Set<String> _packKeys = {
  'format',
  'id',
  'name',
  'version',
  'extends',
  'builtIn',
  'author',
  'fonts',
  'source',
  'modes',
  'assets',
  r'$schema',
  r'$description',
};

const Set<String> _modeKeys = {
  'colors',
  'palette',
  'geometry',
  'type',
  'font',
  'fonts',
  'case',
  'shadows',
  'options',
};

RaftModeValues? _mode(Object? raw, String where) {
  if (raw == null) return null;
  if (raw is! Map)
    throw RaftThemeException('a mode is an object', where: where);
  final warnings = <String>[];
  _checkKeys(raw, _modeKeys, where, warnings);

  // Palette first: a role may refer to one of its entries by name.
  final palette = <String, Color>{};
  final rawPalette = raw['palette'];
  if (rawPalette is! Map && rawPalette != null) {
    throw RaftThemeException('palette is an object', where: '$where.palette');
  }
  if (rawPalette is Map) {
    for (final entry in rawPalette.entries) {
      palette['${entry.key}'] = parseThemeColor(
        entry.value,
        where: '$where.palette.${entry.key}',
      );
    }
  }
  final colors = <String, Color>{};
  final rawColors = raw['colors'];
  if (rawColors != null) {
    if (rawColors is! Map)
      throw RaftThemeException('colors is an object', where: '$where.colors');
    for (final entry in rawColors.entries) {
      final role = '${entry.key}';
      final path = '$where.colors.$role';
      if (!raftColorRoles.contains(role)) {
        throw RaftThemeException('unknown colour role "$role"', where: path);
      }
      colors[role] = _color(entry.value, path, palette);
    }
  }
  final geometry = <String, double>{};
  final rawGeometry = raw['geometry'];
  if (rawGeometry is! Map && rawGeometry != null) {
    throw RaftThemeException('geometry is an object', where: '$where.geometry');
  }
  if (rawGeometry is Map) {
    for (final entry in rawGeometry.entries) {
      final value = entry.value;
      if (value is! num) {
        throw RaftThemeException(
          'a numeric token is a number',
          where: '$where.geometry.${entry.key}',
        );
      }
      final token = '${entry.key}';
      if (!raftGeometryTokens.contains(token)) {
        throw RaftThemeException(
          'unknown geometry token "$token"',
          where: '$where.geometry.$token',
        );
      }
      if (token.startsWith('blur.') && (!value.isFinite || value < 0)) {
        throw RaftThemeException(
          'a blur is nonnegative pixels',
          where: '$where.geometry.$token',
        );
      }
      if (token.startsWith('duration.') &&
          (!value.isFinite || value <= 0 || value % 1 != 0)) {
        throw RaftThemeException(
          'a duration is positive integer milliseconds',
          where: '$where.geometry.$token',
        );
      }
      if (token.startsWith('ratio.') &&
          (!value.isFinite || value < 0 || value > 1)) {
        throw RaftThemeException(
          'a ratio is between 0 and 1',
          where: '$where.geometry.$token',
        );
      }
      geometry[token] = value.toDouble();
    }
  }
  final type = <String, RaftTypeStyleSpec>{};
  final rawType = raw['type'];
  if (rawType is! Map && rawType != null) {
    throw RaftThemeException('type is an object', where: '$where.type');
  }
  if (rawType is Map) {
    for (final entry in rawType.entries) {
      final slot = '${entry.key}';
      if (!raftTypeSlots.contains(slot)) {
        throw RaftThemeException(
          'unknown type slot "$slot"',
          where: '$where.type.$slot',
        );
      }
      type[slot] = _typeStyle(entry.value, '$where.type.$slot');
    }
  }
  final fontRefs = <String, String>{};
  final rawFontRefs = raw['font'];
  if (rawFontRefs != null && rawFontRefs is! Map) {
    throw RaftThemeException('font is an object', where: '$where.font');
  }
  if (rawFontRefs is Map) {
    for (final entry in rawFontRefs.entries) {
      final token = '${entry.key}';
      final path = '$where.font.$token';
      if (token != 'font.messageTime' && token != 'font.messageSubtitle') {
        throw RaftThemeException('unknown font token "$token"', where: path);
      }
      final ref = RegExp(r'^\{fonts\.(sans|heading|mono)\}$')
          .firstMatch('${entry.value}');
      if (ref == null) {
        throw RaftThemeException(
          'a font token references an existing family',
          where: path,
        );
      }
      fontRefs[token] = ref.group(1)!;
    }
  }
  final caseTransforms = <String, RaftCaseTransform>{};
  final rawCase = raw['case'];
  if (rawCase is! Map && rawCase != null) {
    throw RaftThemeException('case is an object', where: '$where.case');
  }
  if (rawCase is Map) {
    for (final entry in rawCase.entries) {
      final slot = '${entry.key}';
      if (!const {
        'heading',
        'label',
        'badge',
        'dialogShellTitle',
      }.contains(slot)) {
        throw RaftThemeException(
          'unknown case slot "$slot"',
          where: '$where.case.$slot',
        );
      }
      caseTransforms[slot] = switch ('${entry.value}') {
        'none' => RaftCaseTransform.none,
        'uppercase' => RaftCaseTransform.uppercase,
        'lowercase' => RaftCaseTransform.lowercase,
        final other => throw RaftThemeException(
          'case is none, uppercase or lowercase, not "$other"',
          where: '$where.case.$slot',
        ),
      };
    }
  }
  final shadows = <String, List<RaftShadowSpec>>{};
  final rawShadows = raw['shadows'];
  if (rawShadows is! Map && rawShadows != null) {
    throw RaftThemeException('shadows is an object', where: '$where.shadows');
  }
  if (rawShadows is Map) {
    for (final entry in rawShadows.entries) {
      shadows['${entry.key}'] = parseShadowList(
        entry.value,
        where: '$where.shadows.${entry.key}',
      );
    }
  }
  final options = <String, String>{};
  final rawOptions = raw['options'];
  if (rawOptions is! Map && rawOptions != null) {
    throw RaftThemeException('options is an object', where: '$where.options');
  }
  if (rawOptions is Map) {
    for (final entry in rawOptions.entries) {
      final option = '${entry.key}';
      final allowed = raftStructuralOptions[option];
      if (allowed == null) {
        throw RaftThemeException(
          'unknown option "$option"',
          where: '$where.options.$option',
        );
      }
      final value = '${entry.value}';
      if (!allowed.contains(value)) {
        throw RaftThemeException(
          'option "$option" is one of ${allowed.join(' / ')}, not "$value"',
          where: '$where.options.$option',
        );
      }
      options[option] = value;
    }
  }
  return RaftModeValues(
    colors: colors,
    palette: palette,
    geometry: geometry,
    type: type,
    fontRefs: fontRefs,
    fonts: _fonts(raw['fonts'], '$where.fonts'),
    caseTransforms: caseTransforms,
    shadows: shadows,
    options: options,
  );
}

/// A colour value, or a `{palette.x.y}` reference to one in [palette].
Color _color(Object? value, String where, Map<String, Color> palette) {
  if (value is String) {
    final reference = RegExp(r'^\{\s*palette[.\-]([^}]+)\s*\}$')
        .firstMatch(value.trim());
    if (reference != null) {
      final body = reference.group(1)!.trim().replaceAll('.', '-');
      // `{palette.cream.100}` and `{palette.palette-cream-100}` both name the
      // same entry; a pack may write either.
      final name = body.startsWith('palette-') ? body : 'palette-$body';
      final color = palette[name];
      if (color == null) {
        throw RaftThemeException('unknown palette entry "$name"', where: where);
      }
      return color;
    }
  }
  return parseThemeColor(value, where: where);
}

RaftTypeStyleSpec _typeStyle(Object? raw, String where) {
  if (raw is List) {
    if (raw.length < 3 || raw.any((v) => v is! num)) {
      throw RaftThemeException(
        '[size, lineHeight, weight, trackingEm?]',
        where: where,
      );
    }
    return RaftTypeStyleSpec(
      size: (raw[0] as num).toDouble(),
      line: (raw[1] as num).toDouble(),
      weight: (raw[2] as num).toDouble(),
      trackingEm: raw.length > 3 ? (raw[3] as num).toDouble() : 0,
    );
  }
  if (raw is Map) {
    return RaftTypeStyleSpec(
      size: _number(raw, 'size', where),
      line: _number(raw, 'line', where),
      weight: _number(raw, 'weight', where),
      trackingEm: raw['tracking'] is num
          ? (raw['tracking'] as num).toDouble()
          : 0,
    );
  }
  throw RaftThemeException(
    'a type slot is [size, line, weight, tracking]',
    where: where,
  );
}

Map<String, RaftFontSpec> _fonts(Object? raw, String where) {
  if (raw == null) return const {};
  if (raw is! Map) {
    throw RaftThemeException('fonts is an object', where: where);
  }
  final fonts = <String, RaftFontSpec>{};
  for (final entry in raw.entries) {
    final role = '${entry.key}';
    if (!const {'sans', 'heading', 'mono'}.contains(role)) {
      throw RaftThemeException(
        'unknown font family role "$role"',
        where: '$where.$role',
      );
    }
    fonts[role] = _font(entry.value, '$where.$role');
  }
  return fonts;
}

RaftFontSpec _font(Object? raw, String where) {
  if (raw is! Map) {
    throw RaftThemeException('a font is an object', where: where);
  }
  final family = raw['family'];
  if (family is! String || family.trim().isEmpty) {
    throw RaftThemeException('family is required', where: where);
  }
  final stack = raw['stack'];
  if (stack != null &&
      (stack is! List ||
          stack.any((item) => item is! String || item.trim().isEmpty))) {
    throw RaftThemeException(
      'stack is a list of font family names',
      where: '$where.stack',
    );
  }
  final asset = raw['asset'];
  if (asset != null && (asset is! String || asset.isEmpty)) {
    throw RaftThemeException(
      'asset is a font asset name or null',
      where: '$where.asset',
    );
  }
  return RaftFontSpec(
    family: family,
    stack: stack is List
        ? [for (final item in stack) item as String]
        : const [],
    asset: asset as String?,
  );
}

Map<String, String> _localisedName(Object? raw, String where) {
  if (raw is String) return {'en': raw};
  if (raw is Map && raw.isNotEmpty) {
    return {for (final entry in raw.entries) '${entry.key}': '${entry.value}'};
  }
  throw RaftThemeException('name is a string or a language map', where: where);
}

String _string(Map<String, dynamic> map, String key, String where) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw RaftThemeException('$key is required', where: where);
  }
  return value;
}

double _number(Map raw, String key, String where) {
  final value = raw[key];
  if (value is! num) throw RaftThemeException('$key is a number', where: where);
  return value.toDouble();
}

void _checkKeys(
  Map raw,
  Set<String> known,
  String where,
  List<String> warnings,
) {
  for (final key in raw.keys) {
    if (!known.contains('$key'))
      warnings.add('$where.$key: unknown key, ignored');
  }
}
