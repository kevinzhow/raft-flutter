import 'dart:convert';
import 'dart:async';

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

const desktopDraftSaveBudget = Duration(seconds: 5);

Future<bool> saveDesktopWindow(
  BuildContext context,
  WorkspaceController? workspace, {
  required bool child,
  VoidCallback? onFailure,
}) async {
  if (!child) return true;
  var active = true;
  final client = workspace?.client,
      authentication = workspace?.client.authenticationGeneration;
  final server = workspace?.server?.id, generation = client?.generation;
  bool current() =>
      active &&
      workspace?.client == client &&
      client?.authenticationGeneration == authentication &&
      client?.generation == generation &&
      workspace?.server?.id == server;
  try {
    Future<void> save() async {
      if (workspace != null) {
        await prepareDesktopComposerClose(
          workspace.composer,
          cache: workspace.cache,
          current: current,
        );
      }
      if (!current()) throw StateError('stale_desktop_close');
      await workspace?.flushCache();
    }

    await save().timeout(desktopDraftSaveBudget);
    return true;
  } catch (error) {
    active = false;
    onFailure?.call();
    if (context.mounted) {
      final timedOut = error is TimeoutException;
      unawaited(
        showRaftAlertDialog(
          context: context,
          title: raftText(
            context,
            timedOut
                ? 'Drafts are taking too long to save'
                : 'This window still has unsaved drafts',
          ),
          description: raftText(
            context,
            timedOut
                ? 'This window will stay open. Keep editing, then try closing it again.'
                : 'Send or remove unsent attachments, or restore the local draft database, then close the window again.',
          ),
          confirmLabel: raftText(context, 'OK'),
        ).then<void>((_) {}),
      );
    }
    return false;
  }
}

Future<void> prepareDesktopComposerClose(
  WorkspaceComposer composer, {
  WorkspaceCache? cache,
  bool Function()? current,
}) async {
  String fingerprint() => jsonEncode([
    composer.drafts,
    for (final entry in composer.sends.pending.entries)
      [entry.key, for (final send in entry.value) send.draft],
  ]);
  for (var attempt = 0; attempt < 3; attempt++) {
    if (current?.call() == false) throw StateError('stale_desktop_close');
    final before = fingerprint();
    final scopes = {
      ...composer.drafts.keys,
      ...composer.uploads.byScope.keys,
      ...composer.sends.pending.keys,
      ...composer.attempts.keys,
    };
    for (final scope in scopes) {
      if (current?.call() == false) throw StateError('stale_desktop_close');
      await composer.saveScope(scope, requiredSuccess: true);
    }
    await composer.flushed;
    if (current?.call() == false) throw StateError('stale_desktop_close');
    if (cache is DesktopDraftCache) await cache.flush();
    if (composer.uploads.byScope.values.any((files) => files.isNotEmpty) ||
        composer.sends.pending.values
            .expand((sends) => sends)
            .any((send) => send.uploads.isNotEmpty)) {
      throw StateError('unsent_attachments');
    }
    if (current?.call() == false) throw StateError('stale_desktop_close');
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
