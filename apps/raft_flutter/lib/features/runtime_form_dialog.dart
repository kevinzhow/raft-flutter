import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

/// Protocol-v2 runtime form state for one computer + runtime (create) or one
/// agent (edit). Shared by [RuntimeFormDialog] and the create-agent dialog.
class RuntimeFormController extends ChangeNotifier {
  RuntimeFormController(
    this.w, {
    required this.machineId,
    required this.runtimeId,
    this.agentId,
    required this.valid,
  });
  final WorkspaceController w;
  final String machineId, runtimeId;
  final String? agentId;

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
  Map<String, String> validation = {};
  final mapProblems = <String, String>{};
  final editors = <String, TextEditingController>{};
  bool loading = true, disposed = false;
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

  Future<Map<String, dynamic>> source(String id, {bool refresh = false}) async {
    try {
      return Map<String, dynamic>.from(
        await w.query(
          '$base/option-sources/${Uri.encodeComponent(id)}',
          query: refresh ? {'refresh': 1} : null,
        ),
      );
    } catch (_) {
      if (!definition!.capabilities.contains('option_source.status')) rethrow;
      return {
        ...definition!.sourceRefs[id]!,
        'status': 'unavailable',
        'retryable': true,
        'options': [],
      };
    }
  }

  /// Loads the definition and its option sources. [seed] pre-fills values the
  /// user already chose before the runtime was known (e.g. env vars).
  Future<void> load({Map<String, dynamic> seed = const {}}) async {
    loading = true;
    error = null;
    _notify();
    try {
      final raw = await w.query(
        editing ? '/agents/$agentId/runtime-form' : base,
      );
      final form = RuntimeForm.parse(raw);
      if (form == null || !form.supported) {
        throw const RaftApiException(
          'This runtime form needs a newer client. It cannot be edited safely.',
        );
      }
      definition = form;
      final layout = raw is Map && raw['uiSchema'] is Map
          ? (raw['uiSchema'] as Map)['layout']
          : null;
      advanced = {
        if (layout is Map && layout['advanced'] is List)
          for (final p in layout['advanced'] as List)
            if (p is String && p.startsWith('/')) p.substring(1),
      };
      final loaded = await Future.wait([
        for (final id in form.sourceRefs.keys) source(id),
      ]);
      if (disposed || !valid()) return;
      sources = Map.fromIterables(form.sourceRefs.keys, loaded);
      values = form.initial(sources);
      for (final entry in seed.entries) {
        final f = form.fields.where((f) => f.key == entry.key).firstOrNull;
        if (f != null) values = form.change(sources, values, f.key, entry.value);
      }
      for (final f in form.fields) {
        if (!['boolean', 'unsupported'].contains(f.kind)) {
          editors[f.key]?.dispose();
          editors[f.key] = TextEditingController(
            text: valueText(f, values[f.key]),
          );
        }
      }
      loading = false;
      _notify();
    } catch (e) {
      if (disposed) return;
      loading = false;
      error = '$e';
      _notify();
    }
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

  Future<void> retry(String id) async {
    if (!retrying.add(id)) return;
    _notify();
    try {
      final next = await source(id, refresh: true);
      if (disposed || !valid()) return;
      sources[id] = next;
    } finally {
      retrying.remove(id);
      _notify();
    }
  }

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

String? runtimeFieldError(BuildContext context, String? code) =>
    switch (code) {
      'required' => raftText(context, 'This field is required.'),
      'invalid_map' => raftText(context, 'Enter one unique KEY=value per line.'),
      'source_unavailable' => raftText(
        context,
        'Choices are unavailable. Retry after connecting the computer.',
      ),
      'invalid_url' => raftText(context, 'Enter an HTTP or HTTPS URL.'),
      'not_a_choice' => raftText(context, 'Select an available choice.'),
      'unsupported_required' => raftText(
        context,
        'Update the client to edit this required field.',
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
  });
  final RuntimeFormController form;
  final bool busy;

  /// Rows rendered before the runtime fields (same rhythm).
  final List<Widget> leading;
  @override
  State<RuntimeFormFields> createState() => _RuntimeFormFieldsState();
}

class _RuntimeFormFieldsState extends State<RuntimeFormFields> {
  bool moreOpen = false;
  RuntimeFormController get c => widget.form;

