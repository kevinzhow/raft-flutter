import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'private_route_guard.dart';

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
  late final base =
      '/servers/${w.server!.id}/machines/${widget.machineId}/runtime-forms/v2/${Uri.encodeComponent(widget.runtimeId)}';
  RuntimeForm? definition;
  Map<String, Map<String, dynamic>> sources = {};
  Map<String, dynamic> values = {};
  Map<String, String> validation = {};
  final mapProblems = <String, String>{};
  final editors = <String, TextEditingController>{};
  final name = TextEditingController(), description = TextEditingController();
  bool loading = true, busy = false;
  String? error;
  final retrying = <String>{};
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
    load();
  }

  @override
  void dispose() {
    for (final e in editors.values) {
      e.dispose();
    }
    name.dispose();
    description.dispose();
    super.dispose();
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

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await w.query(
        editing ? '/agents/${widget.agentId}/runtime-form' : base,
      );
      final form = RuntimeForm.parse(raw);
      if (form == null || !form.supported) {
        throw const RaftApiException(
          'This runtime form needs a newer client. It cannot be edited safely.',
        );
      }
      definition = form;
      final loaded = await Future.wait([
        for (final id in form.sourceRefs.keys) source(id),
      ]);
      if (!currentAuthority) return;
      sources = Map.fromIterables(form.sourceRefs.keys, loaded);
      values = form.initial(sources);
      for (final f in form.fields) {
        if (!['boolean', 'unsupported'].contains(f.kind)) {
          editors[f.key]?.dispose();
          editors[f.key] = TextEditingController(
            text: valueText(f, values[f.key]),
          );
        }
      }
      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  String valueText(RuntimeField field, dynamic value) =>
      field.kind == 'string_map' && value is Map
      ? value.entries.map((e) => '${e.key}=${e.value}').join('\n')
      : value is String
      ? value
      : '';
  void change(RuntimeField f, dynamic value) {
    setState(() {
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
    });
  }

  Future<void> retry(String id) async {
    if (!retrying.add(id)) return;
    setState(() {});
    try {
      final next = await source(id, refresh: true);
      if (!currentAuthority) return;
      setState(() => sources[id] = next);
    } finally {
      if (mounted) setState(() => retrying.remove(id));
    }
  }

  Future<void> submit() async {
    if (busy || definition == null || !currentAuthority) return;
    final problems = definition!.validate(sources, values, editing: editing);
    for (final f in definition!.fields) {
      if (definition!.visible(f, values, sources) &&
          mapProblems.containsKey(f.key)) {
        problems[f.key] = mapProblems[f.key]!;
      }
    }
    if (!editing && name.text.trim().isEmpty) problems['name'] = 'required';
    if (problems.isNotEmpty) {
      setState(() => validation = problems);
      return;
    }
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
          'formDefinitionRef': {
            'protocolVersion': 2,
            'runtimeId': widget.runtimeId,
          },
          'formValues': definition!.submission(values, sources),
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

  String? fieldError(String key) => switch (validation[key]) {
    'required' => 'This field is required.',
    'invalid_map' => 'Enter one unique KEY=value per line.',
    'source_unavailable' =>
      'Choices are unavailable. Retry after connecting the computer.',
    'invalid_url' => 'Enter an HTTP or HTTPS URL.',
    'not_a_choice' => 'Select an available choice.',
    'unsupported_required' => 'Update the client to edit this required field.',
    _ => null,
  };
  Widget field(RuntimeField f) {
    final choices = definition!.choices(f, sources, values),
        custom = definition!.custom(f, sources, values);
    final status = sources[f.sourceId]?['status'],
        sourceReason = sources[f.sourceId]?['reason'];
    final choiceField = [
      'select',
      'dependent_select',
      'derived_select',
    ].contains(f.kind);
    if (f.kind == 'derived_select' && choices.isEmpty) {
      return const SizedBox.shrink();
    }
    if (f.kind == 'unsupported' && !f.required) return const SizedBox.shrink();
    final decoration = InputDecoration(
      labelText: raftText(context, f.label),
      helperText: f.copy['hint'] as String?,
      errorText: fieldError(f.key),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f.kind == 'boolean')
            SwitchListTile(
              title: Text(raftText(context, f.label)),
              value: values[f.key] == true,
              onChanged: busy ? null : (v) => change(f, v),
            )
          else if (f.kind == 'unsupported')
            Text(
              raftFormat(
                context,
                '{field}: update the client to edit this field.',
                {'field': raftText(context, f.label)},
              ),
            )
          else if (choiceField && !custom)
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${f.key}:${values[f.key]}:${choices.map((o) => o['value']).join('|')}',
              ),
              initialValue: choices.any((c) => c['value'] == values[f.key])
                  ? values[f.key]
                  : f.kind == 'derived_select'
                  ? ''
                  : null,
              isExpanded: true,
              decoration: decoration,
              items: [
                if (f.kind == 'derived_select')
                  DropdownMenuItem(
                    value: '',
                    child: Text(raftText(context, 'Runtime default')),
                  ),
                for (final c in choices)
                  DropdownMenuItem(
                    value: c['value'] as String,
                    child: Text(
                      '${c['label']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: busy ? null : (v) => change(f, v ?? ''),
            )
          else
            TextField(
              key: ValueKey('runtime-${f.key}'),
              controller: editors[f.key],
              enabled: !busy,
              obscureText: f.kind == 'secret',
              minLines: f.kind == 'string_map' ? 3 : 1,
              maxLines: f.kind == 'string_map' ? 8 : 1,
              decoration: decoration.copyWith(
                helperText: f.kind == 'string_map'
                    ? raftText(context, 'One KEY=value per line.')
                    : decoration.helperText,
              ),
              onChanged: (v) {
                if (f.kind == 'string_map') {
                  try {
                    final map = parseRuntimeStringMap(v);
                    mapProblems.remove(f.key);
                    change(f, map);
                  } on FormatException {
                    setState(() {
                      mapProblems[f.key] = 'invalid_map';
                      validation[f.key] = 'invalid_map';
                    });
                  }
                } else {
                  change(f, v);
                }
              },
            ),
          if (choiceField && custom && choices.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final c in choices)
                  ActionChip(
                    label: Text('${c['label']}'),
                    tooltip: c['description'] as String?,
                    onPressed: busy
                        ? null
                        : () {
                            editors[f.key]!.text = c['value'];
                            change(f, c['value']);
                          },
                  ),
              ],
            ),
          if (status == 'fallback' || status == 'unavailable')
            Row(
              children: [
                Expanded(
                  child: Text(
                    status == 'fallback'
                        ? 'Using fallback choices${sourceReason == null ? '' : ': $sourceReason'}.'
                        : 'Choices are unavailable${sourceReason == null ? '' : ': $sourceReason'}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (sources[f.sourceId]?['retryable'] == true)
                  TextButton(
                    onPressed: busy || retrying.contains(f.sourceId)
                        ? null
                        : () => retry(f.sourceId!),
                    child: Text(raftText(context, 'Retry')),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        raftText(
          context,
          editing ? 'Edit runtime configuration' : 'Create managed agent',
        ),
      ),
      content: SizedBox(
        width: 560,
        child: loading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null)
                      Semantics(liveRegion: true, child: Text(error!)),
                    if (definition != null) ...[
                      if (!editing) ...[
                        TextField(
                          controller: name,
                          readOnly: widget.onboarding,
                          decoration: InputDecoration(
                            labelText: raftText(context, 'Agent name'),
                            errorText: fieldError('name'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: description,
                          readOnly: widget.onboarding,
                          decoration: InputDecoration(
                            labelText: raftText(context, 'Description'),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      for (final f in definition!.fields)
                        if (definition!.visible(f, values, sources)) field(f),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(raftText(context, 'Cancel')),
        ),
        if (definition != null)
          RaftButton(
            label: editing ? 'Save' : 'Create',
            busy: busy,
            onPressed: submit,
          )
        else if (!loading)
          TextButton(
            onPressed: load,
            child: Text(raftText(context, 'Try again')),
          ),
      ],
    ),
  );
}
