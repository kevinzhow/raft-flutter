// The Artifact viewer: one Artifact's version, its frame or drawn content,
// its menu, versions, files, download and find.
//
// Source: packages/web/src/apps/artifacts/{ArtifactViewer,ArtifactSurface,
// ArtifactContent,ArtifactViewerMenu}.tsx and artifactSource.ts
// (`useArtifactViewer`, `useArtifactNewerVersion`) at v1.24.0-source.1.
// Web opens the viewer beside the conversation on wide windows and over it
// on a phone; the app opens it as a full-screen page on a phone and a
// full-bleed window on wide layouts (the attachment preview's split; see
// docs/parity.md).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' show RaftPanelToggleActionRecipe;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    show WebViewPlatform;

import '../../data/raft_location.dart';
import '../../data/workspace_controller.dart';
import '../../platform/macos_voice_over.dart';
import '../../platform/system_bars.dart';
import '../private_route_guard.dart'
    show channelSearchPageAuthority, workspaceAuthority;
import 'artifact_api.dart';
import 'artifact_comment_composer.dart';
import 'artifact_comment_store.dart';
import 'artifact_comments_panel.dart';
import 'artifact_content.dart';
import 'artifact_find_bar.dart';
import 'artifact_forward_dialog.dart';
import 'artifact_frame_bridge.dart';
import 'artifact_frame_confirm.dart';
import 'artifact_frame_view.dart';
import 'artifact_manage_dialogs.dart';
import 'artifact_models.dart';
import 'artifact_open_in_browser.dart';
import 'artifact_review_store.dart';
import 'artifact_scope_chip.dart';
import 'artifact_session.dart';
import 'artifact_sharing_api.dart';
import 'artifact_text.dart';
import 'artifact_viewer_actions.dart';
import 'artifact_viewer_panels.dart';
import 'artifact_viewer_parts.dart';

