// Where an Artifact clicked inside the app opens: Web v1.24 ArtifactPlace,
// findArtifactPlace and openArtifactInPlace (artifactViewerStore.ts:247-252,
// openArtifactInPlace.ts:26-33; Remy's opening rule, #proj-workspace:#104):
// in the layout it was clicked in, never over the whole window. The places,
// in the order a click is looked up in them ([artifactPlaces]), and on a
// phone or outside the app shell (Web follows the link to the Artifact's own
// page there) a page.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../data/workspace_controller.dart';
import '../../platform/system_bars.dart';
import '../channel_artifact_place.dart';
import '../channel_side_area.dart' show insideChannelSideArea;
import '../channel_side_cards.dart' show ChannelSideCards;
import '../channel_side_web_preview.dart';
import '../list_detail_slot.dart';
import 'artifact_content_slot.dart';
import 'artifact_dialog_cover.dart';
import 'artifact_models.dart';
import 'artifact_session.dart';
import 'artifact_viewer_page.dart';
import 'shell_artifact_column.dart';

enum ArtifactPlace {
  /// Beside the conversation it belongs to (ChannelArtifactPlace).
  channelColumn,

  /// In its list's detail slot (Activity, Search; list_detail_slot.dart).
  listDetail,

  /// Over the dialog card it was clicked in (ArtifactDialogCover).
  dialogCover,

  /// The shell's own column beside the main area (ShellArtifactColumn).
  shellColumn,

  /// A page: a phone, or outside the app shell.
  page,
}

/// One place's opener: false when the click in [context] is not in it.
typedef ArtifactPlaceOpener = bool Function(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
);

/// The places, in the order a click looks them up; the first that holds it
/// opens it. A page when none does.
final List<(ArtifactPlace, ArtifactPlaceOpener)> artifactPlaces = [
  (ArtifactPlace.channelColumn, _channelColumn),
  (ArtifactPlace.listDetail, _listDetail),
  (ArtifactPlace.dialogCover, openArtifactDialogCover),
  (ArtifactPlace.shellColumn, (c, w, t, _) => openShellArtifact(c, w, t)),
];

/// Opens the Artifact [target] names where [context] is ([artifactPlaces]).
Future<void> openWorkspaceArtifact(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target, {
  ArtifactCard? seed,
}) {
  for (final (_, open) in artifactPlaces) {
    if (open(context, w, target, seed)) return Future<void>.value();
  }
  return _page(context, w, target, seed);
}

/// Beside the conversation on every wide window; on a phone only where the
/// built-in browser's place already holds it.
bool _channelColumn(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
) {
  final channel = ChannelSideCards.conversation(w);
  if (channel == null ||
      !insideChannelSideArea(context) ||
      RaftAdaptiveWorkspace.compactOf(context) && !desktopBrowserAvailable(w)) {
    return false;
  }
  final opener = FocusManager.instance.primaryFocus;
  WebPreviewStore.of(w).browserTabs.park(channel.id);
  ChannelArtifactPlace.of(w).show(
    channel.id,
    target,
    seed: seed,
    returnFocus: () {
      if (opener?.context != null) opener?.requestFocus();
    },
  );
  return true;
}

/// Web: the slot opens at once; with Artifacts off it shows nothing.
bool _listDetail(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
) {
  if (!ListDetailHost.hosts(context)) return false;
  rememberArtifactLanding(w, target);
  openListDetail(context, w, artifactSlotQuery(target));
  return true;
}

Future<void> _page(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target,
  ArtifactCard? seed,
) => Navigator.of(context, rootNavigator: true).push<void>(
  RaftPreviewPageRoute<void>(
    settings: const RouteSettings(name: '/workspace-artifact'),
    builder: (context) {
      final surface = RaftTokens.of(context).panel;
      // ds-allow: Native route owns keyboard insets and system bars; raft_ui owns the header.
      return Scaffold(
        backgroundColor: surface,
        body: RaftSystemBarSurface(
          statusBarFallback: surface,
          child: ArtifactWorkspaceViewer(
            session: ArtifactSession.of(w),
            target: target,
            seed: seed,
            page: true,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
    },
  ),
);
