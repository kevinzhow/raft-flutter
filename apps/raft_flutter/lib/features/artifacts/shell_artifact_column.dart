// Web v1.24 ShellArtifactHost (components/layout/ShellArtifactHost.tsx) and
// useArtifactViewerAddress (artifactViewerAddress.ts): the app shell's own
// place for an Artifact clicked where no channel panel and no list slot is (a
// thread or a task opened in Activity's or Search's main area, Saved). Its
// viewer is the side column's (the same ArtifactWorkspaceViewer as beside a
// conversation), standing beside the main area on wide windows and covering
// it where it does not fit (the medium class, or expanded). The page's address
// holds it (`?artifact=<id>&version=&review=`), so it is the one source of
// what is open: leaving the page (another row, another section) drops the
// query and closes it, a reload reopens it.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/phone_stack.dart' show artifactSlotRemoval;
import '../../data/raft_location.dart';
import '../../data/raft_navigation_history.dart';
import '../../data/workspace_controller.dart';
import '../channel_side_area.dart' show channelSideChatMinWidth;
import '../channel_side_cards.dart' show ChannelSideCards;
import '../channel_side_layout.dart';
import 'artifact_content_slot.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';

final _openers = Expando<FocusNode>('shell artifact opener');

/// The Artifact the shell's column shows for [w]'s page, if any: the page's
/// `?artifact=` where neither a list slot nor a conversation's column owns
/// it (Web addressedPlacesOf `shell`).
ArtifactLinkTarget? shellArtifactTarget(WorkspaceController w) {
  final location = w.location;
  if (location.route == RaftRoute.artifacts ||
      location.content?.kind == RaftContentKind.artifact ||
      ChannelSideCards.conversation(w) != null) {
    return null;
  }
  final address = location.query('artifact');
  return address == null ? null : artifactAddressTarget(location, address, w);
}

/// Opens [target] in the shell's column when [context] is in the app shell
/// on a wide window; false otherwise.
bool openShellArtifact(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
) {
  if (!ShellArtifactColumn.hosts(context) ||
      RaftAdaptiveWorkspace.compactOf(context)) {
    return false;
  }
  _openers[w] = FocusManager.instance.primaryFocus;
  rememberArtifactLanding(w, target);
  w.navigation.navigate(
    w.location.withQuery({
      ...artifactSlotRemoval,
      ...artifactSlotQuery(target),
    }),
    kind: RaftNavigationKind.replace,
  );
  w.notifyListeners();
  return true;
}

/// Closes the shell's Artifact; focus goes back to what opened it.
void closeShellArtifact(WorkspaceController w) {
  final opener = _openers[w];
  _openers[w] = null;
  w.navigation.navigate(
    w.location.withQuery(artifactSlotRemoval),
    kind: RaftNavigationKind.replace,
  );
  w.notifyListeners();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (opener?.context != null) opener!.requestFocus();
  });
}

/// The main area [child] and, beside it, the shell's Artifact column.
class ShellArtifactColumn extends StatefulWidget {
  const ShellArtifactColumn({
    super.key,
    required this.workspace,
    required this.child,
  });

  final WorkspaceController workspace;
  final Widget child;

  /// Whether [context] is inside the app shell (Web `shells`).
  static bool hosts(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ShellScope>() != null;

  @override
  State<ShellArtifactColumn> createState() => _ShellArtifactColumnState();
}

class _ShellArtifactColumnState extends State<ShellArtifactColumn> {
  late Listenable changes;
  bool expanded = false;
  ArtifactLinkTarget? shown;

  @override
  void initState() {
    super.initState();
    bind();
  }

  void bind() => changes = Listenable.merge([
    widget.workspace,
    ArtifactSession.of(widget.workspace),
  ]);

  @override
  void didUpdateWidget(ShellArtifactColumn old) {
    super.didUpdateWidget(old);
    if (old.workspace != widget.workspace) bind();
  }

  @override
  Widget build(BuildContext context) => _ShellScope(
    child: ListenableBuilder(
      listenable: changes,
      builder: (context, child) => LayoutBuilder(
        builder: (context, box) => layout(context, box, child!),
      ),
      child: widget.child,
    ),
  );

  Widget layout(BuildContext context, BoxConstraints box, Widget main) {
    final w = widget.workspace;
    final session = ArtifactSession.of(w);
    final target = session.enabled && !RaftAdaptiveWorkspace.compactOf(context)
        ? shellArtifactTarget(w)
        : null;
    if (target != shown) {
      shown = target;
      expanded = false;
    }
    final width = channelSideSectionWidth(ChannelSideSection.artifact);
    final fits =
        raftLayoutClassOf(context) == RaftLayoutClass.wide &&
        box.maxWidth - width >= channelSideChatMinWidth;
    final beside = target != null && fits && !expanded;
    final covering = target != null && !beside;
    Widget column() => _Column(
      key: ValueKey(target),
      workspace: w,
      target: target!,
      covering: covering,
      expanded: expanded,
      onExpand: fits ? () => setState(() => expanded = !expanded) : null,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ExcludeFocus(
                  excluding: covering,
                  child: ExcludeSemantics(
                    excluding: covering,
                    child: IgnorePointer(ignoring: covering, child: main),
                  ),
                ),
              ),
              if (beside) SizedBox(width: width.toDouble(), child: column()),
            ],
          ),
        ),
        if (covering) Positioned.fill(child: column()),
      ],
    );
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope({required super.child});

  @override
  bool updateShouldNotify(_ShellScope old) => false;
}

class _Column extends StatefulWidget {
  const _Column({
    super.key,
    required this.workspace,
    required this.target,
    required this.covering,
    required this.expanded,
    required this.onExpand,
  });

  final WorkspaceController workspace;
  final ArtifactLinkTarget target;
  final bool covering, expanded;
  final VoidCallback? onExpand;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  final scope = FocusScopeNode(debugLabel: 'shell artifact column');

  @override
  void initState() {
    super.initState();
    // Opened by a press, focus goes in with it (Web artifactOpenFocusReason
    // `user`); a field the person is typing in keeps it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      if (mounted && focused is! EditableText) scope.requestFocus();
    });
  }

  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final onExpand = widget.onExpand;
    final expanded = widget.expanded;
    void close() => closeShellArtifact(workspace);
    return RaftBackDismiss(
      onDismiss: close,
      child: FocusScope(
        node: scope,
        child: DecoratedBox(
          key: const ValueKey('shell-artifact-column'),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: widget.covering ? null : RaftPanelEdge.left(context),
          ),
          child: ColoredBox(
            color: RaftTokens.of(context).panel,
            child: ArtifactWorkspaceViewer(
              session: ArtifactSession.of(workspace),
              target: widget.target,
              page: false,
              inline: true,
              onClose: close,
              onDeleted: close,
              headerActions: [
                if (onExpand != null)
                  raftConversationHeaderToggle(
                    key: const ValueKey('shell-artifact-expand'),
                    glyph: expanded ? RaftGlyph.minimize2 : RaftGlyph.maximize2,
                    label: raftText(context, expanded ? 'Restore' : 'Expand'),
                    pressed: expanded,
                    onPressed: onExpand,
                    desktopBar: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
