// Create Agent dialog — Web packages/web/src/components/agent/CreateAgentDialog.tsx
// (DialogCard, capacity Banner, COMPUTER / NAME / DESCRIPTION StableFields,
// RuntimeConfigFields: RUNTIME select + the runtime's protocol-v2 fields,
// Cancel / Create Agent footer) and its zero-computer branch.
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'agent_metadata_catalog.dart';
import 'private_route_guard.dart';
import 'runtime_form_dialog.dart';

/// shared/src/runtimeCatalog.ts `RUNTIMES[].displayName`.
const createAgentRuntimeNames = {
  'claude': 'Claude Code',
  'codex': 'Codex CLI',
  'grok': 'Grok Build',
  'builtin': 'Built-in Pi',
  'antigravity': 'Antigravity CLI',
  'kimi-sdk': 'Kimi Code',
  'kimi': 'Kimi CLI',
  'copilot': 'Copilot CLI',
  'cursor': 'Cursor CLI',
  'gemini': 'Gemini CLI',
  'opencode': 'OpenCode',
  'pi': 'Pi',
};

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
    this.onConnectComputer,
    this.onboarding = false,
    this.onboardingModal = false,
    this.initialRuntimeId,
    this.onSwitchServer,
    this.closeOnCreated = true,
  });
  final WorkspaceController controller;
  final bool onboarding, onboardingModal, closeOnCreated;
  final String? initialRuntimeId;
  final VoidCallback? onSwitchServer;

  /// `GET /servers/:id/machines` rows the user may create on.
  final List<Map<String, dynamic>> machines;
  final String? initialMachineId, requiredMachineId;
  final String? initialName, initialDescription, actionCardMessageId;
  final int? actionCardConfirmationVersion;
  final void Function(Map<String, dynamic>)? onCreated;

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
  final preAdmissionEnv = TextEditingController();
  String? machineId, runtime;
  List<Map<String, dynamic>> runtimeOptions = [];
  RuntimeFormController? form;
  Map<String, dynamic>? billing;

  /// Pre-admission model picker (Web: the declared Claude source shown while
  /// no runtime is selected) — `null` while loading.
  String preAdmissionModel = '';
  List<Map<String, dynamic>>? preAdmissionModels;
  bool preAdmissionLive = false, preAdmissionLoading = false;
  bool moreOpen = false, busy = false, validationAttempted = false;
  bool runtimesRescanning = false;
  String? error;
  int machineTicket = 0;

  @override
  void initState() {
    super.initState();
    generation = w.client.generation;
    openingAuthority = workspaceAuthority(w);
    name.text = widget.onboarding ? 'Cindy' : widget.initialName ?? '';
    description.text = widget.onboarding
        ? 'Onboarding Assistant'
        : widget.initialDescription ?? '';
    // An invalid prefill reports from the first render (task #1139 E-state).
    validationAttempted = name.text.isNotEmpty && _nameReasonInvalid(name.text);
    final ids = [for (final m in widget.machines) m['id'] as String?];
    machineId =
        widget.requiredMachineId ??
        (ids.contains(widget.initialMachineId)
            ? widget.initialMachineId
            : widget.machines
                      .where((m) => m['status'] == 'online')
                      .firstOrNull?['id'] ??
                  ids.firstOrNull);
    w.addListener(authorityChanged);
    loadBilling();
    if (machineId != null) selectMachine(machineId!);
  }

  void authorityChanged() {
    if (mounted) setState(() {});
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
    form?.dispose();
    name.dispose();
    description.dispose();
    preAdmissionEnv.dispose();
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
      // PRO_AGENT_SEAT_FRACTION
      if (seats + .25 > maxSeats) {
        return (label: 'Seat limit', usage: seats, limit: maxSeats);
      }
    }
    return null;
  }

  Future<void> selectMachine(String id) async {
    final ticket = ++machineTicket;
    form?.dispose();
    setState(() {
      machineId = id;
      runtime = null;
      form = null;
      runtimeOptions = [];
      preAdmissionModels = null;
      preAdmissionModel = '';
    });
    final runtimes = machine?['runtimes'];
    if (runtimes is List && runtimes.contains('claude')) loadPreAdmission();
    try {
      final catalog = await w.query(
        '/servers/${w.server!.id}/machines/$id/runtime-options',
      );
      if (!currentAuthority || ticket != machineTicket) return;
      final options = [
        for (final o in (catalog['options'] as List? ?? []).whereType<Map>())
          if (o['canSelectInThisContext'] == true &&
              createAgentRuntimeNames.containsKey(o['runtimeId']))
            Map<String, dynamic>.from(o),
      ];
      setState(() => runtimeOptions = options);
      if (options.isNotEmpty) {
        final initial = options
            .where((o) => o['runtimeId'] == widget.initialRuntimeId)
            .firstOrNull;
        selectRuntime((initial ?? options.first)['runtimeId']);
      }
    } catch (_) {
      // No admission catalog: the runtime stays unselected ("Select...").
    }
  }

  Future<void> rescanRuntimes() async {
    final id = machineId;
    if (!currentAuthority || id == null || busy || runtimesRescanning) return;
    final ticket = machineTicket;
    setState(() => runtimesRescanning = true);
    try {
      await w.command(
        'POST',
        '/servers/${w.server!.id}/machines/$id/runtimes/rescan',
      );
      if (!currentAuthority || ticket != machineTicket) return;
      final catalog = await w.query(
        '/servers/${w.server!.id}/machines/$id/runtime-options',
      );
      if (!currentAuthority || ticket != machineTicket) return;
      final options = [
        for (final o in (catalog['options'] as List? ?? []).whereType<Map>())
          if (o['canSelectInThisContext'] == true &&
              createAgentRuntimeNames.containsKey(o['runtimeId']))
            Map<String, dynamic>.from(o),
      ];
      setState(() {
        runtimeOptions = options;
        if (runtime != null && !options.any((o) => o['runtimeId'] == runtime)) {
          runtime = null;
          form?.dispose();
          form = null;
        }
      });
    } catch (e) {
      if (currentAuthority && ticket == machineTicket) {
        setState(() => error = '$e');
      }
    } finally {
      if (currentAuthority && ticket == machineTicket) {
        setState(() => runtimesRescanning = false);
      }
    }
  }

  Future<void> loadPreAdmission({bool refresh = false}) async {
    final id = machineId;
    final fallback = <Map<String, dynamic>>[
      for (final e in sourceRuntimeModelLabels['claude']!.entries)
        {'id': e.key, 'label': e.value, 'verified': 'suggestion_only'},
    ];
    setState(() => preAdmissionLoading = true);
    var models = fallback;
    var live = false;
    try {
      final result = await w.query(
        '/servers/${w.server!.id}/machines/$id/runtime-models/claude',
        query: refresh ? {'refresh': 1} : null,
      );
      final value = result is Map && result['kind'] == 'live'
          ? result['value']
          : result;
      if (value is Map && value['models'] is List) {
        models = [
          for (final m in (value['models'] as List).whereType<Map>())
            Map<String, dynamic>.from(m),
        ];
        live = true;
      }
    } catch (_) {
      // The machine source failed: the bundled catalog stays as suggestions.
    }
    if (!currentAuthority || id != machineId) return;
    setState(() {
      preAdmissionLoading = false;
      preAdmissionLive = live;
      preAdmissionModels = models;
      if (!models.any((m) => m['id'] == preAdmissionModel)) {
        preAdmissionModel = '${models.firstOrNull?['id'] ?? ''}';
      }
    });
  }

  void selectRuntime(String id) {
    form?.dispose();
    final next = RuntimeFormController(
      w,
      machineId: machineId!,
      runtimeId: id,
      valid: () => currentAuthority,
    );
    Map<String, String>? env;
    try {
      env = parseRuntimeStringMap(preAdmissionEnv.text);
    } on FormatException {
      env = null;
    }
    next.load(
      seed: {
        if (id == 'claude' && preAdmissionModel.isNotEmpty)
          'model': preAdmissionModel,
        if (env != null && env.isNotEmpty) 'envVars': env,
      },
    );
    setState(() {
      runtime = id;
      form = next;
      moreOpen = false;
    });
  }

  bool get createDisabled {
    final f = form;
    return runtimesRescanning ||
        capacityReached != null ||
        machine == null ||
        (widget.requiredMachineId != null &&
            machineId != widget.requiredMachineId) ||
        machine?['status'] != 'online' ||
        runtime == null ||
        f == null ||
        f.loading ||
        f.definition == null ||
        f.missingRequired ||
        name.text.trim().isEmpty;
  }

  Future<void> submit() async {
    final f = form;
    if (busy || createDisabled || f == null || !currentAuthority) return;
    setState(() => validationAttempted = true);
    final problems = f.validate();
    if (createAgentNameError(context, name.text) != null ||
        problems.isNotEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final created = await w.command(
        'POST',
        '/agents',
        data: {
          'name': name.text.trim(),
          'description': description.text.trim(),
          'machineId': machineId,
          'runtime': runtime,
          if (widget.onboarding) ...{
            'onboarding': true,
            'avatarUrl': 'pixel:mug',
          },
          if (widget.actionCardMessageId != null)
            'actionCardMessageId': widget.actionCardMessageId,
          if (widget.actionCardConfirmationVersion != null)
            'actionCardConfirmationVersion':
                widget.actionCardConfirmationVersion,
          ...f.submission,
        },
      );
      if (mounted && currentAuthority) {
        if (created is Map) {
          widget.onCreated?.call(Map<String, dynamic>.from(created));
        }
        if (widget.closeOnCreated &&
            ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void close() {
    if (!busy) Navigator.pop(context);
  }

  Widget needsComputer(BuildContext context) => RaftAgentDialogCard(
    title: 'Create Agent',
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
            label: 'Connect a Computer',
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

  List<Widget> preAdmissionFields(BuildContext context) {
    final models = preAdmissionModels;
    if (models == null && !preAdmissionLoading) return const [];
    final selected = models
        ?.where((m) => m['id'] == preAdmissionModel)
        .firstOrNull;
    return [
      RaftStableField(
        label: 'Model',
        belowControl: [
          if (preAdmissionLoading)
            const RaftAgentSourceStatus(
              message: 'Checking models on this Computer…',
            )
          else if (!preAdmissionLive)
            RaftAgentSourceStatus(
              message: 'Could not load models from this Computer.',
              retryLabel: 'Retry',
              onRetry: () => loadPreAdmission(refresh: true),
            ),
          if (selected?['verified'] == 'suggestion_only')
            const RaftAgentFieldNote(
              "This model is a catalog suggestion and has not been verified to launch with this computer's current runtime config.",
            ),
        ],
        child: RaftAgentSelect<String>(
          value: preAdmissionModel,
          placeholder: 'Model',
          semanticLabel: raftText(context, 'Model'),
          options: [
            for (final m in models ?? const <Map<String, dynamic>>[])
              RaftAgentSelectOption(
                m['id'] as String,
                '${m['label'] ?? m['id']}',
              ),
          ],
          onChanged: busy ? null : (v) => setState(() => preAdmissionModel = v),
        ),
      ),
      if (!widget.onboarding)
        RaftAgentMoreDisclosure(
          open: moreOpen,
          onToggle: () => setState(() => moreOpen = !moreOpen),
          children: [
            RaftStableField(
              label: 'Environment Variables',
              hint: 'One KEY=value per line.',
              child: RaftAgentTextInput(
                controller: preAdmissionEnv,
                multiline: true,
                semanticLabel: raftText(context, 'Environment Variables'),
              ),
            ),
          ],
        ),
    ];
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
          action: 'Connect a Computer',
          onAction: widget.onConnectComputer,
        ),
        onCreate: null,
        onClose: widget.onboardingModal ? close : null,
      );
    }
    if (widget.machines.isEmpty) {
      return PopScope(canPop: !busy, child: needsComputer(context));
    }
    final capacity = capacityReached;
    final nameError = validationAttempted
        ? createAgentNameError(context, name.text)
        : null;
    final f = form;
    final leading = <Widget>[
      if (capacity != null)
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
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
          action: 'Upgrade for more',
          onAction: close,
        )
      else if (error != null)
        RaftAgentBanner(
          status: RaftAgentBannerStatus.warning,
          description: error!,
        ),
      if (!widget.onboarding)
        RaftStableField(
          label: 'Computer',
          required: true,
          child: RaftAgentSelect<String>(
            value: machineId,
            semanticLabel: raftText(context, 'Computer'),
            options: [
              for (final m in widget.machines)
                RaftAgentSelectOption(
                  m['id'] as String,
                  '${m['name'] ?? m['hostname'] ?? m['id']}',
                  enabled:
                      widget.requiredMachineId == null ||
                      m['id'] == widget.requiredMachineId,
                ),
            ],
            onChanged: busy || widget.requiredMachineId != null
                ? null
                : (id) => id == machineId ? null : selectMachine(id),
          ),
        ),
      if (!widget.onboarding)
        RaftStableField(
          label: 'Name',
          required: true,
          error: nameError,
          child: RaftAgentTextInput(
            controller: name,
            placeholder: 'e.g. Alice',
            invalid: nameError != null,
            enabled: !busy,
            semanticLabel: raftText(context, 'Agent name'),
            onChanged: (_) => setState(() => error = null),
          ),
        ),
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
        hint: widget.onboarding
            ? 'The AI agent runtime your agents run on.'
            : null,
        labelAccessory: widget.onboarding
            ? RaftRecipeButton(
                key: const Key('cindy-rescan-runtimes'),
                glyph: RaftGlyph.refreshCw,
                glyphSize: 12,
                size: RaftButtonRecipeSize.iconXs,
                variant: RaftButtonRecipeVariant.ghost,
                tooltip: 'Rescan runtimes on this computer',
                onPressed: busy || runtimesRescanning ? null : rescanRuntimes,
              )
            : null,
        child: RaftAgentSelect<String>(
          value: runtime,
          placeholder: 'Select…',
          semanticLabel: raftText(context, 'Runtime'),
          options: [
            for (final o in runtimeOptions)
              RaftAgentSelectOption(
                o['runtimeId'] as String,
                createAgentRuntimeNames[o['runtimeId']]!,
              ),
          ],
          onChanged: busy
              ? null
              : (id) => id == runtime ? null : selectRuntime(id),
        ),
      ),
    ];
    if (widget.onboarding) {
      Widget fields() => f == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, row) in [
                  ...leading,
                  ...preAdmissionFields(context),
                ].indexed) ...[
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
              hideAdvanced: true,
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
            sessionActions: widget.onSwitchServer == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: RaftCindySessionLink(
                      onPressed: busy ? null : widget.onSwitchServer,
                    ),
                  ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !busy,
      child: RaftAgentDialogCard(
        title: 'Create Agent',
        onClose: close,
        children: [
          if (f == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, row) in [
                  ...leading,
                  ...preAdmissionFields(context),
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
          const SizedBox(height: raftAgentFormGap),
          ListenableBuilder(
            listenable: f ?? const AlwaysStoppedAnimation(0),
            builder: (context, _) => RaftAgentDialogFooter(
              children: [
                RaftAgentDialogButton(label: 'Cancel', onPressed: close),
                RaftAgentDialogButton(
                  label: 'Create Agent',
                  primary: true,
                  busy: busy,
                  onPressed: createDisabled ? null : submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
