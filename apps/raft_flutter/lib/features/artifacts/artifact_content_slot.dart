// Web v1.24 ArtifactContentSlot (MainLayout.tsx) and ArtifactActivityViewer:
// an Artifact opened from its Activity row or a Search hit, its viewer in the
// detail area beside the list (`expanded`, not covering, its own close); on a
// phone its page over the list. Its address is the Artifact address
// (`?artifact=<short id>`, `&version=`, `&review=`; artifactOpenAddress.ts)
// with the comment it lands on in `msg=`.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart' show RaftAdaptiveWorkspace;

import '../../data/raft_location.dart';
import '../../data/workspace_controller.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

/// The detail slot's query for [target].
Map<String, String> artifactSlotQuery(ArtifactLinkTarget target) => {
  'artifact': artifactLinkId(target.id),
  if (target.version case final version?) 'version': '$version',
  'review': ?target.reviewId,
  'msg': ?target.commentId,
};

/// The Artifact [location]'s detail slot shows, if any.
ArtifactLinkTarget? artifactSlotTarget(RaftLocation location) {
  final content = location.content;
  if (content?.kind != RaftContentKind.artifact) return null;
  final id = parseArtifactId(content!.id);
  if (id == null) return null;
  final version = int.tryParse(location.query('version') ?? '');
  return ArtifactLinkTarget.activity(
    id,
    version != null && version > 0 ? version : null,
    reviewId: location.query('review'),
    commentId: content.messageId,
  );
}

class ArtifactContentSlot extends StatelessWidget {
  const ArtifactContentSlot({
    super.key,
    required this.workspace,
    required this.onClose,
  });

  final WorkspaceController workspace;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final session = ArtifactSession.of(workspace);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final target = artifactSlotTarget(workspace.location);
        // workspace_artifacts_v0 off: an address naming one opens nothing.
        if (target == null || !session.enabled) return const SizedBox.expand();
        return ArtifactWorkspaceViewer(
          key: ValueKey(target),
          session: session,
          target: target,
          page: RaftAdaptiveWorkspace.compactOf(context),
          inCollection: true,
          onClose: onClose,
          onDeleted: onClose,
        );
      },
    );
  }
}
