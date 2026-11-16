// Create agent dialog — Web packages/web/src/features/agent/CreateAgentDialog.tsx
// (DialogCard, capacity Banner, COMPUTER / NAME / DESCRIPTION StableFields,
// RuntimeConfigFields: the grouped RUNTIME select + the runtime's protocol-v2
// fields, Cancel / Create footer) and its zero-computer branch.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_name_generator.dart';
import '../data/billing_plans.dart';
import '../data/cause_notice.dart';
import '../data/create_agent_last_config.dart';
import '../data/machine_order.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart' show WorkspaceEntityKind;
import 'agent_hosted_create.dart';
import 'agent_runtime_catalog.dart' show runtimeInfos;
import 'agent_runtime_labels.dart';
import 'delete_server_confirm.dart';
import 'private_route_guard.dart';
import 'runtime_options_request.dart';
import 'runtime_form_dialog.dart';
import 'computer_runtime_sign_in_notice.dart';
import 'runtime_usage_chip.dart' show canViewRuntimeUsage;
import 'runtime_picker_rows.dart';

/// shared MAX_AGENT_DESCRIPTION_LENGTH.
const createAgentDescriptionLimit = 3000;

const _reservedAgentNames = {
  'all',
  'human',
  'humans',
  'agent',
  'agents',
  'here',
  'idle',
  'busy',
  'system',
  'reminders',
};

/// shared validateAgentNameReason → web formatAgentNameValidationError copy.
String? createAgentNameError(BuildContext context, String name) {
  final trimmed = name.trim();
  const label = 'Agent name';
  if (trimmed.isEmpty) {
    return raftFormat(context, '{label} is required', {'label': label});
  }
  final handle = trimmed.replaceFirst(RegExp('^@'), '').toLowerCase();
  if (_reservedAgentNames.contains(handle)) {
    return raftFormat(
      context,
      '{label} @{handle} is reserved. Choose another name.',
      {'label': label, 'handle': handle},
    );
  }
  if (trimmed.length > 32) {
    return raftFormat(context, '{label} must be at most {max} characters', {
      'label': label,
      'max': '32',
    });
  }
  // NAME_REGEX = /^[\p{L}][\p{L}\p{N}_-]*$/u
  if (!RegExp(r'^\p{L}[\p{L}\p{N}_-]*$', unicode: true).hasMatch(trimmed)) {
    return raftText(
      context,
      'Start with a letter, then letters, numbers, - or _',
    );
  }
  return null;
}

class CreateAgentDialog extends StatefulWidget {
  const CreateAgentDialog({
    super.key,
    required this.controller,
    required this.machines,
    this.initialMachineId,
    this.requiredMachineId,
    this.initialName,
    this.initialDescription,
    this.actionCardMessageId,
    this.actionCardConfirmationVersion,
    this.onCreated,
    this.onCreatedDetail,
    this.minimumDaemonVersion,
    this.onConnectComputer,
    this.onboarding = false,
    this.onboardingModal = false,
    this.initialRuntimeId,
    this.onSwitchServer,
    this.closeOnCreated = true,
    this.autoJoinChannelName,
    this.prefilledNameNote,
    this.random,
    this.initialHosting,
    this.initialHostedModel,
  });
  final WorkspaceController controller;
  final bool onboarding, onboardingModal, closeOnCreated;
  final String? initialRuntimeId;
  final VoidCallback? onSwitchServer;

  /// Channel Add members create entry: the channel the new agent joins right
  /// after it is created. Shows the persistent "Will join #channel
  /// automatically" line until submit (Web `autoJoinChannelName`); the caller
  /// does the joining in [onCreated] and keeps the dialog open with
  /// [closeOnCreated] false when it owns what happens next.
  final String? autoJoinChannelName;

  /// Already localized note under the name field about what the caller did to
  /// the prefilled [initialName] (Web `prefilledNameNote`).
  final String? prefilledNameNote;

  /// An `agent:create` card's `hosting` / `model`: preselects the cloud.
  final String? initialHosting, initialHostedModel;

  /// Source of the suggested name and the random pixel avatar (tests pin it).
  final math.Random? random;

