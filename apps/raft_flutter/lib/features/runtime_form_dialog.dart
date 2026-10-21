import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart' show WorkspaceEntityKind;
import 'private_route_guard.dart';
import 'create_agent_dialog.dart';
import 'management_support.dart' show managementMap, managementRows;
import 'provider_edit_dialog.dart';
import 'runtime_form_status_copy.dart';

/// Web `runtimeFormUnavailableMessageId`: the catalog message for a failed
/// form-definition read. The server's own text is never shown here; the
/// failure `code` picks the Built-in copy, anything else is the refresh hint.
String runtimeFormLoadErrorText(Object error) {
  final code = error is RaftApiException ? error.details['code'] : null;
  logUserError(error, where: 'runtime form definition');
  return switch (code) {
    'builtin_catalog_capability_required' => 'This Computer is too old to verify Built-in models. Your saved selection is preserved; update Raft Computer before changing it.',
    'builtin_catalog_unavailable' || 'builtin_catalog_stale' => 'Built-in models cannot be verified right now. Your saved selection is preserved; reconnect this Computer and retry.',
    _ => 'Runtime configuration is unavailable. Refresh and try again.',
  };
}

/// `Accept-Language` for the form reads: the app's display language (what the
/// UI is showing), not the system's. Web `htmlLangForLocale`.
String runtimeFormLanguageTag(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh' ? 'zh-CN' : 'en';

/// 409 `form_revision_stale` (`recovery: refetch_form`): the server's form
/// build moved on since this form was fetched; refetch the whole form and
/// never merge options across builds.
bool isFormRevisionStale(Object error) =>
    error is RaftApiException && error.details['code'] == 'form_revision_stale';

/// Web CreateAgentDialog / AgentDetailPanel `issues` handling: every issue whose
/// pointer is `/formValues/<key>` marks that field with the server's error text
/// (else the issue code).
Map<String, String> runtimeFormIssueErrors(Object error, {String? fallback}) {
  if (error is! RaftApiException) return const {};
  final issues = error.details['issues'];
  if (issues is! List) return const {};
  final text = userErrorText(error, fallback: fallback, where: 'form issues');
  const prefix = '/formValues/';
  return {
    for (final issue in issues)
      if (issue is Map &&
          issue['pointer'] is String &&
          (issue['pointer'] as String).startsWith(prefix) &&
          (issue['pointer'] as String).length > prefix.length)
        (issue['pointer'] as String).substring(prefix.length): text,
  };
}

typedef _FetchedForm = ({
  RuntimeForm form,
  Set<String> advanced,
  Map<String, Map<String, dynamic>> sources,
});

/// Protocol-v2 runtime form state for one computer + runtime (create) or one
/// agent (edit). Shared by [RuntimeFormDialog] and the create-agent dialog.
class RuntimeFormController extends ChangeNotifier {
  RuntimeFormController(
    this.w, {
    required this.machineId,
    required this.runtimeId,
    this.agentId,
    required this.valid,
    this.language,
  });
  final WorkspaceController w;
  final String machineId, runtimeId;
  final String? agentId;

  /// The app's display language as a BCP 47 tag (`en`, `zh-CN`), sent as
  /// `Accept-Language` on every form read: the server writes the field labels,
  /// hints and generic option names in it. Never the system language.
  String? language;

  /// Whether results may still be applied (authority unchanged, still mounted).
  final bool Function() valid;
  bool get editing => agentId != null;
  late final base =
      '/servers/${w.server!.id}/machines/$machineId/runtime-forms/v2/${Uri.encodeComponent(runtimeId)}';
  RuntimeForm? definition;

  /// `uiSchema.layout.advanced` keys: rendered behind the MORE disclosure.
  Set<String> advanced = {};
  Map<String, Map<String, dynamic>> sources = {};
  Map<String, dynamic> values = {};

  /// The values as loaded (edit): what "changed" is measured against.
  Map<String, dynamic> initialValues = {};
  Map<String, String> validation = {};

  /// Field messages from a failed save (server `issues`), keyed by field.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when any field value changes; the controller is disposed with the dialog.
  Map<String, String> serverErrors = {};
  final mapProblems = <String, String>{};
  final editors = <String, TextEditingController>{};
  bool loading = true, disposed = false;

  /// Bumped on every whole-form (re)install: a response that belongs to an
  /// earlier generation (a retry still in flight across a reload) is dropped
  /// instead of being merged into the newer form.
  int _generation = 0;

  /// Whole-form refetches caused by a stale revision after the form was
  /// installed (the first load has its own single attempt).
  int _staleReloads = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- Controller load error: cleared when load restarts (Try again) or completes; dialog submit error: cleared when the next submit starts; both are disposed with the dialog.
  String? error;
  final retrying = <String>{};

  @override
  void dispose() {
    disposed = true;
    for (final e in editors.values) {
      e.dispose();
    }
    super.dispose();
  }

  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<dynamic> _read(String path, {Map<String, dynamic>? query}) {
    final tag = language;
    return tag == null
        ? w.query(path, query: query)
        : RaftClient.runWithHeaders({
            'Accept-Language': tag,
          }, () => w.query(path, query: query));
  }

  /// The display language changed: the form's copy is the server's, so the
  /// form is fetched again (the user's values are kept).
  Future<void> useLanguage(String tag) async {
    final before = language;
    language = tag;
    if (before == null || before == tag || disposed) return;
    if (definition == null && !loading) return;
    final draft = _draft();
    _generation++;
    definition = null;
    await load(seed: draft);
  }

  Future<Map<String, dynamic>> source(
    String id, {
    bool refresh = false,
    RuntimeForm? form,
  }) async {
    final owner = (form ?? definition)!;
    // A revisioned form echoes its token: the server answers within the
    // capability range the form declared, or says the form is stale. An
    // unrevisioned form keeps the plain direct-option protocol.
    final query = <String, dynamic>{
      if (refresh) 'refresh': 1,
      'formRevision': ?owner.revision,
    };
    try {
      return Map<String, dynamic>.from(
        await _read(
          '$base/option-sources/${Uri.encodeComponent(id)}',
          query: query.isEmpty ? null : query,
        ),
      );
    } catch (e) {
      // A stale revision always propagates: the caller refetches the form.
      if (isFormRevisionStale(e) ||
          !owner.capabilities.contains('option_source.status')) {
        rethrow;
      }
      return {
        ...owner.sourceRefs[id]!,
        'status': 'unavailable',
        'retryable': true,
        'options': [],
      };
    }
  }

  /// Fetches the form and all its option sources: one consistent build. A
  /// source answering 409 `form_revision_stale` fails the fetch with that
  /// error (see [isFormRevisionStale]).
  Future<_FetchedForm> _fetch() async {
    final raw = await _read(editing ? '/agents/$agentId/runtime-form' : base);
    final form = RuntimeForm.parse(raw);
    if (form == null || !form.supported) {
      throw const RaftApiException(
        'This runtime form needs a newer client. It cannot be edited safely.',
      );
    }
    final layout = raw is Map && raw['uiSchema'] is Map
        ? (raw['uiSchema'] as Map)['layout']
        : null;
    final advanced = {
      if (layout is Map && layout['advanced'] is List)
        for (final p in layout['advanced'] as List)
          if (p is String && p.startsWith('/')) p.substring(1),
    };
    final loaded = await Future.wait([
      for (final id in form.sourceRefs.keys) source(id, form: form),
    ]);
    return (
      form: form,
      advanced: advanced,
      sources: Map.fromIterables(form.sourceRefs.keys, loaded),
    );
  }

  /// Loads the definition and its option sources. [seed] pre-fills values the
  /// user already chose before the runtime was known (e.g. env vars).
  ///
  /// The form may go stale between its own fetch and its option sources (the
  /// server's build changed, e.g. a feature flag flipped): the whole form is
  /// then fetched once more; a second stale answer is a form-level error.
  Future<void> load({Map<String, dynamic> seed = const {}}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      _FetchedForm fetched;
      try {
        fetched = await _fetch();
      } catch (e) {
        if (!isFormRevisionStale(e)) rethrow;
        if (disposed || !valid() || generation != _generation) return;
        fetched = await _fetch();
      }
      final (:form, advanced: nextAdvanced, sources: nextSources) = fetched;
      if (disposed || !valid() || generation != _generation) return;
      // Publish the definition only together with its sources, values and
      // editors: the fields render whenever `definition` is set, and any
      // rebuild in between (the dialog's entrance animation ticks every
      // frame while option sources load) would find no editor for a field.
      var nextValues = form.initial(nextSources);
      for (final entry in seed.entries) {
        final f = form.fields.where((f) => f.key == entry.key).firstOrNull;
        if (f != null) {
          nextValues = form.change(nextSources, nextValues, f.key, entry.value);
        }
      }
      for (final f in form.fields) {
        if (!['boolean', 'unsupported'].contains(f.kind)) {
          editors[f.key]?.dispose();
          editors[f.key] = TextEditingController(
            text: valueText(f, nextValues[f.key]),
          );
        }
      }
      definition = form;
      advanced = nextAdvanced;
      sources = nextSources;
      values = nextValues;
      initialValues = jsonDecode(jsonEncode(values)) as Map<String, dynamic>;
      loading = false;
      _notify();
    } catch (e) {
      if (disposed || generation != _generation) return;
      // Nothing may be edited or submitted against a form that failed to load
      // consistently.
      definition = null;
      loading = false;
      error = runtimeFormLoadErrorText(e);
      _notify();
    }
  }

  /// The user's current values in dependency order, to survive a refetch.
  Map<String, dynamic> _draft() => {
    for (final f in definition?.dependencyOrder ?? const <RuntimeField>[])
      if (values.containsKey(f.key)) f.key: values[f.key],
  };

  /// A source answered 409 `form_revision_stale`: the form in hand is
  /// known-stale. Drop to loading, so nothing can be edited or submitted
  /// against it, and refetch the whole form once (the user's values are kept);
  /// a second stale answer is a form-level error. Returns false for any other
  /// error.
  Future<bool> _recoverFromStale(Object e) async {
    if (!isFormRevisionStale(e)) return false;
    if (_staleReloads < 1) {
      _staleReloads++;
      final draft = _draft();
      // Retire every callback from this form before starting recovery.
      _generation++;
      definition = null;
      await load(seed: draft);
    } else {
      _generation++;
      definition = null;
      loading = false;
      error = runtimeFormLoadErrorText(e);
      _notify();
    }
    return true;
  }

  String valueText(RuntimeField field, dynamic value) =>
      field.kind == 'string_map' && value is Map
      ? value.entries.map((e) => '${e.key}=${e.value}').join('\n')
      : value is String
      ? value
      : '';

  void change(RuntimeField f, dynamic value) {
    final next = definition!.change(sources, values, f.key, value);
    for (final other in definition!.fields) {
      if (other.key != f.key &&
          next[other.key] != values[other.key] &&
          editors.containsKey(other.key)) {
        editors[other.key]!.text = valueText(other, next[other.key]);
      }
    }
    values = next;
    validation = {};
    serverErrors = {};
    _notify();
  }

  void changeText(RuntimeField f, String v) {
    if (f.kind == 'string_map') {
      try {
        final map = parseRuntimeStringMap(v);
        mapProblems.remove(f.key);
        change(f, map);
      } on FormatException {
        mapProblems[f.key] = 'invalid_map';
        validation = {...validation, f.key: 'invalid_map'};
        _notify();
      }
    } else {
      change(f, v);
    }
  }

  /// Marks [key] with [message] (a failure that belongs to that field).
  void failField(String key, String message) {
    serverErrors = {...serverErrors, key: message};
    _notify();
  }

  Future<void> retry(String id) async {
    if (!retrying.add(id)) return;
    final generation = _generation;
    _notify();
    try {
      final next = await source(id, refresh: true);
      if (disposed || !valid() || generation != _generation) return;
      sources[id] = next;
    } catch (e) {
      if (disposed || generation != _generation) return;
      if (!await _recoverFromStale(e)) rethrow;
    } finally {
      retrying.remove(id);
      _notify();
    }
  }

  /// Re-requests every option source of the current form (without a probe
  /// refresh), e.g. after a saved provider was edited: the connection labels
  /// and availability come from the server on each request. The user's values
  /// stay as they are.
  Future<void> refreshSources() async {
    final form = definition;
    if (form == null) return;
    final generation = _generation;
    try {
      final ids = form.sourceRefs.keys.toList();
      final loaded = await Future.wait([for (final id in ids) source(id)]);
      if (disposed || !valid() || generation != _generation) return;
      sources = {...sources, ...Map.fromIterables(ids, loaded)};
      _notify();
    } catch (e) {
      if (disposed || generation != _generation) return;
      // Anything else leaves the sources already shown in place.
      await _recoverFromStale(e);
    }
  }

  /// Keys whose value differs from the loaded one.
  Set<String> get changedKeys => {
    for (final key in {...values.keys, ...initialValues.keys})
      if (jsonEncode(values[key]) != jsonEncode(initialValues[key])) key,
  };
  bool get valuesChanged => changedKeys.isNotEmpty;

  /// Field problems (empty when submittable); stores them for display.
  Map<String, String> validate() {
    final problems = definition!.validate(sources, values, editing: editing);
    for (final f in definition!.fields) {
      if (definition!.visible(f, values, sources) &&
          mapProblems.containsKey(f.key)) {
        problems[f.key] = mapProblems[f.key]!;
      }
    }
    validation = problems;
    _notify();
    return problems;
  }

  /// Edit: a blank API key can no longer keep the stored one because a field
  /// it is bound to changed. Save stays disabled until a new key is entered.
  bool get reentryBlocked {
    final form = definition;
    return editing &&
        form != null &&
        form.fields.any((f) => form.secretReentryRequired(f, sources, values));
  }

  bool reentryRequired(RuntimeField f) =>
      editing && definition?.secretReentryRequired(f, sources, values) == true;

  /// Required values still missing (Web: Create stays disabled, no error).
  bool get missingRequired {
    if (definition == null) return true;
    return definition!
        .validate(sources, values, editing: editing)
        .values
        .any((code) => code == 'required' || code == 'source_unavailable');
  }

  Map<String, dynamic> get submission => {
    'formDefinitionRef': {'protocolVersion': 2, 'runtimeId': runtimeId},
    'formValues': definition!.submission(values, sources),
  };
}

