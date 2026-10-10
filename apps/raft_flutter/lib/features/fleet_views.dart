import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'runtime_form_dialog.dart';
import 'managed_agent_launcher.dart';
import 'agent_scopes_view.dart';
import 'agent_migration_view.dart';
import 'agent_detail_view.dart';
import 'agent_avatar_dialog.dart';
import 'computer_detail_view.dart';
import 'management_support.dart'
    show pageIdentity, readPageSnapshot, writePageSnapshot;
import '../data/resource_snapshot_cache.dart' show stableValue;

import 'package:raft_ui/recipes.dart';

export 'agent_detail_view.dart' show AgentDetailTab;

/// A client generation does not change for every membership/account projection.
/// Capture both identity and authority so late HTTP and modal closures stay private.
class _FleetScope {
  _FleetScope(WorkspaceController w)
    : controller = w,
      origin = w.client.origin,
      principal = w.client.user?.id,
      server = w.client.serverId,
      projectedServer = w.server?.id,
      role = w.server?.string('role'),
      generation = w.client.generation;
  final WorkspaceController controller;
  final String origin;
  final String? principal, server, projectedServer, role;
  final int generation;
  bool revoked = false;
  bool current(WorkspaceController w) =>
      !revoked &&
      identical(controller, w) &&
      origin == w.client.origin &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      projectedServer == w.server?.id &&
      role == w.server?.string('role') &&
      generation == w.client.generation;
}

Future<T?> _fleetDialog<T>(
  BuildContext context,
  WorkspaceController w,
  bool Function() authorized,
  WidgetBuilder builder,
) async {
  if (!context.mounted || !authorized()) return null;
  final route = DialogRoute<T>(context: context, builder: builder);
  void changed() {
    if (!authorized() && route.isActive) route.navigator?.removeRoute(route);
  }

  w.addListener(changed);
  try {
    return await Navigator.of(context, rootNavigator: true).push(route);
  } finally {
    w.removeListener(changed);
  }
}

void _closeFleetDialog(BuildContext context) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route?.isActive == true && route?.isCurrent == true) {
    Navigator.of(context).pop();
  }
}

Future<void> showCredential(
  BuildContext context,
  String value, {
  String? detail,
  WorkspaceController? controller,
  bool Function()? authorized,
}) async {
  if (!context.mounted) return;
  bool valid() => context.mounted && (authorized?.call() ?? true);
  if (!valid()) return;
  Widget builder(BuildContext dialog) => AlertDialog(
    title: Text(raftText(context, 'Save this credential')),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail ?? 'This credential is shown once. Store it securely before closing.',
            ),
            const SizedBox(height: 16),
            RaftSecretView(
              value: value,
              onCopy: (v) async {
                if (valid()) await Clipboard.setData(ClipboardData(text: v));
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => _closeFleetDialog(dialog),
        child: Text(raftText(context, 'Close')),
      ),
    ],
  );
  if (controller != null) {
    await _fleetDialog<void>(context, controller, valid, builder);
  } else {
    await showDialog<void>(context: context, builder: builder);
  }
}

/// Agent and Computer directories share lifecycle and authority fencing, but
/// their commands use separate mounted API contracts.
/// Shared account/workspace-guarded registration used by both native
/// directories; one-time computer credentials stay inside the private dialog.
Future<void> showFleetRegistration(
  BuildContext context,
  WorkspaceController w, {
  bool computers = false,
  Future<void> Function()? onCreated,
  bool Function()? authorized,
}) async {
  final captured = _FleetScope(w);
  final endpoint = computers ? '/servers/${w.server!.id}/machines' : '/agents';
  final cap = computers ? 'registerMachines' : 'createAgents';
  bool valid() =>
      context.mounted &&
      captured.current(w) &&
      w.can(cap) &&
      (authorized?.call() ?? true);
  if (!valid()) return;
  String? credential;
  await _fleetDialog<void>(
    context,
    w,
    valid,
    (_) => RaftFormDialog(
      title: computers ? 'Register computer' : 'Create external agent',
      submitLabel: computers ? 'Register' : 'Create',
      description: computers
          ? 'Register a computer, then use its one-time key to connect the Raft Computer service.'
          : 'An external agent runs in a client you connect yourself.',
      fields: [
        const RaftFormField('name', 'Name', required: true),
        if (!computers)
          const RaftFormField('description', 'Description', multiline: true),
      ],
      onSubmit: (values) async {
        if (!valid()) throw const RaftApiException('Fleet access changed.');
        final result = await w.command(
          'POST',
          endpoint,
          data: {...values, if (!computers) 'external': true},
        );
        if (!valid()) return;
        if (computers) credential = result['apiKey'];
        await onCreated?.call();
      },
    ),
  );
  if (credential != null && context.mounted && valid()) {
    await showCredential(
      context,
      credential!,
      controller: w,
      authorized: valid,
    );
  }
}