  /// `GET /servers/:id/machines` rows the user may create on.
  final List<Map<String, dynamic>> machines;
  final String? initialMachineId, requiredMachineId;
  final String? initialName, initialDescription, actionCardMessageId;
  final int? actionCardConfirmationVersion;
  final void Function(Map<String, dynamic>)? onCreated;

  /// After [onCreated], with what only the dialog knows: whether this was the
  /// server's first agent (Web `wasFirstAgent`, counted before the create call;
  /// onboarding always is). The Created toast is not for a first agent.
  final void Function(
    Map<String, dynamic> agent, {
    required bool wasFirstAgent,
  })?
  onCreatedDetail;

  /// The lowest Computer (daemon) version the agent being created needs
  /// (Web `minimumDaemonVersion`): an older or unknown-version Computer is
  /// disabled in the picker and a line under it says why.
  final String? minimumDaemonVersion;

  /// Zero-computer branch CTA ("Connect a Computer").
  final VoidCallback? onConnectComputer;
  @override
  State<CreateAgentDialog> createState() => _CreateAgentDialogState();
}

class _CreateAgentDialogState extends State<CreateAgentDialog> {
  WorkspaceController get w => widget.controller;
  late final int generation;
  late final String openingAuthority;
  bool get currentAuthority =>
      mounted &&
      generation == w.client.generation &&
      openingAuthority == workspaceAuthority(w) &&
      w.can('createAgents');
  final name = TextEditingController(), description = TextEditingController();
  late final math.Random random = widget.random ?? math.Random();

  /// The "Cloud agent" choice of the Computer picker.
  late final HostedCreateChoice hosted = HostedCreateChoice(
    w,
    enabled: !widget.onboarding && widget.requiredMachineId == null,
    noComputers: widget.machines.isEmpty,
    prefilledHosting: widget.initialHosting,
    prefilledModel: widget.initialHostedModel,
  );

  /// The last computer and runtime created with on this server (Web
  /// `rememberedConfig`); null for onboarding, which never uses it.
  CreateAgentLastConfig? remembered;
  String? machineId, runtime;

  /// The server's admission rows for the selected computer, all of them (the
  /// picker groups them; `canSelectInThisContext` decides what can be picked).
  List<Map<String, dynamic>> runtimeOptions = [];
  RuntimeFormController? form;
  Map<String, dynamic>? billing;

  /// Show all supported belongs to the computer it was asked for: another
  /// computer starts collapsed again (Web `showAllRuntimesFor`).
  String? showAllFor;
  bool busy = false, validationAttempted = false;
  bool runtimesRescanning = false;
  bool runtimeOptionsLoading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts or the name is edited; the dialog state is dropped when it closes.
  String? error;
  int machineTicket = 0;

  /// A failed runtime rescan: it describes the computer it ran on, so it ends
  /// with a retry, a successful rescan or a switch to another computer.
  late final rescanError = CauseNotice(scope: () => machineTicket);
  late final runtimeOptionsError = CauseNotice(scope: () => machineTicket);

