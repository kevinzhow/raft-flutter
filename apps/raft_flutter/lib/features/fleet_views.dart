import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'runtime_form_dialog.dart';
import 'managed_agent_launcher.dart';
import 'mcp_views.dart';
import 'agent_scopes_view.dart';
import 'agent_migration_view.dart';
import 'agent_apps_view.dart';
import 'agent_detail_view.dart';

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

/// GET /servers/:id/machines answers `{machines: [...]}` or a bare array;
/// Web accepts both.
List<dynamic> _machineRows(dynamic result) {
  final rows = result is Map ? result['machines'] : result;
  return rows is List ? rows.whereType<Map>().toList() : const [];
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
class FleetView extends StatefulWidget {
  const FleetView({
    super.key,
    required this.controller,
    required this.computers,
    this.attentionOnly = false,
  });
  final WorkspaceController controller;
  final bool computers;
  final bool attentionOnly;
  @override
  State<FleetView> createState() => _FleetViewState();
}

class _FleetViewState extends State<FleetView> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? error;
  int request = 0;
  late _FleetScope scope;
  bool current(_FleetScope captured) => mounted && captured.current(w);
  void authorityChanged() {
    if (!mounted || scope.current(w)) return;
    scope.revoked = true;
    scope = _FleetScope(w);
    ++request;
    refresh?.cancel();
    setState(() {
      rows = [];
      error = null;
      loading = true;
    });
    if (w.server != null && w.client.user != null) load();
  }

  StreamSubscription<RaftEvent>? subscription;
  Timer? refresh;
  String get base =>
      widget.computers ? '/servers/${w.server!.id}/machines' : '/agents';
  @override
  void initState() {
    super.initState();
    scope = _FleetScope(w);
    w.addListener(authorityChanged);
    load();
    subscription = w.client.events.listen((e) {
      if (e.name.startsWith(widget.computers ? 'machine:' : 'agent:') ||
          e.name.startsWith('server:member')) {
        refresh?.cancel();
        refresh = Timer(const Duration(milliseconds: 150), load);
      }
    });
  }

  @override
  void dispose() {
    ++request;
    scope.revoked = true;
    w.removeListener(authorityChanged);
    refresh?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final ticket = ++request;
    final captured = scope;
    if (!current(captured) || w.server == null || w.client.user == null) return;
    try {
      final result = await w.query(base);
      if (!current(captured) || ticket != request) {
        return;
      }
      setState(() {
        rows = [
          for (final row
              in (widget.computers ? _machineRows(result) : result) as List)
            if ((widget.computers || row['deletedAt'] == null) &&
                (!widget.attentionOnly ||
                    widget.computers &&
                        row['isComputer'] == true &&
                        (row['computerUpgradeAvailable'] == true ||
                            row['status'] == 'offline')))
              Map<String, dynamic>.from(row),
        ];
        error = null;
        loading = false;
      });
    } catch (e) {
      if (current(captured) && ticket == request) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> create() async {
    final captured = scope, endpoint = base;
    final cap = widget.computers ? 'registerMachines' : 'createAgents';
    bool valid() => current(captured) && w.can(cap);
    if (!valid()) return;
    String? credential;
    await _fleetDialog<void>(
      context,
      w,
      valid,
      (_) => RaftFormDialog(
        title: widget.computers ? 'Register computer' : 'Create external agent',
        submitLabel: widget.computers ? 'Register' : 'Create',
        description: widget.computers
            ? 'Register a computer, then use its one-time key to connect the Raft Computer service.'
            : 'An external agent runs in a client you connect yourself.',
        fields: [
          const RaftFormField('name', 'Name', required: true),
          if (!widget.computers)
            const RaftFormField('description', 'Description', multiline: true),
        ],
        onSubmit: (values) async {
          if (!valid()) throw const RaftApiException('Fleet access changed.');
          final result = await w.command(
            'POST',
            endpoint,
            data: {...values, if (!widget.computers) 'external': true},
          );
          if (!valid()) return;
          if (widget.computers) credential = result['apiKey'];
          await load();
        },
      ),
    );
    if (credential != null && mounted && valid()) {
      await showCredential(
        context,
        credential!,
        controller: w,
        authorized: valid,
      );
    }
  }

  Future<void> managed() async {
    final captured = scope;
    if (!current(captured) || !w.can('createAgents')) return;
    try {
      await showManagedAgentForm(context, w);
      if (current(captured)) await load();
    } catch (e) {
      if (current(captured)) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
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
          child: Semantics(liveRegion: true, child: Text(error!)),
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
                      if (mounted) await load();
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
  });
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

  void authorityChanged() {
    if (!scope.current(w)) closeProfile();
  }

  @override
  void initState() {
    super.initState();
    serverId = w.server!.id;
    scope = _FleetScope(w);
    id = widget.initial['id'] as String;
    w.addListener(authorityChanged);
    load();
    if (!widget.computers) loadMachines();
    subscription = w.client.events.listen((e) {
      if (!scope.current(w)) {
        closeProfile();
        return;
      }
      if (!widget.computers &&
          e.name == 'agent:activity' &&
          e.payload is Map &&
          (e.payload as Map)['agentId'] == id) {
        final p = e.payload as Map;
        setState(
          () => liveActivity = {
            'activity': p['activity'],
            'detail': p['detail'],
          },
        );
        return;
      }
      if (!widget.computers && e.name.startsWith('machine:')) {
        loadMachines();
      }
      if (e.name.startsWith(widget.computers ? 'machine:' : 'agent:') ||
          e.name.startsWith('server:member')) {
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 150), load);
      }
    });
  }

  @override
  void dispose() {
    scope.revoked = true;
    ++request;
    w.removeListener(authorityChanged);
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (!current) return;
    final ticket = ++request;
    try {
      final result = await w.query(
        widget.computers ? '/servers/$serverId/machines' : base,
      );
      if (!current || ticket != request) return;
      final next = widget.computers
          ? _machineRows(result).where((r) => r['id'] == id).firstOrNull
          : result;
      if (next == null ||
          next['id'] != id ||
          (!widget.computers && next['deletedAt'] != null)) {
        closeProfile();
        return;
      }
      setState(() {
        row = Map<String, dynamic>.from(next);
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

  Future<void> loadMachines() async {
    try {
      final result = await w.query('/servers/$serverId/machines');
      if (!current) return;
      final rows = result is Map ? result['machines'] : result;
      setState(
        () => machines = [
          for (final m in (rows is List ? rows : const []))
            if (m is Map) Map<String, dynamic>.from(m),
        ],
      );
    } catch (_) {
      if (current) setState(() => machines = const []);
    }
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

  Widget agentPanel(BuildContext context) => AgentDetailPanel(
    controller: w,
    agent: row,
    machines: machines,
    liveActivity: liveActivity,
    initialTab: widget.initialTab,
    clock: widget.clock,
    busy: busy,
    error: error,
    canManage: allowed('editAgents'),
    canViewPrivate: allowed('editAgents'),
    canControlRuntime: allowed('controlAgentRuntime'),
    actions: AgentDetailActions(
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
  Widget build(BuildContext context) => !widget.computers
      ? agentPanel(context)
      : Scaffold(
    appBar: AppBar(
      title: Text('${row['displayName'] ?? row['name'] ?? ''}'),
      automaticallyImplyLeading: widget.onClose == null,
      actions: [
        if (widget.onClose != null)
          RaftIconButton(
            glyph: RaftGlyph.x,
            tooltip: 'Close profile',
            onPressed: widget.onClose,
          ),
      ],
    ),
    body: ListView(
      key: const Key('fleet-detail'),
      padding: const EdgeInsets.all(24),
      children: [
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text(
          '${row['displayName'] ?? row['name']}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        SelectableText('${row['description'] ?? ''}'),
        ListTile(
          title: Text(raftText(context, 'Status')),
          subtitle: Text('${row['activity'] ?? row['status'] ?? 'Unknown'}'),
        ),
        if (row['activityDetail'] != null)
          ListTile(
            title: Text(raftText(context, 'Current activity')),
            subtitle: Text('${row['activityDetail']}'),
          ),
        if (widget.computers) ...[
          if (row['hostname'] != null)
            ListTile(
              title: Text(raftText(context, 'Hostname')),
              subtitle: Text('${row['hostname']}'),
            ),
          if (row['os'] != null)
            ListTile(
              title: Text(raftText(context, 'Operating system')),
              subtitle: Text('${row['os']}'),
            ),
          if (row['computerVersion'] != null)
            ListTile(
              title: Text(raftText(context, 'Computer version')),
              subtitle: Text('${row['computerVersion']}'),
            ),
        ] else ...[
          ListTile(
            title: Text(raftText(context, 'Runtime')),
            subtitle: Text(external ? 'External agent' : '${row['runtime']}'),
          ),
          if (row['model'] != null)
            ListTile(
              title: Text(raftText(context, 'Model')),
              subtitle: Text('${row['model']}'),
            ),
          if (row['serverRole'] != null)
            ListTile(
              title: Text(raftText(context, 'Workspace role')),
              subtitle: Text('${row['serverRole']}'),
            ),
        ],
        if (allowed(widget.computers ? 'editMachines' : 'editAgents'))
          ListTile(
            title: Text(
              raftText(
                context,
                widget.computers ? 'Edit computer' : 'Edit agent',
              ),
            ),
            leading: const RaftIcon(RaftGlyph.pencil, size: 14),
            onTap: busy ? null : edit,
          ),
        if (!widget.computers &&
            !external &&
            row['machineId'] is String &&
            allowed('editAgents'))
          ListTile(
            title: Text(raftText(context, 'Edit runtime configuration')),
            leading: const RaftIcon(RaftGlyph.pencil, size: 12),
            onTap: busy
                ? null
                : () async {
                    if (!allowed('editAgents')) return;
                    await showDialog(
                      context: context,
                      builder: (_) => RuntimeFormDialog(
                        controller: w,
                        machineId: row['machineId'],
                        runtimeId: row['runtime'],
                        agentId: id,
                      ),
                    );
                    await load();
                  },
          ),
        if (allowed(
              widget.computers ? 'rotateMachineKeys' : 'issueAgentCredentials',
            ) &&
            (widget.computers || external))
          ListTile(
            title: Text(
              raftText(
                context,
                widget.computers
                    ? 'Rotate computer key'
                    : 'Connect external agent',
              ),
            ),
            leading: const Icon(Icons.key),
            onTap: busy ? null : () => action(credential),
          ),
        if (allowed(
              widget.computers ? 'controlComputers' : 'controlAgentRuntime',
            ) &&
            ((widget.computers && row['isComputer'] == true) ||
                (!widget.computers && !external)))
          Wrap(
            spacing: 8,
            children: [
              for (final cmd
                  in widget.computers
                      ? [
                          'restart',
                          if (row['remoteUpgradeSupported'] == true &&
                              row['computerUpgradeAvailable'] == true &&
                              row['computerBroadcastPolicy']?['targetVersion']
                                  is String)
                            'upgrade',
                        ]
                      : ['start', 'stop'])
                TextButton(
                  onPressed: busy
                      ? null
                      : () => action(() => runtimeCommand(cmd)),
                  child: Text(
                    raftText(
                      context,
                      '${cmd[0].toUpperCase()}${cmd.substring(1)}',
                    ),
                  ),
                ),
            ],
          ),
        if (!widget.computers && !external) ...[
          for (final mode in ['restart', 'session', 'full'])
            if (allowed(
              mode == 'full' ? 'resetAgentWorkspace' : 'controlAgentRuntime',
            ))
              ListTile(
                leading: const RaftIcon(RaftGlyph.rotateCcw, size: 14),
                title: Text(
                  raftText(
                    context,
                    mode == 'full'
                        ? 'Reset workspace'
                        : mode == 'session'
                        ? 'Reset session'
                        : 'Restart runtime',
                  ),
                ),
                onTap: busy ? null : () => action(() => resetRuntime(mode)),
              ),
          if (allowed('migrateAgents'))
            ListTile(
              leading: const RaftIcon(RaftGlyph.moveRight, size: 14),
              title: Text(raftText(context, 'Agent migration')),
              onTap: busy
                  ? null
                  : () {
                      if (!allowed('migrateAgents')) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AgentMigrationView(controller: w, agentId: id),
                        ),
                      );
                    },
            ),
        ],
        if (allowed(widget.computers ? 'editMachines' : 'editAgents')) ...[
          if (widget.computers)
            ListTile(
              title: Text(raftText(context, 'Workspaces')),
              leading: const RaftIcon(RaftGlyph.folderOpen, size: 14),
              onTap: () => inspect('workspaces'),
            )
          else ...[
            ListTile(
              title: Text(raftText(context, 'Agent permissions')),
              leading: const Icon(Icons.security),
              onTap: () async {
                if (!allowed('editAgents')) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgentScopesView(controller: w, agentId: id),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(raftText(context, 'Skills')),
              leading: const Icon(Icons.psychology),
              onTap: () => inspect('skills'),
            ),
            ListTile(
              title: Text(raftText(context, 'App access')),
              leading: const RaftIcon(RaftGlyph.link2, size: 12),
              onTap: () async {
                if (!allowed('editAgents')) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AgentAppAccessView(controller: w, agentId: id),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(raftText(context, 'MCP servers')),
              leading: const RaftIcon(RaftGlyph.blocks, size: 12),
              onTap: () async {
                if (!allowed('editAgents')) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgentMcpView(controller: w, agentId: id),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(raftText(context, 'Activity log')),
              leading: const RaftIcon(RaftGlyph.activity, size: 12),
              onTap: () => inspect('activity-log'),
            ),
            ListTile(
              title: Text(raftText(context, 'Agent channels')),
              leading: const Icon(Icons.tag),
              onTap: () => inspect('channels'),
            ),
            ListTile(
              title: Text(raftText(context, 'Agent conversations')),
              leading: const Icon(Icons.forum),
              onTap: () => inspect('agent-dms'),
            ),
            ListTile(
              title: Text(raftText(context, 'Workspace files')),
              leading: const RaftIcon(RaftGlyph.folderOpen, size: 12),
              onTap: () => inspect('workspace-files'),
            ),
          ],
        ],
        if (allowed(widget.computers ? 'removeMachines' : 'deleteAgents'))
          ListTile(
            title: Text(
              raftText(
                context,
                widget.computers ? 'Delete computer' : 'Delete agent',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            leading: const RaftIcon(RaftGlyph.trash2, size: 14),
            onTap: busy ? null : remove,
          ),
      ],
    ),
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
  @override
  void initState() {
    super.initState();
    scope = _FleetScope(w);
    w.addListener(authorityChanged);
    load();
  }

  Future<void> load() async {
    if (!current) return;
    final ticket = ++request;
    ++fileRequest;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.controller.query(
        '${widget.base}/${widget.kind}',
        query: widget.kind == 'workspace-files' ? {'dirPath': dir} : null,
      );
      if (!current || ticket != request) return;
      setState(() {
        rows = [
          for (final r in (result is List ? result : result['files']) as List)
            Map<String, dynamic>.from(r),
        ];
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
        : error != null
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
        : rows.isEmpty
        ? RaftEmptyState(
            title: 'No entries',
            detail: 'There are no entries to show.',
          )
        : ListView(
            children: [
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
