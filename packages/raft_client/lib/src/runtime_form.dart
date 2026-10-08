/// Runtime-form v2 wire semantics mirrored from the pinned shared package.
/// Unknown optional fields survive edits; unsupported required fields block save.
class RuntimeField {
  RuntimeField({
    required this.key,
    required this.kind,
    required this.required,
    required this.label,
    required this.schema,
    this.sourceId,
    this.parent,
    this.derived,
    this.copy = const {},
    this.visibility = const [],
  });
  final String key, kind, label;
  final bool required;
  final Map<String, dynamic> schema, copy;
  final String? sourceId, parent;
  final Map<String, dynamic>? derived;
  final List<Map<String, dynamic>> visibility;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : {};
List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().toList() : [];
String _text(dynamic v) => v is String ? v : '';
String? _pointer(dynamic v) =>
    v is String &&
        v.startsWith('/') &&
        v.length > 1 &&
        !v.substring(1).contains('/')
    ? v.substring(1)
    : null;

class RuntimeForm {
  RuntimeForm._(
    this.runtimeId,
    this.schemaVersion,
    this.fields,
    this.sourceRefs,
    this.stored,
    this.capabilities,
  );
  final String runtimeId, schemaVersion;
  final List<RuntimeField> fields;
  final Map<String, Map<String, dynamic>> sourceRefs;
  final Map<String, dynamic> stored;
  final List<String> capabilities;
  static const supportedCapabilities = {
    'select.custom_value',
    'choice.labels',
    'option_source.status',
  };
  bool get supported => capabilities.every(supportedCapabilities.contains);
  static RuntimeForm? parse(dynamic wire) {
    if (wire is! Map || wire['protocolVersion'] != 2) return null;
    final data = _map(wire['dataSchema']);
    if (data['properties'] is! Map) return null;
    final props = _map(data['properties']), ui = _map(wire['uiSchema']);
    final required = _strings(data['required']).toSet();
    final sources = <String, Map<String, dynamic>>{};
    for (final entry in _map(wire['optionSources']).entries) {
      final source = _map(entry.value),
          key = _pointer(_map(entry.value)['pointer']);
      final parent = _pointer(source['dependsOn']);
      if (key == null ||
          !['select', 'dependent_select'].contains(source['kind']) ||
          (source['kind'] == 'dependent_select' && parent == null))
        continue;
      sources[entry.key] = {...source, 'key': key, 'parent': parent};
    }
    final order = {
      ..._strings(ui['order']).where(props.containsKey),
      ...props.keys,
    };
    final fields = <RuntimeField>[];
    for (final key in order) {
      if (props[key] is! Map) continue;
      final schema = _map(props[key]),
          copy = _map(_map(ui['localization'])[key]);
      final sourceId =
          schema['x-optionSource'] is String &&
              sources.containsKey(schema['x-optionSource'])
          ? schema['x-optionSource'] as String
          : null;
      final d = _map(schema['x-optionsFrom']);
      final derived =
          d['field'] is String &&
              props.containsKey(d['field']) &&
              d['attribute'] is String
          ? d
          : null;
      final type = schema['type'];
      final kind = type == 'boolean'
          ? 'boolean'
          : type == 'object' &&
                _map(schema['additionalProperties'])['type'] == 'string'
          ? 'string_map'
          : type != 'string'
          ? 'unsupported'
          : sourceId != null
          ? sources[sourceId]!['kind'] as String
          : derived != null
          ? 'derived_select'
          : schema['writeOnly'] == true
          ? 'secret'
          : schema['format'] == 'uri'
          ? 'url'
          : 'text';
      fields.add(
        RuntimeField(
          key: key,
          kind: kind,
          required: required.contains(key),
          label: _text(copy['label']).isNotEmpty
              ? copy['label']
              : schema['title'] is String
              ? schema['title']
              : key,
          schema: schema,
          copy: copy,
          sourceId: sourceId,
          parent: sourceId == null
              ? (derived?['field'])
              : sources[sourceId]!['parent'],
          derived: derived,
          visibility: [
            for (final raw
                in ui['visibility'] is List ? ui['visibility'] as List : [])
              if (raw is Map &&
                  _pointer(raw['pointer']) == key &&
                  _pointer(_map(raw['when'])['pointer']) != null)
                {
                  'key': _pointer(_map(raw['when'])['pointer']),
                  'in': _strings(_map(raw['when'])['in']),
                },
          ],
        ),
      );
    }
    final rawCaps = wire['requiredClientCapabilities'];
    final caps = rawCaps == null
        ? <String>[]
        : rawCaps is List && rawCaps.every((v) => v is String)
        ? rawCaps.cast<String>()
        : ['(malformed requiredClientCapabilities)'];
    return RuntimeForm._(
      _text(wire['runtimeId']),
      _text(wire['schemaVersion']),
      fields,
      sources,
      _map(wire['values']),
      caps,
    );
  }

