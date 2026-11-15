// The agent profile's "Edit runtime config" modal (Web AgentProfileInfo
// `editingRuntimeConfig` + RuntimeConfigFields). Web 1.24 has one editor: the
// server-described protocol-v2 form, picked by the runtime's admission row
// (`runtimeFormV2.protocolVersion === 2`), under a Runtime select. A runtime
// whose row has no marker shows the form-unavailable notice and cannot be
// saved. Saving follows Web 1.24 (`saveRuntimeFormV2Edit`): nothing changed
// closes; only a stopped agent's runtime switch is confirmed
// (`restartMode: "session"`); everything else is saved without `restartMode`
// and the server applies it when the agent is next idle, which a toast says
// (agent_runtime_config_apply.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart' show RaftAgentFields;
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import 'agent_metadata_projection.dart' show agentRowName;
import 'agent_model_limits_warning.dart';
import 'agent_runtime_catalog.dart';
import 'agent_runtime_config_apply.dart';
import 'agent_runtime_labels.dart';
import 'private_route_guard.dart';
import 'runtime_form_dialog.dart';
import 'runtime_options_request.dart';

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
    this.cancelLabel = 'Cancel',
  });
  final String title, message, confirmLabel, loadingLabel, cancelLabel;
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

  /// The agent's saved runtime; the draft is only which runtime the form is
  /// for (Web `draftRuntime`): the form owns every other drafted value.
  late final String agentRuntime = _savedRuntime();
  late String draftRuntime = agentRuntime;
  bool get runtimeSwitched => draftRuntime != agentRuntime;

  /// `GET /agents/:id/runtime-options`; null until it arrives.
  List<Map<String, dynamic>>? admissions;
  bool saving = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared at the start of every Save and gone with the dialog.
  String? saveError;

  RuntimeFormController? form;

  String _savedRuntime() {
    final stored = agent['runtimeConfig'];
    final fromConfig = stored is Map ? stored['runtime'] : null;
    for (final value in [fromConfig, agent['runtime']]) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'claude';
  }

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
    unawaited(loadAdmissions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A form's first read carries the display language, which is not
    // available in initState.
    if (admissions != null) ensureForm();
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

  /// `useExistingAgentRuntimeSelectionOptions`: fails closed to an empty list.
  Future<void> loadAdmissions() async {
    List<Map<String, dynamic>> options = const [];
    try {
      final data = await readRuntimeOptions(
        () => w.client.get('/agents/$agentId/runtime-options'),
      );
      if (data is Map && data['options'] is List) {
        options = [
          for (final o in data['options'] as List)
            if (o is Map) Map<String, dynamic>.from(o),
        ];
      }
    } catch (_) {}
    if (!current) return;
    setState(() => admissions = options);
    ensureForm();
  }

  Map<String, dynamic>? admission(String runtime) =>
      admissions?.where((o) => o['runtimeId'] == runtime).firstOrNull;

  /// Web `draftRuntimeHasFormV2`: the runtime's admission row carries the v2
  /// marker (and the Computer is known). Without it the form is unavailable.
  bool hasFormV2(String runtime) {
    final marker = admission(runtime)?['runtimeFormV2'];
    return machineId != null && marker is Map && marker['protocolVersion'] == 2;
  }

  /// The form belongs to the draft runtime: the agent's own values for its
  /// saved runtime, the create form of another one (a runtime switch).
  void ensureForm() {
    if (form == null || form!.runtimeId != draftRuntime) {
      final old = form;
      final next = RuntimeFormController(
        w,
        machineId: machineId ?? '',
        runtimeId: draftRuntime,
        agentId: runtimeSwitched ? null : agentId,
        valid: () => current,
        language: runtimeFormLanguageTag(context),
      );
      form = next;
      // Web `RUNTIME_FORM_V2_UNAVAILABLE`: no marker, nothing to load.
      if (hasFormV2(draftRuntime)) {
        next.load();
      } else {
        next.markUnavailable();
      }
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------- derived

  /// Web `v2EditChanged`: a runtime switch is a change by itself.
  bool get changed => runtimeSwitched || (form?.valuesChanged ?? false);

  /// The runtime must still be selectable here: its Computer capability can
  /// go away mid-edit (`draftRuntimeCanSelect`).
  bool get runtimeCanSelect =>
      admission(draftRuntime)?['canSelectInThisContext'] == true;

  /// Web `v2EditSaveDisabled`.
  bool get saveDisabled {
    final f = form;
    return saving ||
        !runtimeCanSelect ||
        f == null ||
        f.loading ||
        f.definition == null ||
        !changed ||
        f.reentryBlocked;
  }

  // ----------------------------------------------------------- changes

  /// Web `changeDraftRuntime`: the form's draft belongs to the form it was
  /// made in, so the other runtime loads its own.
  void changeRuntime(String id) {
    if (id == draftRuntime) return;
    draftRuntime = id;
    ensureForm();
  }

  // -------------------------------------------------------------- save

  /// `PATCH /agents/:id`; the response carries `configApply` when no
  /// `restartMode` was sent.
  Future<dynamic> patch(
    Map<String, dynamic> data, {
    String? restartMode,
  }) async {
    final response = await w.command(
      'PATCH',
      '/agents/$agentId',
      data: {...data, 'restartMode': ?restartMode},
    );
    if (current) await widget.onSaved?.call();
    return response;
  }

  /// Web `saveRuntimeFormV2Edit`'s save for a running (or any non-confirmed)
  /// agent: no `restartMode`, close the editor, then say when it applies.
  Future<void> saveAndAnnounce(
    Future<dynamic> Function() save, {
    required bool newSession,
  }) async {
    // The toast outlives this modal: it goes through the root navigator.
    final host = Navigator.of(context, rootNavigator: true).context;
    setState(() => saving = true);
    try {
      final response = await save();
      if (!mounted || !current || !host.mounted) return;
      final canRestart = canRestartAgentAfterSave(
        agent: agent,
        currentUserId: w.client.user?.id,
        controlAgentRuntime: w.can('controlAgentRuntime'),
        external: agent['external'] == true,
      );
      final onSaved = widget.onSaved;
      widget.onClose();
      announceRuntimeConfigApply(
        host,
        configApply: agentConfigApplyOf(response),
        agentActive: isActive,
        agentName: agentRowName(agent),
        newSession: newSession,
        restartNow: canRestart
            ? (mode) async {
                await w.command(
                  'POST',
                  '/agents/${Uri.encodeComponent(agentId)}/reset',
                  data: {'mode': mode},
                );
                await onSaved?.call();
              }
            : null,
      );
    } catch (_) {
      // Shown in the banner (the caller's save wrapper set it).
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Web `handleSaveRuntimeConfiguration` + `saveRuntimeFormV2Edit`.
  Future<void> submit() async {
    setState(() => saveError = null);
    final f = form;
    if (f == null || f.definition == null || saving) return;
    if (!changed) return widget.onClose();
    // Field errors are already shown beside the fields; nothing to send yet.
    if (f.validate().isNotEmpty) return;
    final fields = f.submission;
    final context = this.context;
    Future<dynamic> save({String? restartMode}) async {
      try {
        return await patch(fields, restartMode: restartMode);
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
              where: 'agent runtime save',
            ),
          );
        }
        rethrow;
      }
    }

    // A stopped agent's runtime switch is confirmed: it starts on a new
    // session.
    if (runtimeSwitched && !isActive) {
      String tr(String s) => raftText(context, s);
      widget.onClose(
        RuntimeEditorConfirm(
          title: tr('Switch runtime config'),
          message: raftFormat(
            context,
            'This will switch the runtime from {from} to {to}.',
            {
              'from': runtimeDisplayNameOf(agentRuntime),
              'to': runtimeDisplayNameOf(draftRuntime),
            },
          ),
          confirmLabel: tr('Save runtime change'),
          loadingLabel: tr('Applying…'),
          variant: RaftButtonRecipeVariant.warning,
          operation: () async {
            await save(restartMode: 'session');
          },
        ),
      );
      return;
    }
    // A running agent is not interrupted (Web reconciler step 11c): the change
    // applies at its next idle point and a toast says so. A runtime switch or
    // a Codex model change starts a new session.
    await saveAndAnnounce(
      save,
      newSession:
          runtimeSwitched ||
          (draftRuntime == 'codex' && f.changedKeys.contains('model')),
    );
  }

  // ------------------------------------------------------------- build

  /// `formatRuntimeLabelWithStatus` + `formatRuntimeAvailabilitySuffix`: the
  /// "(deprecated)" status is this server's answer for the row.
  String runtimeLabel(BuildContext context, Map<String, dynamic> option) {
    final id = '${option['runtimeId']}';
    var label = runtimeDisplayNameOf(id);
    if (option['admissionReason'] == 'deprecated') {
      label += raftText(context, ' (deprecated)');
    }
    final info = runtimeInfos.where((r) => r.id == id).firstOrNull;
    if (info != null && !info.supported) {
      label += raftText(context, ' (coming soon)');
    } else if (info != null && !machineRuntimes.contains(id)) {
      label += raftText(
        context,
        info.binary.isEmpty ? ' (update required)' : ' (not installed)',
      );
    }
    return label;
  }

  /// Web `runtimePickerRows`: the server's rows for runtimes this build
  /// names, the agent's own runtime first.
  List<RaftAgentSelectOption<String>> runtimeOptions(BuildContext context) {
    final rows = [
      for (final option in admissions ?? const <Map<String, dynamic>>[])
        if (runtimeInfos.any((r) => r.id == option['runtimeId'] && r.supported))
          option,
    ];
    rows.sort((a, b) {
      int rank(Map<String, dynamic> o) =>
          o['runtimeId'] == agentRuntime ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });
    return [
      for (final option in rows)
        RaftAgentSelectOption(
          '${option['runtimeId']}',
          runtimeLabel(context, option),
          enabled: option['canSelectInThisContext'] == true,
        ),
    ];
  }

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
    String tr(String s) => raftText(context, s);
    final f = form;
    final formLoading = f != null && f.loading && f.definition == null;
    final Widget fields;
    if (admissions == null) {
      fields = const RaftAgentFieldNote('Loading runtime configuration…');
    } else {
      final runtimeField = RaftStableField(
        label: 'Runtime',
        required: true,
        child: RaftAgentSelect<String>(
          key: const ValueKey('runtime-editor-runtime'),
          value: draftRuntime,
          unmatchedLabel: runtimeDisplayNameOf(draftRuntime),
          options: runtimeOptions(context),
          placeholder: 'Select…',
          semanticLabel: tr('Runtime'),
          onChanged: saving ? null : changeRuntime,
        ),
      );
      if (f == null) {
        fields = runtimeField;
      } else {
        fields = RuntimeFormFields(
          key: ValueKey('runtime-form-$draftRuntime'),
          form: f,
          busy: saving,
          rowGap: raftAgentSectionGap,
          // Web `RuntimeFormUnavailableNotice`: loading is information, a
          // failed load a warning with a retry.
          leading: [
            runtimeField,
            if (formLoading)
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
      }
    }
    final footer = RaftAgentDialogFooter(
      children: [
        RaftAgentDialogButton(
          label: tr('Cancel'),
          size: RaftButtonRecipeSize.md,
          onPressed: saving ? null : () => widget.onClose(),
        ),
        RaftAgentDialogButton(
          key: const ValueKey('runtime-editor-save'),
          label: tr('Save Runtime Config'),
          primary: true,
          size: RaftButtonRecipeSize.md,
          onPressed: admissions == null || saveDisabled ? null : submit,
        ),
      ],
    );
    return RaftDialog.agent(
      key: const ValueKey('agent-runtime-editor'),
      surfaceKey: const ValueKey('agent-runtime-editor-surface'),
      bare: true,
      plainCard: true,
      title: 'Edit Runtime Config',
      onClose: saving ? null : () => widget.onClose(),
      footerGap: raftAgentSectionGap,
      footer: footer,
      children: [
        fields,
        // Web `agent.modelDefaultsReported && draftRuntime === "builtin" &&
        // !v2EditChanged`.
        if (RaftAgentFields(agent).modelDefaultsReported == true &&
            draftRuntime == 'builtin' &&
            !changed) ...[
          const SizedBox(height: raftAgentSectionGap),
          const AgentModelLimitsWarning(),
        ],
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
}
