import 'runtime_form_v3_rules.dart';

export 'runtime_form_v3_rules.dart'
    show
        RuntimeFormV3Condition,
        evaluateRuntimeFormV3Schema,
        isPortableRuntimeFormV3Pattern,
        isSupportedRuntimeFormV3Schema,
        runtimeFormV3ScopeKey;

/// Runtime-form v2/v3 wire semantics mirrored from Web
/// `packages/runtime-form` (v2.ts, v2State.ts, v3Rules.ts). Unknown optional
/// fields survive edits; unsupported required fields block save.

/// Protocol versions this client parses; a submit echoes the loaded one in
/// `formDefinitionRef.protocolVersion`.
const runtimeFormProtocolVersions = {2, 3};

/// Capabilities this client ADVERTISES to the server (query
/// `clientCapabilities`, comma-separated) on the definition, edit-form,
/// option-source and submit requests. Web
/// `WEB_RUNTIME_FORM_V2_ADVERTISED_CAPABILITIES`: a typed model beside the list
/// (Built-in OpenRouter) and the v3 shapes.
const runtimeFormAdvertisedCapabilities = [
  'dependent_select.custom_value_with_options',
  'runtime_form.v3',
];

/// The `clientCapabilities` query value.
final runtimeFormClientCapabilitiesParam = runtimeFormAdvertisedCapabilities
    .join(',');

/// The query to send with a request so that it advertises
/// [runtimeFormAdvertisedCapabilities], or [query] unchanged when the request
/// is not a runtime-form one. Runtime-form requests are the definition, the
/// edit form, the option sources, and a create (`POST /agents`) or save
/// (`PATCH /agents/:id`) whose body carries a v2/v3 `formDefinitionRef`
/// (Web `runtimeFormV2SubmitRequestConfig`). The one place both create and
/// edit go through: callers add nothing of their own.
Map<String, dynamic>? runtimeFormRequestQuery(
  String method,
  String path,
  dynamic data,
  Map<String, dynamic>? query,
) {
  final bool form;
  if (method == 'GET') {
    form =
        RegExp(r'^/servers/[^/]+/machines/[^/]+/runtime-forms/v2/')
            .hasMatch(path) ||
        RegExp(r'^/agents/[^/]+/runtime-form$').hasMatch(path);
  } else if (method == 'POST' && path == '/agents' ||
      method == 'PATCH' && RegExp(r'^/agents/[^/]+$').hasMatch(path)) {
    final ref = data is Map ? data['formDefinitionRef'] : null;
    form =
        ref is Map &&
        runtimeFormProtocolVersions.contains(ref['protocolVersion']);
  } else {
    form = false;
  }
  if (!form) return query;
  return {...?query, 'clientCapabilities': runtimeFormClientCapabilitiesParam};
}

/// A `fallback` or `unavailable` option source (`option_source.status`), as the
/// field's status line shows it.
class RuntimeSourceStatus {
  const RuntimeSourceStatus({
    required this.status,
    required this.retryable,
    this.reason,
    this.stale = false,
    this.fetchedAt,
  });

  /// `fallback` or `unavailable`.
  final String status;

  /// As sent; may be a reason this client does not know.
  final String? reason;
  final bool retryable;

  /// `OptionSource.state: "stale"`: the Computer did not answer in time and the
  /// list is the last one it reported (received at [fetchedAt]).
  final bool stale;
  final String? fetchedAt;
}

/// A v3 `uiSchema.rules` entry for one field: SHOW or HIDE on a condition.
class RuntimeFieldRule {
  const RuntimeFieldRule({required this.show, required this.condition});
  final bool show;
  final RuntimeFormV3Condition condition;
}

