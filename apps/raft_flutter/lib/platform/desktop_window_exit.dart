import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';

import 'dart:ui' show AppExitResponse;

import 'package:raft_ui/raft_ui.dart' show showRaftAlertDialog, raftText;

import '../data/workspace_controller.dart';
import '../data/workspace_composer.dart';
import '../data/workspace_cache.dart';
import 'desktop_drafts.dart';
import 'cache_exit.dart';
import 'desktop_windows.dart';

Future<bool> saveDesktopWindow(
  BuildContext context,
  WorkspaceController? workspace, {
  required bool child,
  VoidCallback? onFailure,
}) async {
  if (!child) return true;
  try {
    if (workspace != null) {
      await prepareDesktopComposerClose(
        workspace.composer,
        cache: workspace.cache,
      );
    }
    await workspace?.flushCache();
    return true;
  } catch (_) {
    onFailure?.call();
    if (context.mounted) {
      await showRaftAlertDialog(
        context: context,
        title: raftText(context, 'This window still has unsaved drafts'),
        description: raftText(
          context,
          'Send or remove unsent attachments, or restore the local draft database, then close the window again.',
        ),
        confirmLabel: raftText(context, 'OK'),
      );
    }
    return false;
  }
}

Future<void> prepareDesktopComposerClose(
  WorkspaceComposer composer, {
  WorkspaceCache? cache,
}) async {
  String fingerprint() => jsonEncode([
    composer.drafts,
    for (final entry in composer.sends.pending.entries)
      [entry.key, for (final send in entry.value) send.draft],
  ]);
  for (var attempt = 0; attempt < 3; attempt++) {
    final before = fingerprint();
    final scopes = {
      ...composer.drafts.keys,
      ...composer.uploads.byScope.keys,
      ...composer.sends.pending.keys,
      ...composer.attempts.keys,
    };
    for (final scope in scopes) {
      await composer.saveScope(scope, requiredSuccess: true);
    }
    await composer.flushed;
    if (cache is DesktopDraftCache) await cache.flush();
    if (composer.uploads.byScope.values.any((files) => files.isNotEmpty) ||
        composer.sends.pending.values
            .expand((sends) => sends)
            .any((send) => send.uploads.isNotEmpty)) {
      throw StateError('unsent_attachments');
    }
    if (before == fingerprint()) return;
  }
  throw StateError('draft_changed_during_close');
}

Future<void> retireDesktopDrafts(
  DesktopWindows? windows,
  Future<void>? workspace,
) async {
  await Future.wait([?workspace, ?windows?.retireDrafts()]);
}

Future<CacheExitOutcome> prepareDesktopExit(
  DesktopWindows? windows,
  Future<void> Function()? close,
) async {
  if (windows != null) {
    try {
      if (!await windows.prepareExit()) return CacheExitOutcome.vetoed;
    } catch (_) {
      return CacheExitOutcome.vetoed;
    }
  }
  return closeCacheForExit(close);
}

Future<AppExitResponse> desktopExitResponse(
  DesktopWindows? windows,
  Future<void> Function()? close,
) async => await prepareDesktopExit(windows, close) == CacheExitOutcome.vetoed
    ? AppExitResponse.cancel
    : AppExitResponse.exit;

String desktopServerMemoryKey(
  String origin,
  String? principal,
  DesktopWindows? windows,
) =>
    'raft.server-surface.${Uri.encodeComponent(origin)}.$principal'
    '${windows?.navigationNamespace == null ? '' : '.window.${windows!.navigationNamespace}'}';

/// Only the typed already-focused result uses this recovery. The rejected
/// selection has not mutated the controller, so its existing route/draft wins.
Future<void> recoverDesktopServerSelection(
  WorkspaceController workspace,
  Future<void> Function(RaftRecord server, {Uri? location}) select,
) async {
  final server = workspace.server;
  if (server == null) return;
  final client = workspace.client,
      authentication = workspace.client.authenticationGeneration;
  final principal = client.user?.id, location = workspace.location.uri;
  await select(server, location: location);
  if (client.authenticationGeneration == authentication &&
      client.user?.id == principal &&
      workspace.server?.id == server.id) {
    // ignore: raft_lints/avoid_imperative_notice_state -- One current-account notice after the focused-window selection restores the original editor.
    workspace.setError('This server is already open in another window.');
  }
}
