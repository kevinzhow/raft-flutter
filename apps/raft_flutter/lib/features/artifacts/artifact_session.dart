// Per-session Artifacts state: the workspace_artifacts_v0 flag, the object
// summaries the message cards read, and the deployment the frames load from.
//
// Source: packages/web/src/apps/artifacts/useWorkspaceArtifactsEnabled.ts and
// packages/web/src/objects/objectSummaryLoader.ts at v1.24.0-source.1.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show ArtifactAttachmentSavedEvent;

import '../../data/device_preferences.dart';
import '../../data/feature_flag_client_facts.dart';
import '../../data/workspace_controller.dart';
import 'artifact_api.dart';
import 'artifact_attachment_saves.dart';
import 'artifact_models.dart';

/// One presentation's Artifacts: created by the first surface that needs it
/// (a message card, a link, the attachment menu), disposed with the session.
/// A new principal, server or role drops every summary and the flag's value
/// (Web: the loader clears on a server switch or a new access token).
class ArtifactSession extends ChangeNotifier {
  ArtifactSession._(this.w) : api = ArtifactApi(w.client) {
    w.addListener(_changed);
    _events = w.client.events.listen(_event);
    w.services.disposeWithSession(dispose);
    _changed();
  }

  static final _owners = Expando<ArtifactSession>('artifact session');

  static ArtifactSession of(WorkspaceController w) =>
      _owners[w] ??= ArtifactSession._(w);

  /// Tests install a session with a fake client.
  @visibleForTesting
  static ArtifactSession? peek(WorkspaceController w) => _owners[w];

  static const flagKey = RaftFeatureFlags.workspaceArtifacts;

  final WorkspaceController w;
  final ArtifactApi api;
  StreamSubscription<RaftEvent>? _events;
  String? _scope;
  int _ticket = 0;
  bool _ended = false;
  bool _enabled = false;

  /// workspace_artifacts_v0 for this server (default off until evaluated;
  /// the last accepted value is remembered on the device).
  bool get enabled => _enabled;

  /// Bumped on every change of what a summary or save may answer.
  int generation = 0;

  String get _authority => jsonEncode([
    w.client.origin,
    w.client.generation,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ]);

  List<Object?> get _memoryScope => [
    w.client.origin,
    w.client.user?.id,
    w.server?.id,
    w.server?.string('role'),
  ];

  void _changed({bool reevaluate = false}) {
    if (_ended || w.services.isDisposed()) return;
    final next = _authority;
    final same = next == _scope;
    if (same && !reevaluate) return;
    _scope = next;
    if (!same) {
      generation++;
      summaries.clear();
      attachments.clear();
      final remembered =
          w.server != null &&
          w.client.user != null &&
          (FeatureFlagMemory.read(_memoryScope, flagKey) ?? false);
      if (remembered != _enabled) {
        _enabled = remembered;
        notifyListeners();
      }
    }
    final server = w.server;
    if (server != null && w.client.user != null) {
      unawaited(_evaluate(next, ++_ticket, server.id));
    }
  }