  Widget field(RuntimeField f) {
    final d = c.definition!;
    final choices = d.choices(f, c.sources, c.values),
        custom = d.custom(f, c.sources, c.values);
    final source = c.sources[f.sourceId];
    final status = source?['status'], sourceReason = source?['reason'];
    final choiceField = [
      'select',
      'dependent_select',
      'derived_select',
    ].contains(f.kind);
    if (f.kind == 'derived_select' && choices.isEmpty) {
      return const SizedBox.shrink();
    }
    if (f.kind == 'unsupported' && !f.required) return const SizedBox.shrink();
    final error = runtimeFieldError(context, c.validation[f.key]);
    final hint = f.kind == 'string_map'
        ? 'One KEY=value per line.'
        : f.copy['hint'] as String?;
    final Widget control;
    if (f.kind == 'boolean') {
      control = Align(
        alignment: Alignment.centerLeft,
        child: RaftSwitch(
          value: c.values[f.key] == true,
          semanticLabel: raftText(context, f.label),
          onChanged: widget.busy ? null : (v) => c.change(f, v),
        ),
      );
    } else if (f.kind == 'unsupported') {
      control = Text(
        raftFormat(context, '{field}: update the client to edit this field.', {
          'field': raftText(context, f.label),
        }),
      );
    } else if (choiceField && !custom) {
      control = RaftAgentSelect<String>(
        key: ValueKey('runtime-${f.key}'),
        semanticLabel: raftText(context, f.label),
        value: choices.any((o) => o['value'] == c.values[f.key])
            ? c.values[f.key] as String
            : f.kind == 'derived_select'
            ? ''
            : null,
        invalid: error != null,
        placeholder: f.copy['placeholder'] as String? ?? 'Select...',
        options: [
          if (f.kind == 'derived_select')
            RaftAgentSelectOption('', raftText(context, 'Runtime default')),
          for (final o in choices)
            RaftAgentSelectOption(o['value'] as String, '${o['label']}'),
        ],
        onChanged: widget.busy ? null : (v) => c.change(f, v),
      );
    } else {
      control = RaftAgentTextInput(
        key: ValueKey('runtime-${f.key}'),
        controller: c.editors[f.key]!,
        semanticLabel: raftText(context, f.label),
        placeholder: f.copy['placeholder'] as String?,
        enabled: !widget.busy,
        invalid: error != null,
        obscure: f.kind == 'secret',
        multiline: f.kind == 'string_map',
        onChanged: (v) => c.changeText(f, v),
      );
    }
    return RaftStableField(
      label: f.label,
      required: f.required && f.kind != 'boolean',
      hint: hint,
      error: error,
      belowControl: [
        if (choiceField && custom && choices.isNotEmpty)
          Wrap(
            spacing: raftAgentChipGap,
            runSpacing: raftAgentChipGap,
            children: [
              for (final o in choices)
                RaftTextButton(
                  label: '${o['label']}',
                  tooltip: o['description'] as String?,
                  visualHeight: RaftMetrics.buttonSm,
                  onPressed: widget.busy
                      ? null
                      : () {
                          c.editors[f.key]!.text = o['value'];
                          c.change(f, o['value']);
                        },
                ),
            ],
          ),
        if (status == 'fallback' || status == 'unavailable')
          RaftAgentSourceStatus(
            message: status == 'fallback'
                ? 'Using fallback choices${sourceReason == null ? '' : ': $sourceReason'}.'
                : 'Choices are unavailable${sourceReason == null ? '' : ': $sourceReason'}.',
            retryLabel: source?['retryable'] == true ? 'Retry' : null,
            onRetry: widget.busy || c.retrying.contains(f.sourceId)
                ? null
                : () => c.retry(f.sourceId!),
          ),
      ],
      child: control,
    );
  }

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
        if (more.isNotEmpty)
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
            if (i > 0) const SizedBox(height: raftAgentFormGap),
            row,
          ],
        ],
      );
    },
  );
}

/// Runtime form for an existing agent (edit) or the onboarding agent: the
/// same DialogCard shell and v2 fields as Create Agent.
class RuntimeFormDialog extends StatefulWidget {
  const RuntimeFormDialog({
    super.key,
    required this.controller,
    required this.machineId,
    required this.runtimeId,
    this.agentId,
    this.onboarding = false,
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
  bool busy = false, nameMissing = false;
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
    form.load();
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
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
                    onPressed: submit,
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
