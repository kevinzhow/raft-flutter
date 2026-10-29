import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/search_memory.dart';
import 'app_update.dart' show AppRelease, AppUpdateFetcher;

/// The client's own release notes: `release-notes.json`, an asset the release
/// CI attaches to every release (tool/release_notes.py). It has the shape of
/// one page of the Web `GET /release-notes` response (`{"items": [...],
/// "nextCursor": null}`), so the Settings > Release Notes view keeps its Web
/// parser and layout. The notes come from GitHub, not from the Raft server.
///
/// The stored copy remembers which app build downloaded it ([appBuild]). A
/// copy written by another build predates the installed version, so it is
/// never "fresh": after an app update the next [load] downloads again even if
/// the copy is only minutes old.
class ClientReleaseNotes {
  ClientReleaseNotes({
    required this.fetch,
    SearchMemoryStorage? storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(hours: 6),
    this.appBuild,
  }) : storage = storage ?? PreferencesSearchMemoryStorage(),
       _clock = clock ?? DateTime.now;

  static const url =
      '${AppRelease.repository}/releases/latest/download/release-notes.json';
  static const storageKey = 'raft:release-notes:v1';

  final AppUpdateFetcher fetch;
  final SearchMemoryStorage storage;
  final DateTime Function() _clock;
  final Duration maxAge;

  /// The running app's CI build number; null for builds without one.
  final int? appBuild;
  Future<List<RaftReleaseNote>>? _inflight, _downloading;
  DateTime? _downloadedAt;

  /// The notes: the stored copy while it is younger than [maxAge], was
  /// written by this app build and (with [requireTag]) holds that release;
  /// otherwise a fresh download. Offline (or an unusable download) falls back
  /// to the last stored copy, except that a copy without [requireTag] is no
  /// answer and the error is rethrown; with no copy at all the error is
  /// rethrown too. A release without the asset yields an empty list.
  Future<List<RaftReleaseNote>> load({
    bool force = false,
    String? requireTag,
  }) => _inflight ??= _load(
    force,
    requireTag,
  ).whenComplete(() => _inflight = null);

  /// The stored copy of any age, without a request; null when there is none.
  Future<List<RaftReleaseNote>?> cached() async => (await _readStored())?.notes;

  /// Always downloads (concurrent calls share one request) and stores the
  /// result. Unlike [load] a failure is reported, so a view that already shows
  /// the stored copy can tell the user it could not be refreshed. With [minAge]
  /// a download made less than that long ago by this object is not repeated:
  /// the stored copy it wrote is returned instead.
  Future<List<RaftReleaseNote>> refresh({Duration minAge = Duration.zero}) {
    final at = _downloadedAt, now = _clock();
    if (minAge > Duration.zero &&
        _downloading == null &&
        at != null &&
        !now.isBefore(at) &&
        now.difference(at) < minAge) {
      return cached().then((notes) => notes ?? const []);
    }
    return _download();
  }

  Future<List<RaftReleaseNote>> _download() =>
      _downloading ??= _fetchAndStore().whenComplete(() => _downloading = null);

  Future<List<RaftReleaseNote>> _fetchAndStore() async {
    final now = _clock();
    final downloaded = await fetch(Uri.parse(url));
    // A release without the asset: whatever is stored stays.
    if (downloaded == null) return await cached() ?? const [];
    final parsed = parseClientReleaseNotes(downloaded);
    _downloadedAt = now;
    try {
      await storage.write(
        storageKey,
        jsonEncode({
          'fetchedAt': now.millisecondsSinceEpoch,
          'body': downloaded,
          'appBuild': ?appBuild,
        }),
      );
    } catch (_) {
      // The notes are still shown this time.
    }
    return parsed;
  }