  Future<void> _evaluate(String authority, int ticket, String server) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: const [flagKey], serverId: server),
      );
      if (_ended || authority != _authority || ticket != _ticket) return;
      final rows = value is Map ? value['evaluations'] : null;
      if (rows is! List) return;
      final matches = rows
          .whereType<Map>()
          .where((row) => row['key'] == flagKey)
          .toList(growable: false);
      if (matches.length != 1 || matches.single['enabled'] is! bool) return;
      _accept(matches.single['enabled'] as bool);
    } catch (error) {
      if (!_ended &&
          authority == _authority &&
          ticket == _ticket &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        _accept(false);
      }
    }
  }

  void _accept(bool enabled) {
    FeatureFlagMemory.write(_memoryScope, {flagKey: enabled});
    if (enabled == _enabled) return;
    _enabled = enabled;
    notifyListeners();
  }

  /// Test seam: answer the flag without a server.
  @visibleForTesting
  void debugSetEnabled(bool enabled) {
    _enabled = enabled;
    notifyListeners();
  }

  void _event(RaftEvent event) {
    if (event.name == ArtifactAttachmentSavedEvent.name) {
      // Web handleArtifactAttachmentSaved: only with the flag on, and only
      // for an attachment shown here.
      final saved = ArtifactAttachmentSavedEvent.read(event.payload);
      if (saved != null && _enabled) attachments.saved(saved.attachmentId);
      return;
    }
    if (event.name == 'server:updated' || event.name == 'connected') {
      _changed(reevaluate: true);
    } else if (event.name == 'server:features-changed') {
      final payload = event.payload;
      final keys = payload is Map ? payload['keys'] : null;
      if (payload is Map &&
          payload['serverId'] == w.server?.id &&
          (keys is! List || keys.contains(flagKey))) {
        _changed(reevaluate: true);
      }
    }
  }

  /// What the attachments on screen were saved as (and saves under way).
  late final attachments = AttachmentSaves(api: api);

  late final summaries = ObjectSummaryLoader(
    post: (refs) => api.objectSummaries(refs),
    onChanged: notifyListeners,
  );

  ArtifactDeployment? _deployment;
  Future<ArtifactDeployment>? _deploymentRead;

  /// The deployment, once read (null before).
  ArtifactDeployment? get deployment => _deployment;

  Future<ArtifactDeployment> readDeployment() =>
      _deploymentRead ??= ArtifactDeployment.of(w.client).then((value) {
        _deployment = value;
        if (!_ended) notifyListeners();
        return value;
      });

  /// The Artifact [href] names when Artifacts are on here, else null (with
  /// the flag off a link to an Artifact is a plain link).
  ArtifactLinkTarget? linkTarget(String href) {
    if (!_enabled) return null;
    final deployment = _deployment;
    if (deployment == null) {
      unawaited(readDeployment());
      return artifactLinkTarget(
        href,
        ArtifactDeployment.resolve(w.client.origin, null).appHosts,
      );
    }
    return artifactLinkTarget(href, deployment.appHosts);
  }

  @override
  void dispose() {
    if (_ended) return;
    _ended = true;
    w.removeListener(_changed);
    unawaited(_events?.cancel());
    _events = null;
    summaries.dispose();
    attachments.dispose();
    super.dispose();
  }
}

/// One answer of the object summaries for one reference.
typedef ObjectSummaryPost = Future<List<Object?>> Function(
  List<ArtifactLinkTarget> refs,
);