/// Opens the Artifact [target] names in the viewer: a page on narrow
/// windows, a full-bleed window on wide ones.
Future<void> openWorkspaceArtifact(
  BuildContext context,
  WorkspaceController w,
  ArtifactLinkTarget target, {
  ArtifactCard? seed,
}) {
  final page = RaftAdaptiveWorkspace.compactOf(context);
  Widget viewer(BuildContext context) => ArtifactWorkspaceViewer(
    session: ArtifactSession.of(w),
    target: target,
    seed: seed,
    page: page,
    onClose: () => Navigator.of(context).pop(),
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<void>(
    page
        ? RaftPreviewPageRoute<void>(
            settings: const RouteSettings(name: '/workspace-artifact'),
            builder: (context) {
              final surface = RaftTokens.of(context).panel;
              // ds-allow: Native route owns keyboard insets and system bars; raft_ui owns the header.
              return Scaffold(
                backgroundColor: surface,
                body: RaftSystemBarSurface(
                  statusBarFallback: surface,
                  child: viewer(context),
                ),
              );
            },
          )
        : RaftFullBleedDialogRoute<void>(context: context, builder: viewer),
  );
}

enum _Panel { none, files, versions, comments }

/// The files / versions panel beside the content on wide windows.
const _sidePanelWidth = 320.0;
const _displayReportPanelWidth = 340.0;
const _headerActionsMinWidth = 440;
// Web ArtifactMetaRow reserves the presence row from the first paint.
const _collectionMetaMinHeight = 27.0;

class ArtifactWorkspaceViewer extends StatefulWidget {
  const ArtifactWorkspaceViewer({
    super.key,
    required this.session,
    required this.target,
    required this.page,
    required this.onClose,
    this.seed,
    this.inCollection = false,
    this.onDeleted,
    this.webViewBuilder,
    this.save,
    this.openExternal,
    this.operatingSystem,
    this.voiceOver,
    this.hostScript,
  });

  final ArtifactSession session;
  final ArtifactLinkTarget target;

  /// What a card already showed (Web `artifactCardSeed`): the title while
  /// the viewer route answers.
  final ArtifactCard? seed;
  final bool page, inCollection;
  final VoidCallback onClose;
  final VoidCallback? onDeleted;

  // Test seams.
  final ArtifactFrameWebViewBuilder? webViewBuilder;
  final ArtifactSaveBytes? save;
  final Future<bool> Function(Uri)? openExternal;
  final String? operatingSystem;
  final ValueListenable<bool>? voiceOver;
  final Future<String> Function()? hostScript;

  @override
  State<ArtifactWorkspaceViewer> createState() =>
      _ArtifactWorkspaceViewerState();
}

class _ArtifactWorkspaceViewerState extends State<ArtifactWorkspaceViewer> {
  WorkspaceController get w => widget.session.w;
  ArtifactApi get api => widget.session.api;
  late final ArtifactSession viewerSession;
  late final int sessionGeneration;
  late final String authority;
  bool get current =>
      mounted &&
      identical(widget.session, viewerSession) &&
      viewerSession.isCurrent(sessionGeneration) &&
      workspaceAuthority(w) == authority;

  final viewerFocus = FocusNode();
  ArtifactViewerData? data;
  bool unavailable = false, switching = false, failedLatest = false;
  int? failedVersion;
  int? pinned;
  int ticket = 0, frameAttempt = 0;
  Object? firstFrame;
  String? shownPath;
  _Panel panel = _Panel.none;
  bool finding = false;
  ArtifactDeployment? deployment;
  final frame = ArtifactFrameController();
  ({int version, String? publisher})? newer;
  RaftForegroundPeriodic? poll;
  ArtifactCommentStore? discussion;
  ArtifactReviewStore? review;
  final commentsFocus = FocusNode();
  final moreFocus = FocusNode();
  final reportArea = GlobalKey();
  ArtifactCommentInsert? report;
  RaftPresentedRoute<void>? reportSheet;
  bool confirmingDelete = false;
  bool discussionLanding = false;

  void _mountDiscussion() {
    final shown = data?.card;
    if (!widget.session.enabled || shown == null || shown.fromAnotherServer) {
      return;
    }
    if (discussion != null) return;
    discussion = ArtifactCommentStore(
      w,
      shown.id,
      reviewId: widget.target.reviewId,
    );
    if (data!.capabilities.comment) review = ArtifactReviewStore(discussion!);
    if (widget.target.commentId != null || widget.target.reviewId != null) {
      panel = _Panel.comments;
      discussionLanding = true;
    }
  }

  void _discussionAvailability() {
    if (!mounted) return;
    setState(() {
      if (widget.session.enabled) {
        _mountDiscussion();
      } else {
        if (panel == _Panel.comments) panel = _Panel.none;
        report = null;
        _removeReportSheet();
        review?.dispose();
        review = null;
        discussion?.dispose();
        discussion = null;
      }
    });
  }

  void _closeComments() {
    setState(() {
      discussionLanding = false;
      panel = _Panel.none;
      report = null;
    });
    if (widget.inCollection && commentsFocus.parent == null) {
      moreFocus.requestFocus();
    } else {
      commentsFocus.requestFocus();
    }
  }

  void _toggleComments() {
    if (panel == _Panel.comments) {
      _closeComments();
      return;
    }
    setState(() {
      report = null;
      panel = _Panel.comments;
    });
  }

  late final actions = ArtifactViewerActions(
    api: api,
    webOrigin:
        widget.session.deployment?.webOrigin ??
        ArtifactDeployment.resolve(w.client.origin, null).webOrigin,
    current: () => current,
    save: widget.save,
    openExternal: widget.openExternal,
  );

  @override
  void initState() {
    super.initState();
    viewerSession = widget.session;
    sessionGeneration = viewerSession.generation;
    authority = workspaceAuthority(w);
    if (widget.inCollection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
          viewerFocus.requestFocus();
        }
      });
    }
    pinned = widget.target.version;
    frame.addListener(_frameChanged);
    widget.session.addListener(_discussionAvailability);
    _voiceOver.addListener(_voiceOverChanged);
    deployment = widget.session.deployment;
    if (deployment == null) {
      unawaited(
        widget.session.readDeployment().then((value) {
          if (mounted) setState(() => deployment = value);
        }),
      );
    }
    unawaited(_load(pinned));
    poll = RaftForegroundPeriodic(
      const Duration(seconds: 60),
      () => unawaited(_checkNewer()),
    );
  }

  @override
  void dispose() {
    _removeReportSheet();
    poll?.dispose();
    viewerSession.removeListener(_discussionAvailability);
    review?.dispose();
    discussion?.dispose();
    commentsFocus.dispose();
    moreFocus.dispose();
    viewerFocus.dispose();
    _voiceOver.removeListener(_voiceOverChanged);
    frame.removeListener(_frameChanged);
    frame.dispose();
    super.dispose();
  }

  void _frameChanged() {
    if (!mounted) return;
    if (frame.findRequests > 0 && !finding && frame.ready) finding = true;
    setState(() {});
  }

  /// VoiceOver turning on while a frame is mounted rebuilds now, so the platform view is gone
  /// before this frame's semantics flush (build runs first): the crash path in
  /// `artifactFrameSupportFor`.
  void _voiceOverChanged() {
    if (mounted) setState(() {});
  }

  /// Reads the viewer for [version] (null: the latest). While another
  /// version is shown, it stays until the answer comes; a failed switch keeps
  /// it with a notice (Web `useArtifactViewer`).
  Future<void> _load(int? version) async {
    final mine = ++ticket;
    if (data != null) setState(() => switching = true);
    try {
      final result = await api.viewer(
        ArtifactLinkTarget(widget.target.id, version),
      );
      if (!current || mine != ticket) return;
      setState(() {
        switching = false;
        failedVersion = null;
        failedLatest = false;
        if (result == null) {
          if (data == null) unavailable = true;
          return;
        }
        data = result;
        _mountDiscussion();
        firstFrame = result.frame;
        frameAttempt++;
        pinned = result.card.pinned ? result.card.version : null;
        shownPath = null;
        report = null;
        if (newer != null && newer!.version <= result.card.latestVersion) {
          newer = null;
        }
      });
    } catch (_) {
      if (!current || mine != ticket) return;
      setState(() {
        switching = false;
        if (data == null) {
          unavailable = true;
        } else {
          failedLatest = version == null;
          failedVersion = version;
        }
      });
    }
  }

  void _pick(int? version) {
    pinned = version;
    unawaited(_load(version));
  }

  /// Whether a newer version is out (Web `useArtifactNewerVersion`: a poll
  /// every 60 s while visible, through the object summaries).
  Future<void> _checkNewer() async {
    final shown = data;
    if (shown == null || shown.card.fromAnotherServer) return;
    final summaries = widget.session.summaries;
    final target = ArtifactLinkTarget(shown.card.id);
    summaries.invalidate(shown.card.id);
    summaries.stateOf(target);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    for (var i = 0; i < 40 && mounted; i++) {
      final state = summaries.stateOf(target);
      if (state is ArtifactLinkOk) {
        final latest = state.card.latestVersion;
        if (latest > shown.card.latestVersion && mounted) {
          setState(() => newer = (version: latest, publisher: null));
        }
        return;
      }
      if (state is! ArtifactLinkLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  late final ValueListenable<bool> _voiceOver =
      widget.voiceOver ?? MacosVoiceOver.instance;

  String get _os => widget.operatingSystem ?? Platform.operatingSystem;

  bool get _webView =>
      artifactFrameSupportFor(_os, voiceOver: _voiceOver.value) ==
          ArtifactFrameSupport.webView &&
      (widget.webViewBuilder != null || WebViewPlatform.instance != null) &&
      deployment?.contentDomain != null;

  ArtifactFile? _shownFile(ArtifactViewerData data) {
    final path = shownPath;
    if (path == null) return data.entry;
    return data.files.where((f) => f.path == path).firstOrNull ?? data.entry;
  }

  bool _framed(ArtifactViewerData data) {
    if (shownPath == null) return data.card.kind.framed;
    return _shownFile(data)?.kind.framed ?? false;
  }

  bool get _readsInOwnServer => data?.card.fromAnotherServer != true;

  bool _canDelete(ArtifactViewerData? shown) =>
      current &&
      viewerSession.enabled &&
      shown != null &&
      !shown.card.fromAnotherServer &&
      shown.capabilities.delete;

  bool _canReport(ArtifactViewerData shown) =>
      current && shown.capabilities.comment && discussion?.current == true;

  bool _reportInCommentsMenu(ArtifactViewerData shown) =>
      _canReport(shown) &&
      shown.card.kind.framed &&
      _shownFile(shown) != null &&
      _webView;

  bool get _reportSidebarOpen =>
      !widget.page && panel == _Panel.comments && report != null;

  RaftMenuEntry _reportEntry(BuildContext context) => RaftMenuEntry(
    label: raftText(context, "Doesn't display well here"),
    glyph: RaftGlyph.monitorSmartphone,
    onPressed: _reportDisplay,
  );

  void _removeReportSheet() {
    final route = reportSheet;
    if (route == null) return;
    reportSheet = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  void _reportDisplay() {
    final shown = data;
    if (shown == null || !_canReport(shown)) return;
    final box = reportArea.currentContext?.findRenderObject();
    final area = box is RenderBox && box.hasSize && !box.size.isEmpty
        ? '${box.size.width.round()}x${box.size.height.round()} CSS px'
        : null;
    final ratio = (View.of(context).devicePixelRatio * 100).round() / 100;
    final ratioText = ratio == ratio.round() ? '${ratio.round()}' : '$ratio';
    final file = shown.files.length > 1 ? _shownFile(shown)?.path : null;
    final os = switch (_os) {
      'android' => 'Android',
      'ios' => 'iOS',
      'linux' => 'Linux',
      'macos' => 'macOS',
      'windows' => 'Windows',
      _ => null,
    };
    final text = [
      "Display report from Raft's viewer:",
      'Version: v${shown.card.version}',
      if (file != null) 'Shown file: $file',
      '${area == null ? '' : 'Page area: $area · '}Pixel ratio: ${ratioText}x',
      if (os != null) 'Browser: $os',
      '',
      '',
    ].join('\n');
    final insert = ArtifactCommentInsert(text);
    discussion!.showAll();
    if (widget.page) {
      setState(() {
        report = null;
        discussionLanding = false;
        panel = _Panel.none;
      });
      unawaited(_openReportSheet(shown, insert));
      return;
    }
    setState(() {
      report = insert;
      discussionLanding = false;
      panel = _Panel.comments;
    });
  }

  Future<void> _openReportSheet(
    ArtifactViewerData shown,
    ArtifactCommentInsert insert,
  ) async {
    final store = discussion!;
    final review = this.review;
    final handle = RaftSheetMetrics.handleBox(RaftTokens.of(context));
    final height = MediaQuery.sizeOf(context).height;
    final route = raftPresentedRoute<void>(
      context,
      policy: const RaftPresentationPolicy(
        compact: RaftSurfaceForm.sheet,
        medium: RaftSurfaceForm.sheet,
        wide: RaftSurfaceForm.sheet,
      ),
      label: raftText(context, 'Comments'),
      sheetInitialSize: (.7 + handle / height).clamp(
        .7,
        RaftSheetMetrics.largeDetent,
      ),
      dragDismissible: RaftInteraction.of(context).touch,
      content: (context, _) => RaftSheet.fixed(
        child: ArtifactCommentsPanel(
          store: store,
          review: review,
          data: shown,
          insert: insert,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
    reportSheet = route;
    await Navigator.of(context, rootNavigator: true).push(route);
    if (identical(reportSheet, route)) reportSheet = null;
  }

  Future<void> _deleteArtifact() async {
    final shown = data;
    if (shown == null || !_canDelete(shown) || confirmingDelete) return;
    final id = shown.card.id;
    final target = widget.target;
    final versionTicket = ticket;
    final route = ModalRoute.of(context);
    bool stillShown() =>
        current &&
        widget.target == target &&
        ticket == versionTicket &&
        data?.card.id == id &&
        (route?.isActive ?? true);
    Future<void>? pending;
    var deleted = false;
    Future<void> confirm() async {
      if (deleted || !stillShown() || !_canDelete(data)) return;
      try {
        await viewerSession.deleteArtifact(id, sessionGeneration);
        deleted = true;
      } catch (_) {
        if (stillShown() && viewerSession.enabled) rethrow;
      }
    }

    confirmingDelete = true;
    try {
      final accepted = await RaftConfirmDialog.show(
        context,
        RaftConfirmDialog(
          title: raftText(context, 'Delete this Artifact?'),
          cssTitle: true,
          message: raftFormat(
            context,
            'Everyone loses access to “{title}” and all of its versions.',
            {'title': shown.card.title},
          ),
          confirmLabel: raftText(context, 'Delete Artifact'),
          loadingLabel: raftText(context, 'Processing…'),
          surfaceKey: const ValueKey('artifact-delete-dialog'),
          confirmKey: const ValueKey('artifact-delete-confirm'),
          onConfirm: () =>
              pending ??= confirm().whenComplete(() => pending = null),
        ),
        overModal: !widget.inCollection && !widget.page,
      );
      if (accepted == true &&
          deleted &&
          stillShown() &&
          (route?.isCurrent ?? true)) {
        (widget.onDeleted ?? widget.onClose)();
      }
    } finally {
      confirmingDelete = false;
    }
  }

  Future<void> _download() async {
    final shown = data;
    if (shown != null) await actions.download(context, shown);
  }

  Future<void> _downloadShownFile() async {
    final shown = data;
    final file = shown == null ? null : _shownFile(shown);
    if (shown != null && file != null) {
      await actions.downloadFile(context, shown.card, file);
    }
  }

  Future<void> _toggleFollow() async {
    final shown = data;
    if (shown == null) return;
    final answer = await actions.setFollowing(shown.card, !shown.following);
    if (answer != null && current && data?.card.id == shown.card.id) {
      setState(() => data = data!.copyWith(following: answer));
    }
  }

  void _retryFrame() => setState(() {
    firstFrame = null;
    frameAttempt++;
  });

  ArtifactFrameHost get _host => ArtifactFrameHost(
    openLink: (uri) => actions.openExternal(uri),
    copyText: (text) async {
      try {
        await copyArtifactFrameText(text);
        if (mounted) {
          showRaftToast(
            context,
            raftText(context, 'Copied'),
            tone: RaftToastRecipeTone.success,
          );
        }
        return true;
      } catch (_) {
        if (mounted) {
          showRaftToast(context, raftText(context, 'Couldn\'t copy'));
        }
        return false;
      }
    },
    // ART2 opens the comment composer here; until then a page's Comment
    // button is declined (the page is told no).
    comments: (_) async => false,
    confirm: (capability, args, title) async =>
        mounted &&
        await confirmArtifactFrameRequest(
          context,
          capability: capability,
          args: args,
          pageTitle: title,
        ),
  );

  Widget _frame(BuildContext context, ArtifactViewerData data) {
    final card = data.card;
    final file = _shownFile(data);
    final kind = shownPath == null ? card.kind : (file?.kind ?? card.kind);
    final pageUrl = actions.addressOf(card);
    if (!_webView) {
      return ArtifactOpenInBrowser(
        title: card.title,
        pageUrl: pageUrl,
        open: actions.openExternal,
      );
    }
    final t = RaftTokens.of(context);
    final dark = t.dark;
    final use = shownPath == null ? firstFrame : null;
    final path = shownPath;
    final view = ArtifactFrameView(
      key: ValueKey(
        'artifact-frame-${card.id}@${card.version}:$path#$frameAttempt',
      ),
      artifactId: card.id,
      version: card.version,
      title: path ?? card.title,
      appOrigin: deployment!.webOrigin,
      contentDomain: deployment!.contentDomain!,
      firstLocation: use,
      locate: () {
        firstFrame = null;
        return api.frame(card.id, version: card.version, path: path);
      },
      host: _host,
      hostScript: widget.hostScript ?? artifactHostScript,
      controller: frame,
      dark: dark,
      theme: kind == ArtifactKind.markdown
          ? artifactPageTheme(t.colors)
          : const {},
      webViewBuilder: widget.webViewBuilder,
    );
    // The viewer route's ticket is spent by this mount.
    firstFrame = null;
    final failed =
        frame.status == ArtifactFrameStatus.fallback ||
        frame.status == ArtifactFrameStatus.error;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: failed, child: view),
        if (failed)
          ColoredBox(
            color: t.panel,
            child: artifactFrameStateView(
              context,
              frame,
              onRetry: _retryFrame,
              onOpenInBrowser: () => unawaited(actions.openExternal(pageUrl)),
              onDownload: _readsInOwnServer ? _downloadShownFile : null,
            ),
          )
        else if (!frame.ready)
          ArtifactLoadingSplash(
            kind: kind,
            starting: frame.status == ArtifactFrameStatus.starting,
          ),
      ],
    );
  }

  Widget _content(BuildContext context, ArtifactViewerData data) {
    final card = data.card;
    final activityAddress = discussion?.current != true && shownPath == null
        ? _activityBrowserAddress(card)
        : null;
    if (activityAddress != null) {
      return ArtifactOpenInBrowser(
        title: card.title,
        pageUrl: activityAddress,
        open: actions.openExternal,
      );
    }
    final file = _shownFile(data);
    final kind = shownPath == null ? card.kind : (file?.kind ?? card.kind);
    final download = _readsInOwnServer && file != null
        ? () => unawaited(_downloadShownFile())
        : null;
    final nativeMarkdown =
        widget.inCollection &&
        !_webView &&
        kind == ArtifactKind.markdown &&
        file != null &&
        _readsInOwnServer;
    if (_framed(data) && !nativeMarkdown) return _frame(context, data);
    if (file != null && (artifactDrawnKind(kind) || nativeMarkdown)) {
      return ArtifactDrawnContent(
        key: ValueKey('artifact-drawn-${card.id}@${card.version}:${file.path}'),
        kind: kind,
        path: file.path,
        read: () => api.fileBytes(card.id, file.path, card.version),
        onDownload: download,
      );
    }
    return ArtifactNoPreview(onDownload: download);
  }

  Uri? _activityBrowserAddress(ArtifactCard card) {
    final target = widget.target;
    if (card.version != (target.version ?? card.latestVersion)) return null;
    final review = target.reviewId;
    final slug = w.server?.string('slug');
    if (review != null && slug != null && slug.isNotEmpty) {
      final location = RaftLocation.at(
        serverSlug: slug,
        route: RaftRoute.activity,
        query: {
          'artifact': artifactLinkId(target.id),
          if (target.version case final version?) 'version': '$version',
          'review': review,
        },
      );
      return actions.webOrigin.resolveUri(location.uri);
    }
    final comment = target.commentId;
    if (comment == null) return null;
    return artifactUrl(
      actions.webOrigin,
      target.id,
      target.version,
    ).replace(queryParameters: {'panel': 'comments', 'comment': comment});
  }

  List<RaftMenuEntry> _menu(
    BuildContext context,
    ArtifactViewerData data, {
    RaftMenuEntry? foldedComments,
  }) {
    String tr(String s) => raftText(context, s);
    final card = data.card;
    final own = _readsInOwnServer;
    final collectionCard = widget.inCollection && !widget.page;
    final rename = data.capabilities.publish
        ? RaftMenuEntry(
            label: tr(widget.inCollection ? 'Rename' : 'Rename Artifact'),
            glyph: RaftGlyph.pencil,
            onPressed: () => unawaited(_manage(ArtifactManageAction.rename)),
          )
        : null;
    final itself = [
      if (widget.inCollection) ?rename,
      if (own && data.versions.isNotEmpty)
        RaftMenuEntry(
          label: tr('Version history'),
          glyph: collectionCard ? RaftGlyph.history : RaftGlyph.clock,
          onPressed: collectionCard
              ? null
              : () => setState(() => panel = _Panel.versions),
          submenu: collectionCard ? _versionChoices(context, data) : const [],
          submenuSide: RaftDropdownSide.left,
          openSubmenuOnHover: collectionCard,
        ),
      if (data.files.isNotEmpty)
        RaftMenuEntry(
          label: tr('Files'),
          glyph: collectionCard ? RaftGlyph.files : RaftGlyph.folderOpen,
          onPressed: () => setState(() => panel = _Panel.files),
        ),
      if (own && data.entry != null)
        RaftMenuEntry(
          label: tr(data.files.length > 1 ? 'Download all' : 'Download'),
          glyph: collectionCard && data.files.length > 1
              ? RaftGlyph.folderDown
              : RaftGlyph.download,
          onPressed: () => unawaited(_download()),
        ),
    ];
    return [
      if (!widget.inCollection || widget.page)
        RaftMenuEntry(
          label: tr('Open in browser'),
          glyph: RaftGlyph.arrowUpRight,
          onPressed: () {
            final address = _activityBrowserAddress(card);
            unawaited(
              address == null
                  ? actions.openInBrowser(card)
                  : actions.openExternal(address),
            );
          },
        ),
      ?foldedComments,
      if ((!widget.inCollection || widget.page) &&
          _framed(data) &&
          _webView &&
          frame.ready)
        RaftMenuEntry(
          label: tr('Find in page'),
          glyph: RaftGlyph.search,
          onPressed: () => setState(() => finding = true),
        ),
      if (!widget.inCollection || widget.page || foldedComments != null)
        const RaftMenuEntry.separator(),
      RaftMenuEntry(
        label: tr('Copy link'),
        glyph: RaftGlyph.link,
        onPressed: () => unawaited(actions.copyLink(context, card)),
      ),
      RaftMenuEntry(
        label: tr('Send to conversation'),
        glyph: RaftGlyph.forward,
        onPressed: () => unawaited(_forward(card)),
      ),
      if (!widget.inCollection) ?rename,
      if (!widget.inCollection)
        RaftMenuEntry(
          label: tr('Who can see it'),
          glyph: artifactScopeGlyph(card.home),
          onPressed: () => unawaited(_manage(ArtifactManageAction.visibility)),
        )
      else if (_visibilityChoices(context, data) case final choices
          when choices.isNotEmpty)
        RaftMenuEntry(
          label: tr('Who can see'),
          glyph: RaftGlyph.users,
          submenu: choices,
          submenuSide: RaftDropdownSide.left,
          openSubmenuOnHover: collectionCard,
        ),
      if (itself.isNotEmpty) ...[const RaftMenuEntry.separator(), ...itself],
      if (own) ...[
        const RaftMenuEntry.separator(),
        RaftMenuEntry(
          label: tr(data.following ? 'Unfollow' : 'Follow'),
          glyph: collectionCard
              ? (data.following
                    ? RaftGlyph.unfollowArtifact
                    : RaftGlyph.followArtifact)
              : (data.following ? RaftGlyph.bellOff : RaftGlyph.bell),
          onPressed: () => unawaited(_toggleFollow()),
        ),
        if (_canReport(data) && !_reportInCommentsMenu(data))
          _reportEntry(context),
      ],
      if (_canDelete(data)) ...[
        const RaftMenuEntry.separator(),
        RaftMenuEntry(
          label: tr('Delete'),
          glyph: RaftGlyph.trash2,
          onPressed: () => unawaited(_deleteArtifact()),
        ),
      ],
    ];
  }

  List<RaftMenuEntry> _versionChoices(
    BuildContext context,
    ArtifactViewerData data,
  ) {
    final card = data.card;
    return [
      for (final version in data.versions)
        RaftMenuEntry(
          label: version.number == card.latestVersion
              ? '${artifactVersionLabel(context, version.number)} · ${raftText(context, 'Latest')}'
              : artifactVersionLabel(context, version.number),
          description: raftFormat(context, '{name} · {time}', {
            'name': artifactActorName(context, version.publisher),
            'time': artifactRelativeTime(context, version.createdAt),
          }),
          checked: version.number == card.version,
          onPressed: () {
            if (version.number != card.version) {
              _pick(artifactPinnedFor(version.number, card.latestVersion));
            }
          },
        ),
    ];
  }

  List<RaftMenuEntry> _visibilityChoices(
    BuildContext context,
    ArtifactViewerData shown,
  ) {
    final home = shown.card.home;
    final caps = shown.capabilities;
    final original = shown.originalConversationId;
    final server = w.server?.name;
    final canMoveToConversation = caps.narrowHome && original != null;
    final canMoveToServer =
        home.kind == 'conversation' && caps.changeHome ||
        home.kind == 'public' && (caps.narrowHome || caps.unpublish);
    final canPublish = caps.changeHome && home.kind != 'public';
    if (!canMoveToConversation && !canMoveToServer && !canPublish) return [];
    final originalChannel = original == null ? null : w.channelById(original);
    return [
      if (home.kind == 'conversation' || canMoveToConversation)
        RaftMenuEntry(
          label: home.kind == 'conversation'
              ? artifactAudience(context, home, server)
              : originalChannel == null
              ? raftText(context, 'A conversation')
              : raftFormat(context, 'Members of {name}', {
                  'name': '#${originalChannel.name}',
                }),
          checked: home.kind == 'conversation',
          onPressed: () {
            if (home.kind != 'conversation' && original != null) {
              unawaited(
                _changeVisibility(ArtifactHomeTarget.conversation(original)),
              );
            }
          },
        ),
      if (home.kind == 'server' || canMoveToServer)
        RaftMenuEntry(
          label: artifactScopeLabel(
            context,
            const ArtifactHome.server(),
            serverName: server,
          ),
          checked: home.kind == 'server',
          onPressed: () {
            if (canMoveToServer) {
              unawaited(_changeVisibility(const ArtifactHomeTarget.server()));
            }
          },
        ),
      if (home.kind == 'public' || canPublish)
        RaftMenuEntry(
          label: raftText(context, 'Anyone with the link'),
          checked: home.kind == 'public',
          onPressed: () {
            if (canPublish) {
              unawaited(_changeVisibility(const ArtifactHomeTarget.public()));
            }
          },
        ),
    ];
  }

  Future<void> _changeVisibility(ArtifactHomeTarget target) async {
    final shown = data;
    if (shown == null || !current) return;
    if (shown.card.home.kind == 'conversation' && target.kind == 'server') {
      try {
        final result = await ArtifactSharingApi(w.client)
            .move(shown.card.id, target);
        _applyManageResult(result);
      } catch (_) {
        if (!mounted || !current) return;
        showRaftToast(
          context,
          raftText(context, "Couldn't change who can see it. Try again."),
        );
      }
      return;
    }
    await _manage(ArtifactManageAction.visibility, initialTarget: target);
  }

  Future<void> _manage(
    ArtifactManageAction action, {
    ArtifactHomeTarget? initialTarget,
  }) async {
    final before = data;
    if (before == null) return;
    final original = before.originalConversationId;
    final result = await showArtifactManageDialog(
      context,
      api: ArtifactSharingApi(w.client),
      data: before,
      action: action,
      initialTarget: initialTarget,
      opaqueHost: widget.inCollection,
      current: () => current,
      serverName: w.server?.name,
      conversationName: original == null ? null : w.channelById(original)?.name,
    );
    if (result != null) _applyManageResult(result);
  }

  void _applyManageResult(ArtifactViewerData result) {
    final shown = data;
    if (!current || shown == null) return;
    setState(() {
      data = shown.copyWith(
        card: shown.card.copyWith(
          title: result.card.title,
          home: result.card.home,
        ),
        changed: result,
      );
    });
    widget.session.summaries.invalidate(result.card.id);
  }

  Future<void> _forward(ArtifactCard card) async {
    final result = await showArtifactForwardDialog(
      context,
      workspace: w,
      card: card,
      current: () => current,
    );
    if (!mounted || result == null || workspaceAuthority(w) != authority) {
      return;
    }
    if (result.home case final home?) {
      final shown = data;
      if (shown != null) {
        setState(
          () => data = shown.copyWith(card: shown.card.copyWith(home: home)),
        );
        widget.session.summaries.invalidate(card.id);
      }
    }
    showRaftToast(
      context,
      raftText(context, 'Sent'),
      tone: RaftToastRecipeTone.success,
    );
  }

  Future<void> _openOrigin(ArtifactOrigin origin) async {
    final serverAuthority = channelSearchPageAuthority(w);
    await w.jumpToMessage(
      origin.conversationId,
      origin.messageId,
      replaceEntry: widget.page,
    );
    if (mounted &&
        widget.page &&
        channelSearchPageAuthority(w) == serverAuthority &&
        w.channel?.id == origin.conversationId) {
      widget.onClose();
    }
  }

  Widget _collectionMeta(
    BuildContext context,
    ArtifactCard card,
    ArtifactViewerData? data,
  ) {
    final origin = data?.origin;
    final conversation = origin == null || card.fromAnotherServer
        ? null
        : w.channelById(origin.conversationId);
    final direct = conversation?.type == 'dm';
    final name = conversation == null
        ? null
        : direct
        ? conversation.peerLabel
        : '#${conversation.name}';
    final t = RaftTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: RaftSpace.x2,
      children: [
        Flexible(
          child: ArtifactScopeChip(
            key: const ValueKey('artifact-viewer-scope'),
            card: card,
            serverName: w.server?.name,
            viewerHeader: widget.page,
            choices: data == null
                ? const []
                : _visibilityChoices(context, data),
          ),
        ),
        if (origin != null && name != null)
          Flexible(
            child: RaftTextLink(
              label: name,
              semanticLabel: direct
                  ? raftTextZh(
                      context,
                      'From a message with $name',
                      '来自和 $name 的私信里的一条消息',
                    )
                  : raftTextZh(
                      context,
                      'From a message in $name',
                      '来自 $name 里的一条消息',
                    ),
              glyph: RaftGlyph.messageSquare,
              variant: RaftTextLinkVariant.muted,
              typeStyle: t.scale(RaftTypeScale.monoMeta, mono: true),
              maxLines: 1,
              onPressed: () => unawaited(_openOrigin(origin)),
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, {bool foldComments = false}) {
    String tr(String s) => raftText(context, s);
    final data = this.data;
    final card = data?.card ?? widget.seed;
    final title = card == null
        ? tr('Loading Artifact')
        : widget.inCollection
        ? artifactShownTitle(card.title)
        : card.title;
    final meta = card == null
        ? null
        : artifactScopeLabel(
            context,
            card.home,
            fromAnotherServer: card.fromAnotherServer,
            serverName: w.server?.name,
          );
    final more = tr('More actions');
    final showComments = discussion?.current == true;
    final commentsLabel = tr(
      panel == _Panel.comments ? 'Close comments' : 'Comments',
    );
    final version = data == null
        ? null
        : widget.inCollection
        ? RaftBadge(
            label: artifactVersionLabel(context, data.card.version),
            appearance: RaftBadgeRecipeAppearance.outline,
            variant: RaftBadgeRecipeVariant.muted,
            onPressed: () => setState(() => panel = _Panel.versions),
          )
        : ArtifactVersionTag(
            data: data,
            onOpen: () => setState(() => panel = _Panel.versions),
          );
    final actions = <Widget>[
      if (data != null) ...[
        if (!widget.inCollection) version!,
        if (widget.inCollection && !widget.page)
          RaftPanelAction(
            key: const ValueKey('artifact-viewer-open-external'),
            responsiveRecipe: true,
            glyph: RaftGlyph.arrowUpRight,
            tooltip: tr('Open in browser'),
            onPressed: () => unawaited(this.actions.openInBrowser(data.card)),
          ),
        if (_framed(data) && _webView && frame.ready)
          RaftButton(
            key: const ValueKey('artifact-viewer-find'),
            glyph: RaftGlyph.search,
            tooltip: tr('Find in page'),
            semanticLabel: tr('Find in page'),
            tone: RaftButtonRecipeVariant.ghost,
            size: widget.inCollection
                ? RaftButtonRecipeSize.iconMd
                : RaftButtonRecipeSize.iconLg,
            onPressed: () => setState(() => finding = !finding),
          ),
        if (showComments && !foldComments)
          RaftButton(
            key: const ValueKey('artifact-comments-trigger'),
            focusNode: commentsFocus,
            glyph: RaftGlyph.messageSquare,
            tooltip: commentsLabel,
            semanticLabel: commentsLabel,
            toggled: _reportSidebarOpen ? true : null,
            tone: RaftButtonRecipeVariant.ghost,
            size: widget.inCollection
                ? RaftButtonRecipeSize.iconMd
                : RaftButtonRecipeSize.iconLg,
            styleBuilder: _reportSidebarOpen
                ? (context, state, _) {
                    final tokens = RaftTokens.of(context);
                    return RaftPanelToggleActionRecipe.resolve(
                      tokens: tokens.recipeTokens,
                      states: tokens.recipeStates(
                        responsive: true,
                        hovered: state.hovered,
                        pressed: state.pressed,
                        focusVisible: state.focusVisible,
                        extra: const ['data-pressed'],
                      ),
                    ).base;
                  }
                : null,
            glyphSize: _reportSidebarOpen
                ? RaftTokens.of(context).recipeTokens.number('controlIconSize')
                : null,
            onPressed: _toggleComments,
          ),
        if (_reportInCommentsMenu(data))
          RaftDropdownMenu(
            key: const ValueKey('artifact-comment-menu-trigger'),
            label: tr('Comment actions'),
            align: RaftDropdownAlign.end,
            kind: RaftMenuKind.dropdownMenu,
            width: 220,
            entries: [_reportEntry(context)],
            triggerBuilder: (context, focus, onPressed) => RaftPanelAction(
              responsiveRecipe: true,
              glyph: RaftGlyph.chevronDown,
              tooltip: tr('Comment actions'),
              focusNode: focus,
              onPressed: onPressed,
            ),
          ),
        RaftDropdownMenu(
          key: const ValueKey('artifact-viewer-menu'),
          label: more,
          surfaceKey: const ValueKey('artifact-viewer-menu-surface'),
          kind: RaftMenuKind.dropdownMenu,
          align: RaftDropdownAlign.end,
          sideOffset: 4,
          width: 220,
          triggerFocus: widget.inCollection ? moreFocus : null,
          entries: _menu(
            context,
            data,
            foldedComments: showComments && foldComments
                ? RaftMenuEntry(
                    label: commentsLabel,
                    glyph: RaftGlyph.messageSquare,
                    onPressed: _toggleComments,
                  )
                : null,
          ),
          triggerBuilder: (context, focus, onPressed) => widget.inCollection
              ? RaftPanelAction(
                  key: const ValueKey('artifact-viewer-menu-trigger'),
                  responsiveRecipe: true,
                  glyph: RaftGlyph.ellipsisVertical,
                  tooltip: more,
                  focusNode: focus,
                  onPressed: onPressed,
                )
              : RaftButton(
                  key: const ValueKey('artifact-viewer-menu-trigger'),
                  glyph: RaftGlyph.ellipsisVertical,
                  tooltip: more,
                  semanticLabel: more,
                  focusNode: focus,
                  tone: RaftButtonRecipeVariant.ghost,
                  size: RaftButtonRecipeSize.iconLg,
                  onPressed: onPressed,
                ),
        ),
      ],
    ];
    if (widget.inCollection) {
      final t = RaftTokens.of(context);
      final details = card == null
          ? null
          : _collectionMeta(context, card, data);
      final close = panel == _Panel.comments ? _closeComments : widget.onClose;
      const closeKey = ValueKey('artifact-viewer-close');
      return RaftPanelHeaderBar(
        title: title,
        titleSuffix: version,
        columnMargin: widget.page
            ? RaftArtifactCollectionLayout.columnMargin
            : null,
        metaSlot: widget.page && details != null
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _collectionMetaMinHeight,
                ),
                child: details,
              )
            : null,
        background: t.ui.layerCanvas,
        onBack: widget.page ? close : null,
        backKey: closeKey,
        titleSlot: widget.page
            ? null
            : Row(
                spacing: RaftSpace.x2,
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: RaftCssText(
                        title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: RaftScaled.grows(context) ? null : 1,
                        style: t.scale(t.typeSlot('headline')),
                      ),
                    ),
                  ),
                  ?version,
                  if (details != null) Flexible(child: details),
                ],
              ),
        actions: [
          ...actions,
          if (!widget.page)
            RaftPanelAction(
              key: closeKey,
              responsiveRecipe: true,
              glyph: RaftGlyph.x,
              tooltip: tr('Close'),
              onPressed: close,
            ),
        ],
      );
    }
    return widget.page
        ? RaftPanelHeaderBar(
            title: title,
            subtitle: meta,
            onBack: panel == _Panel.comments ? _closeComments : widget.onClose,
            backKey: const ValueKey('artifact-viewer-close'),
            backTooltip: 'Close',
            actions: actions,
          )
        : RaftLightboxHeader(
            title: title,
            subtitle: meta,
            borderWidth: 1,
            onClose: panel == _Panel.comments ? _closeComments : widget.onClose,
            closeLabel: 'Close',
            actions: actions,
          );
  }

  Widget? _panel(BuildContext context, ArtifactViewerData data) {
    final own = _readsInOwnServer;
    return switch (panel) {
      _Panel.files => ArtifactFilesPanel(
        data: data,
        shownPath: shownPath,
        onShow: (path) => setState(() {
          shownPath = path;
          finding = false;
          if (widget.page) panel = _Panel.none;
        }),
        onClose: () => setState(() => panel = _Panel.none),
        onDownload: own
            ? (file) =>
                  unawaited(actions.downloadFile(context, data.card, file))
            : null,
        onDownloadAll: own && data.files.length > 1
            ? () => unawaited(_download())
            : null,
      ),
      _Panel.versions => ArtifactVersionsPanel(
        data: data,
        onPick: _pick,
        onClose: () => setState(() => panel = _Panel.none),
      ),
      _Panel.comments =>
        discussion == null
            ? null
            : ArtifactCommentsPanel(
                store: discussion!,
                review: review,
                data: data,
                initialComment: discussionLanding
                    ? widget.target.commentId
                    : null,
                path: report == null ? _shownFile(data)?.path : null,
                insert: report,
                onClose: _closeComments,
              ),
      _Panel.none => null,
    };
  }

  Widget _body(BuildContext context) {
    final t = RaftTokens.of(context);
    final data = this.data;
    if (data == null) {
      if (unavailable) {
        return ArtifactViewerState(
          key: const ValueKey('artifact-viewer-unavailable'),
          title: raftText(context, 'Can\'t open this Artifact'),
          detail: raftText(
            context,
            'It doesn\'t exist, or you don\'t have access to it.',
          ),
        );
      }
      return ArtifactLoadingSplash(
        key: const ValueKey('artifact-viewer-loading'),
        kind: widget.seed?.kind,
        starting: false,
      );
    }
    final content = _content(context, data);
    final side = _panel(context, data);
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtifactVersionNotice(
          card: data.card,
          failedVersion: failedVersion,
          failedLatest: failedLatest,
          onBackToLatest: () => _pick(null),
          onRetry: () => unawaited(_load(pinned)),
        ),
        if (newer case final next?)
          ArtifactNewVersionNotice(
            version: next.version,
            publisher: next.publisher,
            onViewLatest: () => _pick(null),
          ),
        if (finding && _framed(data) && frame.ready)
          ArtifactFindBar(
            frame: frame,
            onClose: () => setState(() => finding = false),
          ),
        Expanded(
          child: SizedBox.expand(key: reportArea, child: content),
        ),
      ],
    );
    if (widget.page) {
      return Stack(
        fit: StackFit.expand,
        children: [
          main,
          if (side != null) ColoredBox(color: t.panel, child: side),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        if (side != null && _reportSidebarOpen)
          Container(
            width: _displayReportPanelWidth,
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: t.ui.lineSeam),
              ),
            ),
            child: side,
          )
        else if (side != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.ui.lineHairline)),
            ),
            child: SizedBox(width: _sidePanelWidth, child: side),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final busy = switching || data == null && !unavailable;
    final view = Semantics(
      container: true,
      label: data?.card.title ?? raftText(context, 'Artifact'),
      child: ColoredBox(
        key: const ValueKey('artifact-workspace-viewer'),
        color: widget.inCollection ? t.ui.layerCanvas : t.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.inCollection)
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return _header(
                    context,
                    foldComments:
                        width.isFinite &&
                        width > 0 &&
                        width.round() < _headerActionsMinWidth,
                  );
                },
              )
            else
              _header(context),
            if (busy && data != null)
              const RaftProgressBar(size: RaftProgressRecipeSize.sm),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
    final scoped = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (finding) {
            setState(() => finding = false);
          } else if (panel == _Panel.comments) {
            _closeComments();
          } else if (panel != _Panel.none) {
            setState(() => panel = _Panel.none);
          } else {
            widget.onClose();
          }
        },
      },
      child: Focus(focusNode: viewerFocus, autofocus: true, child: view),
    );
    final safe = PopScope(
      canPop: panel != _Panel.comments,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && panel == _Panel.comments) _closeComments();
      },
      child: widget.inCollection
          ? scoped
          : SafeArea(bottom: false, child: scoped),
    );
    return widget.page || widget.inCollection
        ? safe
        // ds-allow: full-bleed viewer shell, the same Dialog.fullscreen the attachment preview shell uses (raft_ui)
        : Dialog.fullscreen(backgroundColor: t.panel, child: safe);
  }
}