  String? get userId => w.client.user?.id;

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    openingAuthority = workspaceAuthority(w);
    remembered = widget.onboarding
        ? null
        : CreateAgentLastConfig.read(w.server?.id);
    // A fresh create starts with a suggested `adjective-noun` name; a prefill
    // (even an empty one) keeps what the caller gave.
    name.text = widget.onboarding
        ? 'Cindy'
        : widget.initialName ??
              suggestAgentName(exclude: takenAgentNames(), random: random);
    description.text = widget.onboarding
        ? 'Onboarding agent'
        : widget.initialDescription ?? '';
    // An invalid prefill reports from the first render (task #1139 E-state).
    validationAttempted = name.text.isNotEmpty && _nameReasonInvalid(name.text);
    machineId = initialMachineId();
    w.addListener(authorityChanged);
    hosted
      ..addListener(authorityChanged)
      ..start();
    loadBilling();
    if (machineId != null) selectMachine(machineId!);
  }

  bool _usable(Map<String, dynamic>? m) =>
      m != null &&
      m['status'] == 'online' &&
      machineMeetsDaemonRequirement(m, widget.minimumDaemonVersion);

  /// Web `selectedMachineId`'s initial value: the required computer, the
  /// caller's suggestion, the last one used, else an online computer of the
  /// viewer's own before any other. Nothing is chosen when none is usable.
  String? initialMachineId() {
    final byId = {for (final m in widget.machines) m['id']: m};
    final required = widget.requiredMachineId;
    if (required != null) return required;
    final suggested = byId[widget.initialMachineId];
    if (suggested != null) return widget.initialMachineId;
    final last = byId[remembered?.machineId];
    if (_usable(last)) return remembered!.machineId;
    return pickFallbackMachine(
          widget.machines,
          widget.minimumDaemonVersion,
          userId,
        )?['id']
        as String?;
  }

  @override
  void didUpdateWidget(CreateAgentDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The computer list arrives or changes in place (Web's one-shot waiter):
    // nothing chosen yet, so choose now; a choice the person made stays.
    if (machineId == null && widget.machines != oldWidget.machines) {
      final next = initialMachineId();
      if (next != null &&
          _usable(widget.machines.where((m) => m['id'] == next).firstOrNull)) {
        selectMachine(next);
      }
    }
  }

  void authorityChanged() {
    if (mounted) setState(() {});
  }

  /// Names already used on this server by agents or human members, so a
  /// suggested name avoids them (Web `takenAgentNames`).
  List<String> takenAgentNames() => [
    for (final a in w.services.entityDirectory.rows(WorkspaceEntityKind.agents))
      if (a['deletedAt'] == null && a['name'] is String) a['name'] as String,
    for (final m in w.services.entityDirectory.rows(
      WorkspaceEntityKind.members,
    ))
      if (m['name'] is String) m['name'] as String,
  ];

  /// Web `agents.length === 0` (before the create call): the server's first
  /// agent gets no Created toast.
  bool get noAgentsYet => !w.services.entityDirectory
      .rows(WorkspaceEntityKind.agents)
      .any((a) => a['deletedAt'] == null);

  void suggestName() {
    if (busy) return;
    setState(() {
      name.text = suggestAgentName(
        exclude: [name.text, ...takenAgentNames()],
        random: random,
      );
      error = null;
    });
  }

  static bool _nameReasonInvalid(String v) {
    final t = v.trim();
    return t.isEmpty ||
        _reservedAgentNames.contains(t.replaceFirst('@', '').toLowerCase()) ||
        t.length > 32 ||
        !RegExp(r'^\p{L}[\p{L}\p{N}_-]*$', unicode: true).hasMatch(t);
  }

  @override
  void dispose() {
    w.removeListener(authorityChanged);
    hosted.dispose();
    form?.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get machine =>
      widget.machines.where((m) => m['id'] == machineId).firstOrNull;

  Future<void> loadBilling() async {
    try {
      final value = await w.query('/billing/subscription');
      if (currentAuthority && value is Map) {
        setState(() => billing = Map<String, dynamic>.from(value));
      }
    } catch (_) {
      // Web loadBilling: a failed summary just leaves the banner off.
    }
  }

  /// shared getBillingCapacityLimitState(capacity, usage, "agent").
  ({String label, num usage, num limit})? get capacityReached {
    final capacity = billing?['capacity'], usage = billing?['usage'];
    if (capacity is! Map || usage is! Map) return null;
    final maxAgents = capacity['maxAgents'], agents = usage['agents'];
    if (maxAgents is num && agents is num && maxAgents != -1) {
      if (agents + 1 > maxAgents) {
        return (label: 'Agent limit', usage: agents, limit: maxAgents);
      }
    }
    final maxSeats = capacity['maxUniversalSeats'],
        seats = usage['universalSeats'];
    if (maxSeats is num && seats is num && maxSeats != -1) {
      if (seats + RaftBillingPlans.proAgentSeatFraction > maxSeats) {
        return (label: 'Seat limit', usage: seats, limit: maxSeats);
      }
    }
    return null;
  }

  /// The admission rows of runtimes this build knows (Web: `getRuntimeInfo(id)
  /// ?.supported`), in the server's order.
  List<Map<String, dynamic>> _supportedRows(Object? catalog) => [
    for (final o
        in (catalog is Map ? catalog['options'] as List? ?? [] : [])
            .whereType<Map>())
      if (runtimeInfos.any((r) => r.id == o['runtimeId'] && r.supported))
        Map<String, dynamic>.from(o),
  ];

  List<String> get _availableRuntimes => [
    for (final o in runtimeOptions)
      if (o['canSelectInThisContext'] == true) o['runtimeId'] as String,
  ];

  /// Web `pickCreateAgentRuntime`: onboarding prefers Claude, Codex, Grok and
  /// Built-in; a create restores the last runtime when it is still offered.
  String pickRuntime() {
    final available = _availableRuntimes;
    String? firstSupported(Iterable<String> ids) => ids
        .where((id) => runtimeInfos.any((r) => r.id == id && r.supported))
        .firstOrNull;
    if (widget.onboarding) {
      return const ['claude', 'codex', 'grok', 'builtin']
              .where(available.contains)
              .where((id) => runtimeInfos.any((r) => r.id == id && r.supported))
              .firstOrNull ??
          firstSupported(available) ??
          available.firstOrNull ??
          '';
    }
    final last = remembered?.runtime;
    if (last != null &&
        available.contains(last) &&
        runtimeInfos.any((r) => r.id == last && r.supported)) {
      return last;
    }
    return firstSupported(available) ?? available.firstOrNull ?? '';
  }

  Future<void> selectMachine(String id) async {
    final ticket = ++machineTicket;
    form?.dispose();
    setState(() {
      machineId = id;
      runtime = null;
      form = null;
      runtimeOptions = [];
      runtimeOptionsLoading = true;
      runtimeOptionsError.clear();
    });
    try {
      final catalog = await readRuntimeOptions(
        () => w.query('/servers/${w.server!.id}/machines/$id/runtime-options'),
      );
      if (!currentAuthority || ticket != machineTicket) return;
      setState(() => runtimeOptions = _supportedRows(catalog));
      final available = _availableRuntimes;
      if (available.isNotEmpty) {
        final initial = available.contains(widget.initialRuntimeId)
            ? widget.initialRuntimeId
            : null;
        selectRuntime(initial ?? pickRuntime());
      }
    } catch (failure) {
      if (currentAuthority && ticket == machineTicket) {
        setState(
          () => runtimeOptionsError.raise(
            userErrorText(
              failure,
              fallback: 'Could not load runtimes. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (currentAuthority && ticket == machineTicket) {
        setState(() => runtimeOptionsLoading = false);
      }
    }
  }

  Future<void> rescanRuntimes() async {
    final id = machineId;
    if (!currentAuthority || id == null || busy || runtimesRescanning) return;
    final ticket = machineTicket;
    setState(() {
      runtimesRescanning = true;
      rescanError.clear();
    });
    try {
      await w.command(
        'POST',
        '/servers/${w.server!.id}/machines/$id/runtimes/rescan',
      );
      if (!currentAuthority || ticket != machineTicket) return;
      final catalog = await readRuntimeOptions(
        () => w.query('/servers/${w.server!.id}/machines/$id/runtime-options'),
      );
      if (!currentAuthority || ticket != machineTicket) return;
      setState(() {
        runtimeOptions = _supportedRows(catalog);
        if (runtime != null && !_availableRuntimes.contains(runtime)) {
          runtime = null;
          form?.dispose();
          form = null;
        }
      });
    } catch (e) {
      if (currentAuthority && ticket == machineTicket) {
        setState(
          () => rescanError.raise(
            userErrorText(
              e,
              fallback: raftGenericErrorText,
              where: 'rescan runtimes',
            ),
          ),
        );
      }
    } finally {
      if (currentAuthority && ticket == machineTicket) {
        setState(() => runtimesRescanning = false);
      }
    }
  }

  void selectRuntime(String id) {
    form?.dispose();
    final next = RuntimeFormController(
      w,
      machineId: machineId!,
      runtimeId: id,
      valid: () => currentAuthority,
      language: runtimeFormLanguageTag(context),
    );
    // Web `runtimeHasFormV2`: a row without the v2 marker has no form here.
    final row = runtimeOptions.where((o) => o['runtimeId'] == id).firstOrNull;
    if (row?['runtimeFormV2'] == null) {
      next.markUnavailable();
    } else {
      next.load();
    }
    setState(() {
      runtime = id;
      form = next;
    });
  }

  /// Web `rememberedConfig` write after a successful create: only the
  /// computer and runtime; the runtime's server form owns its defaults.
  void rememberConfig() {
    final id = machineId, selected = runtime;
    if (widget.onboarding || id == null || selected == null) return;
    CreateAgentLastConfig(machineId: id, runtime: selected).write(w.server?.id);
  }

  bool get createDisabled {
    final f = form;
    if (hosted.active) {
      // A cloud agent needs a name and, while it loads, the model list.
      return capacityReached != null ||
          hosted.loading ||
          name.text.trim().isEmpty;
    }
    return runtimesRescanning ||
        capacityReached != null ||
        machine == null ||
        (widget.requiredMachineId != null &&
            machineId != widget.requiredMachineId) ||
        machine?['status'] != 'online' ||
        !machineMeetsDaemonRequirement(machine, widget.minimumDaemonVersion) ||
        runtime == null ||
        !_availableRuntimes.contains(runtime) ||
        f == null ||
        f.loading ||
        f.unavailable ||
        f.definition == null ||
        f.missingRequired ||
        name.text.trim().isEmpty;
  }

  Future<void> submit() async {
    final f = form;
    final cloud = hosted.active;
    if (busy || createDisabled || (f == null && !cloud) || !currentAuthority) {
      return;
    }
    setState(() => validationAttempted = true);
    final Map<String, String> problems = cloud ? const {} : f!.validate();
    if (createAgentNameError(context, name.text) != null ||
        problems.isNotEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      // Counted before the create call mutates the directory (Web
      // `wasFirstAgent`): onboarding is first-agent territory by definition.
      final wasFirstAgent = widget.onboarding || noAgentsYet;
      final created = await w.command(
        'POST',
        '/agents',
        data: {
          'name': name.text.trim(),
          'description': description.text.trim(),
          if (!cloud) ...{'machineId': machineId, 'runtime': runtime},
          if (widget.onboarding) 'onboarding': true,
          // Web: Cindy gets the mug, every other new agent a random preset.
          'avatarUrl': widget.onboarding
              ? 'pixel:mug'
              : 'pixel:${raftAgentAvatarChoices[random.nextInt(raftAgentAvatarChoices.length)]}',
          if (widget.actionCardMessageId != null)
            'actionCardMessageId': widget.actionCardMessageId,
          if (widget.actionCardConfirmationVersion != null)
            'actionCardConfirmationVersion':
                widget.actionCardConfirmationVersion,
          if (cloud) ...hosted.submission else ...f!.submission,
        },
      );
      if (mounted && currentAuthority) {
        if (!cloud) rememberConfig();
        if (created is Map) {
          final agent = Map<String, dynamic>.from(created);
          widget.onCreatedDetail?.call(agent, wasFirstAgent: wasFirstAgent);
          widget.onCreated?.call(agent);
        }
        if (widget.closeOnCreated &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        // Web: `data.error || agent.create.failedCreate`, and each `issues`
        // pointer marks its runtime-form field.
        setState(() {
          f?.serverErrors = runtimeFormIssueErrors(
            e,
            fallback: 'Failed to create agent',
          );
          error = userErrorText(
            e,
            fallback: 'Failed to create agent',
            where: 'create agent',
          );
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void close() {
    if (!busy) Navigator.pop(context);
  }

  Widget needsComputer(BuildContext context) => RaftDialog.agent(
    title: 'Create agent',
    onClose: close,
    children: [
      const RaftAgentBanner(
        status: RaftAgentBannerStatus.info,
        title: 'Connect a computer first',
        description: 'Agents run on your computer. Connect one and Raft will detect the runtimes on it, then you can create agents here.',
      ),
      const SizedBox(height: raftAgentSectionGap), // mt-4
      RaftAgentDialogFooter(
        children: [
          RaftAgentDialogButton(label: 'Cancel', onPressed: close),
          RaftAgentDialogButton(
            label: 'Add computer',
            primary: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onConnectComputer?.call();
            },
          ),
        ],
      ),
    ],
  );

  /// Web `machineOptions`: `name (hostname)` plus " · Offline" and
  /// " · Update required"; an offline computer, one the action card did not
  /// ask for and one whose daemon is too old are disabled.
  RaftAgentSelectOption<String> computerOption(
    BuildContext context,
    Map<String, dynamic> m,
  ) {
    final offline = m['status'] != 'online';
    final blocked =
        widget.requiredMachineId != null && m['id'] != widget.requiredMachineId;
    final tooOld = !machineMeetsDaemonRequirement(
      m,
      widget.minimumDaemonVersion,
    );
    final hostname = m['hostname'];
    return RaftAgentSelectOption(
      m['id'] as String,
      '${m['name'] ?? m['id']}'
      '${hostname is String && hostname.isNotEmpty ? ' ($hostname)' : ''}'
      '${offline ? raftText(context, ' · Offline') : ''}'
      '${tooOld && widget.minimumDaemonVersion != null ? raftText(context, ' · Update required') : ''}',
      enabled: !(offline || blocked || tooOld),
    );
  }

  /// The runtime field's rows (Web `runtimePickerRows`): one per admission row
  /// this build knows. Onboarding keeps one flat list with suffixes; a create
  /// groups them by whether they can run on this computer right now.
  List<RaftAgentSelectOption<String>> runtimePickerOptions(
    BuildContext context,
  ) {
    final installed = machine?['runtimes'] is List
        ? [for (final r in machine!['runtimes'] as List) '$r']
        : const <String>[];
    final experimental = raftText(context, 'Experimental');
    final rows = [
      for (final o in runtimeOptions)
        () {
          final id = o['runtimeId'] as String;
          final deprecated = o['admissionReason'] == 'deprecated';
          return RuntimePickerRow(
            value: id,
            label: runtimeLabelBesideBadge(context, id, deprecated: deprecated),
            availabilitySuffix: runtimeAvailabilitySuffixText(
              context,
              id,
              installed,
            ),
            experimental: runtimeShowsExperimentalBadge(
              id,
              deprecated: deprecated,
            ),
            disabled: o['canSelectInThisContext'] != true,
            capabilityStatus: '${o['capabilityStatus'] ?? 'available'}',
            selectable: o['canSelectInThisContext'] == true,
          );
        }(),
    ];
    if (widget.onboarding) {
      return flatRuntimePickerOptions(rows, experimentalLabel: experimental);
    }
    final showAll = showAllFor != null && showAllFor == machineId;
    final grouped = groupRuntimePickerRows(
      rows,
      showAll: showAll,
      selectedValue: runtime ?? '',
      labels: RuntimePickerGroupLabels(
        current: raftText(context, 'Current runtime'),
        ready: raftText(context, 'Ready on this computer'),
        notAvailable: raftText(context, 'Not available on this server'),
        needsUpdate: raftText(context, 'Needs a Raft Computer update'),
        notInstalled: raftText(context, 'Not installed on this computer'),
      ),
      experimentalLabel: experimental,
    );
    final action = runtimeShowAllAction(
      canToggle: grouped.canToggle,
      showAll: showAll,
      showAllLabel: raftText(context, 'Show all supported'),
      installedOnlyLabel: raftText(context, 'Show installed only'),
      onToggle: () => setState(() => showAllFor = showAll ? null : machineId),
    );
    return [...grouped.options, ?action];
  }

  @override
  Widget build(BuildContext context) {
    if (!currentAuthority) return const SizedBox.shrink();
    if (widget.machines.isEmpty && widget.onboarding) {
      return RaftCindySetupScreen(
        fields: RaftAgentBanner(
          status: RaftAgentBannerStatus.info,
          title: 'Connect a computer first',
          description: 'Cindy runs on your computer, and there is none connected yet. Once one is online, Raft detects the runtimes on it and this step fills itself in.',
          action: 'Add computer',
          onAction: widget.onConnectComputer,
        ),
        onCreate: null,
        onClose: widget.onboardingModal ? close : null,
      );
    }
    hosted.noComputers = widget.machines.isEmpty;
    // With no computer, the cloud (where offered) is the place to run.
    if (widget.machines.isEmpty && !hosted.offered) {
      return PopScope(canPop: !busy, child: needsComputer(context));
    }
    final cloud = hosted.active;
    final capacity = capacityReached;
    final tokens = RaftTokens.of(context);
    final legacyDarkWarning = tokens.dark && !tokens.isRaftLook;
    final nameError = validationAttempted
        ? createAgentNameError(context, name.text)
        : null;
    final f = form;
    final shownError = error ?? rescanError.message;
    final leading = <Widget>[
      if (widget.autoJoinChannelName case final channel?)
        RaftAgentContextLine(
          raftFormat(
            context,
            'Will join {channel} automatically after it is created',
            {'channel': '#$channel'},
          ),
        ),
      if (capacity != null)
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
          // Web uses the warning Banner recipe without caller overrides.
          // Retain the prior colours in the frozen legacy looks.
          backgroundColor: legacyDarkWarning
              ? tokens.colors['warning-soft']
              : null,
          foregroundColor: legacyDarkWarning
              ? tokens.colors['warning-strong']
              : null,
          actionForeground: legacyDarkWarning
              ? tokens.colors['warning-strong']
              : null,
          description: raftFormat(
            context,
            '{limitLabel} reached ({usage}/{limit} on {planName} plan).',
            {
              'limitLabel': raftText(context, capacity.label),
              'usage': '${capacity.usage}',
              'limit': '${capacity.limit}',
              'planName': '${billing?['displayName'] ?? 'Free'}',
            },
          ),
          action: tokens.isRaftLook ? 'Upgrade for more' : 'Upgrade for More',
          actionSeparator:
              tokens.isRaftLook &&
                  Localizations.maybeLocaleOf(context)?.languageCode == 'zh'
              ? ''
              : ' ',
          // Web: onClose(); nav.toSettings("billing").
          onAction: () {
            if (busy) return;
            close();
            w.setSection('billing');
          },
        )
      else if (shownError != null)
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
          description: shownError,
          // Web isQuotaError: the server's "... limit reached" text gets an
          // inline View Plans link to Settings > Billing.
          action: shownError.contains('limit reached') ? 'View plans' : null,
          onAction: shownError.contains('limit reached')
              ? () {
                  if (busy) return;
                  close();
                  w.setSection('billing');
                }
              : null,
        ),
      if (!cloud && runtimeOptionsLoading)
        const Center(key: Key('runtime-options-loading'), child: RaftSpinner())
      else if (runtimeOptionsError.message case final message? when !cloud)
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
          description: message,
          action: 'Retry',
          onAction: () => selectMachine(machineId!),
        ),
      if (!widget.onboarding)
        RaftStableField(
          label: 'Computer',
          required: true,
          hint: switch (widget.minimumDaemonVersion) {
            final version? when !cloud => raftFormat(
              context,
              'Use a Computer updated to {version} or newer.',
              {'version': version},
            ),
            _ => null,
          },
          child: RaftAgentSelect<String>(
            value: cloud ? hostedComputerChoice : machineId,
            semanticLabel: raftText(context, 'Computer'),
            options: [
              for (final m in orderMachinesLikeSidebar(
                widget.machines,
                userId: userId,
              ))
                computerOption(context, m),
              if (hosted.offered) hosted.option(context),
            ],
            onChanged: busy || widget.requiredMachineId != null
                ? null
                : (id) {
                    hosted.select(id == hostedComputerChoice);
                    if (id != hostedComputerChoice && id != machineId) {
                      selectMachine(id);
                    }
                  },
          ),
        ),
      if (!widget.onboarding)
        RaftStableField(
          label: 'Name',
          required: true,
          error: nameError,
          labelAccessory: RaftRecipeButton(
            key: const Key('create-agent-random-name'),
            glyph: RaftGlyph.dices,
            glyphSize: 12,
            size: RaftButtonRecipeSize.iconSm,
            variant: RaftButtonRecipeVariant.ghost,
            tooltip: 'Suggest a random name',
            onPressed: busy ? null : suggestName,
          ),
          child: RaftAgentTextInput(
            controller: name,
            placeholder: 'e.g. Alice',
            invalid: nameError != null,
            enabled: !busy,
            semanticLabel: raftText(context, 'Agent name'),
            onChanged: (_) => setState(() => error = null),
          ),
        ),
      if (!widget.onboarding) ...[
        if (widget.prefilledNameNote case final note?) RaftAgentHintNote(note),
      ],
      if (!widget.onboarding)
        RaftStableField(
          label: 'Description',
          counter: '${description.text.length}/$createAgentDescriptionLimit',
          child: RaftAgentTextInput(
            controller: description,
            multiline: true,
            maxLength: createAgentDescriptionLimit,
            enabled: !busy,
            placeholder:
                'Leave blank for a general-purpose agent, or describe a role…',
            semanticLabel: raftText(context, 'Description'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      RaftStableField(
        label: 'Runtime',
        required: true,
        // Web `runtimeBelowDescription`: signed out is said, never enforced.
        belowDescription: RuntimeSignInNotice(
          controller: w,
          serverId: w.server?.id,
          machineId: machineId,
          machineName:
              machine?['name'] as String? ?? raftText(context, 'this Computer'),
          runtimeId: runtime ?? '',
          enabled: canViewRuntimeUsage(w, machine),
        ),
        labelAccessory: widget.onboarding
            ? RaftRecipeButton(
                key: const Key('cindy-rescan-runtimes'),
                glyph: RaftGlyph.refreshCw,
                glyphSize: 12,
                size: RaftButtonRecipeSize.iconXs,
                variant: RaftButtonRecipeVariant.ghost,
                tooltip: 'Rescan Runtimes on This Computer',
                onPressed: busy || runtimesRescanning ? null : rescanRuntimes,
              )
            : null,
        child: RaftAgentSelect<String>(
          value: runtime,
          placeholder: 'Select…',
          semanticLabel: raftText(context, 'Runtime'),
          options: runtimePickerOptions(context),
          onChanged: busy
              ? null
              : (id) => id == runtime ? null : selectRuntime(id),
        ),
      ),
    ];
    // A cloud agent has no runtime: that field is the last row.
    if (cloud) leading.removeLast();
    if (widget.onboarding) {
      Widget fields() => f == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in leading.indexed) ...[
                  if (i > 0) const SizedBox(height: raftCindyFieldGap),
                  i == 0 && capacity != null
                      ? Padding(
                          padding: raftCindyCapacityFieldInset,
                          child: row,
                        )
                      : row,
                ],
              ],
            )
          : RuntimeFormFields(
              form: f,
              busy: busy,
              leading: [
                for (final (i, row) in leading.indexed)
                  i == 0 && capacity != null
                      ? Padding(
                          padding: raftCindyCapacityFieldInset,
                          child: row,
                        )
                      : row,
              ],
              rowGap: raftCindyFieldGap,
            );
      return PopScope(
        canPop: !busy,
        child: ListenableBuilder(
          listenable: f ?? const AlwaysStoppedAnimation(0),
          builder: (context, _) => RaftCindySetupScreen(
            fields: fields(),
            onClose: widget.onboardingModal ? close : null,
            onCreate: createDisabled ? null : submit,
            busy: busy,
            sessionActions: switch (setupSessionActions(
              context,
              w,
              onSwitchServer: widget.onSwitchServer,
              busy: busy,
            )) {
              final actions? => Align(
                alignment: Alignment.centerLeft,
                child: actions,
              ),
              null => null,
            },
          ),
        ),
      );
    }
    return PopScope(
      canPop: !busy,
      child: RaftDialog.agent(
        title: 'Create agent',
        onClose: close,
        footerGap: raftAgentFormGap,
        footer: ListenableBuilder(
          listenable: f ?? const AlwaysStoppedAnimation(0),
          builder: (context, _) => RaftAgentDialogFooter(
            children: [
              RaftAgentDialogButton(label: 'Cancel', onPressed: close),
              RaftAgentDialogButton(
                label: 'Create',
                primary: true,
                // CreateAgentDialog.tsx2103 caller; other primary buttons keep defaults.
                foreground: tokens.dark
                    ? tokens.colors['foreground-inverse']
                    : null,
                busy: busy,
                onPressed: createDisabled ? null : submit,
              ),
            ],
          ),
        ),
        children: [
          if (f == null || cloud)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, row) in [
                  ...leading,
                  if (cloud) ...hosted.fields(context, busy: busy),
                ].indexed) ...[
                  if (i > 0) const SizedBox(height: raftAgentFormGap),
                  row,
                ],
              ],
            )
          else
            ListenableBuilder(
              listenable: f,
              builder: (context, _) => RuntimeFormFields(
                form: f,
                busy: busy,
                leading: [
                  ...leading,
                  if (f.loading)
                    const Center(child: RaftSpinner())
                  else if (f.error != null)
                    RaftAgentBanner(
                      status: RaftAgentBannerStatus.warning,
                      description: f.error!,
                      action: 'Retry',
                      onAction: f.load,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
