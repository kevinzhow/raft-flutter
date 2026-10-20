import 'page_layout.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/web_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../platform/system_bars.dart';
import 'managed_agent_launcher.dart';
import 'agent_scopes_view.dart';
import 'agent_migration_view.dart';
import 'agent_detail_view.dart';
import 'agent_profile_rules.dart';
import 'agent_metadata_catalog.dart' show sourceAgentActivities;
import 'agent_metadata_projection.dart';
import 'report_issue.dart';
import 'agent_runtime_editor.dart';
import 'agent_avatar_dialog.dart';
import 'computer_detail_view.dart';
import 'add_computer_dialog.dart';
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
  WidgetBuilder builder, {
  bool dismissible = false,
  bool form = false,
  bool guardUnsaved = true,
}) async {
  if (!context.mounted || !authorized()) return null;
  // Web `Dialog` layer: the recipe overlay (Brutal black/65, Elegant backdrop + blur).
  final navigator = Navigator.of(context, rootNavigator: true);
  final Route<T> route = form
      // A form with inputs: a bottom sheet on a phone, a dialog from 768.
      ? raftFormRoute<T>(context, builder: builder, guardUnsaved: guardUnsaved)
      : RaftDialogRoute<T>(
          builder: builder,
          // Web `DialogCard` / `ConfirmDialog`: no scrim close, Escape closes.
          dismissible: dismissible,
          capturedThemes: InheritedTheme.capture(
            from: context,
            to: navigator.context,
          ),
        );
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
    form: true,
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
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared on scope change and controller change; only set by a defensive catch around showManagedAgentForm, which does not throw.
  String? actionError;
  bool current(_FleetScope captured) => mounted && captured.current(w);
  WorkspaceEntityKind get kind => widget.computers
      ? WorkspaceEntityKind.computers
      : WorkspaceEntityKind.agents;

  /// Rows come from the server-scoped entity directory, which fences and
  /// clears itself on identity change and patches realtime events in place.
  List<Map<String, dynamic>> get rows => [
    if (w.server != null && w.client.user != null)
      for (final row in w.services.entityDirectory.rows(kind))
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
      w.services.entityDirectory.ensure([kind]);
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
    _directory = w.services.entityDirectory..addListener(directoryChanged);
  }

  @override
  void initState() {
    super.initState();
    scope = _FleetScope(w);
    bind();
    if (w.server != null && w.client.user != null) {
      w.services.entityDirectory.ensure([kind], retryFailed: true);
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
      w.services.entityDirectory.ensure([kind]);
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
    await w.services.entityDirectory.refresh(kind, force: true);
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
      if (current(captured)) {
        setState(
          () => actionError = userErrorText(
            e,
            fallback: 'Failed to create agent',
            where: 'managed agent form',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = this.rows;
    final state = w.services.entityDirectory.state(kind);
    final loading = !w.services.entityDirectory.settled(kind);
    final error =
        actionError ??
        (state.error == null
            ? null
            : userErrorText(
                state.error,
                fallback: widget.computers
                    ? "Couldn't load computers"
                    : raftGenericErrorText,
                where: 'fleet directory',
              ));
    if (widget.computers &&
        MediaQuery.sizeOf(context).width <
            RaftLayoutMetrics.desktopBreakpoint) {
      final captured = scope;
      return RaftMobileComputerList(
        key: const PageStorageKey('fleet-computers'),
        loading: loading,
        // Web MobileComputersPanel: a failed first load is the load-error
        // state; a failed refresh that kept the saved list is a banner.
        error: error == null || rows.isNotEmpty
            ? null
            : raftText(context, 'Directory could not be loaded.'),
        errorTitle: raftText(context, "Couldn't load computers"),
        errorDetail: raftText(context, 'Check your connection and try again.'),
        refreshError: error != null && rows.isNotEmpty
            ? raftText(
                context,
                "Couldn't refresh computers. Showing saved results.",
              )
            : null,
        emptyTitle: raftText(
          context,
          widget.attentionOnly
              ? 'No computers need attention'
              : 'No computers yet',
        ),
        emptyDetail: raftText(
          context,
          widget.attentionOnly
              ? 'All computers are up to date and online.'
              : 'Add a computer to run agents in this workspace.',
        ),
        addLabel: raftText(context, 'Add computer'),
        retryLabel: raftText(context, 'Retry'),
        onRetry: load,
        onAdd: state.loaded && w.can('registerMachines')
            ? () {
                if (current(captured)) showAddComputerDialog(context, w);
              }
            : null,
        rows: [
          for (final row in rows)
            RaftComputerRow(
              key: ValueKey('fleet-${row['id']}'),
              mobile: true,
              name: '${row['name'] ?? ''}',
              description: '${row['description'] ?? ''}',
              runLabel: raftText(context, computerRunLabel(row).$1),
              offline: computerRunLabel(row).$2,
              availableVersion: computerAvailableVersion(
                row,
                w.services.entityDirectory.latestComputerVersion,
              ),
              diskLow: computerDiskLow(row) != null,
              dot:
                  computerAvailableVersion(
                        row,
                        w.services.entityDirectory.latestComputerVersion,
                      ) !=
                      null
                  ? RaftComputerDot.upgrade
                  : row['status'] == 'online'
                  ? RaftComputerDot.online
                  : RaftComputerDot.offline,
              onTap: () {
                if (!current(captured)) return;
                if (widget.onOpenDetail != null) {
                  widget.onOpenDetail!(Map.of(row));
                } else {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      // ds-allow: Standalone native route supplies the Material host and system insets; workspace routes already own them.
                      builder: (context) => Scaffold(
                        body: RaftSystemBarSurface(
                          statusBarFallback: RaftTokens.of(context).panel,
                          child: SafeArea(
                            bottom: false,
                            child: FleetDetail(
                              controller: w,
                              computers: true,
                              initial: row,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      );
    }
    return KeyedSubtree(
      key: PageStorageKey('fleet-${widget.computers ? 'computers' : 'agents'}'),
      child: fleetList(context, rows, loading, error),
    );
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
            RaftTooltip(
              message: raftText(context, 'Refresh'),
              child: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
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
          child: RaftErrorBanner(error),
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
                      name = nonEmptyOr(
                        rows[index]['displayName'],
                        rows[index]['name'],
                      );
                  return ListTile(
                    key: ValueKey('fleet-${row['id']}'),
                    leading: widget.computers
                        ? const RaftIcon(RaftGlyph.monitor, size: 20)
                        : RaftAvatar(name: name),
                    title: Text(name),
                    subtitle: Text(
                      widget.computers
                          ? '${row['status'] ?? 'Offline'} · ${row['hostname'] ?? row['os'] ?? ''}'
                          : '${row['external'] == true ? 'External' : row['runtime'] ?? ''} · ${raftText(context, agentDisplayText(agentRowAmbientDisplay(row)))}',
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
                      await Navigator.of(context, rootNavigator: true).push(
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
    this.closeAction = false,
    this.onLeaveForMessage,
    this.backAlways = false,
    this.initialTab = AgentDetailTab.profile,
    this.clock,
    this.initialTrajectoryLog = const [],
    this.onOpenAgent,
    this.feedbackExportUrl,
  });
  final List<Map<String, dynamic>> initialTrajectoryLog;

  /// Feedback export worker of Report Issue; null = the build's
  /// `RAFT_FEEDBACK_EXPORT_URL` (Web `VITE_FEEDBACK_EXPORT_URL`).
  final String? feedbackExportUrl;

  /// Computers: open an agent row of "Agents on this computer".
  final ValueChanged<String>? onOpenAgent;
  final WorkspaceController controller;
  final bool computers;
  final Map<String, dynamic> initial;
  final VoidCallback? onClose;

  /// The agent header carries a close action at md+ (Web profile overlay
  /// `onClose`); the Agents route detail column has none.
  final bool closeAction;

  /// A host that owns the page this detail lives on (the profile slot): called
  /// just before the DM is opened, in place of [onClose] afterwards. [onClose]
  /// is the host's *Back* (on a phone it pops the topmost mobile page), and
  /// once the DM is the topmost page, running it would pop the DM the user
  /// just opened.
  final VoidCallback? onLeaveForMessage;

  /// The agent header keeps its Back at md+ too (a Search / Activity content
  /// slot: Web `backButtonVisibility="always"`).
  final bool backAlways;

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
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when an action starts, a detail read succeeds, the user dismisses it, or the profile closes for an authority change.
  String? error;

  StreamSubscription<RaftEvent>? subscription;
  Timer? timer;
  Route<dynamic>? profileRoute;
  bool closingForAuthority = false;

  /// GET /servers/:id/machines for the agent's Computer rows; null while
  /// in flight.
  List<Map<String, dynamic>>? machines;
  Map<String, dynamic>? liveActivity;
  BigInt? liveSeq;
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

  /// The last accepted detail read of this agent, kept for the session so a
  /// revisit shows the detail-only rows at the first frame.
  String get detailCacheKey => 'agent-detail/$id';

  /// Whether the shared directory has listed this entity in this scope; only
  /// then does its absence from an accepted list mean it was deleted.
  bool listed = false;

  Map<String, dynamic>? get directoryRow => widget.computers
      ? w.services.entityDirectory.computer(id)
      : w.services.entityDirectory.agent(id);

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
    final directory = w.services.entityDirectory;
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
    if (!widget.computers) {
      final cached = w.agentTabCache.peek(detailCacheKey);
      if (cached is Map<String, dynamic>) detail = cached;
    }
    row = compose();
    if (w.services.entityDirectory
        .state(WorkspaceEntityKind.computers)
        .loaded) {
      machines = w.services.entityDirectory.rows(WorkspaceEntityKind.computers);
    }
    w.services.entityDirectory.addListener(directoryChanged);
    w.addListener(authorityChanged);
    // The shared directory is read only when this scope has not settled it;
    // a revisit renders the accepted rows with no list request.
    w.services.entityDirectory.ensure([
      kind,
      if (!widget.computers) WorkspaceEntityKind.computers,
    ], retryFailed: true);
    if (!widget.computers) unawaited(loadDetail());
    subscription = w.client.events.listen((e) {
      if (!scope.current(w)) {
        closeProfile();
        return;
      }
      if (e.name == 'connected') liveSeq = null;
      if (widget.computers || e.payload is! Map) return;
      final p = e.payload as Map;
      if (e.name == 'agent:activity' && p['agentId'] == id) {
        // Web applySocketActivity: unknown activities and a serverSeq at or
        // below the held one are dropped.
        if (!sourceAgentActivities.contains(
          p['activityKind'] ?? p['activity'],
        )) {
          return;
        }
        final seq = BigInt.tryParse('${p['serverSeq'] ?? ''}');
        if (seq != null && liveSeq != null && seq <= liveSeq!) return;
        if (seq != null) liveSeq = seq;
        setState(
          () => liveActivity = {
            'activity': p['activity'],
            'activityKind': p['activityKind'],
            'detail': p['detail'],
            'detailKind': p['detailKind'],
          },
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
    w.services.entityDirectory.removeListener(directoryChanged);
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
        // Web `AgentById`: an id the server does not hold renders the
        // "Agent unavailable" panel (it does not navigate away).
        setState(() => gone = true);
        return;
      }
      detail = Map<String, dynamic>.from(result);
      w.agentTabCache.put(detailCacheKey, detail!);
      setState(() {
        gone = false;
        row = compose();
        error = null;
      });
    } on RaftApiException catch (e) {
      if (!current || ticket != request) return;
      if (e.status == 404 || e.status == 403) {
        setState(() => gone = true);
        return;
      }
      _readFailed(e, 'agent detail');
    } catch (e) {
      if (current && ticket == request) _readFailed(e, 'agent detail');
    }
  }

  bool get _renderable => widget.computers
      ? canRenderWorkspaceComputer(row)
      : canRenderWorkspaceAgent(row, serverId);

  /// A secondary read (GET /agents/:id detail-only fields, the shared list
  /// refresh) failed. Web falls back silently once the profile is on screen,
  /// so the page-level error slot is only for a profile that cannot render
  /// yet (it carries the Retry); mutation failures use `action` instead.
  void _readFailed(Object failure, String where) {
    if (_renderable) return;
    setState(
      () => error = userErrorText(
        failure,
        fallback: raftGenericErrorText,
        where: where,
      ),
    );
  }

  /// After the user's own mutation (or an explicit retry): re-read the shared
  /// list in place and, for agents, the detail fields.
  Future<void> load() async {
    if (!current) return;
    final list = w.services.entityDirectory.refresh(kind, force: true);
    await Future.wait([list, if (!widget.computers) loadDetail()]);
    if (!current) return;
    final failure = w.services.entityDirectory.state(kind).error;
    if (widget.computers &&
        failure == null &&
        w.services.entityDirectory.state(kind).loaded &&
        directoryRow == null) {
      closeProfile();
      return;
    }
    setState(() {
      row = compose();
      if (failure != null && !_renderable) {
        error = userErrorText(
          failure,
          fallback: raftGenericErrorText,
          where: 'fleet detail refresh',
        );
      }
    });
  }

  /// Web AgentDetailHeader onMessage: open (or create) the DM and jump to it.
  Future<void> message() async {
    // The DM with this agent is usually already in the sidebar: go there at
    // once; only a first conversation asks the server to create it.
    final existing = w.dms
        .where((c) => c.json['peerId'] == id && c.json['peerType'] == 'agent')
        .firstOrNull;
    final value = existing != null
        ? {'id': existing.id}
        : await w.client.post('/channels/dm', data: {'agentId': id});
    if (!current || value is! Map || value['id'] is! String) return;
    final leave = widget.onLeaveForMessage;
    if (leave != null) {
      leave();
      await w.jumpToMessage(value['id'], null);
      return;
    }
    await w.jumpToMessage(value['id'], null);
    if (mounted && widget.onClose == null) Navigator.of(context).maybePop();
    widget.onClose?.call();
  }

  /// ResetAgentDialog: one entry point, the mode is chosen in the dialog and
  /// the confirm button runs it (no second confirmation, like Web).
  Future<void> restartReset() async {
    if (!allowed('controlAgentRuntime') || external) return;
    await _fleetDialog<bool>(
      context,
      w,
      () => allowed('controlAgentRuntime'),
      (_) => RaftResetAgentDialog(
        agentName: nonEmptyOr(row['displayName'], row['name']),
        canFullReset: allowed('resetAgentWorkspace'),
        // Web: a plain member may only restart / reset the model.
        memberRuntimeOnly: w.server?.string('role') == 'member',
        onConfirm: resetRuntime,
      ),
    );
  }

  Future<void> action(
    Future<void> Function() operation, {
    String fallback = raftGenericErrorText,
  }) async {
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
      if (current) {
        setState(
          () => error = userErrorText(
            e,
            fallback: fallback,
            where: 'agent action',
          ),
        );
      }
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  /// AgentProfileEditDialog: one field per pencil (display name, description,
  /// role); the change is PATCHed to the agent.
  Future<void> editField(String field) async {
    require('editAgents');
    // Role options the viewer may assign (`canChangeAgentRole`): owners and
    // admins choose between Admin and Member.
    final role = '${row['serverRole'] ?? ''}';
    await _fleetDialog<bool>(
      context,
      w,
      () => allowed('editAgents'),
      (_) => RaftAgentProfileEditDialog(
        field: field,
        displayName: '${row['displayName'] ?? ''}',
        description: '${row['description'] ?? ''}',
        namePlaceholder: '${row['name'] ?? ''}',
        role: role.isEmpty ? null : role,
        roleOptions: const [('admin', 'Admin'), ('member', 'Member')],
        onSave: (fields) async {
          require('editAgents');
          await w.command('PATCH', base, data: fields);
          await load();
        },
      ),
      // Web `Dialog`: an outside press runs `requestClose`.
      dismissible: true,
      form: true,
      // The dialog asks about its own dirty draft (requestClose).
      guardUnsaved: false,
    );
  }

  Future<void> edit() async {
    final cap = widget.computers ? 'editMachines' : 'editAgents';
    require(cap);
    await _fleetDialog<void>(
      context,
      w,
      () => allowed(cap),
      form: true,
      (_) => RaftFormDialog(
        title: widget.computers ? 'Edit computer' : 'Edit agent',
        fields: [
          RaftFormField(
            widget.computers ? 'name' : 'displayName',
            'Display name',
            initial: nonEmptyOr(row['displayName'], row['name']),
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

  /// Web `ConfirmDialog` (raft-ui `Dialog`, `max-w-sm`): title, one plain
  /// message, Cancel and the coloured confirm action.
  Future<void> webConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    required String loadingLabel,
    required RaftButtonRecipeVariant variant,
    required Future<void> Function() operation,
  }) async {
    if (!current) return;
    await _fleetDialog<bool>(
      context,
      w,
      () => current,
      (_) => RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-dialog'),
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        loadingLabel: loadingLabel,
        confirmVariant: variant,
        onConfirm: () async {
          if (!current) throw const RaftApiException('Fleet access changed.');
          await operation();
        },
      ),
    );
  }

  Future<void> remove() async {
    bool removed = false;
    if (!widget.computers) {
      // AgentDetailPanel `ConfirmDialog` "Delete Agent" (external agents get
      // their own copy: the external runtime is left alone).
      final name = nonEmptyOr(row['displayName'], row['name']);
      await webConfirm(
        title: raftText(context, 'Delete Agent'),
        message: raftFormat(
          context,
          external
              ? 'Are you sure you want to delete "{name}"? This removes the Raft agent identity, credentials, and associated Raft data. It will not stop, uninstall, or clean up the external runtime, local profile, or harness.'
              : 'Are you sure you want to delete "{name}"? This will remove all associated data and cannot be undone.',
          {'name': name},
        ),
        confirmLabel: raftText(context, 'Delete Agent'),
        loadingLabel: raftText(context, 'Deleting…'),
        variant: RaftButtonRecipeVariant.danger,
        operation: () async {
          require('deleteAgents');
          await w.command('DELETE', base);
          removed = true;
        },
      );
      if (removed) closeProfile();
      return;
    }
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
    await Navigator.of(context, rootNavigator: true).push(
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
    final capability = mode == 'full'
        ? 'resetAgentWorkspace'
        : 'controlAgentRuntime';
    if (!allowed(capability) || external) {
      throw const RaftApiException('This action is not available.');
    }
    require(capability);
    // Web ResetAgentDialog: `data.error || agent.reset.failed`.
    await withWebError(
      'Failed to reset agent',
      () => w.command('POST', '$base/reset', data: {'mode': mode}),
      where: 'agent reset',
    );
    await load();
  }

  Future<void> runtimeCommand(String command) async {
    require(widget.computers ? 'controlComputers' : 'controlAgentRuntime');
    // The confirmation opens from the row on screen (the shared directory
    // keeps it current); the fresh read happens when the user confirms.
    String? upgradeTarget() {
      final policy = row['computerBroadcastPolicy'];
      final target = policy is Map ? policy['targetVersion'] : null;
      return target is String && row['computerUpgradeAvailable'] == true
          ? target
          : null;
    }

    final upgrading = widget.computers && command == 'upgrade';
    if (upgrading && upgradeTarget() == null) {
      throw const RaftApiException(
        'An upgrade is no longer available. Refresh this computer.',
      );
    }
    final target = upgradeTarget();
    if (!mounted) return;
    if (!widget.computers && command == 'stop') {
      // AgentDetailPanel `ConfirmDialog` "Stop Agent" (confirm colour orange).
      await webConfirm(
        title: raftText(context, 'Stop Agent'),
        message: raftFormat(
          context,
          'Are you sure you want to stop "{name}"? The agent will stop processing messages.',
          {'name': nonEmptyOr(row['displayName'], row['name'])},
        ),
        confirmLabel: raftText(context, 'Stop Agent'),
        loadingLabel: raftText(context, 'Stopping…'),
        variant: RaftButtonRecipeVariant.warning,
        operation: () async {
          require('controlAgentRuntime');
          await withWebError(
            'Failed to stop agent',
            () => w.command('POST', '$base/stop', data: {}),
            where: 'agent stop',
          );
          await load();
        },
      );
      return;
    }
    await confirm(
      '${command[0].toUpperCase()}${command.substring(1)} ${widget.computers ? 'computer' : 'agent'}?',
      upgrading
          ? 'Upgrade this computer to $target. Active agent sessions may be interrupted.'
          : 'This action affects the selected runtime.',
      () async {
        require(widget.computers ? 'controlComputers' : 'controlAgentRuntime');
        // Action time: re-read, then act only on what is still true.
        await load();
        if (!current) return;
        final fresh = upgrading ? upgradeTarget() : null;
        if (upgrading && fresh == null) {
          throw const RaftApiException(
            'An upgrade is no longer available. Refresh this computer.',
          );
        }
        final result = await w.command(
          'POST',
          widget.computers ? '$base/computer/$command' : '$base/$command',
          data: upgrading ? {'targetVersion': fresh} : {},
        );
        await load();
        if (mounted && current) {
          showRaftToast(
            context,
            result is Map && result['appliesOnReconnect'] == true
                ? 'Requested. Applies when the computer reconnects.'
                : 'Request accepted. Check runtime status for completion.',
            tone: RaftToastRecipeTone.success,
          );
        }
      },
    );
  }

  /// The "Edit runtime config" modal, then the confirmation it asks for
  /// (Web `requestConfirm` closes the modal before the ConfirmDialog opens).
  Future<void> editRuntime() async {
    if (!allowed('editAgents')) return;
    final machineId = row['machineId'];
    final confirm = await showAgentRuntimeEditor(
      context,
      controller: w,
      agent: row,
      machine: machineId is String
          ? machines?.where((m) => m['id'] == machineId).firstOrNull
          : null,
      authorized: () => allowed('editAgents'),
      onSaved: load,
    );
    if (confirm == null || !mounted) return;
    await webConfirm(
      title: confirm.title,
      message: confirm.message,
      confirmLabel: confirm.confirmLabel,
      loadingLabel: confirm.loadingLabel,
      variant: confirm.variant,
      operation: () async {
        require('editAgents');
        await confirm.operation();
        await load();
      },
    );
  }

  /// Web `ReportIssueDialog` (`canManageAgent && showReportDialog`).
  Future<void> reportIssue() async {
    final captured = scope;
    bool valid() =>
        current &&
        identical(scope, captured) &&
        row['deletedAt'] == null &&
        allowed('editAgents');
    if (!valid()) return;
    final machineId = row['machineId'];
    await showReportIssueDialog(
      context,
      controller: w,
      agent: row,
      machine: machineId is String
          ? machines?.where((m) => m['id'] == machineId).firstOrNull
          : null,
      activityLog: agentCachedActivityEntries(w, id),
      authorized: valid,
      exportUrl: widget.feedbackExportUrl,
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
      // Web `Dialog`: an outside press runs `requestClose` (the PopScope in
      // the dialog asks before discarding a staged change).
      barrierDismissible: true,
      builder: (_) => AgentAvatarDialog(
        controller: w,
        agent: row,
        authorized: valid,
        onSaved: (next) {
          if (!valid()) return;
          setState(() => row = next);
          unawaited(
            w.services.entityDirectory.refresh(
              WorkspaceEntityKind.agents,
              force: true,
            ),
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

  Widget agentPanel(BuildContext context) {
    final access = agentProfileAccess(
      agent: row,
      currentServerId: serverId,
      currentUserId: w.client.user?.id,
      editAgents: allowed('editAgents'),
      controlAgentRuntime: allowed('controlAgentRuntime'),
      external: external,
    );
    final managed = access.canManage && !busy;
    return AgentDetailPanel(
      controller: w,
      agent: row,
      machines: machines,
      liveActivity: liveActivity,
      initialTab: widget.initialTab,
      clock: widget.clock,
      initialTrajectoryLog: widget.initialTrajectoryLog,
      busy: busy,
      error: error,
      onDismissError: () => setState(() => error = null),
      canManage: access.canManage,
      canViewPrivate: access.canViewPrivate,
      canControlRuntime: access.canControlRuntime,
      actions: AgentDetailActions(
        onEditAvatar: managed ? editAvatar : null,
        onBack: widget.onClose ?? () => Navigator.of(context).maybePop(),
        onClose: widget.closeAction ? widget.onClose : null,
        backAlways: widget.backAlways,
        onEditName: managed ? () => editField('displayName') : null,
        onEditDescription: managed ? () => editField('description') : null,
        onEditRole: managed ? () => editField('role') : null,
        onEditRuntime: managed && !external && row['machineId'] is String
            ? editRuntime
            : null,
        onStartStop: () {
          final starting =
              agentRowAmbientDisplay(row, live: liveActivity).activity ==
              'offline';
          unawaited(
            action(
              () => runtimeCommand(starting ? 'start' : 'stop'),
              // Web handleStop: `agent.detail.stopAgentFailed`.
              fallback: starting
                  ? raftGenericErrorText
                  : 'Failed to stop agent',
            ),
          );
        },
        onRestartReset: () => action(restartReset),
        onDelete: access.canManage && allowed('deleteAgents') ? remove : null,
        onMessage: !access.boundedPublic && row['deletedAt'] == null
            ? () => action(message)
            : null,
        // Web `AgentMigrationSection`: `agent_migration_v0` and a computer.
        onMigrate:
            access.canManage &&
                allowed('migrateAgents') &&
                w.agentMigrationEnabled &&
                row['machineId'] is String
            ? () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AgentMigrationView(controller: w, agentId: id),
                ),
              )
            : null,
        onReportIssue:
            access.canManage &&
                reportIssueEnabled(
                  widget.feedbackExportUrl ?? reportIssueBuildUrl,
                ) &&
                row['deletedAt'] == null
            ? reportIssue
            : null,
        onPermissions: access.canManage
            ? () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => AgentScopesView(controller: w, agentId: id),
                ),
              )
            : null,
      ),
    );
  }

  /// Web `AgentById`: the id is not an agent this server holds (deleted,
  /// terminated or no access) once its list has loaded.
  bool gone = false;
  bool get _unavailable =>
      !widget.computers &&
      (gone ||
          row['deletedAt'] != null ||
          (w.services.entityDirectory.state(kind).loaded &&
              directoryRow == null));

  @override
  Widget build(BuildContext context) => !current
      ? const SizedBox.shrink()
      : !_renderable && _unavailable
      ? RaftAgentUnavailablePanel(
          onBack: widget.onClose ?? () => Navigator.of(context).maybePop(),
          onClose: widget.onClose,
        )
      : !_renderable
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

class _PendingFile {
  const _PendingFile();
}

const _pendingFile = _PendingFile();

class _FileReadFailed {
  const _FileReadFailed(this.message);
  final String message;
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
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when an action starts, a detail read succeeds, the user dismisses it, or the profile closes for an authority change.
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
      if (current && ticket == request) {
        setState(
          () => error = userErrorText(
            e,
            fallback: switch (widget.kind) {
              'workspace-files' => 'Failed to load files',
              'skills' => 'Failed to load skills',
              _ => raftGenericErrorText,
            },
            where: 'fleet inspection',
          ),
        );
      }
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
    // The dialog opens at once with the file name; the content (never held
    // locally) fills in when the read lands.
    final content = ValueNotifier<Object?>(_pendingFile);
    unawaited(
      widget.controller
          .query('${widget.base}/workspace-files/read', query: {'path': path})
          .then<void>(
            (data) {
              if (current && ticket == fileRequest) content.value = data;
            },
            onError: (Object e) {
              if (current && ticket == fileRequest) {
                content.value = _FileReadFailed(
                  userErrorText(
                    e,
                    fallback: 'Failed to load file',
                    where: 'workspace file read',
                  ),
                );
              }
            },
          ),
    );
    await _fleetDialog<void>(
      context,
      w,
      () => current && ticket == fileRequest,
      (dialog) => AlertDialog(
        title: Text('${row['name']}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: ValueListenableBuilder<Object?>(
              valueListenable: content,
              builder: (_, data, _) => SelectableText(switch (data) {
                _PendingFile() => raftText(context, 'Loading…'),
                _FileReadFailed(:final message) => raftText(context, message),
                Map() when data['binary'] == true =>
                  'Binary file · ${data['mimeType'] ?? ''} · ${data['size']} bytes',
                Map() => '${data['content'] ?? ''}',
                _ => '',
              }),
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
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: raftPageAppBar(
      context,
      title: switch (widget.kind) {
        'activity-log' => 'Activity log',
        'channels' => 'Agent channels',
        'agent-dms' => 'Agent conversations',
        'workspace-files' => 'Workspace files',
        'skills' => 'Skills',
        _ => 'Workspaces',
      },
      actions: [
        RaftTooltip(
          message: raftText(context, 'Refresh'),
          child: IconButton(
            onPressed: load,
            icon: const RaftIcon(RaftGlyph.refreshCw, size: 12),
          ),
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
                children: [RaftLoadError(error!, onRetry: load, expand: false)],
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
                  child: RaftErrorBanner(error!),
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