class FleetView extends StatefulWidget {
  const FleetView({
    super.key,
    required this.controller,
    required this.computers,
    this.attentionOnly = false,
    this.onOpenDetail,
  });
  final WorkspaceController controller;
  final bool computers;
  final bool attentionOnly;

  /// The workspace supplies URI-owned navigation; standalone surfaces retain
  /// their existing Navigator route.
  final ValueChanged<Map<String, dynamic>>? onOpenDetail;
  @override
  State<FleetView> createState() => _FleetViewState();
}

class _FleetViewState extends State<FleetView> {
  WorkspaceController get w => widget.controller;
  late _FleetScope scope;
  WorkspaceController? _listened;
  WorkspaceEntityDirectory? _directory;
  String? actionError;
  bool current(_FleetScope captured) => mounted && captured.current(w);
  WorkspaceEntityKind get kind => widget.computers
      ? WorkspaceEntityKind.computers
      : WorkspaceEntityKind.agents;

  /// Rows come from the server-scoped entity directory, which fences and
  /// clears itself on identity change and patches realtime events in place.
  List<Map<String, dynamic>> get rows => [
    if (w.server != null && w.client.user != null)
      for (final row in w.entityDirectory.rows(kind))
        if (!widget.attentionOnly ||
            widget.computers &&
                row['isComputer'] == true &&
                (row['computerUpgradeAvailable'] == true ||
                    row['status'] == 'offline'))
          row,
  ];

  void authorityChanged() {
    if (!mounted || scope.current(w)) return;
    scope.revoked = true;
    scope = _FleetScope(w);
    if (w.server != null && w.client.user != null) {
      w.entityDirectory.ensure([kind]);
    }
    setState(() => actionError = null);
  }

  void directoryChanged() {
    if (mounted) setState(() {});
  }

  void bind() {
    _listened?.removeListener(authorityChanged);
    _directory?.removeListener(directoryChanged);
    _listened = w..addListener(authorityChanged);
    _directory = w.entityDirectory..addListener(directoryChanged);
  }

  @override
  void initState() {
    super.initState();
    scope = _FleetScope(w);
    bind();
    if (w.server != null && w.client.user != null) {
      w.entityDirectory.ensure([kind], retryFailed: true);
    }
  }

