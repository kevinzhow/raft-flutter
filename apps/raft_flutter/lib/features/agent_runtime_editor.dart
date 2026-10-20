// The agent profile's "Edit runtime config" modal (Web AgentDetailPanel
// `editingRuntimeConfig` + RuntimeConfigFields). Web picks the editor by
// capability: the protocol-v2 server form only while the server flag
// `runtime_form_v2_web` (default off) is on AND the runtime's admission option
// carries `runtimeFormV2.protocolVersion === 2`; otherwise it presents the
// legacy Runtime / Provider / Model / Reasoning / Mode fields, which this file
// ports for every runtime except Built-in Pi, Pi and Kimi Code (those keep
// the v2 form here). Saving follows Web: nothing changed closes, an idle agent
// saves in place, an active one asks first (switching runtime or a Codex
// model change resets the session, anything else restarts).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_runtime_catalog.dart';
import 'agent_runtime_draft.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;
import 'private_route_guard.dart';
import 'runtime_form_dialog.dart';

/// A confirmation the profile shows after the modal closes (Web
/// `requestConfirm` closes the editor first).
class RuntimeEditorConfirm {
  const RuntimeEditorConfirm({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.loadingLabel,
    required this.variant,
    required this.operation,
  });
  final String title, message, confirmLabel, loadingLabel;
  final RaftButtonRecipeVariant variant;
  final Future<void> Function() operation;
}