  List<RuntimeField> get dependencyOrder {
    final out = <RuntimeField>[], seen = <String>{};
    void visit(RuntimeField field, int depth) {
      if (seen.contains(field.key) || depth > fields.length) return;
      final parent = fields.where((f) => f.key == field.parent).firstOrNull;
      if (parent != null) visit(parent, depth + 1);
      if (seen.add(field.key)) out.add(field);
    }

    for (final field in fields) {
      visit(field, 0);
    }
    return out;
  }

  Map<String, dynamic> selectedOption(
    String key,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    for (final source in sources.values) {
      if (source['pointer'] != '/$key') continue;
      final options = source['options'] is List
          ? source['options'] as List
          : _map(source['optionsByValue'])[_text(
                      values[_pointer(source['dependsOn'])],
                    )]
                    as List? ??
                [];
      for (final option in options.whereType<Map>()) {
        if (option['value'] == values[key]) return _map(option);
      }
    }
    return {};
  }

  List<Map<String, dynamic>> choices(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    final source = sources[f.sourceId] ?? {};
    List<dynamic> options = [];
    if (f.kind == 'select') {
      options = source['options'] as List? ?? [];
    }
    if (f.kind == 'dependent_select') {
      options =
          _map(source['optionsByValue'])[_text(values[f.parent])] as List? ??
          [];
    }
    if (f.kind == 'derived_select') {
      final option = selectedOption(f.parent!, sources, values),
          attr = f.derived!['attribute'];
      options = [
        for (final value in _strings(option[attr]))
          {'value': value, 'label': value},
      ];
    }
    return [
      for (final raw in options.whereType<Map>())
        {
          ..._map(raw),
          'label':
              _text(_map(_map(f.copy['choices'])[raw['value']])['label'])
                  .isNotEmpty
              ? _map(_map(f.copy['choices'])[raw['value']])['label']
              : _text(raw['label']).isNotEmpty
              ? raw['label']
              : raw['value'],
          if (_map(_map(f.copy['choices'])[raw['value']])['description']
              is String)
            'description': _map(
              _map(f.copy['choices'])[raw['value']],
            )['description'],
        },
    ];
  }

  bool custom(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    final source = sources[f.sourceId] ?? {};
    return f.kind == 'select' && source['customValueAllowed'] == true ||
        f.kind == 'dependent_select' &&
            _map(source['customValueAllowedByValue'])[_text(
                  values[f.parent],
                )] ==
                true;
  }

  dynamic defaultFor(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    final source = sources[f.sourceId] ?? {};
    return switch (f.kind) {
      'boolean' => false,
      'string_map' => <String, String>{},
      'unsupported' => null,
      'select' =>
        source['defaultValue'] ??
            (source['options'] as List? ?? []).firstOrNull?['value'] ??
            '',
      'dependent_select' =>
        custom(f, sources, values)
            ? ''
            : _map(source['defaultValueByValue'])[_text(values[f.parent])] ??
                  '',
      'derived_select' =>
        selectedOption(
              f.parent!,
              sources,
              values,
            )[f.derived!['defaultAttribute']] ??
            '',
      _ => '',
    };
  }

