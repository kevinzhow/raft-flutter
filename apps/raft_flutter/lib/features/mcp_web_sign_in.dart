import 'package:raft_ui/raft_ui.dart' show RaftUserError;

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'management_support.dart';

Future<void> openMcpWebSignIn(WorkspaceController workspace) async {
  final origin = ContentLinks.originFor(workspace.client.origin);
  final slug = workspace.server?.string('slug').trim();
  final server = slug == null || slug.isEmpty ? workspace.server?.id : slug;
  if (server == null || server.isEmpty) {
    throw const RaftUserError('The active server changed. Reopen this form.');
  }
  await managementLaunch(
    origin.resolve('/s/${Uri.encodeComponent(server)}/apps').toString(),
  );
}