/// Opens the editor over the workspace. Resolves to the confirmation the
/// caller must present, or null when the editor saved (or was dismissed).
Future<RuntimeEditorConfirm?> showAgentRuntimeEditor(
  BuildContext context, {
  required WorkspaceController controller,
  required Map<String, dynamic> agent,
  Map<String, dynamic>? machine,
  bool Function()? authorized,
  Future<void> Function()? onSaved,
}) async {
  if (!context.mounted || !(authorized?.call() ?? true)) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  // A form: a bottom sheet below 768, a centered dialog from 768.
  final route = raftFormRoute<RuntimeEditorConfirm>(
    context,
    builder: (dialogContext) => RaftModalBackdrop(
      child: AgentRuntimeEditor(
        controller: controller,
        agent: agent,
        machine: machine,
        authorized: authorized,
        onSaved: onSaved,
        onClose: ([outcome]) => navigator.pop(outcome),
      ),
    ),
  );
  void changed() {
    if (!(authorized?.call() ?? true) && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  controller.addListener(changed);
  try {
    return await navigator.push(route);
  } finally {
    controller.removeListener(changed);
  }
}

/// `formatList(labels, { type: "conjunction" })`.
String runtimeEditorList(BuildContext context, List<String> labels) {
  if (labels.length < 2) return labels.join();
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  if (zh) {
    return '${labels.take(labels.length - 1).join('、')}和${labels.last}';
  }
  return labels.length == 2
      ? '${labels.first} and ${labels.last}'
      : '${labels.take(labels.length - 1).join(', ')}, and ${labels.last}';
}

class AgentRuntimeEditor extends StatefulWidget {
  const AgentRuntimeEditor({
    super.key,
    required this.controller,
    required this.agent,
    required this.onClose,
    this.machine,
    this.authorized,
    this.onSaved,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> agent;
  final Map<String, dynamic>? machine;
  final bool Function()? authorized;
  final Future<void> Function()? onSaved;
  final void Function([RuntimeEditorConfirm? outcome]) onClose;
  @override
  State<AgentRuntimeEditor> createState() => _AgentRuntimeEditorState();
}

class _AgentRuntimeEditorState extends State<AgentRuntimeEditor> {
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> get agent => widget.agent;
  String get agentId => '${agent['id']}';
  String? get machineId =>
      agent['machineId'] is String && '${agent['machineId']}'.isNotEmpty
      ? agent['machineId'] as String
      : null;
  List<String> get machineRuntimes => [
    for (final r in (widget.machine?['runtimes'] as List? ?? const [])) '$r',
  ];

  late final int generation = w.client.generation;
  late final String openingAuthority = workspaceAuthority(w);
  bool get current =>
      mounted &&
      generation == w.client.generation &&
      openingAuthority == workspaceAuthority(w) &&
      (widget.authorized?.call() ?? true);

  late final RuntimeDraft base = RuntimeDraft.hydrate(agent);
  late final RuntimeDraft draft = base.copy();
  late final String agentRuntime = base.runtime;

  // The last accepted admission options and live model catalog (this
  // session, in memory) paint at the first frame; the reads below revalidate
  // them in place.
  String get _admissionsKey => 'agent-runtime-editor:$agentId:admissions';
  String _modelsKey(String machine, String runtime) =>
      'agent-runtime-editor:$machine:$runtime:models';
  late List<Map<String, dynamic>>? admissions = () {
    final cached = readPageSnapshot(w, _admissionsKey)?['options'];
    return cached is List<Map<String, dynamic>> ? cached : null;
  }();
  RuntimeModelSource source = const RuntimeModelIdle();
  int sourceTicket = 0;
  bool moreOpen = false, saving = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared at the start of every Save (legacy and protocol-v2) and gone with the dialog.
  String? saveError;

  RuntimeFormController? form;

  /// `isActive`.
  bool get isActive {
    final activity = '${agent['activity'] ?? ''}';
    return (activity.isNotEmpty && activity != 'offline') ||
        agent['status'] == 'active';
  }

  @override
  void initState() {
    super.initState();
    w.addListener(authorityChanged);
    if (admissions != null) syncForm();
    unawaited(loadAdmissions());
    loadModels();
  }

  @override
  void dispose() {
    w.removeListener(authorityChanged);
    form?.dispose();
    super.dispose();
  }

  void authorityChanged() {
    if (!current && mounted) widget.onClose();
  }

  // ------------------------------------------------------------- loading

  /// `useExistingAgentRuntimeOptions`: fails closed to an empty list.
  Future<void> loadAdmissions() async {
    List<Map<String, dynamic>> options = const [];
    final identity = pageIdentity(w);
    var accepted = false;
    try {
      final data = await w.client.get('/agents/$agentId/runtime-options');
      if (data is Map && data['options'] is List) {
        options = [
          for (final o in data['options'] as List)
            if (o is Map) Map<String, dynamic>.from(o),
        ];
        accepted = true;
      }
    } catch (_) {}
    if (!current) return;
    if (accepted) {
      writePageSnapshot(w, _admissionsKey, identity, {'options': options});
    }
    setState(() => admissions = options);
    syncForm();
  }

  Map<String, dynamic>? admission(String runtime) =>
      admissions?.where((o) => o['runtimeId'] == runtime).firstOrNull;

  /// Web `v2EditEligible`: the flag, the runtime's v2 marker, the draft still
  /// on the agent's saved runtime. Runtimes without a legacy form stay v2.
  bool get v2Active {
    if (!legacyRuntimeEditorSupports(agentRuntime)) return true;
    final option = admission(agentRuntime);
    final marker = option?['runtimeFormV2'];
    return w.runtimeFormV2WebEnabled &&
        draft.runtime == agentRuntime &&
        marker is Map &&
        marker['protocolVersion'] == 2;
  }

  void syncForm() {
    if (v2Active && form == null && machineId != null) {
      form = RuntimeFormController(
        w,
        machineId: machineId!,
        runtimeId: agentRuntime,
        agentId: agentId,
        valid: () => current,
      )..load();
    }
    if (mounted) setState(() {});
  }

  /// `useRuntimeModels(agent.machineId, draftRuntime)`.
  void loadModels() {
    final id = machineId;
    final runtime = draft.runtime;
    if (id == null || runtime.isEmpty || w.server == null) {
      source = const RuntimeModelIdle();
      return;
    }
    final ticket = ++sourceTicket;
    final key = _modelsKey(id, runtime), identity = pageIdentity(w);
    final cached = readPageSnapshot(w, key)?['source'];
    source = cached is RuntimeModelLive
        ? cached
        : runtimeModelLoadingFor(runtime);
    unawaited(() async {
      RuntimeModelSource next;
      try {
        next = parseRuntimeModelSourcePayload(
          await w.client.get(
            '/servers/${w.server!.id}/machines/$id/runtime-models/$runtime',
          ),
        );
      } catch (_) {
        next = const RuntimeModelError();
      }
      if (!current || ticket != sourceTicket) return;
      if (next is RuntimeModelLive) {
        writePageSnapshot(w, key, identity, {'source': next});
      }
      setState(() => source = next);
    }());
  }

  // ---------------------------------------------------------- derived

  ({List<RuntimeModelInfo> models, bool loading, bool live}) get projection =>
      projectRuntimeModels(draft.runtime, source);

  bool get changed => draft.changedFrom(base);

  bool get runtimeCanSelect =>
      admission(draft.runtime)?['canSelectInThisContext'] == true;

  bool get modelSourceInvalid => !runtimeModelSelectionIsRunnable(
    runtime: draft.runtime,
    source: source,
    model: draft.model,
    customMode: draft.customModelMode,
    customAllowed: supportsRuntimeCustomModelName(draft.runtime),
  );

  bool get saveDisabled => runtimeConfigSaveDisabled(
    saving: saving,
    changed: changed,
    runtimeCanSelect: runtimeCanSelect,
    providerApiUrlInvalid: draft.apiUrlInvalid,
    providerApiKeyInvalid: draft.apiKeyInvalid,
    customModelInvalid: draft.customModelInvalid,
    modelSourceInvalid: modelSourceInvalid,
  );

  // ----------------------------------------------------------- changes

  void changeRuntime(String id) {
    final next = RuntimeDraft(
      runtime: id,
      model: defaultRuntimeModel(id),
      envVars: draft.envVars,
    );
    draft
      ..runtime = next.runtime
      ..model = next.model
      ..customModelMode = false
      ..providerCustom = false
      ..providerApiUrl = ''
      ..providerApiKey = ''
      ..fastMode = false
      ..command = ''
      ..reasoning = supportsRuntimeReasoning(id)
          ? reconcileReasoningEffort(id, next.model, null, const [])
          : null;
    loadModels();
    setState(() {});
    syncForm();
  }

  void changeModel(String model) {
    draft
      ..model = model
      ..reasoning = reconcileReasoningEffort(
        draft.runtime,
        model,
        draft.reasoning,
        projection.models,
      );
    setState(() {});
  }

  // -------------------------------------------------------------- save

  Future<void> patch(Map<String, dynamic> data, {String? restartMode}) async {
    await w.command(
      'PATCH',
      '/agents/$agentId',
      data: {...data, 'restartMode': ?restartMode},
    );
    if (current) await widget.onSaved?.call();
  }

  String reasoningLabel(BuildContext context) => draft.reasoning == null
      ? raftText(context, 'Default')
      : (reasoningEfforts
                .where((e) => e.$1 == draft.reasoning)
                .firstOrNull
                ?.$2 ??
            draft.reasoning!);

  Future<void> submit() async {
    // Web handleSaveRuntimeConfiguration clears the banner for both forms.
    setState(() => saveError = null);
    if (v2Active) return submitV2();
    if (!changed) return widget.onClose();
    if (saveDisabled) return;
    final context = this.context;
    String tr(String s) => raftText(context, s);
    final runtime = draft.runtime;
    final config = draft.buildRuntimeConfig();
    final fields = {
      'runtime': runtime,
      'model': draft.model,
      'runtimeConfig': config,
      'reasoningEffort': supportsRuntimeReasoning(runtime)
          ? draft.reasoning
          : null,
    };
    final runtimeChanged = runtime != base.runtime;
    final modelChanged = draft.model != base.model;
    final customChanged = draft.customModelMode != base.customModelMode;
    final reasoning = supportsRuntimeReasoning(runtime)
        ? reasoningLabel(context)
        : tr('Not available');
    final modelLabel = runtimeModelLabel(runtime, draft.model);

    if (runtimeChanged) {
      final from = runtimeDisplayName(base.runtime);
      final to = runtimeDisplayName(runtime);
      widget.onClose(
        RuntimeEditorConfirm(
          title: tr('Switch runtime config'),
          message: raftFormat(
            context,
            isActive
                ? 'This will switch the runtime from {from} to {to} and reset the active runtime session.'
                : 'This will switch the runtime from {from} to {to}.',
            {'from': from, 'to': to},
          ),
          confirmLabel: tr(
            isActive ? 'Reset runtime session' : 'Save runtime change',
          ),
          loadingLabel: tr(isActive ? 'Resetting…' : 'Applying…'),
          variant: RaftButtonRecipeVariant.warning,
          operation: () => patch(fields, restartMode: 'session'),
        ),
      );
      return;
    }
    if (!isActive) {
      setState(() => saving = true);
      try {
        await patch(fields);
        if (current) widget.onClose();
      } catch (e) {
        if (mounted) {
          setState(
            () => saveError = userErrorText(
              e,
              fallback: 'Runtime config is invalid.',
              where: 'agent runtime save',
            ),
          );
        }
      } finally {
        if (mounted) setState(() => saving = false);
      }
      return;
    }
    // A Codex model switch resets the native session (`thread/resume` pins
    // the model).
    if (runtime == 'codex' && (modelChanged || customChanged)) {
      widget.onClose(
        RuntimeEditorConfirm(
          title: tr('Switch model and reset session'),
          message: supportsRuntimeReasoning(runtime)
              ? raftFormat(
                  context,
                  'Switching to {model} ({reasoning} reasoning) resets the current runtime session.',
                  {'model': modelLabel, 'reasoning': reasoning},
                )
              : raftFormat(
                  context,
                  'Switching to {model} resets the current runtime session.',
                  {'model': modelLabel},
                ),
          confirmLabel: tr('Reset'),
          loadingLabel: tr('Resetting…'),
          variant: RaftButtonRecipeVariant.warning,
          operation: () => patch(fields, restartMode: 'session'),
        ),
      );
      return;
    }
    final labels = <String>[
      if (modelChanged || customChanged) tr('Model'),
      if (draft.providerCustom != base.providerCustom ||
          draft.providerApiUrl.trim() != base.providerApiUrl ||
          draft.providerApiKey.trim() != base.providerApiKey)
        tr('Provider'),
      if (draft.fastMode != base.fastMode) tr('Mode'),
      if (draft.command.trim() != base.command) tr('Command'),
      if (draft.reasoning != base.reasoning) tr('Reasoning'),
      if (RuntimeDraft.envChanged(draft, base)) tr('Environment Variables'),
    ];
    widget.onClose(
      RuntimeEditorConfirm(
        title: tr('Restart to apply runtime config'),
        message: raftFormat(
          context,
          'Apply {changes} and restart this agent now?',
          {'changes': runtimeEditorList(context, labels)},
        ),
        confirmLabel: tr('Restart agent'),
        loadingLabel: tr('Restarting…'),
        variant: RaftButtonRecipeVariant.information,
        operation: () => patch(fields, restartMode: 'restart'),
      ),
    );
  }

  /// Web `saveRuntimeFormV2Edit`.
  Future<void> submitV2() async {
    final f = form;
    if (f == null || f.definition == null || saving) return;
    final context = this.context;
    String tr(String s) => raftText(context, s);
    if (!f.valuesChanged) return widget.onClose();
    // Field errors are already shown beside the fields; nothing to send yet.
    if (f.validate().isNotEmpty) return;
    final fields = f.submission;
    Future<void> save([String? restartMode]) async {
      try {
        await patch(fields, restartMode: restartMode);
      } catch (e) {
        if (mounted) {
          // Web: `data.error ?? runtimeConfigInvalid`, and each `issues`
          // pointer marks its field.
          f.serverErrors = runtimeFormIssueErrors(
            e,
            fallback: 'Runtime config is invalid.',
          );
          setState(
            () => saveError = userErrorText(
              e,
              fallback: 'Runtime config is invalid.',
              where: 'agent runtime v2 save',
            ),
          );
        }
        rethrow;
      }
    }

    if (!isActive) {
      setState(() => saving = true);
      try {
        await save();
        if (current) widget.onClose();
      } catch (_) {
        // Shown in the banner.
      } finally {
        if (mounted) setState(() => saving = false);
      }
      return;
    }
    final labels = [
      for (final field in f.definition!.fields)
        if (f.changedKeys.contains(field.key)) field.label,
    ];
    widget.onClose(
      RuntimeEditorConfirm(
        title: tr('Restart to apply runtime config'),
        message: raftFormat(
          context,
          'Apply {changes} and restart this agent now?',
          {'changes': runtimeEditorList(context, labels)},
        ),
        confirmLabel: tr('Restart agent'),
        loadingLabel: tr('Restarting…'),
        variant: RaftButtonRecipeVariant.information,
        operation: () => save('restart'),
      ),
    );
  }

  // ------------------------------------------------------------- build

  String runtimeDisplayName(String id) =>
      runtimeInfos.where((r) => r.id == id).firstOrNull?.name ?? id;

  /// `formatRuntimeLabelWithStatus` + `formatRuntimeAvailabilitySuffix`.
  String runtimeLabel(BuildContext context, String id) {
    final info = runtimeInfos.where((r) => r.id == id).firstOrNull;
    var label = runtimeDisplayName(id);
    if (info?.deprecated == true) {
      label += raftText(context, ' (deprecated)');
    }
    label += switch (runtimeAvailabilityKind(id, machineRuntimes)) {
      'comingSoon' => raftText(context, ' (coming soon)'),
      'updateComputer' => raftText(context, ' (update computer)'),
      'notInstalled' => raftText(context, ' (not installed)'),
      _ => '',
    };
    return label;
  }

  List<RaftAgentSelectOption<String>> runtimeOptions(BuildContext context) => [
    for (final option in admissions ?? const <Map<String, dynamic>>[])
      if (existingAgentRuntimeOptions(
            base.runtime,
          ).any((r) => r.id == option['runtimeId']) &&
          (legacyRuntimeEditorSupports('${option['runtimeId']}') ||
              option['runtimeId'] == draft.runtime))
        RaftAgentSelectOption(
          '${option['runtimeId']}',
          runtimeLabel(context, '${option['runtimeId']}'),
          enabled: option['canSelectInThisContext'] == true,
        ),
  ];

  /// `runtimeModelSourceStatus`.
  String? sourceStatus(BuildContext context) {
    final runtimeName = runtimeDisplayName(draft.runtime);
    String fmt(String s) =>
        raftFormat(context, s, {'runtimeName': runtimeName});
    return switch (source) {
      RuntimeModelLive() => null,
      RuntimeModelLoading() => raftText(
        context,
        'Checking models on this Computer…',
      ),
      RuntimeModelIdle() => raftText(
        context,
        'Choose an online Computer to check available models.',
      ),
      RuntimeModelNonLive(kind: 'missing_config') => fmt(
        '{runtimeName} needs configuration on this Computer before its models can be loaded.',
      ),
      RuntimeModelNonLive(kind: 'no_models') => fmt(
        '{runtimeName} is configured, but this Computer reported no available models.',
      ),
      RuntimeModelNonLive() =>
        runtimeIgnoresModel(draft.runtime)
            ? fmt(
                '{runtimeName} uses its configured default; no model selection is required.',
              )
            : fmt(
                '{runtimeName} does not report a model catalog from this Computer.',
              ),
      RuntimeModelError(:final code) => switch (code) {
        'runtime_not_authenticated' =>
          draft.runtime == 'grok'
              ? raftText(
                  context,
                  'Grok CLI is not signed in. Run grok login on this Computer, then retry.',
                )
              : fmt(
                  '{runtimeName} requires sign-in on this Computer. Sign in, then retry.',
                ),
        'runtime_not_found' => fmt(
          '{runtimeName} was not found on this Computer. Install it, then retry.',
        ),
        'detect_timeout' => fmt(
          '{runtimeName} model discovery timed out. Check the runtime on this Computer, then retry.',
        ),
        'protocol_unsupported' => fmt(
          'This version of {runtimeName} does not support the model discovery protocol. Update it, then retry.',
        ),
        'computer_offline' => raftText(
          context,
          'This Computer is offline. Reconnect it, then retry.',
        ),
        _ => raftText(context, 'Could not load models from this Computer.'),
      },
    };
  }

  bool get sourceCanRetry => switch (source) {
    RuntimeModelNonLive(kind: 'missing_config' || 'no_models') => true,
    RuntimeModelError(:final retryable) => retryable,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    // The Save button reads the form's change / loading / validity state, so
    // the card follows the form controller, not only this State's setState.
    final f = form;
    return f == null
        ? buildCard(context)
        : ListenableBuilder(listenable: f, builder: (c, _) => buildCard(c));
  }

  Widget buildCard(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final f = form;
    final Widget fields;
    if (v2Active) {
      fields = f == null
          ? const RaftAgentFieldNote('Loading runtime configuration…')
          : RuntimeFormFields(
              form: f,
              busy: saving,
              rowGap: 16,
              // Web `schema-runtime-unavailable`: a form that did not load (or
              // went stale twice) says so instead of showing nothing.
              leading: [
                if (f.loading && f.definition == null)
                  const RaftAgentFieldNote('Loading runtime configuration…')
                else if (f.error != null)
                  RaftAgentBanner(
                    key: const ValueKey('runtime-editor-form-error'),
                    status: RaftAgentBannerStatus.warning,
                    description: f.error!,
                    action: 'Retry',
                    onAction: f.load,
                  ),
              ],
            );
    } else {
      fields = legacyFields(context, t);
    }
    final v2Ready = f != null && f.definition != null;
    final disabled = v2Active
        ? saving ||
              f == null ||
              f.loading ||
              f.definition == null ||
              !f.valuesChanged
        : saveDisabled;
    final footer = RaftAgentDialogFooter(
      children: [
        RaftAgentDialogButton(
          label: tr('Cancel'),
          size: RaftButtonRecipeSize.md,
          onPressed: saving ? null : () => widget.onClose(),
        ),
        RaftAgentDialogButton(
          key: const ValueKey('runtime-editor-save'),
          label: tr('Save runtime config'),
          primary: true,
          size: RaftButtonRecipeSize.md,
          onPressed: disabled && !(v2Active && !v2Ready) ? null : submit,
        ),
      ],
    );
    return RaftAgentDialogCard(
      key: const ValueKey('agent-runtime-editor'),
      surfaceKey: const ValueKey('agent-runtime-editor-surface'),
      bare: true,
      plainCard: true,
      title: 'Edit runtime config',
      onClose: saving ? null : () => widget.onClose(),
      footerGap: raftAgentSectionGap,
      footer: footer,
      children: [
        fields,
        if (saveError != null) ...[
          const SizedBox(height: raftAgentSectionGap),
          // Web `<Banner intent="warning" density="sm" className="font-bold">`.
          RaftErrorBanner(
            saveError!,
            key: const ValueKey('runtime-editor-error'),
            small: true,
            bold: true,
          ),
        ],
      ],
    );
  }

  /// RuntimeConfigFields legacy arm: Runtime, Provider (Claude), Model,
  /// Reasoning, Mode and the MORE disclosure (command, environment variables).
  Widget legacyFields(BuildContext context, RaftTokens t) {
    String tr(String s) => raftText(context, s);
    final runtime = draft.runtime;
    final proj = projection;
    final customAllowed = supportsRuntimeCustomModelName(runtime);
    final status = sourceStatus(context);
    final machineSourceApplies = true;
    final showHeaderRescan =
        machineSourceApplies &&
        (source is RuntimeModelLive || source is RuntimeModelLoading);
    final modelOptions = <RaftAgentSelectOption<String>>[
      for (final m in proj.models) RaftAgentSelectOption(m.id, m.label),
    ];
    if (proj.live &&
        !draft.customModelMode &&
        draft.model.isNotEmpty &&
        !modelOptions.any((o) => o.value == draft.model)) {
      modelOptions.add(
        RaftAgentSelectOption(
          draft.model,
          raftFormat(context, "{model} (not in this computer's config)", {
            'model': runtimeModelLabel(runtime, draft.model),
          }),
        ),
      );
    }
    if (customAllowed) {
      modelOptions.add(
        RaftAgentSelectOption(customModelSelectValue, tr('Custom')),
      );
    }
    final modelInfo = proj.models.where((m) => m.id == draft.model).firstOrNull;
    final suggestionOnly = modelInfo?.verified == 'suggestion_only';
    final showSuggestion =
        suggestionOnly ||
        (!proj.live &&
            !proj.loading &&
            proj.models.any((m) => m.verified == 'suggestion_only'));
    final customInput = customAllowed && draft.customModelMode;
    final reasoningChoices = reasoningOptionsForModel(
      runtime,
      draft.model,
      proj.models,
    );
    const defaultReasoning = '__default_reasoning_effort__';
    final rows = <Widget>[
      RaftStableField(
        label: 'Runtime',
        required: true,
        child: RaftAgentSelect<String>(
          key: const ValueKey('runtime-editor-runtime'),
          value: runtime,
          unmatchedLabel: runtime,
          options: runtimeOptions(context),
          placeholder: 'Select…',
          semanticLabel: tr('Runtime'),
          onChanged: saving ? null : changeRuntime,
        ),
      ),
      if (supportsRuntimeApiUrl(runtime)) ...[
        RaftStableField(
          label: 'Provider',
          hint:
              'Default leaves Claude Code provider settings untouched. Custom sets ANTHROPIC_BASE_URL and ANTHROPIC_API_KEY for this agent.',
          child: RaftAgentSelect<String>(
            key: const ValueKey('runtime-editor-provider'),
            value: draft.providerCustom ? 'custom' : 'default',
            options: [
              RaftAgentSelectOption('default', tr('Default')),
              RaftAgentSelectOption('custom', tr('Custom')),
            ],
            semanticLabel: tr('Provider'),
            onChanged: saving
                ? null
                : (v) => setState(() {
                    draft.providerCustom = v == 'custom';
                    if (!draft.providerCustom) {
                      draft
                        ..providerApiUrl = ''
                        ..providerApiKey = '';
                    }
                  }),
          ),
        ),
        if (draft.apiUrlRequired) ...[
          RaftStableField(
            label: 'API URL',
            required: true,
            error: draft.apiUrlInvalid
                ? tr('API URL must start with http:// or https://.')
                : null,
            child: _TextField(
              key: const ValueKey('runtime-editor-api-url'),
              value: draft.providerApiUrl,
              placeholder: 'https://gateway.example.com',
              invalid: draft.apiUrlInvalid,
              onChanged: (v) => setState(() => draft.providerApiUrl = v),
            ),
          ),
          RaftStableField(
            label: 'API Key',
            required: true,
            error: draft.apiKeyInvalid
                ? tr('API Key is required for a custom provider.')
                : null,
            child: _TextField(
              key: const ValueKey('runtime-editor-api-key'),
              value: draft.providerApiKey,
              placeholder: 'sk-ant-...',
              obscure: true,
              invalid: draft.apiKeyInvalid,
              onChanged: (v) => setState(() => draft.providerApiKey = v),
            ),
          ),
        ],
      ],
      RaftStableField(
        label: 'Model',
        required: draft.customModelMode,
        error: draft.customModelInvalid
            ? tr('Custom model name is required.')
            : null,
        labelAccessory: showHeaderRescan
            ? RaftIconButton(
                key: const ValueKey('runtime-editor-rescan'),
                glyph: RaftGlyph.refreshCw,
                tooltip: tr('Rescan models from this Computer'),
                visualSize: 20,
                minimumTargetSize: 20,
                glyphSize: 12,
                variant: RaftControlVariant.ghost,
                onPressed: machineId == null || proj.loading || saving
                    ? null
                    : () => setState(loadModels),
              )
            : null,
        belowControl: [
          if (status != null)
            RaftAgentSourceStatus(
              key: const ValueKey('runtime-model-source-status'),
              message: status,
              retryLabel: sourceCanRetry ? tr('Retry') : null,
              onRetry: machineId == null || proj.loading
                  ? null
                  : () => setState(loadModels),
            ),
          if (showSuggestion)
            const RaftAgentFieldNote(
              "This model is a catalog suggestion and has not been verified to launch with this computer's current runtime config.",
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftAgentSelect<String>(
              key: const ValueKey('runtime-editor-model'),
              value: draft.customModelMode
                  ? customModelSelectValue
                  : draft.model,
              unmatchedLabel: draft.model,
              options: modelOptions,
              placeholder: 'Model',
              semanticLabel: tr('Model'),
              onChanged: saving
                  ? null
                  : (next) {
                      if (next == customModelSelectValue) {
                        setState(() {
                          draft.customModelMode = true;
                          draft.model = '';
                        });
                        return;
                      }
                      draft.customModelMode = false;
                      changeModel(next);
                    },
            ),
            if (customInput) ...[
              const SizedBox(height: raftAgentChipGap),
              _TextField(
                key: const ValueKey('runtime-editor-custom-model'),
                value: draft.model,
                placeholder: runtime == 'claude'
                    ? 'Custom model name'
                    : 'Custom model ID',
                invalid: draft.customModelInvalid,
                onChanged: (v) => setState(() => draft.model = v),
              ),
            ],
          ],
        ),
      ),
      if (supportsRuntimeReasoning(runtime))
        RaftStableField(
          label: 'Reasoning',
          child: RaftAgentSelect<String>(
            key: const ValueKey('runtime-editor-reasoning'),
            value: draft.reasoning ?? defaultReasoning,
            unmatchedLabel: draft.reasoning,
            options: [
              RaftAgentSelectOption(defaultReasoning, tr('Default')),
              for (final (id, label) in reasoningChoices)
                RaftAgentSelectOption(id, tr(label)),
            ],
            placeholder: 'Reasoning',
            semanticLabel: tr('Reasoning'),
            onChanged: saving
                ? null
                : (v) => setState(
                    () => draft.reasoning = v == defaultReasoning ? null : v,
                  ),
          ),
        ),
      if (supportsRuntimeFastMode(runtime))
        RaftStableField(
          label: 'Mode',
          child: RaftAgentOptionCard(
            key: const ValueKey('runtime-editor-fast-mode'),
            checked: draft.fastMode,
            title: 'Fast mode',
            description:
                'Launch this runtime with higher speed at a higher cost per token.',
            onChanged: saving
                ? null
                : (v) => setState(() => draft.fastMode = v),
          ),
        ),
      RaftAgentMoreDisclosure(
        key: const ValueKey('runtime-editor-more'),
        open: moreOpen,
        onToggle: () => setState(() => moreOpen = !moreOpen),
        children: [
          if (supportsRuntimeCommand(runtime))
            RaftStableField(
              label: 'Claude Command',
              hint:
                  'Executable path or command name; Slock adds the Claude stream-json runtime arguments.',
              child: _TextField(
                key: const ValueKey('runtime-editor-command'),
                value: draft.command,
                placeholder: 'claude',
                onChanged: (v) => setState(() => draft.command = v),
              ),
            ),
          RaftStableField(
            label: 'Environment Variables',
            child: RaftAgentKeyValueRows(
              hint:
                  'Environment variables are injected into the agent runtime.',
              entries: draft.envVars,
              enabled: !saving,
              onChanged: (entries) => setState(() => draft.envVars = entries),
            ),
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: raftAgentSectionGap), // `space-y-4`
          row,
        ],
      ],
    );
  }
}

/// A recipe text input driven by a plain string value.
class _TextField extends StatefulWidget {
  const _TextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.obscure = false,
    this.invalid = false,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final bool obscure, invalid;
  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftAgentTextInput(
    controller: controller,
    placeholder: widget.placeholder,
    obscure: widget.obscure,
    invalid: widget.invalid,
    onChanged: widget.onChanged,
  );
}
