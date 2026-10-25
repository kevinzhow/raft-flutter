import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:raft_client/raft_client.dart';

import '../data/attachment_disk_cache.dart';
import 'artifact_web_data.dart';
import 'cache_staging.dart';
import 'session_store.dart';
import 'video_cache.dart';

/// The (origin, user) of every saved session, or null when the list cannot be
/// trusted: [savedSessions] threw, or a session does not say which user it
/// belongs to (so its folder cannot be named). An incomplete list must never
/// cost an account its cache, so callers delete nothing for null.
Future<List<(String, String)>?> _keptAccounts(
  Future<Map<String, Session>> Function() savedSessions,
) async {
  final Map<String, Session> sessions;
  try {
    sessions = await savedSessions();
  } catch (_) {
    return null;
  }
  final keep = <(String, String)>[];
  for (final MapEntry(:key, :value) in sessions.entries) {
    final principal = value.cachedUser?['id'];
    if (principal is! String || principal.isEmpty) return null;
    // The client strips a trailing slash from its origin before it reads or
    // writes a session and before it names a cache folder.
    keep.add((key.replaceFirst(RegExp(r'/$'), ''), principal));
  }
  return keep;
}

/// Deletes the cached attachments of accounts that have no saved session: what
/// a sign-out or a removed session left behind while the app was not running.
///
/// [savedSessions] must list every saved session. When it throws, or a session
/// does not say which user it belongs to (so its folder cannot be named), this
/// deletes nothing: an incomplete list must never cost an account its cache.
/// Returns the number of account folders removed.
Future<int> removeOrphanAttachmentAccounts(
  AttachmentDiskCache cache,
  Future<Map<String, Session>> Function() savedSessions,
) async {
  final keep = await _keptAccounts(savedSessions);
  return keep == null ? 0 : cache.removeOrphanAccounts(keep);
}

/// The same for cached videos (`VideoCache`): the folders of accounts with no
/// saved session go. Starts no proxy.
Future<int> removeOrphanVideoAccounts(
  Future<Map<String, Session>> Function() savedSessions,
) async {
  final keep = await _keptAccounts(savedSessions);
  return keep == null ? 0 : VideoCache.removeOrphanAccounts(keep);
}

/// Everything cached on this device for one account, attachments and videos,
/// and what the in-app artifact browser kept (its cookies and storage are
/// device-wide, so the next person never inherits them): sign-out, a session
/// the server ended, an account switch. Never throws; a
/// layer that cannot be emptied now is emptied by the next start-up pass.
Future<void> purgeAccountCaches(String origin, String principal) async {
  try {
    await AttachmentDiskCache.purgeInstalledAccount(origin, principal);
  } on Object {
    // Housekeeping never breaks sign-out.
  }
  try {
    await VideoCache.purgeAccount(origin, principal);
  } on Object {
    // Same.
  }
  await clearArtifactWebData();
}

/// The one-time housekeeping at app start; no timers, every step best effort:
/// leftover staging older than an hour, orphan account folders (attachments
/// and videos). (The cache's
/// own start-up scan removes entries unopened for 30 days.)
Future<void> runStartupCacheHygiene({
  required AttachmentDiskCache cache,
  Future<Map<String, Session>> Function()? savedSessions,
}) async {
  try {
    await sweepStaging(
      staging: await cacheStagingDirectory(),
      legacyTemporary: await getTemporaryDirectory(),
    );
  } on Object {
    // Housekeeping never blocks or breaks the app.
  }
  final sessions = savedSessions ?? SecureSessionStore().readAll;
  try {
    await removeOrphanAttachmentAccounts(cache, sessions);
  } on Object {
    // Same.
  }
  try {
    await removeOrphanVideoAccounts(sessions);
  } on Object {
    // Same.
  }
}