/// A v3 `dataSchema.allOf` branch listing the field as required: required while
/// [condition] over the whole values evaluates to [when].
class RuntimeFieldRequiredWhen {
  const RuntimeFieldRequiredWhen(this.condition, this.when);
  final Map<String, dynamic> condition;
  final bool when;
}

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
    this.connectionOwned = false,
    this.advanced = false,
    this.rule,
    this.requiredWhen = const [],
  });
  final String key, kind, label;
  final bool required;

  /// `uiSchema.layout.advanced`: rendered behind the Advanced disclosure.
  final bool advanced;

  /// v3 rule for this field (SHOW/HIDE on a condition), if any.
  final RuntimeFieldRule? rule;

  /// v3 conditional required, in addition to the unconditional [required].
  final List<RuntimeFieldRequiredWhen> requiredWhen;

  /// `x-connectionOwned` (capability `provider.saved_connection`): a selected
  /// saved provider connection owns this field's value.
  final bool connectionOwned;
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
    this.revision,
    this.keepRequiresUnchanged, {
    required this.protocolVersion,
    required this.editing,
  });
  final String runtimeId, schemaVersion;

  /// The wire `protocolVersion` (2 or 3); a submit echoes it in
  /// `formDefinitionRef`.
  final int protocolVersion;

  /// Edit form: the server sent the agent's stored `values`. Decides the
  /// edit defaults of [initial].
  final bool editing;

  /// `Definition.revision`: opaque token of this exact form build, echoed on
  /// every option-source request as `?formRevision=`. Null: the plain direct
  /// option protocol (the server never sends connection options then).
  final String? revision;

  /// `writeOnlyKeepRequiresUnchanged` (edit only), by secret field key: the
  /// fields the stored secret is bound to. While one of them differs from its
  /// stored value a blank secret no longer means "keep": a new one is needed.
  /// Advisory (no capability): a client that ignores it gets the server's
  /// `api_key_required` on save.
  final Map<String, List<String>> keepRequiresUnchanged;
  final List<RuntimeField> fields;
  final Map<String, Map<String, dynamic>> sourceRefs;
  final Map<String, dynamic> stored;
  final List<String> capabilities;
  static const supportedCapabilities = {
    'select.custom_value',
    'choice.labels',
    'option_source.status',
    'provider.saved_connection',
  };
  bool get supported => capabilities.every(supportedCapabilities.contains);

  /// What the parser records for a v3 rule or conditional required it cannot
  /// evaluate: the form is unavailable, never rendered with a rule silently
  /// ignored.
  static const unsupportedRuleMarker = '(unsupported v3 rule)';
  static RuntimeForm? parse(dynamic wire) {
    if (wire is! Map ||
        !runtimeFormProtocolVersions.contains(wire['protocolVersion'])) {
      return null;
    }
    final protocolVersion = wire['protocolVersion'] as int;
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
    final advancedKeys = {
      for (final p in _strings(_map(ui['layout'])['advanced']))
        if (_pointer(p) case final key?) key,
    };
    // v3 rules and conditional required; anything unsupported fails the form
    // closed. A v2 body never reads them (unknown keys, as ever).
    var unsupportedRule = false;
    final rules = <String, RuntimeFieldRule>{};
    final requiredWhen = <String, List<RuntimeFieldRequiredWhen>>{};
    if (protocolVersion == 3) {
      for (final raw in ui['rules'] is List ? ui['rules'] as List : const []) {
        final rule = raw is Map ? raw : null;
        final target = rule == null
            ? null
            : runtimeFormV3ScopeKey(rule['scope']);
        final condition = rule != null && rule['condition'] is Map
            ? rule['condition'] as Map
            : null;
        final on = condition == null
            ? null
            : runtimeFormV3ScopeKey(condition['scope']);
        final effect = rule?['effect'];
        if (rule == null ||
            target?.key == null ||
            condition == null ||
            on == null ||
            effect != 'SHOW' && effect != 'HIDE' ||
            !isSupportedRuntimeFormV3Schema(condition['schema']) ||
            rules.containsKey(target!.key)) {
          unsupportedRule = true;
          continue;
        }
        rules[target.key!] = RuntimeFieldRule(
          show: effect == 'SHOW',
          condition: RuntimeFormV3Condition(
            on.key,
            Map<String, dynamic>.from(condition['schema'] as Map),
          ),
        );
      }
      for (final raw
          in data['allOf'] is List ? data['allOf'] as List : const []) {
        if (raw is! Map || !isSupportedRuntimeFormV3Schema(raw['if'])) {
          unsupportedRule = true;
          continue;
        }
        final condition = Map<String, dynamic>.from(raw['if'] as Map);
        for (final (branch, branchWhen) in [('then', true), ('else', false)]) {
          final clause = raw[branch];
          if (clause == null && !raw.containsKey(branch)) continue;
          if (clause is! Map || clause['required'] is! List) {
            unsupportedRule = true;
            continue;
          }
          for (final key in _strings(clause['required'])) {
            (requiredWhen[key] ??= []).add(
              RuntimeFieldRequiredWhen(condition, branchWhen),
            );
          }
        }
      }
    }
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
          connectionOwned: schema['x-connectionOwned'] == true,
          advanced: advancedKeys.contains(key),
          rule: rules[key],
          requiredWhen: requiredWhen[key] ?? const [],
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
    // Entries naming no secret field, or bound fields naming no field, are
    // dropped (tolerant by contract).
    final kinds = {for (final f in fields) f.key: f.kind};
    final keep = <String, List<String>>{};
    for (final entry in _map(wire['writeOnlyKeepRequiresUnchanged']).entries) {
      final key = _pointer(entry.key);
      if (key == null || kinds[key] != 'secret' || entry.value is! List) {
        continue;
      }
      final bound = [
        for (final raw in entry.value as List)
          if (_pointer(raw) case final name?)
            if (kinds.containsKey(name) && name != key) name,
      ];
      if (bound.isNotEmpty) keep[key] = bound;
    }
    final rawCaps = wire['requiredClientCapabilities'];
    final caps = [
      ...rawCaps == null
          ? <String>[]
          : rawCaps is List && rawCaps.every((v) => v is String)
          ? rawCaps.cast<String>().toSet()
          : ['(malformed requiredClientCapabilities)'],
      if (unsupportedRule) unsupportedRuleMarker,
    ];
    return RuntimeForm._(
      _text(wire['runtimeId']),
      _text(wire['schemaVersion']),
      fields,
      sources,
      _map(wire['values']),
      caps,
      wire['revision'] is String && (wire['revision'] as String).isNotEmpty
          ? wire['revision'] as String
          : null,
      keep,
      protocolVersion: protocolVersion,
      editing: wire['values'] is Map,
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

  /// Typed values only (a gateway: nothing listed) is a text box. Listed
  /// options that also take a typed value (Built-in OpenRouter, capability
  /// `dependent_select.custom_value_with_options`) is the same combobox as
  /// `select.custom_value`.
  bool freeText(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) =>
      f.kind == 'dependent_select' &&
      custom(f, sources, values) &&
      choices(f, sources, values).isEmpty;

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
      // A typed-only value starts blank; a list (custom allowed or not)
      // starts at its default.
      'dependent_select' =>
        freeText(f, sources, values)
            ? ''
            : _map(source['defaultValueByValue'])[_text(values[f.parent])] ??
                  '',
      'derived_select' => switch (selectedOption(
        f.parent!,
        sources,
        values,
      )[f.derived!['defaultAttribute']]) {
        final String fallback => fallback,
        _ => '',
      },
      _ => '',
    };
  }

  /// Whether the field is required under the current values: the
  /// unconditional `required`, or (v3) a `dataSchema.allOf` entry whose
  /// condition gives the branch that lists it (Web
  /// `isRuntimeFormV2FieldRequired`).
  bool isRequired(RuntimeField f, Map<String, dynamic> values) =>
      f.required ||
      f.requiredWhen.any(
        (entry) =>
            evaluateRuntimeFormV3Schema(entry.condition, values) == entry.when,
      );

  /// The field's option source status when it is not live
  /// (`option_source.status`); null when live or when the source says
  /// nothing. An unknown status is ignored; an unknown reason is passed on.
  RuntimeSourceStatus? sourceStatus(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
  ) {
    final source = sources[f.sourceId];
    final status = source?['status'];
    if (source == null || status != 'fallback' && status != 'unavailable') {
      return null;
    }
    final reason = source['reason'];
    final fetchedAt = source['fetchedAt'];
    return RuntimeSourceStatus(
      status: status as String,
      reason: reason is String && reason.isNotEmpty ? reason : null,
      retryable: source['retryable'] == true,
      stale: source['state'] == 'stale',
      fetchedAt:
          source['state'] == 'stale' &&
              fetchedAt is String &&
              fetchedAt.isNotEmpty
          ? fetchedAt
          : null,
    );
  }

  /// `OptionSource.unavailableOptions` entries of the field's source: values
  /// the server lists but this selection cannot use (a model the Computer
  /// listed as disabled; v3: a saved connection that is not selectable).
  List<Map<String, dynamic>> unavailableOptions(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
  ) {
    if (f.kind == 'derived_select') return const [];
    final list = sources[f.sourceId]?['unavailableOptions'];
    return list is List
        ? [
            for (final option in list.whereType<Map>())
              if (option['value'] is String &&
                  (option['value'] as String).isNotEmpty)
                _map(option),
          ]
        : const [];
  }

  /// The `unavailableOptions` entry the field's current value names, if any.
  Map<String, dynamic>? unavailableSelection(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    final value = _text(values[f.key]).trim();
    if (value.isEmpty) return null;
    for (final option in unavailableOptions(f, sources)) {
      if (option['value'] == value) return option;
    }
    return null;
  }

  /// Starting values: for edit, the agent's stored values where they fit the
  /// field's kind; otherwise each field's default. Parents come before their
  /// dependents so defaults follow the stored parent.
  ///
  /// Edit: an optional dependent_select or derived_select (a reasoning effort)
  /// with no stored string (null or absent: the agent uses the runtime
  /// default) starts at "" (Default), never at the parent's default: saving
  /// untouched must not turn Default into the model's default effort. The
  /// parent's default applies on create, and on edit only once the parent
  /// changes ([change]).
  Map<String, dynamic> initial(Map<String, Map<String, dynamic>> sources) {
    final values = <String, dynamic>{};
    for (final f in dependencyOrder) {
      values[f.key] = _storedFits(f, stored[f.key], stored.containsKey(f.key))
          ? stored[f.key]
          : editing && _keepsRuntimeDefault(f) && _parentStored(f)
          ? ''
          : defaultFor(f, sources, values);
    }
    return values;
  }

  static bool _storedFits(RuntimeField f, dynamic v, bool present) =>
      present &&
      switch (f.kind) {
        'boolean' => v is bool,
        'string_map' => v is Map && v.values.every((v) => v is String),
        'unsupported' => true,
        _ => v is String,
      };

  /// The field's parent has a stored value: the field is in effect for the
  /// agent as saved. A parent with none (a branch the saved agent is not on,
  /// e.g. Pi's "configured" model while it uses a provider) means the field
  /// does not apply, so switching to that branch starts at the parent's
  /// default, as on create.
  bool _parentStored(RuntimeField f) {
    final parent = fields.where((c) => c.key == f.parent).firstOrNull;
    return parent != null &&
        _storedFits(
          parent,
          stored[parent.key],
          stored.containsKey(parent.key),
        ) &&
        stored[parent.key] != '';
  }

  /// An optional choice field whose empty value means "the runtime's default"
  /// and whose default follows a parent.
  static bool _keepsRuntimeDefault(RuntimeField f) =>
      (f.kind == 'dependent_select' || f.kind == 'derived_select') &&
      !f.required &&
      f.requiredWhen.isEmpty;

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
    // Moving onto or off a saved-connection selection hands the
    // connection-owned fields to the connection or back to the user: either
    // way their old value must not survive the switch.
    if (connectionActive(sources, next) != connectionActive(sources, values)) {
      for (final f in fields) {
        if (f.connectionOwned) next[f.key] = defaultFor(f, sources, next);
      }
    }
    return next;
  }

  /// An option that is a saved provider connection (capability
  /// `provider.saved_connection`). Hard constraint of the contract:
  /// `value == "connection:" + connectionId`; an option that breaks it is
  /// treated as a plain option, never as a connection.
  static bool isConnectionOption(Map<String, dynamic> option) {
    final id = option['connectionId'];
    return id is String && id.isNotEmpty && option['value'] == 'connection:$id';
  }

  /// The selected option of a select field when it is a saved provider
  /// connection; null for any other selection or field.
  Map<String, dynamic>? selectedConnection(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    if (f.kind != 'select') return null;
    final option = selectedOption(f.key, sources, values);
    return isConnectionOption(option) ? option : null;
  }

  /// True while any field holds a saved-connection selection: the
  /// connection-owned fields are disabled, not required and not submitted.
  bool connectionActive(
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) => fields.any((f) => selectedConnection(f, sources, values) != null);

  /// The values a visibility rule sees for [key]: the raw one, plus, for a
  /// saved-connection selection, the connection's underlying provider id. A
  /// gateway connection keeps driving the gateway fields: they stay visible
  /// (as disabled managed fields) instead of vanishing with the raw
  /// `connection:<id>` value.
  List<String> _visibilityValues(
    String key,
    Map<String, dynamic> values,
    Map<String, Map<String, dynamic>>? sources,
  ) {
    final raw = _text(values[key]);
    if (sources == null) return [raw];
    for (final source in sources.values) {
      if (source['pointer'] != '/$key' || source['options'] is! List) continue;
      for (final option in (source['options'] as List).whereType<Map>()) {
        if (option['value'] != raw) continue;
        final underlying = option['underlyingProviderId'];
        return underlying is String && underlying.isNotEmpty
            ? [raw, underlying]
            : [raw];
      }
      return [raw];
    }
    return [raw];
  }

  /// `writeOnlyKeepRequiresUnchanged` comparison: as strings, trimmed,
  /// trailing slashes removed.
  static String _boundValue(dynamic value) =>
      (value is String ? value : (value ?? '').toString()).trim().replaceAll(
        RegExp(r'/+$'),
        '',
      );

  /// Edit: a blank secret cannot keep the stored value because a visible field
  /// it is bound to was changed. A connection-owned secret never needs one (the
  /// connection owns the credential).
  bool secretReentryRequired(
    RuntimeField f,
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values,
  ) {
    if (f.kind != 'secret' || _text(values[f.key]).trim().isNotEmpty) {
      return false;
    }
    if (!visible(f, values, sources)) return false;
    if (connectionActive(sources, values) && f.connectionOwned) return false;
    return (keepRequiresUnchanged[f.key] ?? const []).any((name) {
      final bound = fields
          .where((candidate) => candidate.key == name)
          .firstOrNull;
      return bound != null &&
          visible(bound, values, sources) &&
          _boundValue(values[name]) != _boundValue(stored[name]);
    });
  }

  bool unavailable(RuntimeField f, Map<String, Map<String, dynamic>> sources) =>
      sources[f.sourceId]?['status'] == 'unavailable';

  /// Hidden but kept: an optional field whose source is unavailable, or an
  /// optional dependent_select whose parent value has no key in its loaded
  /// source (v3 reasoning effort for a typed or effort-less model). Its value
  /// is kept: never reset, and on edit the stored one is submitted unchanged.
  /// A required one stays to show why it blocks.
  bool hiddenAsUnavailable(
    RuntimeField f,
    Map<String, dynamic> values,
    Map<String, Map<String, dynamic>>? sources,
  ) {
    if (sources == null || isRequired(f, values)) return false;
    if (unavailable(f, sources)) return true;
    if (f.kind != 'dependent_select') return false;
    final source = sources[f.sourceId];
    if (source == null) return false;
    final parent = _text(values[f.parent]);
    return !_map(source['optionsByValue']).containsKey(parent) &&
        !_map(source['customValueAllowedByValue']).containsKey(parent);
  }

  /// Visibility rules (v2 `visibility`, v3 `rules`), plus (when [sources] is
  /// given) `option_source.status`: an optional field whose source is
  /// unavailable is hidden, and so is an optional dependent_select whose
  /// parent value has no key in its source.
  bool visible(
    RuntimeField f,
    Map<String, dynamic> values, [
    Map<String, Map<String, dynamic>>? sources,
  ]) {
    final rule = f.rule;
    if (rule != null && rule.condition.evaluate(values) != rule.show) {
      return false;
    }
    if (hiddenAsUnavailable(f, values, sources)) return false;
    return f.visibility.every(
      (r) => _visibilityValues(
        r['key'] as String,
        values,
        sources,
      ).any((candidate) => (r['in'] as List).contains(candidate)),
    );
  }

  /// Renderer convention (no contract key): the Advanced section starts open
  /// when any visible field in it has a non-blank value (a non-blank string,
  /// a non-empty map, or `true`), so a value in effect is never collapsed out
  /// of sight. Clients open it when this turns true (on edit, or once a value
  /// is set) and let the user collapse it afterwards.
  bool advancedStartsOpen(
    Map<String, dynamic> values, [
    Map<String, Map<String, dynamic>>? sources,
  ]) => fields.any((f) {
    if (!f.advanced || !visible(f, values, sources)) return false;
    final value = values[f.key];
    return switch (value) {
      final String text => text.trim().isNotEmpty,
      final Map map => map.isNotEmpty,
      _ => value == true,
    };
  });

  Map<String, String> validate(
    Map<String, Map<String, dynamic>> sources,
    Map<String, dynamic> values, {
    bool editing = false,
  }) {
    final errors = <String, String>{};
    if (!supported) return {'form': 'unsupported_capabilities'};
    final connected = connectionActive(sources, values);
    for (final f in fields) {
      if (!visible(f, values, sources)) continue;
      if (f.kind == 'unsupported') {
        if (f.required) errors[f.key] = 'unsupported_required';
        continue;
      }
      // A bound-but-unavailable connection stays visible and blocks the
      // save: the binding is never silently rewritten.
      if (connected &&
          selectedConnection(f, sources, values)?['unavailable'] == true) {
        errors[f.key] = 'connection_unavailable';
        continue;
      }
      final required = isRequired(f, values);
      if (required && unavailable(f, sources)) {
        errors[f.key] = 'source_unavailable';
        continue;
      }
      final isSelect = const [
        'select',
        'dependent_select',
        'derived_select',
      ].contains(f.kind);
      final typedOnly = freeText(f, sources, values);
      final strictSelect =
          isSelect && !typedOnly && !custom(f, sources, values);
      // A value that is an unavailable entry blocks, unless the source takes
      // typed values: then it is accepted as typed, as before.
      if (strictSelect && unavailableSelection(f, sources, values) != null) {
        errors[f.key] = 'option_unavailable';
        continue;
      }
      final text = _text(values[f.key]).trim();
      // While a saved connection is selected, the fields it owns are not the
      // user's to fill: not required and not submitted.
      final ownedNow = connected && f.connectionOwned;
      if (editing && secretReentryRequired(f, sources, values)) {
        errors[f.key] = 'secret_reentry_required';
        continue;
      }
      if (required &&
          !(editing && f.kind == 'secret') &&
          !ownedNow &&
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
          !RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) {
        errors[f.key] = 'invalid_url';
      }
      if (strictSelect) {
        final list = choices(f, sources, values);
        if (!(f.kind == 'derived_select' && list.isEmpty) &&
            text.isNotEmpty &&
            !list.any((o) => o['value'] == text)) {
          errors[f.key] = 'not_a_choice';
        }
      }
    }
    return errors;
  }

  Map<String, dynamic> submission(
    Map<String, dynamic> values,
    Map<String, Map<String, dynamic>> sources,
  ) {
    final out = <String, dynamic>{};
    final connected = connectionActive(sources, values);
    for (final f in fields) {
      // Connection-owned fields never enter formValues while a saved
      // connection is selected, not even as empty strings: the server refuses
      // any value for them (`connection_field_forbidden`).
      if (connected && f.connectionOwned) continue;
      if (hiddenAsUnavailable(f, values, sources)) {
        if (stored.containsKey(f.key)) out[f.key] = stored[f.key];
        continue;
      }
      if (f.kind != 'unsupported' && !visible(f, values, sources)) continue;
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

/// One piece of a runtime-form hint: plain [text], or a link ([href] set).
class RuntimeFormHintPart {
  const RuntimeFormHintPart(this.text, [this.href]);
  final String text;

  /// An absolute https URL without credentials; null for plain text.
  final String? href;
}

final _hintLink = RegExp(r'\[([^\[\]\n]+)\]\(([^()\s]+)\)');

String? _httpsHref(String raw) {
  if (!raw.startsWith('https://')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.toString();
}

/// Hints are server copy (`uiSchema.localization.<field>.hint`). The one
/// markup they may carry is an inline Markdown link `[text](https://...)`; a
/// target that is not an absolute https URL without credentials (or is
/// malformed) stays plain text. Adjacent text is merged (Web
/// `parseRuntimeFormV2Hint`).
List<RuntimeFormHintPart> parseRuntimeFormHint(String hint) {
  final parts = <RuntimeFormHintPart>[];
  void pushText(String text) {
    if (text.isEmpty) return;
    if (parts.isNotEmpty && parts.last.href == null) {
      parts[parts.length - 1] = RuntimeFormHintPart(parts.last.text + text);
    } else {
      parts.add(RuntimeFormHintPart(text));
    }
  }

  var cursor = 0;
  for (final match in _hintLink.allMatches(hint)) {
    pushText(hint.substring(cursor, match.start));
    final href = _httpsHref(match.group(2)!);
    if (href != null) {
      parts.add(RuntimeFormHintPart(match.group(1)!, href));
    } else {
      pushText(match.group(0)!);
    }
    cursor = match.end;
  }
  pushText(hint.substring(cursor));
  return parts;
}