String? runtimeFieldError(BuildContext context, String? code) => switch (code) {
  'required' => raftText(context, 'This field is required.'),
  'invalid_map' => raftText(context, 'Enter one unique KEY=value per line.'),
  // The field's source status line already says why, with its retry.
  'source_unavailable' => null,
  'invalid_url' => raftText(
    context,
    'Base URL must start with http:// or https://.',
  ),
  'not_a_choice' => raftText(context, 'Choose one of the available options.'),
  'secret_reentry_required' => raftText(
    context,
    'The API key is tied to the saved settings you changed. Enter a new one.',
  ),
  'connection_unavailable' => raftText(
    context,
    'This saved provider is unavailable. Select another provider.',
  ),
  'unsupported_required' => raftText(
    context,
    'Update Raft to edit this setting.',
  ),
  _ => null,
};

/// The v2 fields as StableField rows (Web RuntimeFormV2Fields); advanced
/// layout fields sit behind the MORE disclosure.
class RuntimeFormFields extends StatefulWidget {
  const RuntimeFormFields({
    super.key,
    required this.form,
    this.busy = false,
    this.leading = const [],
    this.hideAdvanced = false,
    this.rowGap = raftAgentFormGap,
  });
  final RuntimeFormController form;
  final bool busy;
  final bool hideAdvanced;
  final double rowGap;