  Map<String, dynamic> initial(Map<String, Map<String, dynamic>> sources) {
    final values = <String, dynamic>{};
    for (final f in dependencyOrder) {
      final v = stored[f.key];
      final fits =
          stored.containsKey(f.key) &&
          switch (f.kind) {
            'boolean' => v is bool,
            'string_map' => v is Map && v.values.every((v) => v is String),
            'unsupported' => true,
            _ => v is String,
          };
      values[f.key] = fits ? v : defaultFor(f, sources, values);
    }
    return values;
  }

  Map<String, dynamic> change(
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
    String key,
    dynamic value,
  ) {
    final next = {...values, key: value}, changed = {key};
    for (final f in dependencyOrder) {
      if (f.parent != null && changed.contains(f.parent)) {
        next[f.key] = defaultFor(f, sources, next);
        changed.add(f.key);
      }
    }
    return next;
  }

  bool unavailable(RuntimeField f, Map<String, Map<String, dynamic>> sources) =>
      sources[f.sourceId]?['status'] == 'unavailable';
  bool visible(
    RuntimeField f,
    Map<String, dynamic> values, [
    Map<String, Map<String, dynamic>>? sources,
  ]) =>
      !(sources != null && !f.required && unavailable(f, sources)) &&
      f.visibility.every(
        (r) => (r['in'] as List).contains(_text(values[r['key']])),
      );
  Map<String, String> validate(
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values, {
    bool editing = false,
  }) {
    final errors = <String, String>{};
    if (!supported) return {'form': 'unsupported_capabilities'};
    for (final f in fields) {
      if (!visible(f, values, sources)) continue;
      if (f.kind == 'unsupported') {
        if (f.required) errors[f.key] = 'unsupported_required';
        continue;
      }
      if (f.required && unavailable(f, sources)) {
        errors[f.key] = 'source_unavailable';
        continue;
      }
      final text = _text(values[f.key]).trim();
      if (f.required &&
          !(editing && f.kind == 'secret') &&
          [
            'text',
            'secret',
            'url',
            'select',
            'dependent_select',
          ].contains(f.kind) &&
          text.isEmpty) {
        errors[f.key] = 'required';
        continue;
      }
      if (f.kind == 'url' &&
          text.isNotEmpty &&
          !RegExp(r'^https?://', caseSensitive: false).hasMatch(text))
        errors[f.key] = 'invalid_url';
      if (['select', 'dependent_select', 'derived_select'].contains(f.kind) &&
          !custom(f, sources, values)) {
        final list = choices(f, sources, values);
        if (!(f.kind == 'derived_select' && list.isEmpty) &&
            text.isNotEmpty &&
            !list.any((o) => o['value'] == text))
          errors[f.key] = 'not_a_choice';
      }
    }
    return errors;
  }

  Map<String, dynamic> submission(
    Map<String, dynamic> values,
    Map<String, Map<String, dynamic>> sources,
  ) {
    final out = <String, dynamic>{};
    for (final f in fields) {
      if (!f.required && unavailable(f, sources)) {
        if (stored.containsKey(f.key)) out[f.key] = stored[f.key];
        continue;
      }
      if (f.kind != 'unsupported' && !visible(f, values)) continue;
      if (!values.containsKey(f.key)) continue;
      final v = values[f.key];
      out[f.key] = v is String
          ? v.trim().isEmpty && f.kind == 'derived_select'
                ? null
                : v.trim()
          : v;
    }
    return out;
  }
}

/// Parses the native editor without dropping malformed or duplicate entries.
/// Values preserve whitespace and additional equals signs.
Map<String, String> parseRuntimeStringMap(String text) {
  final result = <String, String>{};
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;
    final at = line.indexOf('=');
    final key = at < 0 ? '' : line.substring(0, at).trim();
    if (key.isEmpty || result.containsKey(key)) {
      throw const FormatException('Enter one unique KEY=value per line.');
    }
    result[key] = line.substring(at + 1);
  }
  return result;
}