  Future<({List<RaftReleaseNote> notes, DateTime? at, int? build})?>
  _readStored() async {
    String? body;
    DateTime? fetchedAt;
    int? build;
    try {
      final raw = await storage.read(storageKey);
      final stored = raw == null ? null : jsonDecode(raw);
      if (stored is Map && stored['body'] is String) {
        body = stored['body'] as String;
        final at = stored['fetchedAt'];
        if (at is int) fetchedAt = DateTime.fromMillisecondsSinceEpoch(at);
        final by = stored['appBuild'];
        if (by is int) build = by;
      }
    } catch (_) {
      // An unreadable copy is no copy.
    }
    if (body == null) return null;
    try {
      return (
        notes: parseClientReleaseNotes(body),
        at: fetchedAt,
        build: build,
      );
    } on FormatException {
      return null;
    }
  }

  Future<List<RaftReleaseNote>> _load(bool force, String? requireTag) async {
    final stored = await _readStored();
    final now = _clock();
    final at = stored?.at;
    final fresh =
        at != null &&
        !now.isBefore(at) &&
        now.difference(at) < maxAge &&
        (appBuild == null || stored?.build == appBuild);
    final covers =
        requireTag == null ||
        (stored?.notes.any((n) => n.id == requireTag) ?? false);
    if (stored != null && fresh && covers && !force) return stored.notes;
    try {
      return await _download();
    } catch (_) {
      if (stored != null && covers) return stored.notes;
      rethrow;
    }
  }
}

/// The notes a user reads before installing the offered release
/// ([offeredTag]): that release and every one between it and the installed
/// one, newest first ([notes] is newest first, as the asset lists it). The
/// installed release itself is excluded, retracted releases are skipped. Empty
/// when [notes] has nothing for the offered release.
///
/// [installedTag] is the running build's release tag when it knows it; without
/// it (builds made before the tag was compiled in) the range is the offered
/// release plus every release of a higher app version than [installedVersion].
List<RaftReleaseNote> releasesBetween(
  List<RaftReleaseNote> notes, {
  required String offeredTag,
  required String? installedTag,
  required String installedVersion,
}) {
  final offered = notes.indexWhere((n) => n.id == offeredTag);
  if (offered < 0) return const [];
  final installed = installedTag == null || installedTag.isEmpty
      ? -1
      : notes.indexWhere((n) => n.id == installedTag);
  final result = <RaftReleaseNote>[];
  for (var i = offered; i < notes.length; i++) {
    final note = notes[i];
    final include = i == offered
        ? true
        : installed > offered
        ? i < installed
        : installed < 0 &&
              _compareCore(note.version ?? '', installedVersion) > 0;
    if (installed > offered && i >= installed) break;
    if (include && !note.retracted) result.add(note);
  }
  return result;
}

List<int> _core(String version) => [
  for (final part in version.split('-').first.split('.'))
    int.tryParse(part) ?? 0,
];

