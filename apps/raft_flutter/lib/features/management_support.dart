import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/device_preferences.dart';
import '../data/resource_snapshot_cache.dart';
import '../data/workspace_controller.dart';

Map<String, dynamic> managementMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> managementRows(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : [];
List<String> managementStrings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];
String? managementHttpUrl(String value) {
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? null
      : 'Enter a complete HTTP or HTTPS address.';
}

Future<void> managementLaunch(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('Could not open this address.');
  }
}

/// Server-level identity of a management or settings page: account
/// generation, principal, server and role. Server capabilities derive from the
/// role, so equal identities see the same management data.
String pageIdentity(WorkspaceController w) =>
    '${w.client.generation}|${w.client.user?.id}|${w.server?.id}|${w.server?.string("role")}';

/// The fields a settings view last accepted for [key] under the current
/// [pageIdentity] (in memory on the controller; see [ManagementState]).
Map<String, Object?>? readPageSnapshot(WorkspaceController w, String key) => w
    .resourceSnapshots
    .read<FieldSnapshot>('page:$key', pageIdentity(w))
    ?.fields;

/// Record [fields] for [key] as accepted under [identity]; a result that
/// arrives after the identity changed is never cached.
void writePageSnapshot(
  WorkspaceController w,
  String key,
  String identity,
  Map<String, Object?> fields,
) {
  if (identity != pageIdentity(w)) return;
  w.resourceSnapshots.write(
    'page:$key',
    FieldSnapshot(identity: identity, fields: fields),
  );
}

List<Object?> _flagMemoryScope(WorkspaceController w) => [
  w.client.origin,
  w.client.user?.id,
  w.server?.id,
  w.server?.string('role'),
];

/// A server-level feature flag value last evaluated under the current
/// identity (this session, else the device's [FeatureFlagMemory]), so a page
/// gated on it renders final at its first frame.
bool? cachedServerFlag(WorkspaceController w, String key) =>
    readPageSnapshot(w, 'flag:$key')?['enabled'] as bool? ??
    (w.server == null || w.client.user == null
        ? null
        : FeatureFlagMemory.read(_flagMemoryScope(w), key));

/// Record [key] as evaluated under [identity] (dropped if it changed since).
void rememberServerFlag(
  WorkspaceController w,
  String key,
  bool enabled,
  String identity,
) {
  if (identity != pageIdentity(w)) return;
  writePageSnapshot(w, 'flag:$key', identity, {'enabled': enabled});
  FeatureFlagMemory.write(_flagMemoryScope(w), {key: enabled});
}

