// Web v1.24 ArtifactCoverViewer and the `cover` place (artifactViewerStore.ts
// ArtifactPlace :22-23, coverOf :233-238): an Artifact clicked inside a
// dialog (a task's conversation, its modal or its dock) opens over that
// dialog's own card, not over the window. The dialog closing closes it with
// it; × and Escape close it and focus goes back to what opened it.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

typedef _Covering = ({
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
  FocusNode? opener,
});

/// Opens [target] over the dialog card [context] is in, on a wide window;
/// false when it is in none.
bool openArtifactDialogCover(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
) {
  if (RaftAdaptiveWorkspace.compactOf(context)) return false;
  final cover = context.getInheritedWidgetOfExactType<_CoverScope>()?.state;
  if (cover == null || !cover.mounted) return false;
  cover.show((
    w: w,
    target: target,
    seed: seed,
    opener: FocusManager.instance.primaryFocus,
  ));
  return true;
}

/// A dialog's card [child]: an Artifact clicked in it covers it.
class ArtifactDialogCover extends StatefulWidget {
  const ArtifactDialogCover({super.key, required this.child});
  final Widget child;

  @override
  State<ArtifactDialogCover> createState() => _ArtifactDialogCoverState();
}

class _ArtifactDialogCoverState extends State<ArtifactDialogCover> {
  final scope = FocusScopeNode(debugLabel: 'artifact dialog cover');
  _Covering? open;

  void show(_Covering next) {
    setState(() => open = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && open == next) scope.requestFocus();
    });
  }

  void close() {
    final opener = open?.opener;
    setState(() => open = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (opener?.context != null) opener!.requestFocus();
    });
  }

  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = this.open;
    final covering = open != null;
    return _CoverScope(
      state: this,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeFocus(
            excluding: covering,
            child: ExcludeSemantics(
              excluding: covering,
              child: IgnorePointer(ignoring: covering, child: widget.child),
            ),
          ),
          if (open != null)
            Positioned.fill(
              key: const ValueKey('artifact-dialog-cover'),
              child: RaftBackDismiss(
                onDismiss: close,
                child: FocusScope(
                  node: scope,
                  child: ColoredBox(
                    color: RaftTokens.of(context).panel,
                    child: ArtifactWorkspaceViewer(
                      key: ValueKey(open.target),
                      session: ArtifactSession.of(open.w),
                      target: open.target,
                      seed: open.seed,
                      page: false,
                      inline: true,
                      onClose: close,
                      onDeleted: close,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverScope extends InheritedWidget {
  const _CoverScope({required this.state, required super.child});
  final _ArtifactDialogCoverState state;

  @override
  bool updateShouldNotify(_CoverScope old) => false;
}
