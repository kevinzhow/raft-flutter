import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';

/// An external workspace route is meaningful only with a frontend explicitly
/// bound to this API. API origins are never guessed to serve the Web client.
Uri? workspaceBrowserOrigin(
  String coordinator, {
  String frontend = const String.fromEnvironment('RAFT_FRONTEND_ORIGIN'),
  String api = const String.fromEnvironment(
    'RAFT_ORIGIN',
    defaultValue: 'http://localhost:13041',
  ),
}) {
  final candidate = Uri.tryParse(frontend);
  if (candidate == null ||
      !['https', 'http'].contains(candidate.scheme) ||
      candidate.host.isEmpty ||
      candidate.userInfo.isNotEmpty ||
      candidate.hasQuery ||
      candidate.hasFragment ||
      candidate.path.isNotEmpty && candidate.path != '/') {
    return null;
  }
  final origin = ContentLinks.originFor(
    coordinator,
    frontend: frontend,
    api: api,
  );
  final bound = Uri.tryParse(api), current = Uri.tryParse(coordinator);
  if (bound == null ||
      current == null ||
      !['https', 'http'].contains(bound.scheme) ||
      !['https', 'http'].contains(current.scheme) ||
      bound.origin != current.origin ||
      origin.origin != candidate.origin) {
    return null;
  }
  return origin;
}

/// The pinned Web's workspace-window fallback uses the public frontend URL.
/// Browser authentication is owned by the browser; no native session is passed.
Future<void> openWorkspaceInBrowser(
  BuildContext context,
  WorkspaceController w,
  RaftRecord target, {
  Future<bool> Function(Uri)? open,
  Uri? frontendOrigin,
}) async {
  final generation = w.client.generation,
      principal = w.client.user?.id,
      server = w.client.serverId,
      role = w.server?.string('role');
  bool current() =>
      context.mounted &&
      principal != null &&
      generation == w.client.generation &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      role == w.server?.string('role');
  if (!current()) return;
  try {
    final origin = frontendOrigin ?? workspaceBrowserOrigin(w.client.origin);
    if (origin == null) throw const FormatException('Frontend unavailable');
    // A stale switcher item cannot grant workspace access or choose a slug.
    final members = await w.client.servers();
    if (!current()) return;
    final matches = members.where((s) => s.id == target.id).toList();
    if (matches.length != 1 || matches.single.string('slug').isEmpty) {
      throw const FormatException('Workspace unavailable');
    }
    final uri = origin.replace(
      pathSegments: ['s', matches.single.string('slug')],
      query: null,
      fragment: null,
    );
    final opened =
        await (open ??
            (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
    if (!opened) throw const FormatException('Browser unavailable');
  } catch (_) {
    if (context.mounted && current()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raftText(
              context,
              'The workspace could not be opened in the browser.',
            ),
          ),
        ),
      );
    }
  }
}