  /// Rows rendered before the runtime fields (same rhythm).
  final List<Widget> leading;
  @override
  State<RuntimeFormFields> createState() => _RuntimeFormFieldsState();
}

class _RuntimeFormFieldsState extends State<RuntimeFormFields> {
  bool moreOpen = false;
  RuntimeFormController get c => widget.form;

  bool editingProvider = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tag = runtimeFormLanguageTag(context);
    if (c.language == null) {
      c.language = tag;
    } else if (c.language != tag) {
      // The language switched under an open form: its copy is the server's,
      // so it is fetched again (after this build; the user's values stay).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(c.useLanguage(tag));
      });
    }
  }

  /// Web `savedConnections.onEdit`: the selected connection's edit dialog.
  /// Saving refreshes the option sources, so the field shows its new name.
  Future<void> editSavedProvider(String fieldKey, String connectionId) async {
    if (editingProvider || !c.valid()) return;
    editingProvider = true;
    try {
      final catalog = managementMap(
        await c.w.client.get('/provider-connections'),
      );
      if (!mounted || !c.valid()) return;
      final connection = managementRows(catalog['connections'])
          .where((row) => row['id'] == connectionId)
          .firstOrNull;
      if (connection == null) return;
      final gateway = managementRows(catalog['providerOptions']).any(
        (option) =>
            option['id'] == connection['providerId'] &&
            option['providerKind'] == 'gateway',
      );
      await showRaftForm<bool>(
        context,
        builder: (_) => EditProviderConnectionDialog(
          controller: c.w,
          connection: connection,
          gateway: gateway,
          onCompleted: c.refreshSources,
        ),
      );
    } catch (e) {
      if (mounted) {
        c.failField(
          fieldKey,
          userErrorText(
            e,
            fallback: 'The provider connection could not be updated.',
            where: 'edit saved provider',
          ),
        );
      }
    } finally {
      editingProvider = false;
    }
  }

  Widget field(RuntimeField f) {
    final d = c.definition!;
    final choices = d.choices(f, c.sources, c.values),
        custom = d.custom(f, c.sources, c.values);
    final source = c.sources[f.sourceId];
    final status = source?['status'], sourceReason = source?['reason'];
    if (f.kind == 'derived_select' && choices.isEmpty) {
      return const SizedBox.shrink();
    }
    if (f.kind == 'unsupported' && !f.required) return const SizedBox.shrink();
    // Saved provider connections (`provider.saved_connection`): a field the
    // selected connection owns is the connection's, not the user's. Disabled,
    // "Provided by ...", never required, never submitted.
    final connected = d.connectionActive(c.sources, c.values);
    final ownedNow = connected && f.connectionOwned;
    final selectedConnection = d.selectedConnection(f, c.sources, c.values);
    final managed = ownedNow ? managedPlaceholder(d) : null;
    final serverError = c.serverErrors[f.key];
    // Edit: a blank secret keeps the stored one, unless a field it is bound to
    // changed; then a new one is required, said at once (Save is disabled).
    final reentry = c.reentryRequired(f);
    final secretKept = c.editing && f.kind == 'secret' && !reentry;
    final error =
        (serverError == null || serverError.isEmpty
            ? null
            : raftText(context, serverError)) ??
        (reentry
            ? runtimeFieldError(context, 'secret_reentry_required')
            : runtimeFieldError(context, c.validation[f.key]));
    final hint = ownedNow
        ? managed
        : secretKept
        ? 'Leave blank to keep the saved value.'
        : f.kind == 'string_map'
        ? 'One KEY=value per line.'
        : f.copy['hint'] as String?;
    // Web `RuntimeFormV2FieldControl`: a list the server describes is searched
    // in a combobox (a field that takes typed text too); only a derived list
    // (reasoning effort) is a plain select, and a dependent field whose
    // current parent takes free text is a plain text input.
    final searchable =
        f.kind == 'select' || (f.kind == 'dependent_select' && !custom);
    // A stored value the current list no longer offers (a retired model, a
    // removed connection) stays selected, marked, until another is picked.
    final text = c.values[f.key] is String ? c.values[f.key] as String : '';
    final unlisted =
        searchable &&
        text.isNotEmpty &&
        !choices.any((o) => o['value'] == text);
    final Widget control;
    if (f.kind == 'boolean') {
      control = Align(
        alignment: Alignment.centerLeft,
        child: RaftSwitch(
          value: c.values[f.key] == true,
          semanticLabel: raftText(context, f.label),
          onChanged: widget.busy || ownedNow ? null : (v) => c.change(f, v),
        ),
      );
    } else if (f.kind == 'unsupported') {
      control = Text(raftText(context, 'Update Raft to edit this setting.'));
    } else if (f.kind == 'derived_select') {
      control = RaftAgentSelect<String>(
        key: ValueKey('runtime-${f.key}'),
        semanticLabel: raftText(context, f.label),
        value: choices.any((o) => o['value'] == c.values[f.key])
            ? c.values[f.key] as String
            : '',
        invalid: error != null,
        placeholder: f.copy['placeholder'] as String? ?? 'Select...',
        options: [
          RaftAgentSelectOption('', raftText(context, 'Default')),
          for (final o in choices)
            RaftAgentSelectOption(o['value'] as String, '${o['label']}'),
        ],
        onChanged: widget.busy ? null : (v) => c.change(f, v),
      );
    } else if (searchable) {
      control = RaftAgentCombobox(
        key: ValueKey('runtime-${f.key}'),
        label: f.label,
        semanticLabel: raftText(context, f.label),
        value: text,
        invalid: error != null,
        placeholder: f.copy['placeholder'] as String? ?? 'Select...',
        enabled: !widget.busy,
        items: [
          if (unlisted)
            RaftComboboxItem(
              text,
              text,
              description: raftText(context, 'Not in the current list'),
            ),
          for (final o in choices)
            RaftComboboxItem(
              '${o['value']}',
              '${o['label']}',
              description: o['description'] as String?,
              hint: '${o['value']}',
              keywords: '${o['value']}',
              group: runtimeOptionGroup(context, o),
              enabled: o['unavailable'] != true,
            ),
        ],
        onSelected: (id) => c.change(f, id),
        // A field that takes typed text offers the typed value as is.
        customLabel: custom
            ? (typed) => raftFormat(context, 'Use “{value}”', {'value': typed})
            : null,
        onCustom: custom ? (typed) => c.change(f, typed) : null,
      );
    } else {
      control = RaftAgentTextInput(
        key: ValueKey('runtime-${f.key}'),
        // ignore: raft_lints/avoid_render_index_assertion -- load() publishes definition and editors in one synchronous block (test/runtime_form_loading_test.dart); boolean and unsupported fields are branched out earlier.
        controller: c.editors[f.key]!,
        semanticLabel: raftText(context, f.label),
        placeholder: managed ?? f.copy['placeholder'] as String?,
        enabled: !widget.busy && !ownedNow,
        invalid: error != null,
        obscure: f.kind == 'secret',
        multiline: f.kind == 'string_map',
        onChanged: (v) => c.changeText(f, v),
      );
    }
    final connectionId = selectedConnection?['connectionId'] as String?;
    return RaftStableField(
      label: f.label,
      required: f.required && f.kind != 'boolean' && !ownedNow && !secretKept,
      hint: hint,
      error: error,
      // The pencil for the selected saved connection: operators who manage
      // provider connections only (Web `capabilities.manageExternalAuth`).
      labelAccessory: connectionId != null && c.w.can('manageExternalAuth')
          ? RaftInlineIconButton(
              key: ValueKey('runtime-${f.key}-edit-provider'),
              glyph: RaftGlyph.pencil,
              tooltip: 'Edit saved provider',
              size: 14,
              onPressed: widget.busy
                  ? null
                  : () => editSavedProvider(f.key, connectionId),
            )
          : null,
      belowControl: [
        if (unlisted)
          RaftAgentFieldNote(
            raftFormat(
              context,
              'The saved value {value} is not in the current list. It stays selected until you pick another.',
              {'value': text},
            ),
          ),
        if (status == 'fallback' || status == 'unavailable')
          RaftAgentSourceStatus(
            message: runtimeSourceStatusText(
              context,
              status: status as String,
              reason: sourceReason,
            ),
            retryLabel: source?['retryable'] == true ? 'Retry' : null,
            onRetry: widget.busy || c.retrying.contains(f.sourceId)
                ? null
                : () => c.retry(f.sourceId!),
          ),
      ],
      child: control,
    );
  }

  /// "Provided by ..." for the fields the selected saved connection owns.
  String managedPlaceholder(RuntimeForm d) {
    final option = d.fields
        .map((f) => d.selectedConnection(f, c.sources, c.values))
        .nonNulls
        .firstOrNull;
    return raftFormat(context, 'Provided by “{connection}”', {
      'connection':
          option?['label'] ??
          raftText(
            context,
            'This saved provider is unavailable. Select another provider.',
          ),
    });
  }

  /// Option `group` (`provider.saved_connection`): saved connections first,
  /// then direct setup.
  String? runtimeOptionGroup(BuildContext context, Map<String, dynamic> o) =>
      switch (o['group']) {
        'saved' => raftText(context, 'Saved providers'),
        'direct' => raftText(context, 'Direct setup'),
        _ => null,
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final d = c.definition;
      final visible = d == null
          ? const <RuntimeField>[]
          : [
              for (final f in d.fields)
                if (d.visible(f, c.values, c.sources)) f,
            ];
      final basic = [
        for (final f in visible)
          if (!c.advanced.contains(f.key)) field(f),
      ];
      final more = [
        for (final f in visible)
          if (c.advanced.contains(f.key)) field(f),
      ];
      final rows = [
        ...widget.leading,
        ...basic,
        if (more.isNotEmpty && !widget.hideAdvanced)
          RaftAgentMoreDisclosure(
            open: moreOpen,
            onToggle: () => setState(() => moreOpen = !moreOpen),
            children: more,
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) SizedBox(height: widget.rowGap),
            row,
          ],
        ],
      );
    },
  );
}