/// Management screens never persist API payloads or one-time credentials.
/// An account or workspace generation change invalidates every pending result.
///
/// Pages that name a [snapshotKey] keep their last accepted projection in the
/// controller's in-memory page cache, bound to [snapshotIdentity]: a revisit
/// renders it in the first frame and revalidates in the background; only a
/// true cold load shows the loading state.
abstract class ManagementState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  WorkspaceController get w;
  bool loading = true, busy = false;
  String? error;
  int _request = 0;
  String? _authority;
  WorkspaceController? _listenedController;
  String? _operationAuthority;
  String get authority => pageIdentity(w);
  Future<void> loadData(int request, int generation);
  void clearData();

  /// Page/route id plus the request inputs that select its data. Null keeps
  /// the page uncached.
  String? get snapshotKey => null;

  /// The identity a snapshot is accepted under. Pages whose [authority]
  /// carries mount-local revisions override this with its stable part.
  String get snapshotIdentity => authority;

  /// The page's data fields by name. Never include one-time credentials.
  Map<String, Object?> captureSnapshot() => const {};

  /// Assign captured fields back; false rejects a snapshot that no longer
  /// applies to the current workspace state.
  bool restoreSnapshot(Map<String, Object?> fields) => true;

  /// The page shows data accepted under the current authority.
  bool _accepted = false;
  int? _loadingRequest;
  String? get _snapshotSection {
    final key = snapshotKey;
    return key == null ? null : 'management:$key';
  }

  bool _restoreSnapshot() {
    final section = _snapshotSection;
    if (section == null) return false;
    final snapshot = w.resourceSnapshots.read<FieldSnapshot>(
      section,
      snapshotIdentity,
    );
    if (snapshot == null) return false;
    if (!restoreSnapshot(snapshot.fields)) {
      w.resourceSnapshots.remove(section);
      clearData();
      return false;
    }
    _accepted = true;
    loading = false;
    return true;
  }

  /// Record the current projection as the page snapshot. Called after every
  /// accepted load and mutation; pages that patch their fields outside [run]
  /// call it themselves.
  void saveSnapshot() {
    final section = _snapshotSection;
    if (section == null || !_accepted || _authority != authority) return;
    w.resourceSnapshots.write(
      section,
      FieldSnapshot(identity: snapshotIdentity, fields: captureSnapshot()),
    );
  }

  void _dropSnapshot() {
    _accepted = false;
    final section = _snapshotSection;
    if (section != null) w.resourceSnapshots.remove(section);
  }

  /// The snapshot section the page last bound to. A page whose key follows
  /// its inputs (a member id) moves to another section when they change; the
  /// section it left keeps its snapshot for a revisit.
  String? _sectionInUse;

  void startManagement() {
    _authority = authority;
    WidgetsBinding.instance.addObserver(this);
    _listenedController = w;
    w.addListener(_workspaceChanged);
    _sectionInUse = _snapshotSection;
    _restoreSnapshot();
    reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  void _workspaceChanged() {
    if (_authority == authority) return;
    _authority = authority;
    _request++;
    final moved = _snapshotSection != _sectionInUse;
    _sectionInUse = _snapshotSection;
    if (!moved) _dropSnapshot();
    clearData();
    _accepted = false;
    final restored = moved && _restoreSnapshot();
    if (mounted) {
      setState(() {
        error = null;
        loading = !restored;
      });
      reload();
    }
  }

  /// Rebind an explicitly reused page State to its new controller. Old HTTP
  /// tickets and private projections are retired before any new request.
  void rebindManagementController() {
    if (identical(_listenedController, w)) return;
    _listenedController?.removeListener(_workspaceChanged);
    _listenedController = w;
    w.addListener(_workspaceChanged);
    _authority = authority;
    ++_request;
    _accepted = false;
    clearData();
    loading = true;
    error = null;
    _sectionInUse = _snapshotSection;
    _restoreSnapshot();
    reload();
  }

  /// Reevaluate authority after a source event invalidates a page-specific scope.
  void refreshAuthority() => _workspaceChanged();

  /// A mount-local revision moved while the data identity did not: retire
  /// in-flight work and revalidate without blanking the accepted projection.
  void revalidateAuthority() {
    if (_authority == authority) return;
    _authority = authority;
    _request++;
    if (mounted) reload();
  }

  Future<void> reload() async {
    final request = ++_request, generation = w.client.generation;
    final before = _accepted && snapshotKey != null ? captureSnapshot() : null;
    _loadingRequest = request;
    try {
      await loadData(request, generation);
      if (!mounted ||
          request != _request ||
          generation != w.client.generation) {
        return;
      }
      // Unchanged rows keep their accepted objects.
      if (before != null) {
        restoreSnapshot(stableFields(before, captureSnapshot()));
      }
      setState(() {
        loading = false;
        error = null;
      });
      _accepted = true;
      saveSnapshot();
    } catch (e) {
      if (mounted && request == _request && generation == w.client.generation) {
        if (e is RaftApiException && [401, 403].contains(e.status)) {
          _dropSnapshot();
          clearData();
        }
        // Any other failure keeps the accepted projection and its snapshot.
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    } finally {
      if (_loadingRequest == request) _loadingRequest = null;
    }
  }

  /// A loader must check this before assigning results to its page projection.
  bool accepts(int generation, [int? request]) =>
      mounted &&
      generation == w.client.generation &&
      _authority == authority &&
      (request == null || request == _request);
  Future<void> run(
    Future<void> Function() action, {
    bool refresh = true,
  }) async {
    if (busy) return;
    final generation = w.client.generation, sourceAuthority = authority;
    _operationAuthority = sourceAuthority;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (accepts(generation) && authority == sourceAuthority) {
        if (refresh) {
          await reload();
        } else {
          saveSnapshot();
        }
      }
    } catch (e) {
      if (accepts(generation) && authority == sourceAuthority) {
        invalidateDeniedMutation(e);
        setState(() => error = '$e');
      }
    } finally {
      _operationAuthority = null;
      if (mounted) setState(() => busy = false);
    }
  }

  bool invalidateDeniedMutation(Object error) {
    if (error is! RaftApiException || ![401, 403].contains(error.status)) {
      return false;
    }
    _request++;
    _dropSnapshot();
    clearData();
    if (mounted) {
      setState(() {
        loading = false;
        this.error = '$error';
      });
    }
    return true;
  }

  Future<V?> scopedDialog<V>(Widget Function(BuildContext) builder) async {
    final sourceAuthority = _operationAuthority ?? authority;
    if (!mounted || sourceAuthority != authority) return null;
    BuildContext? routeContext;
    void dismissOnScopeChange() {
      if (sourceAuthority == authority) return;
      final current = routeContext;
      if (current != null && current.mounted) {
        final route = ModalRoute.of(current);
        if (route != null && route.isActive) {
          Navigator.of(current).removeRoute(route);
        }
      }
    }

    w.addListener(dismissOnScopeChange);
    try {
      return await showDialog<V>(
        context: context,
        builder: (context) {
          routeContext = context;
          if (sourceAuthority != authority) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              dismissOnScopeChange();
            });
            return const SizedBox.shrink();
          }
          return builder(context);
        },
      );
    } finally {
      w.removeListener(dismissOnScopeChange);
    }
  }

  Future<void> launchManaged(String value) async {
    if (!mounted ||
        (_operationAuthority != null && _operationAuthority != authority)) {
      return;
    }
    await managementLaunch(value);
  }

  Future<bool> form(
    String title,
    List<RaftFormField> fields,
    Future<void> Function(Map<String, String>) save, {
    String submit = 'Save',
    String? description,
    bool destructive = false,
  }) async {
    final generation = w.client.generation, sourceAuthority = authority;
    return await scopedDialog<bool>(
          (dialogContext) => RaftFormDialog(
            title: title,
            fields: fields,
            onSubmit: (values) async {
              if (!accepts(generation) || sourceAuthority != authority) {
                throw StateError(
                  'The active workspace changed. Reopen this form.',
                );
              }
              try {
                await save(values);
              } catch (e) {
                if (accepts(generation) &&
                    sourceAuthority == authority &&
                    invalidateDeniedMutation(e) &&
                    dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
                rethrow;
              }
            },
            submitLabel: submit,
            description: description,
            destructive: destructive,
          ),
        ) ==
        true;
  }

  Future<bool> confirm(
    String title,
    String description,
    Future<void> Function() save, {
    String submit = 'Confirm',
    bool destructive = false,
  }) => form(
    title,
    [],
    (_) => save(),
    submit: submit,
    description: description,
    destructive: destructive,
  );
  Future<void> secret(
    String value, {
    String label = 'One-time credential',
  }) async {
    if (!mounted) return;
    await scopedDialog<void>(
      (context) => AlertDialog(
        title: Text(raftText(context, label)),
        content: SizedBox(
          width: 480,
          child: RaftSecretView(
            value: value,
            label: 'Save this credential before closing.',
            onCopy: (value) => Clipboard.setData(ClipboardData(text: value)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(raftText(context, 'Close')),
          ),
        ],
      ),
    );
  }

  Widget page(
    String title,
    List<Widget> children, {
    List<Widget> actions = const [],
  }) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleWidget = Text(
              raftText(context, title),
              style: Theme.of(context).textTheme.headlineSmall,
            );
            final refresh = IconButton(
              onPressed: busy ? null : reload,
              tooltip: raftText(context, 'Refresh'),
              icon: const Icon(Icons.refresh),
            );
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: titleWidget),
                      refresh,
                    ],
                  ),
                  if (actions.isNotEmpty)
                    Wrap(spacing: 4, runSpacing: 4, children: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: titleWidget),
                ...actions,
                refresh,
              ],
            );
          },
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (loading) const LinearProgressIndicator(),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: children),
      ),
    ],
  );
  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      raftText(context, title),
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );

  /// [glyph] (with the Web's icon size) wins over [icon]; see
  /// docs/glyph-mapping.md for the Web element each call site mirrors.
  Widget action(
    String label,
    VoidCallback? callback, {
    IconData? icon,
    RaftGlyph? glyph,
    double glyphSize = 14,
  }) => TextButton.icon(
    onPressed: busy ? null : callback,
    icon: glyph != null
        ? RaftIcon(glyph, size: glyphSize)
        : Icon(icon ?? Icons.chevron_right),
    label: Text(raftText(context, label)),
  );
  @override
  void dispose() {
    // A load still in flight may have assigned part of its result; the
    // snapshot keeps the last complete projection instead.
    if (_loadingRequest == null) saveSnapshot();
    WidgetsBinding.instance.removeObserver(this);
    _listenedController?.removeListener(_workspaceChanged);
    _request++;
    super.dispose();
  }
}