/// Batches the Artifact references every visible message asks about into one
/// `POST /api/objects/summaries` per 10 ms (at most 50 a request), keeps
/// answers 60 s (unavailable and deleted ones 15 s), and holds the next
/// request for a 429's Retry-After (Web `createObjectSummaryLoader`).
class ObjectSummaryLoader {
  ObjectSummaryLoader({
    required this.post,
    this.onChanged,
    this.batchWindow = const Duration(milliseconds: 10),
    this.okTtl = const Duration(seconds: 60),
    this.unavailableTtl = const Duration(seconds: 15),
    this.maxEntries = 1000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ObjectSummaryPost post;
  final VoidCallback? onChanged;
  final Duration batchWindow, okTtl, unavailableTtl;
  final int maxEntries;
  final DateTime Function() _now;

  final _kept =
      <ArtifactLinkTarget, ({ArtifactLinkState state, DateTime until})>{};
  final _waiting = <ArtifactLinkTarget>{};
  final _inFlight = <ArtifactLinkTarget>{};
  Timer? _timer;
  DateTime? _heldUntil;
  int _generation = 0;
  bool _disposed = false;

  /// Starts a read when the answer is missing or expired. A resolved card
  /// stays visible until the refresh answers.
  ArtifactLinkState stateOf(ArtifactLinkTarget target) {
    final kept = _kept[target];
    if (kept != null) {
      final fresh = kept.until.isAfter(_now());
      // Most recently used last (the oldest go first past maxEntries).
      _kept.remove(target);
      if (fresh || kept.state is ArtifactLinkOk) _kept[target] = kept;
      if (fresh) return kept.state;
    }
    if (!_inFlight.contains(target) && _waiting.add(target)) _schedule();
    return kept?.state ?? ArtifactLinkLoading(target);
  }

  /// Forgets [target]'s answer (an Artifact changed) and reads it again.
  void invalidate(String id) {
    _kept.removeWhere((target, _) => target.id == id);
    onChanged?.call();
  }

  void clear() {
    _generation++;
    _kept.clear();
    _waiting.clear();
    _inFlight.clear();
    _timer?.cancel();
    _timer = null;
    _heldUntil = null;
  }

  void _schedule([Duration? delay]) {
    if (_disposed || _timer != null) return;
    _timer = Timer(delay ?? batchWindow, _flush);
  }

  void _flush() {
    _timer = null;
    if (_disposed || _waiting.isEmpty) return;
    final held = _heldUntil;
    if (held != null && held.isAfter(_now())) {
      _schedule(held.difference(_now()));
      return;
    }
    final all = _waiting.toList();
    _waiting.clear();
    _inFlight.addAll(all);
    for (var at = 0; at < all.length; at += objectSummariesMaxRefs) {
      final chunk = all.sublist(
        at,
        (at + objectSummariesMaxRefs).clamp(0, all.length),
      );
      unawaited(_send(chunk, _generation));
    }
  }

  Future<void> _send(List<ArtifactLinkTarget> chunk, int generation) async {
    try {
      final answers = await post(chunk);
      if (_disposed || generation != _generation) return;
      final byRef = <ArtifactLinkTarget, Map>{};
      for (final answer in answers) {
        if (answer is! Map) continue;
        final ref = answer['ref'];
        final id = ref is Map ? ref['id'] : null;
        if (id is! String) continue;
        final version = ref is Map ? ref['version'] : null;
        byRef[ArtifactLinkTarget(id, version is int ? version : null)] = answer;
      }
      final now = _now();
      for (final target in chunk) {
        _inFlight.remove(target);
        final answer = byRef[target];
        final ArtifactLinkState state;
        if (answer == null) {
          state = ArtifactLinkUnavailable(target);
        } else if (answer['ok'] == true) {
          final card = ArtifactCard.fromJson(answer['summary']);
          state = card == null
              ? ArtifactLinkUnavailable(target)
              : ArtifactLinkOk(target, card);
        } else if (answer['reason'] == 'deleted') {
          final deleted = ArtifactDeleted.fromJson(answer['deleted']);
          state = deleted == null
              ? ArtifactLinkUnavailable(target)
              : ArtifactLinkDeleted(target, deleted);
        } else {
          state = ArtifactLinkUnavailable(target);
        }
        _kept[target] = (
          state: state,
          until: now.add(state is ArtifactLinkOk ? okTtl : unavailableTtl),
        );
      }
      while (_kept.length > maxEntries) {
        _kept.remove(_kept.keys.first);
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      if (error is RaftApiException && error.status == 429) {
        final wait = error.retryAfter ?? const Duration(seconds: 5);
        final clamped = Duration(
          milliseconds: wait.inMilliseconds.clamp(1000, 60000),
        );
        _heldUntil = _now().add(clamped);
      }
      // The card shows nothing for a failed read. Web asks again when the
      // message mounts again; this loader is asked on every paint, so it asks
      // again after the hold or the unavailable answer's lifetime.
      final retry = _now().add(unavailableTtl);
      final held = _heldUntil;
      for (final target in chunk) {
        _inFlight.remove(target);
        _kept[target] = (
          state: ArtifactLinkUnavailable(target, error: true),
          until: held != null && held.isAfter(retry) ? held : retry,
        );
      }
    }
    onChanged?.call();
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