/// Runtime form for an existing agent (edit), or the mounted Cindy onboarding
/// screen. Both use the same authority-fenced protocol-v2 fields.
class RuntimeFormDialog extends StatefulWidget {
  const RuntimeFormDialog({
    super.key,
    required this.controller,
    required this.machineId,
    required this.runtimeId,
    this.agentId,
    this.onboarding = false,
    this.onSwitchServer,
    this.onCreated,
    this.initialName,
    this.initialDescription,
    this.actionCardMessageId,
    this.actionCardConfirmationVersion,
  });
  final WorkspaceController controller;
  final String machineId, runtimeId;
  final String? agentId;
  final bool onboarding;
  final VoidCallback? onSwitchServer;
  final String? initialName, initialDescription, actionCardMessageId;
  final int? actionCardConfirmationVersion;
  final void Function(Map<String, dynamic>)? onCreated;
  @override
  State<RuntimeFormDialog> createState() => _RuntimeFormDialogState();
}

class _RuntimeFormDialogState extends State<RuntimeFormDialog> {
  WorkspaceController get w => widget.controller;
  late final int generation;
  late final String openingAuthority;
  bool get currentAuthority =>
      mounted &&
      generation == w.client.generation &&
      openingAuthority == workspaceAuthority(w) &&
      w.can(editing ? 'editAgents' : 'createAgents');
  late final RuntimeFormController form = RuntimeFormController(
    w,
    machineId: widget.machineId,
    runtimeId: widget.runtimeId,
    agentId: widget.agentId,
    valid: () => currentAuthority,
  );
  final name = TextEditingController(), description = TextEditingController();
  List<Map<String, dynamic>>? onboardingMachines;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the machines load succeeds (Try again re-runs it); the dialog state is dropped when it closes.
  String? onboardingLoadError;
  bool busy = false, nameMissing = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Controller load error: cleared when load restarts (Try again) or completes; dialog submit error: cleared when the next submit starts; both are disposed with the dialog.
  String? error;
  bool get editing => widget.agentId != null;
  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    openingAuthority = workspaceAuthority(w);
    name.text = widget.initialName ?? '';
    description.text = widget.initialDescription ?? '';
    if (widget.onboarding) {
      name.text = 'Cindy';
      description.text = 'Onboarding Assistant';
    }
    if (widget.onboarding) {
      // The directory's computers paint at once; the read revalidates them.
      if (w.services.entityDirectory
          .state(WorkspaceEntityKind.computers)
          .loaded) {
        onboardingMachines = w.services.entityDirectory.rows(
          WorkspaceEntityKind.computers,
        );
      }
      loadOnboardingMachines();
    }
  }

  bool formLoadStarted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first read needs the display language, which is not available in
    // initState.
    if (formLoadStarted || widget.onboarding) return;
    formLoadStarted = true;
    form.language = runtimeFormLanguageTag(context);
    form.load();
  }

  Future<void> loadOnboardingMachines() async {
    try {
      final result = await w.query('/servers/${w.server!.id}/machines');
      if (!currentAuthority) return;
      final rows = result is Map ? result['machines'] : result;
      setState(() {
        onboardingLoadError = null;
        onboardingMachines = [
          for (final row in (rows is List ? rows : const []).whereType<Map>())
            Map<String, dynamic>.from(row),
        ];
      });
    } catch (e) {
      if (currentAuthority) {
        setState(
          () => onboardingLoadError = userErrorText(
            e,
            fallback: raftGenericErrorText,
            where: 'onboarding machines',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    form.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || form.definition == null || !currentAuthority) return;
    final problems = form.validate();
    final missingName = !editing && name.text.trim().isEmpty;
    setState(() => nameMissing = missingName);
    if (problems.isNotEmpty || missingName) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final created = await w.command(
        editing ? 'PATCH' : 'POST',
        editing ? '/agents/${widget.agentId}' : '/agents',
        data: {
          if (!editing) ...{
            'name': name.text.trim(),
            'description': description.text.trim(),
            'machineId': widget.machineId,
            'runtime': widget.runtimeId,
            if (widget.onboarding) 'onboarding': true,
            if (widget.onboarding) 'avatarUrl': 'pixel:mug',
            if (widget.actionCardMessageId != null)
              'actionCardMessageId': widget.actionCardMessageId,
            if (widget.actionCardConfirmationVersion != null)
              'actionCardConfirmationVersion':
                  widget.actionCardConfirmationVersion,
          },
          ...form.submission,
        },
      );
      if (mounted && currentAuthority) {
        if (!editing && created is Map) {
          widget.onCreated?.call(Map<String, dynamic>.from(created));
        }
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        // Web: `data.error ?? failedCreate` (edit: `runtimeConfigInvalid`),
        // plus a message on each field the server's `issues` point at.
        final fallback = editing
            ? 'Runtime config is invalid.'
            : 'Failed to create agent';
        setState(() {
          form.serverErrors = runtimeFormIssueErrors(e, fallback: fallback);
          error = userErrorText(
            e,
            fallback: fallback,
            where: 'agent runtime form',
          );
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onboarding) {
      return ListenableBuilder(
        listenable: w,
        builder: (context, _) {
          if (!currentAuthority) return const SizedBox.shrink();
          final machines = onboardingMachines;
          if (machines == null) {
            return RaftCindySetupScreen(
              fields: onboardingLoadError == null
                  ? const Center(child: RaftSpinner())
                  : RaftAgentBanner(
                      status: RaftAgentBannerStatus.warning,
                      description: onboardingLoadError!,
                      action: 'Try again',
                      onAction: loadOnboardingMachines,
                    ),
              onCreate: null,
            );
          }
          return CreateAgentDialog(
            controller: w,
            machines: machines,
            requiredMachineId: widget.machineId,
            initialRuntimeId: widget.runtimeId,
            onboarding: true,
            onSwitchServer: widget.onSwitchServer,
            onCreated: widget.onCreated,
            actionCardMessageId: widget.actionCardMessageId,
            actionCardConfirmationVersion: widget.actionCardConfirmationVersion,
          );
        },
      );
    }
    return PopScope(
      canPop: !busy,
      child: ListenableBuilder(
        listenable: form,
        builder: (context, _) {
          final loadError = form.error;
          return RaftAgentDialogCard(
            title: editing ? 'Edit runtime configuration' : 'Create Agent',
            onClose: busy ? null : () => Navigator.pop(context),
            children: [
              if (form.loading)
                const Center(child: RaftSpinner())
              else
                RuntimeFormFields(
                  form: form,
                  busy: busy,
                  leading: [
                    if (error != null || loadError != null)
                      RaftAgentBanner(
                        status: RaftAgentBannerStatus.warning,
                        description: (error ?? loadError)!,
                      ),
                    if (!editing && form.definition != null) ...[
                      RaftStableField(
                        label: 'Name',
                        required: true,
                        error: nameMissing
                            ? raftText(context, 'This field is required.')
                            : null,
                        hint: widget.onboarding
                            ? 'Fixed for the onboarding agent.'
                            : null,
                        child: RaftAgentTextInput(
                          controller: name,
                          readOnly: widget.onboarding,
                          invalid: nameMissing,
                          semanticLabel: raftText(context, 'Agent name'),
                        ),
                      ),
                      RaftStableField(
                        label: 'Description',
                        child: RaftAgentTextInput(
                          controller: description,
                          readOnly: widget.onboarding,
                          multiline: true,
                          semanticLabel: raftText(context, 'Description'),
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: raftAgentFormGap),
              RaftAgentDialogFooter(
                children: [
                  RaftAgentDialogButton(
                    label: 'Cancel',
                    onPressed: busy ? null : () => Navigator.pop(context),
                  ),
                  if (form.definition != null)
                    RaftAgentDialogButton(
                      label: editing ? 'Save' : 'Create Agent',
                      primary: true,
                      busy: busy,
                      onPressed: form.reentryBlocked ? null : submit,
                    )
                  else if (!form.loading)
                    RaftAgentDialogButton(
                      label: 'Try again',
                      primary: true,
                      onPressed: form.load,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