  @override
  void didUpdateWidget(FleetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, w)) {
      bind();
      scope.revoked = true;
      scope = _FleetScope(w);
      actionError = null;
      w.entityDirectory.ensure([kind]);
    }
  }

  @override
  void dispose() {
    scope.revoked = true;
    _listened?.removeListener(authorityChanged);
    _directory?.removeListener(directoryChanged);
    super.dispose();
  }

  /// Explicit refresh and the user's own mutations re-read the list in place.
  Future<void> load() async {
    if (!current(scope) || w.server == null || w.client.user == null) return;
    await w.entityDirectory.refresh(kind, force: true);
  }

  Future<void> create() async {
    final captured = scope;
    await showFleetRegistration(
      context,
      w,
      computers: widget.computers,
      onCreated: load,
      authorized: () => current(captured),
    );
  }

  Future<void> managed() async {
    final captured = scope;
    if (!current(captured) || !w.can('createAgents')) return;
    try {
      await showManagedAgentForm(context, w);
      if (current(captured)) await load();
    } catch (e) {
      if (current(captured)) setState(() => actionError = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final state = w.entityDirectory.state(kind);
    final loading = !w.entityDirectory.settled(kind);
    final error =
        actionError ?? (state.error == null ? null : '${state.error}');
    return fleetList(context, rows, loading, error);
  }

  Widget fleetList(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    bool loading,
    String? error,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                raftText(context, widget.computers ? 'Computers' : 'Agents'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: raftText(context, 'Refresh'),
              onPressed: load,
              icon: const Icon(Icons.refresh),
            ),
            if (w.can(widget.computers ? 'registerMachines' : 'createAgents'))
              RaftButton(
                label: raftText(
                  context,
                  widget.computers ? 'Register computer' : 'Create agent',
                ),
                onPressed: create,
              ),
          ],
        ),
      ),
      if (!widget.computers && w.can('createAgents'))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: managed,
              icon: const RaftIcon(RaftGlyph.bot, size: 14),
              label: Text(raftText(context, 'Create managed agent')),
            ),
          ),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(liveRegion: true, child: Text(error)),
        ),
      Expanded(
        child: loading && rows.isEmpty
            ? Center(child: CircularProgressIndicator())
            : rows.isEmpty
            ? RaftEmptyState(
                title: raftText(
                  context,
                  widget.computers ? 'No computers' : 'No agents',
                ),
                detail: 'Add one to this workspace.',
              )
            : ListView.builder(
                key: const Key('fleet-directory'),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final captured = scope;
                  final row = rows[index],
                      name =
                          '${rows[index]['displayName'] ?? rows[index]['name']}';
                  return ListTile(
                    key: ValueKey('fleet-${row['id']}'),
                    leading: widget.computers
                        ? const RaftIcon(RaftGlyph.monitor, size: 20)
                        : RaftAvatar(name: name),
                    title: Text(name),
                    subtitle: Text(
                      widget.computers
                          ? '${row['status'] ?? 'Offline'} · ${row['hostname'] ?? row['os'] ?? ''}'
                          : '${row['external'] == true ? 'External' : row['runtime'] ?? ''} · ${row['activity'] ?? row['status'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (!current(captured)) return;
                      if (widget.onOpenDetail != null) {
                        widget.onOpenDetail!(Map.of(row));
                        return;
                      }
                      // The detail edits the shared directory, so the list is
                      // already current when the route pops.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FleetDetail(
                            controller: w,
                            computers: widget.computers,
                            initial: row,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    ],
  );
}

class FleetDetail extends StatefulWidget {
  const FleetDetail({
    super.key,
    required this.controller,
    required this.computers,
    required this.initial,
    this.onClose,
    this.initialTab = AgentDetailTab.profile,
    this.clock,
    this.initialTrajectoryLog = const [],
    this.onOpenAgent,
  });
  final List<Map<String, dynamic>> initialTrajectoryLog;

  /// Computers: open an agent row of "Agents on this computer".
  final ValueChanged<String>? onOpenAgent;
  final WorkspaceController controller;
  final bool computers;
  final Map<String, dynamic> initial;
  final VoidCallback? onClose;

  /// Web `?agentTab=` deep link (agents only).
  final AgentDetailTab initialTab;

  /// Injected clock for relative labels (reminders); null = wall clock.
  final DateTime Function()? clock;
  @override
  State<FleetDetail> createState() => _FleetDetailState();
}

class _FleetDetailState extends State<FleetDetail> {
  WorkspaceController get w => widget.controller;
  late Map<String, dynamic> row = Map.of(widget.initial);
  late final String serverId;
  late final _FleetScope scope;
  late final String id;
  int request = 0;
  bool get current => mounted && !closingForAuthority && scope.current(w);
  String get base =>
      widget.computers ? '/servers/$serverId/machines/$id' : '/agents/$id';
  bool get external => row['external'] == true || row['runtime'] == 'external';
  bool get owned => widget.computers
      ? row['userId'] == w.client.user?.id
      : row['creatorType'] == 'user' && row['creatorId'] == w.client.user?.id;
  bool allowed(String cap) => current && (owned || w.can(cap));
  void require(String cap) {
    if (!allowed(cap)) throw const RaftApiException('Fleet access changed.');
  }

  bool busy = false;
  String? error;
  StreamSubscription<RaftEvent>? subscription;
  Timer? timer;
  Route<dynamic>? profileRoute;
  bool closingForAuthority = false;

  /// GET /servers/:id/machines for the agent's Computer rows; null while
  /// in flight.
  List<Map<String, dynamic>>? machines;
  Map<String, dynamic>? liveActivity;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    profileRoute ??= ModalRoute.of(context);
  }

  void closeProfile() {
    if (!mounted || closingForAuthority) return;
    closingForAuthority = true;
    scope.revoked = true;
    ++request;
    setState(() {
      row = {};
      error = null;
    });
    if (widget.onClose != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onClose!();
      });
      return;
    }
    final route = profileRoute;
    // An HTTP/socket completion can arrive while this route has already popped
    // but its State is still mounted for the transition. Remove only our route.
    if (route?.isActive != true || route!.isFirst) return;
    final navigator = route.navigator;
    navigator?.popUntil((r) => identical(r, route) || r.isFirst);
    if (route.isActive) navigator?.removeRoute(route);
  }

  WorkspaceEntityKind get kind => widget.computers
      ? WorkspaceEntityKind.computers
      : WorkspaceEntityKind.agents;

  /// Agent detail-only fields (GET /agents/:id: runtime profile, workspace
  /// role) cached for this route. Fields the shared directory carries win, so
  /// realtime patches show here exactly as in the list.
  Map<String, dynamic>? detail;

  /// Whether the shared directory has listed this entity in this scope; only
  /// then does its absence from an accepted list mean it was deleted.
  bool listed = false;

  Map<String, dynamic>? get directoryRow => widget.computers
      ? w.entityDirectory.computer(id)
      : w.entityDirectory.agent(id);

  /// The visible row never blanks: without any accepted source it keeps the
  /// row it already shows.
  Map<String, dynamic> compose() {
    final accepted = directoryRow;
    if (accepted != null) listed = true;
    if (accepted == null && detail == null) return row;
    return {...?detail, ...?accepted};
  }

  void directoryChanged() {
    if (!current) return;
    final directory = w.entityDirectory;
    final failure = directory.state(kind).error;
    if (failure is RaftApiException && [401, 403].contains(failure.status)) {
      closeProfile();
      return;
    }
    if (!widget.computers && directory.agentDeleted(id)) {
      closeProfile();
      return;
    }
    if (listed && directory.state(kind).loaded && directoryRow == null) {
      closeProfile();
      return;
    }
    final next = compose();
    final nextMachines =
        !widget.computers &&
            directory.state(WorkspaceEntityKind.computers).loaded
        ? directory.rows(WorkspaceEntityKind.computers)
        : machines;
    setState(() {
      row = next;
      machines = nextMachines;
    });
  }

  void authorityChanged() {
    if (!scope.current(w)) closeProfile();
  }

  @override
  void initState() {
    super.initState();
    serverId = w.server!.id;
    scope = _FleetScope(w);
    id = widget.initial['id'] as String;
    row = compose();
    if (w.entityDirectory.state(WorkspaceEntityKind.computers).loaded) {
      machines = w.entityDirectory.rows(WorkspaceEntityKind.computers);
    }
    w.entityDirectory.addListener(directoryChanged);
    w.addListener(authorityChanged);
    // The shared directory is read only when this scope has not settled it;
    // a revisit renders the accepted rows with no list request.
    w.entityDirectory.ensure([
      kind,
      if (!widget.computers) WorkspaceEntityKind.computers,
    ], retryFailed: true);
    if (!widget.computers) unawaited(loadDetail());
    subscription = w.client.events.listen((e) {
      if (!scope.current(w)) {
        closeProfile();
        return;
      }
      if (widget.computers || e.payload is! Map) return;
      final p = e.payload as Map;
      if (e.name == 'agent:activity' && p['agentId'] == id) {
        setState(
          () =>
              liveActivity = {'activity': p['activity'], 'detail': p['detail']},
        );
      } else if (e.name == 'agent:updated' && (p['agentId'] ?? p['id']) == id) {
        // Only this agent's stored profile changed; the list itself is
        // re-read by the shared directory.
        timer?.cancel();
        timer = Timer(WorkspaceEntityDirectory.reloadDelay, loadDetail);
      }
    });
  }

  @override
  void dispose() {
    scope.revoked = true;
    ++request;
    w.removeListener(authorityChanged);
    w.entityDirectory.removeListener(directoryChanged);
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  /// GET /agents/:id for detail-only fields. Computers have no detail read:
  /// the machine list row is the whole record.
  Future<void> loadDetail() async {
    if (!current || widget.computers) return;
    final ticket = ++request;
    try {
      final result = await w.query(base);
      if (!current || ticket != request) return;
      if (result is! Map || result['id'] != id || result['deletedAt'] != null) {
        closeProfile();
        return;
      }
      detail = Map<String, dynamic>.from(result);
      setState(() {
        row = compose();
        error = null;
      });
    } on RaftApiException catch (e) {
      if (!current || ticket != request) return;
      if (e.status == 404 || e.status == 403) {
        closeProfile();
        return;
      }
      setState(() => error = '$e');
    } catch (e) {
      if (current && ticket == request) setState(() => error = '$e');
    }
  }

  /// After the user's own mutation (or an explicit retry): re-read the shared
  /// list in place and, for agents, the detail fields.
  Future<void> load() async {
    if (!current) return;
    final list = w.entityDirectory.refresh(kind, force: true);
    await Future.wait([list, if (!widget.computers) loadDetail()]);
    if (!current) return;
    final failure = w.entityDirectory.state(kind).error;
    if (widget.computers &&
        failure == null &&
        w.entityDirectory.state(kind).loaded &&
        directoryRow == null) {
      closeProfile();
      return;
    }
    setState(() {
      row = compose();
      error = failure == null ? error : '$failure';
    });
  }

  /// Web AgentDetailHeader onMessage: open (or create) the DM and jump to it.
  Future<void> message() async {
    final value = await w.client.post('/channels/dm', data: {'agentId': id});
    if (!current || value is! Map || value['id'] is! String) return;
    await w.jumpToMessage(value['id'], null);
    if (mounted && widget.onClose == null) Navigator.of(context).maybePop();
    widget.onClose?.call();
  }

  /// ResetAgentDialog: one entry point, the mode is chosen in the dialog.
  Future<void> restartReset() async {
    if (!allowed('controlAgentRuntime') || external) return;
    String? mode;
    await _fleetDialog<void>(
      context,
      w,
      () => allowed('controlAgentRuntime'),
      (_) => RaftFormDialog(
        title: 'Restart / Reset',
        fields: [
          RaftFormField(
            'mode',
            'Mode',
            initial: 'restart',
            choices: {
              'restart': 'Restart runtime',
              'session': 'Reset session',
              if (allowed('resetAgentWorkspace')) 'full': 'Reset workspace',
            },
          ),
        ],
        submitLabel: 'Continue',
        onSubmit: (v) async => mode = v['mode'],
      ),
    );
    if (mode != null) await resetRuntime(mode!);
  }

  Future<void> action(Future<void> Function() operation) async {
    if (busy || !current) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (e) {
      if (current) setState(() => error = '$e');
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    final cap = widget.computers ? 'editMachines' : 'editAgents';
    require(cap);
    await _fleetDialog<void>(
      context,
      w,
      () => allowed(cap),
      (_) => RaftFormDialog(
        title: widget.computers ? 'Edit computer' : 'Edit agent',
        fields: [
          RaftFormField(
            widget.computers ? 'name' : 'displayName',
            'Display name',
            initial: '${row['displayName'] ?? row['name']}',
            required: true,
          ),
          RaftFormField(
            'description',
            'Description',
            initial: '${row['description'] ?? ''}',
            multiline: true,
          ),
        ],
        onSubmit: (values) async {
          require(cap);
          await w.command('PATCH', base, data: values);
          await load();
        },
      ),
    );
  }

  Future<void> confirm(
    String title,
    String detail,
    Future<void> Function() operation, {
    bool destructive = false,
  }) async {
    if (!current) return;
    await _fleetDialog<void>(
      context,
      w,
      () => current,
      (_) => RaftFormDialog(
        title: title,
        description: detail,
        fields: [],
        submitLabel: destructive ? 'Delete' : 'Continue',
        destructive: destructive,
        onSubmit: (_) async {
          if (!current) throw const RaftApiException('Fleet access changed.');
          await operation();
        },
      ),
    );
  }

  Future<void> remove() async {
    bool removed = false;
    await confirm(
      widget.computers ? 'Delete computer?' : 'Delete agent?',
      widget.computers
          ? 'Disconnect this computer from the workspace. Its agents can no longer use this connection.'
          : 'Delete this agent and stop its managed runtime. This cannot be undone.',
      () async {
        require(widget.computers ? 'removeMachines' : 'deleteAgents');
        await w.command('DELETE', base);
        removed = true;
      },
      destructive: true,
    );
    if (removed) closeProfile();
  }

  Future<void> credential() async {
    final cap = widget.computers
        ? 'rotateMachineKeys'
        : 'issueAgentCredentials';
    require(cap);
    if (widget.computers) {
      await confirm('Rotate computer key?', 'The old key will stop working. Reconnect this computer using the new key.', () async {
        require(cap);
        final result = await w.command('POST', '$base/rotate-key');
        if (mounted && allowed(cap)) {
          await showCredential(
            context,
            result['apiKey'],
            controller: w,
            authorized: () => allowed(cap),
          );
        }
      });
    } else {
      final result = await w.command(
        'POST',
        '$base/bootstrap-tokens',
        data: {},
      );
      if (mounted && allowed(cap)) {
        await showCredential(
          context,
          result['bootstrapToken'],
          controller: w,
          authorized: () => allowed(cap),
          detail:
              'Use this short-lived bootstrap token to connect your external agent. Expires ${result['ttlExpiresAt']}.',
        );
      }
    }
  }

  Future<void> inspect(String kind) async {
    require(widget.computers ? 'editMachines' : 'editAgents');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FleetInspection(
          controller: w,
          base: base,
          kind: kind,
          computers: widget.computers,
        ),
      ),
    );
  }

  Future<void> resetRuntime(String mode) async {
    if (!allowed(
          mode == 'full' ? 'resetAgentWorkspace' : 'controlAgentRuntime',
        ) ||
        external) {
      return;
    }
    await confirm(
      mode == 'full'
          ? 'Reset agent workspace?'
          : mode == 'session'
          ? 'Reset agent session?'
          : 'Restart agent?',
      mode == 'full'
          ? 'This removes the agent workspace and starts a fresh session. Existing files will be lost.'
          : mode == 'session'
          ? 'Start a fresh conversation session while retaining workspace files.'
          : 'Restart the runtime while retaining the session and workspace files.',
      () async {
        require(mode == 'full' ? 'resetAgentWorkspace' : 'controlAgentRuntime');
        await w.command('POST', '$base/reset', data: {'mode': mode});
        await load();
        if (mounted && current) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Request accepted. Check runtime status for completion.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> runtimeCommand(String command) async {
    require(widget.computers ? 'controlComputers' : 'controlAgentRuntime');
    await load();
    if (!current) return;
    final target = row['computerBroadcastPolicy'] is Map
        ? row['computerBroadcastPolicy']['targetVersion']
        : null;
    if (widget.computers &&
        command == 'upgrade' &&
        (target is! String || row['computerUpgradeAvailable'] != true)) {
      throw const RaftApiException(
        'An upgrade is no longer available. Refresh this computer.',
      );
    }
    await confirm(
      '${command[0].toUpperCase()}${command.substring(1)} ${widget.computers ? 'computer' : 'agent'}?',
      command == 'upgrade'
          ? 'Upgrade this computer to $target. Active agent sessions may be interrupted.'
          : 'This action affects the selected runtime.',
      () async {
        require(widget.computers ? 'controlComputers' : 'controlAgentRuntime');
        final result = await w.command(
          'POST',
          widget.computers ? '$base/computer/$command' : '$base/$command',
          data: command == 'upgrade' ? {'targetVersion': target} : {},
        );
        await load();
        if (mounted && current) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result is Map && result['appliesOnReconnect'] == true
                    ? 'Requested. Applies when the computer reconnects.'
                    : 'Request accepted. Check runtime status for completion.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> editAvatar() async {
    final captured = scope;
    bool valid() =>
        current &&
        identical(scope, captured) &&
        row['deletedAt'] == null &&
        allowed('editAgents');
    if (!valid() || busy) return;
    final rt = RaftRecipeTokens(RaftTokens.of(context));
    final overlay = RaftDialogRecipe.resolve(
      theme: raftRecipeTheme(RaftTokens.of(context)),
      states: RaftRecipeStates({
        if (RaftTokens.of(context).dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).overlay;
    final route = DialogRoute<void>(
      context: context,
      barrierColor: overlay.backgroundColor?.resolve(rt),
      barrierDismissible: false,
      builder: (_) => AgentAvatarDialog(
        controller: w,
        agent: row,
        authorized: valid,
        onSaved: (next) {
          if (!valid()) return;
          setState(() => row = next);
          unawaited(
            w.entityDirectory.refresh(WorkspaceEntityKind.agents, force: true),
          );
        },
      ),
    );
    void changed() {
      if (!valid() && route.isActive) route.navigator?.removeRoute(route);
    }

    w.addListener(changed);
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      w.removeListener(changed);
    }
  }

  Widget agentPanel(BuildContext context) => AgentDetailPanel(
    controller: w,
    agent: row,
    machines: machines,
    liveActivity: liveActivity,
    initialTab: widget.initialTab,
    clock: widget.clock,
    initialTrajectoryLog: widget.initialTrajectoryLog,
    busy: busy,
    error: error,
    canManage: allowed('editAgents'),
    canViewPrivate: allowed('editAgents'),
    canControlRuntime: allowed('controlAgentRuntime'),
    actions: AgentDetailActions(
      onEditAvatar: busy ? null : editAvatar,
      onBack: widget.onClose ?? () => Navigator.of(context).maybePop(),
      onEditProfile: busy ? null : edit,
      onEditRuntime: !external && row['machineId'] is String
          ? () async {
              if (!allowed('editAgents')) return;
              await _fleetDialog<void>(
                context,
                w,
                () => allowed('editAgents'),
                (_) => RuntimeFormDialog(
                  controller: w,
                  machineId: row['machineId'],
                  runtimeId: row['runtime'],
                  agentId: id,
                ),
              );
              await load();
            }
          : null,
      onStartStop: () => action(
        () => runtimeCommand(
          '${liveActivity?['activity'] ?? row['activity'] ?? 'offline'}' ==
                  'offline'
              ? 'start'
              : 'stop',
        ),
      ),
      onRestartReset: () => action(restartReset),
      onDelete: allowed('deleteAgents') ? remove : null,
      onMessage: row['deletedAt'] == null ? () => action(message) : null,
      onMigrate: allowed('migrateAgents')
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgentMigrationView(controller: w, agentId: id),
              ),
            )
          : null,
      onPermissions: allowed('editAgents')
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AgentScopesView(controller: w, agentId: id),
              ),
            )
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => !current
      ? const SizedBox.shrink()
      : !(widget.computers
            ? canRenderWorkspaceComputer(row)
            : canRenderWorkspaceAgent(row, serverId))
      ? SourceProfileLoadingPanel(
          onBack: widget.onClose ?? () => Navigator.of(context).maybePop(),
          error: error,
          onRetry: load,
        )
      : !widget.computers
      ? agentPanel(context)
      // Web MachineDetailPanel (computer_detail_view.dart); the desktop
      // detail column has no close action, like the Web route.
      : ComputerDetailPanel(
          controller: w,
          machine: row,
          onClose: widget.onClose,
          onOpenAgent: widget.onOpenAgent,
          onCreateAgent: () async {
            if (!allowed('createAgents')) return;
            await showManagedAgentForm(context, w, suggestedComputer: id);
          },
        );
}

class FleetInspection extends StatefulWidget {
  const FleetInspection({
    super.key,
    required this.controller,
    required this.base,
    required this.kind,
    required this.computers,
  });
  final WorkspaceController controller;
  final String base, kind;
  final bool computers;
  @override
  State<FleetInspection> createState() => _FleetInspectionState();
}

class _FleetInspectionState extends State<FleetInspection> {
  WorkspaceController get w => widget.controller;
  late final _FleetScope scope;
  bool get current => mounted && scope.current(w);
  int request = 0, fileRequest = 0;
  Route<dynamic>? inspectionRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    inspectionRoute ??= ModalRoute.of(context);
  }

  void authorityChanged() {
    if (!mounted || scope.current(w)) return;
    scope.revoked = true;
    ++request;
    ++fileRequest;
    setState(() {
      rows = [];
      shownDir = null;
      error = null;
    });
    final route = inspectionRoute;
    if (route?.isActive == true && !route!.isFirst) {
      final navigator = route.navigator;
      navigator?.popUntil((r) => identical(r, route) || r.isFirst);
      if (route.isActive) navigator?.removeRoute(route);
    }
  }

  @override
  void dispose() {
    scope.revoked = true;
    ++request;
    ++fileRequest;
    w.removeListener(authorityChanged);
    super.dispose();
  }

  List<Map<String, dynamic>> rows = [];
  String? error;
  bool loading = true;
  String dir = '';

  /// The folder [rows] were accepted for; null before the first result.
  String? shownDir;
  String get snapshotKey => 'fleet:${widget.base}/${widget.kind}';
  @override
  void initState() {
    super.initState();
    scope = _FleetScope(w);
    w.addListener(authorityChanged);
    // Revisit: the accepted listing renders at once and revalidates quietly.
    final snapshot = readPageSnapshot(w, snapshotKey);
    if (snapshot != null) {
      rows = snapshot['rows'] as List<Map<String, dynamic>>;
      dir = shownDir = snapshot['dir'] as String;
      loading = false;
    }
    load();
  }

  Future<void> load() async {
    if (!current) return;
    final ticket = ++request, identity = pageIdentity(w), target = dir;
    ++fileRequest;
    // Only a folder without accepted rows shows the loading state.
    if (shownDir != target) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await widget.controller.query(
        '${widget.base}/${widget.kind}',
        query: widget.kind == 'workspace-files' ? {'dirPath': target} : null,
      );
      if (!current || ticket != request) return;
      final next = <Map<String, dynamic>>[
        for (final r in (result is List ? result : result['files']) as List)
          Map<String, dynamic>.from(r),
      ];
      setState(() {
        rows = shownDir == target
            ? stableValue(rows, next) as List<Map<String, dynamic>>
            : next;
        shownDir = target;
        error = null;
      });
      writePageSnapshot(w, snapshotKey, identity, {
        'rows': rows,
        'dir': target,
      });
    } catch (e) {
      if (current && ticket == request) setState(() => error = '$e');
    } finally {
      if (current && ticket == request) setState(() => loading = false);
    }
  }

  Future<void> openFile(Map<String, dynamic> row) async {
    if (!current) return;
    final ticket = ++fileRequest;
    final path = '${row['path'] ?? row['name']}';
    if (row['type'] == 'directory' || row['isDirectory'] == true) {
      dir = path;
      await load();
      return;
    }
    try {
      final data = await widget.controller.query(
        '${widget.base}/workspace-files/read',
        query: {'path': path},
      );
      if (!mounted || !current || ticket != fileRequest) return;
      await _fleetDialog<void>(
        context,
        w,
        () => current && ticket == fileRequest,
        (dialog) => AlertDialog(
          title: Text('${row['name']}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(
                data['binary'] == true
                    ? 'Binary file · ${data['mimeType'] ?? ''} · ${data['size']} bytes'
                    : '${data['content'] ?? ''}',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _closeFleetDialog(dialog),
              child: Text(raftText(context, 'Close')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (current && ticket == fileRequest) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.kind) {
        'activity-log' => 'Activity log',
        'channels' => 'Agent channels',
        'agent-dms' => 'Agent conversations',
        'workspace-files' => 'Workspace files',
        'skills' => 'Skills',
        _ => 'Workspaces',
      }),
      actions: [
        IconButton(
          tooltip: raftText(context, 'Refresh'),
          onPressed: load,
          icon: const RaftIcon(RaftGlyph.refreshCw, size: 12),
        ),
      ],
    ),
    body: loading
        ? Center(child: CircularProgressIndicator())
        : error != null && shownDir != dir
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(
                    onPressed: load,
                    child: Text(raftText(context, 'Try again')),
                  ),
                ],
              ),
            ),
          )
        : rows.isEmpty && error == null
        ? RaftEmptyState(
            title: 'No entries',
            detail: 'There are no entries to show.',
          )
        : ListView(
            children: [
              // A failed revalidation keeps the accepted rows.
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(RaftSpace.x4),
                  child: RaftWarningBanner(error!),
                ),
              if (dir.isNotEmpty)
                ListTile(
                  title: Text(raftText(context, 'Root folder')),
                  leading: const Icon(Icons.arrow_upward),
                  onTap: () {
                    dir = '';
                    load();
                  },
                ),
              for (final row in rows)
                ListTile(
                  title: Text(
                    '${row['name'] ?? row['agentName'] ?? row['directoryName'] ?? row['activity'] ?? row['eventType'] ?? 'Entry'}',
                  ),
                  subtitle: Text(
                    '${row['detail'] ?? row['message'] ?? row['description'] ?? row['createdAt'] ?? row['status'] ?? ''}',
                  ),
                  leading: widget.kind == 'workspace-files'
                      ? RaftIcon(
                          row['type'] == 'directory' ||
                                  row['isDirectory'] == true
                              ? RaftGlyph.folderClosed
                              : RaftGlyph.fileText,
                          size: 14,
                        )
                      : null,
                  onTap: widget.kind == 'workspace-files'
                      ? () => openFile(row)
                      : null,
                ),
            ],
          ),
  );
}
