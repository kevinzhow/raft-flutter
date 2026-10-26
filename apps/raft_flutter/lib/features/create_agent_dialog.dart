// Create Agent dialog — Web packages/web/src/components/agent/CreateAgentDialog.tsx
// (DialogCard, capacity Banner, COMPUTER / NAME / DESCRIPTION StableFields,
// RuntimeConfigFields: RUNTIME select + the runtime's protocol-v2 fields,
// Cancel / Create Agent footer) and its zero-computer branch.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_name_generator.dart';
import '../data/billing_plans.dart';
import '../data/cause_notice.dart';
import '../data/create_agent_last_config.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart' show WorkspaceEntityKind;
import 'agent_metadata_catalog.dart';
import 'agent_hosted_create.dart';
import 'agent_runtime_labels.dart' show creatableRuntimeIds;
import 'delete_server_confirm.dart';
import 'private_route_guard.dart';
import 'runtime_options_request.dart';
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
  late final math.Random random = widget.random ?? math.Random();

  /// The "Cloud agent" choice of the Computer picker.
  late final HostedCreateChoice hosted = HostedCreateChoice(
    w,
    enabled: !widget.onboarding && widget.requiredMachineId == null,
    noComputers: widget.machines.isEmpty,
    prefilledHosting: widget.initialHosting,
    prefilledModel: widget.initialHostedModel,
  );

  /// The last computer, runtime and model created with on this server (Web
  /// `rememberedConfig`); null for onboarding, which never uses it.
  CreateAgentLastConfig? remembered;
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
  bool runtimeOptionsLoading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts or the name is edited; the dialog state is dropped when it closes.
  String? error;
  int machineTicket = 0;

  /// A failed runtime rescan: it describes the computer it ran on, so it ends
  /// with a retry, a successful rescan or a switch to another computer.
  late final rescanError = CauseNotice(scope: () => machineTicket);
  late final runtimeOptionsError = CauseNotice(scope: () => machineTicket);

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
    final ids = [for (final m in widget.machines) m['id'] as String?];
    final online = [
      for (final m in widget.machines)
        if (m['status'] == 'online') m['id'] as String?,
    ];
    machineId =
        widget.requiredMachineId ??
        (ids.contains(widget.initialMachineId)
            ? widget.initialMachineId
            : online.contains(remembered?.machineId)
            ? remembered?.machineId
            : online.firstOrNull ?? ids.firstOrNull);
    w.addListener(authorityChanged);
    hosted
      ..addListener(authorityChanged)
      ..start();
    loadBilling();
    if (machineId != null) selectMachine(machineId!);
  }

  void authorityChanged() {
    if (mounted) setState(() {});
  }

  /// Names already used on this server, so a suggested name avoids them (Web
  /// `takenAgentNames`).
  List<String> takenAgentNames() => [
    for (final a in w.services.entityDirectory.rows(WorkspaceEntityKind.agents))
      if (a['deletedAt'] == null && a['name'] is String) a['name'] as String,
  ];

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
      if (seats + RaftBillingPlans.proAgentSeatFraction > maxSeats) {
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
      runtimeOptionsLoading = true;
      runtimeOptionsError.clear();
      preAdmissionModels = null;
      preAdmissionModel = remembered?.runtime == 'claude'
          ? remembered!.model
          : '';
    });
    final runtimes = machine?['runtimes'];
    if (runtimes is List && runtimes.contains('claude')) loadPreAdmission();
    try {
      final catalog = await readRuntimeOptions(
        () => w.query('/servers/${w.server!.id}/machines/$id/runtime-options'),
      );
      if (!currentAuthority || ticket != machineTicket) return;
      final options = [
        for (final o in (catalog['options'] as List? ?? []).whereType<Map>())
          if (o['canSelectInThisContext'] == true &&
              creatableRuntimeIds.contains(o['runtimeId']))
            Map<String, dynamic>.from(o),
      ];
      setState(() => runtimeOptions = options);
      if (options.isNotEmpty) {
        final initial = options
            .where((o) => o['runtimeId'] == widget.initialRuntimeId)
            .firstOrNull;
        final last = options
            .where((o) => o['runtimeId'] == remembered?.runtime)
            .firstOrNull;
        final pick = initial ?? last ?? options.first;
        selectRuntime(
          pick['runtimeId'],
          restoreModel: initial == null && last != null,
        );
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
      final options = [
        for (final o in (catalog['options'] as List? ?? []).whereType<Map>())
          if (o['canSelectInThisContext'] == true &&
              creatableRuntimeIds.contains(o['runtimeId']))
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

  void selectRuntime(String id, {bool restoreModel = false}) {
    form?.dispose();
    final next = RuntimeFormController(
      w,
      machineId: machineId!,
      runtimeId: id,
      valid: () => currentAuthority,
      language: runtimeFormLanguageTag(context),
    );
    Map<String, String>? env;
    try {
      env = parseRuntimeStringMap(preAdmissionEnv.text);
    } on FormatException {
      env = null;
    }
    // Claude takes its model from the pre-admission picker (which already
    // starts at the remembered one); other runtimes restore it once the form
    // and its option sources are in.
    final lastModel = remembered?.model ?? '';
    if (restoreModel && id != 'claude' && lastModel.isNotEmpty) {
      restoreRememberedModel(next, lastModel);
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

  /// Puts the remembered [model] into the model field once [f] has loaded, but
  /// only where the form still offers it (a listed option, a custom value the
  /// source allows, or a free text field).
  void restoreRememberedModel(RuntimeFormController f, String model) {
    void apply() {
      if (f.loading) return;
      f.removeListener(apply);
      final definition = f.definition;
      final field = definition?.fields
          .where((field) => field.key == 'model')
          .firstOrNull;
      if (definition == null || field == null || f.values['model'] == model) {
        return;
      }
      final offered = switch (field.kind) {
        'text' => true,
        'select' || 'dependent_select' || 'derived_select' =>
          definition
                  .choices(field, f.sources, f.values)
                  .any((c) => c['value'] == model) ||
              definition.custom(field, f.sources, f.values),
        _ => false,
      };
      if (offered) f.change(field, model);
    }

    f.addListener(apply);
  }

  /// Web `writeCreateAgentLastConfig` after a successful create.
  void rememberConfig(RuntimeFormController f) {
    final id = machineId, selected = runtime;
    final field = f.definition?.fields
        .where((field) => field.key == 'model')
        .firstOrNull;
    if (widget.onboarding || id == null || selected == null) return;
    final value = f.values['model'];
    final model = value is String ? value.trim() : '';
    final custom =
        field != null &&
        model.isNotEmpty &&
        f.definition!.custom(field, f.sources, f.values) &&
        !f.definition!
            .choices(field, f.sources, f.values)
            .any((c) => c['value'] == model);
    CreateAgentLastConfig(
      machineId: id,
      runtime: selected,
      model: model,
      customModelMode: custom,
    ).write(w.server?.id);
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
        runtime == null ||
        f == null ||
        f.loading ||
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
        if (!cloud) rememberConfig(f!);
        if (created is Map) {
          widget.onCreated?.call(Map<String, dynamic>.from(created));
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
            label: 'Add Computer',
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
              message: 'Could not load models from this computer.',
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
                '${m['id'] ?? ''}',
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
          action: 'Add Computer',
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
          // Actual capacity caller: dark:bg-warning-soft, dark:!text-warning-strong
          // on both BannerDescription and its inline Upgrade button.
          backgroundColor: tokens.dark ? tokens.colors['warning-soft'] : null,
          foregroundColor: tokens.dark ? tokens.colors['warning-strong'] : null,
          actionForeground: tokens.dark
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
          action: 'Upgrade for More',
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
          action: shownError.contains('limit reached') ? 'View Plans' : null,
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
          hint: cloud
              ? 'Raft creates the agent in the cloud and connects it for you. No command line needed.'
              : null,
          child: RaftAgentSelect<String>(
            value: cloud ? hostedComputerChoice : machineId,
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
        hint: widget.onboarding ? 'The runtime your agents run on.' : null,
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
          options: [
            for (final o in runtimeOptions)
              RaftAgentSelectOption(
                o['runtimeId'] as String,
                // ignore: raft_lints/avoid_render_index_assertion -- runtimeOptions are filtered with creatableRuntimeIds (a subset of createAgentRuntimeNames) when loaded.
                createAgentRuntimeNames[o['runtimeId']]!,
              ),
          ],
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
        title: 'Create Agent',
        onClose: close,
        footerGap: raftAgentFormGap,
        footer: ListenableBuilder(
          listenable: f ?? const AlwaysStoppedAnimation(0),
          builder: (context, _) => RaftAgentDialogFooter(
            children: [
              RaftAgentDialogButton(label: 'Cancel', onPressed: close),
              RaftAgentDialogButton(
                label: 'Create Agent',
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
                  ...(cloud
                      ? hosted.fields(context, busy: busy)
                      : preAdmissionFields(context)),
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
