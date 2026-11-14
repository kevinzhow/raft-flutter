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

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    show WebViewPlatform;

import '../../data/workspace_controller.dart';
import '../../platform/system_bars.dart';
import '../private_route_guard.dart' show workspaceAuthority;
import 'artifact_api.dart';
import 'artifact_content.dart';
import 'artifact_find_bar.dart';
import 'artifact_frame_bridge.dart';
import 'artifact_frame_confirm.dart';
import 'artifact_frame_view.dart';
import 'artifact_models.dart';
import 'artifact_open_in_browser.dart';
import 'artifact_session.dart';
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

enum _Panel { none, files, versions }

class ArtifactWorkspaceViewer extends StatefulWidget {
  const ArtifactWorkspaceViewer({
    super.key,
    required this.session,
    required this.target,
    required this.page,
    required this.onClose,
    this.seed,
    this.webViewBuilder,
    this.save,
    this.openExternal,
    this.operatingSystem,
    this.semantics,
    this.hostScript,
  });

  final ArtifactSession session;
  final ArtifactLinkTarget target;

  /// What a card already showed (Web `artifactCardSeed`): the title while
  /// the viewer route answers.
  final ArtifactCard? seed;
  final bool page;
  final VoidCallback onClose;

  // Test seams.
  final ArtifactFrameWebViewBuilder? webViewBuilder;
  final ArtifactSaveBytes? save;
  final Future<bool> Function(Uri)? openExternal;
  final String? operatingSystem;
  final bool? semantics;
  final Future<String> Function()? hostScript;

  @override
  State<ArtifactWorkspaceViewer> createState() =>
      _ArtifactWorkspaceViewerState();
}