int _compareCore(String a, String b) {
  final x = _core(a), y = _core(b);
  for (var i = 0; i < 3; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}

/// [notes] with the installed release marked [RaftReleaseNote.current] and the
/// releases above it (newer, not installed) [RaftReleaseNote.isNew].
///
/// The installed release is [installedTag]; without it, the one release of
/// [installedVersion] when there is exactly one (a build number alone says
/// nothing about the tag, see [AppUpdateService.installedTag]). When the
/// installed release cannot be found, [notes] are returned unchanged: the
/// newest published release stays Current, as [parseClientReleaseNotes] marks it.
List<RaftReleaseNote> markInstalled(
  List<RaftReleaseNote> notes, {
  required String? installedTag,
  required String installedVersion,
}) {
  var at = installedTag == null || installedTag.isEmpty
      ? -1
      : notes.indexWhere((n) => n.id == installedTag);
  if (at < 0) {
    final same = [
      for (var i = 0; i < notes.length; i++)
        if (!notes[i].retracted && notes[i].version == installedVersion) i,
    ];
    if (same.length == 1) at = same.single;
  }
  if (at < 0) return notes;
  return [
    for (final (i, n) in notes.indexed)
      RaftReleaseNote(
        id: n.id,
        date: n.date,
        version: n.version,
        current: i == at,
        isNew: i < at && !n.retracted,
        retracted: n.retracted,
        entries: n.entries,
      ),
  ];
}

enum UpdateNotesStatus { loading, ready, empty, failed }

/// The notes of the release the update prompt offers: one read per offered
/// release (a rebuild or a repeated update check does not start another) and
/// a [retry] after a failure. A failure never blocks the update itself.
class UpdateReleaseNotes extends ChangeNotifier {
  UpdateReleaseNotes(this.source);
  final ClientReleaseNotes source;

  UpdateNotesStatus status = UpdateNotesStatus.loading;
  List<RaftReleaseNote> releases = const [];
  String? _tag, _installedTag;
  String _installedVersion = '';
  int _ticket = 0;
  // ignore: raft_lints/avoid_imperative_notice_state -- lifecycle flag, not UI state.
  bool _disposed = false;

  /// Starts reading the notes of [release] unless that read is the current
  /// one. Safe to call from a build: it only notifies when the read ends.
  void show(
    AppRelease release, {
    required String installedTag,
    required String installedVersion,
  }) {
    if (_tag == release.releaseTag) return;
    _tag = release.releaseTag;
    _installedTag = installedTag;
    _installedVersion = installedVersion;
    _start();
  }

  void retry() {
    if (_tag == null) return;
    _start();
    notifyListeners();
  }

  void _start() {
    final ticket = ++_ticket;
    final tag = _tag!;
    status = UpdateNotesStatus.loading;
    releases = const [];
    source
        .load(requireTag: tag)
        .then(
          (notes) {
            if (_disposed || ticket != _ticket) return;
            releases = releasesBetween(
              notes,
              offeredTag: tag,
              installedTag: _installedTag,
              installedVersion: _installedVersion,
            );
            status = releases.isEmpty
                ? UpdateNotesStatus.empty
                : UpdateNotesStatus.ready;
            notifyListeners();
          },
          onError: (Object _) {
            if (_disposed || ticket != _ticket) return;
            status = UpdateNotesStatus.failed;
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

const _kinds = {
  'feature': RaftReleaseNoteKind.feature,
  'improvement': RaftReleaseNoteKind.improvement,
  'fix': RaftReleaseNoteKind.fix,
  'breaking': RaftReleaseNoteKind.breaking,
  'deprecated': RaftReleaseNoteKind.deprecated,
};

/// Web `parseRelease` / `parseReleaseNotesPage` for one page: a malformed
/// document fails as a whole (the Web view shows its unavailable banner
/// rather than a partial list). The first published release is Current.
@visibleForTesting
List<RaftReleaseNote> parseClientReleaseNotes(String body) {
  final Object? raw;
  try {
    raw = jsonDecode(body);
  } on FormatException {
    throw const FormatException('release notes');
  }
  if (raw is! Map || raw['items'] is! List) {
    throw const FormatException('release notes page');
  }
  final rows = [for (final item in raw['items'] as List) _parseRelease(item)];
  final current = rows.where((r) => r.published).firstOrNull?.id;
  return [
    for (final r in rows)
      r.id == current
          ? RaftReleaseNote(
              id: r.note.id,
              date: r.note.date,
              version: r.note.version,
              current: true,
              retracted: r.note.retracted,
              entries: r.note.entries,
            )
          : r.note,
  ];
}

({String id, RaftReleaseNote note, bool published}) _parseRelease(Object? raw) {
  if (raw is! Map) throw const FormatException('release');
  final id = raw['releaseId'], date = raw['date'], state = raw['state'];
  final version = raw['version'], entries = raw['entries'];
  if (id is! String ||
      id.isEmpty ||
      date is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      (state != 'published' && state != 'retracted') ||
      (version != null && version is! String) ||
      entries is! List) {
    throw const FormatException('release');
  }
  final parsed = [
    for (final e in entries)
      if (e is Map &&
          _kinds[e['type']] != null &&
          e['text'] is String &&
          e['emphasis'] is bool)
        RaftReleaseNoteEntry(
          _kinds[e['type']]!,
          e['text'] as String,
          emphasis: e['emphasis'] as bool,
        )
      else
        throw const FormatException('release entry'),
  ];
  return (
    id: id,
    published: state == 'published',
    note: RaftReleaseNote(
      id: id,
      date: date,
      version: version as String?,
      retracted: state == 'retracted',
      entries: parsed,
    ),
  );
}