class _ArtifactWorkspaceViewerState extends State<ArtifactWorkspaceViewer> {
  WorkspaceController get w => widget.session.w;
  ArtifactApi get api => widget.session.api;
  late final String authority = workspaceAuthority(w);
  bool get current => mounted && workspaceAuthority(w) == authority;

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
    pinned = widget.target.version;
    frame.addListener(_frameChanged);
    SemanticsBinding.instance.addSemanticsEnabledListener(_semanticsChanged);
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
    poll?.dispose();
    SemanticsBinding.instance.removeSemanticsEnabledListener(_semanticsChanged);
    frame.removeListener(_frameChanged);
    frame.dispose();
    super.dispose();
  }

  void _frameChanged() {
    if (!mounted) return;
    if (frame.findRequests > 0 && !finding && frame.ready) finding = true;
    setState(() {});
  }

  void _semanticsChanged() {
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
        firstFrame = result.frame;
        frameAttempt++;
        pinned = result.card.pinned ? result.card.version : null;
        shownPath = null;
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

  bool get _semanticsOn =>
      widget.semantics ?? SemanticsBinding.instance.semanticsEnabled;

  String get _os => widget.operatingSystem ?? Platform.operatingSystem;

  bool get _webView =>
      artifactFrameSupportFor(_os, semantics: _semanticsOn) ==
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
        if (mounted) showRaftToast(context, raftText(context, 'Couldn\'t copy'));
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final use = shownPath == null ? firstFrame : null;
    final path = shownPath;
    final view = ArtifactFrameView(
      key: ValueKey('artifact-frame-${card.id}@${card.version}:$path#$frameAttempt'),
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
    if (_framed(data)) return _frame(context, data);
    final file = _shownFile(data);
    final kind = shownPath == null ? card.kind : (file?.kind ?? card.kind);
    final download = _readsInOwnServer && file != null
        ? () => unawaited(_downloadShownFile())
        : null;
    if (file != null && artifactDrawnKind(kind)) {
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

  List<RaftMenuEntry> _menu(BuildContext context, ArtifactViewerData data) {
    String tr(String s) => raftText(context, s);
    final card = data.card;
    final own = _readsInOwnServer;
    final itself = [
      if (own && data.versions.isNotEmpty)
        RaftMenuEntry(
          label: tr('Version history'),
          glyph: RaftGlyph.clock,
          onPressed: () => setState(() => panel = _Panel.versions),
        ),
      if (data.files.isNotEmpty)
        RaftMenuEntry(
          label: tr('Files'),
          glyph: RaftGlyph.folderOpen,
          onPressed: () => setState(() => panel = _Panel.files),
        ),
      if (own && data.entry != null)
        RaftMenuEntry(
          label: tr(data.files.length > 1 ? 'Download all' : 'Download'),
          glyph: RaftGlyph.download,
          onPressed: () => unawaited(_download()),
        ),
    ];
    return [
      RaftMenuEntry(
        label: tr('Open in browser'),
        glyph: RaftGlyph.arrowUpRight,
        onPressed: () => unawaited(actions.openInBrowser(card)),
      ),
      if (_framed(data) && _webView && frame.ready)
        RaftMenuEntry(
          label: tr('Find in page'),
          glyph: RaftGlyph.search,
          onPressed: () => setState(() => finding = true),
        ),
      const RaftMenuEntry.separator(),
      RaftMenuEntry(
        label: tr('Copy link'),
        glyph: RaftGlyph.link,
        onPressed: () => unawaited(actions.copyLink(context, card)),
      ),
      if (itself.isNotEmpty) ...[const RaftMenuEntry.separator(), ...itself],
      if (own) ...[
        const RaftMenuEntry.separator(),
        RaftMenuEntry(
          label: tr(data.following ? 'Unfollow' : 'Follow'),
          glyph: data.following ? RaftGlyph.bellOff : RaftGlyph.bell,
          onPressed: () => unawaited(_toggleFollow()),
        ),
      ],
    ];
  }

  Widget _header(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final data = this.data;
    final card = data?.card ?? widget.seed;
    final title = card?.title ?? tr('Loading Artifact');
    final meta = card == null
        ? null
        : artifactScopeLabel(
            context,
            card.home,
            fromAnotherServer: card.fromAnotherServer,
            serverName: w.server?.name,
          );
    final more = tr('More actions');
    final actions = <Widget>[
      if (data != null) ...[
        ArtifactVersionTag(
          data: data,
          onOpen: () => setState(() => panel = _Panel.versions),
        ),
        if (_framed(data) && _webView && frame.ready)
          RaftButton(
            key: const ValueKey('artifact-viewer-find'),
            glyph: RaftGlyph.search,
            tooltip: tr('Find in page'),
            semanticLabel: tr('Find in page'),
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.iconLg,
            onPressed: () => setState(() => finding = !finding),
          ),
        RaftDropdownMenu(
          key: const ValueKey('artifact-viewer-menu'),
          label: more,
          surfaceKey: const ValueKey('artifact-viewer-menu-surface'),
          kind: RaftMenuKind.dropdownMenu,
          align: RaftDropdownAlign.end,
          sideOffset: 4,
          width: 220,
          entries: _menu(context, data),
          triggerBuilder: (context, focus, onPressed) => RaftButton(
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
    return widget.page
        ? RaftPanelHeaderBar(
            title: title,
            subtitle: meta,
            onBack: widget.onClose,
            backKey: const ValueKey('artifact-viewer-close'),
            backTooltip: 'Close',
            actions: actions,
          )
        : RaftLightboxHeader(
            title: title,
            subtitle: meta,
            borderWidth: 1,
            onClose: widget.onClose,
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
            ? (file) => unawaited(actions.downloadFile(context, data.card, file))
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
        Expanded(child: content),
      ],
    );
    if (side == null) return main;
    if (widget.page) {
      return Stack(
        fit: StackFit.expand,
        children: [
          main,
          ColoredBox(color: t.panel, child: side),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.ui.lineHairline)),
          ),
          child: SizedBox(width: 320, child: side),
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
        color: t.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          } else if (panel != _Panel.none) {
            setState(() => panel = _Panel.none);
          } else {
            widget.onClose();
          }
        },
      },
      child: Focus(autofocus: true, child: view),
    );
    final safe = SafeArea(bottom: false, child: scoped);
    // ds-allow: full-bleed viewer shell, the same Dialog.fullscreen the attachment preview shell uses (raft_ui)
    return widget.page ? safe : Dialog.fullscreen(backgroundColor: t.panel, child: safe);
  }
}
