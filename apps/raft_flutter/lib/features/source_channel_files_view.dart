import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_channel_files_store.dart';
import '../data/workspace_controller.dart';
import 'artifacts/artifact_models.dart';
import 'artifacts/artifact_session.dart';
import 'artifacts/artifact_viewer_page.dart' show openWorkspaceArtifact;
import 'channel_side_files_artifacts.dart';
import 'channel_side_files_rows.dart';
import 'source_channel_file_glyph.dart';
import 'source_channel_files_actions.dart';

typedef ChannelFileThumbnailBuilder = Widget Function(
  SourceChannelFileEntry file,
  bool Function() authorized,
);

class SourceChannelFilesView extends StatefulWidget {
  const SourceChannelFilesView({
    super.key,
    required this.controller,
    required this.channelId,
    required this.formatCreatedAt,
    this.beforeOpenSource,
    this.thumbnailBuilder,
    this.acquireImage,
    this.peekImage,
    this.compact = false,
    this.formatCompactDate,
    this.formatFullDate,
    this.onOpenArtifact,
    this.showArtifacts = true,
  });
  final WorkspaceController controller;
  final String channelId;
  // Actual useTimeFormatter.formatShortDateTime: preferred IANA zone, locale,
  // short month/day + two-digit hour/minute + chosen12/24h; not host-local UTC.
  final String Function(String instant) formatCreatedAt;
  final ValueChanged<SourceChannelFileEntry>? beforeOpenSource;
  final ChannelFileThumbnailBuilder? thumbnailBuilder;
  final SourceChannelImageAcquire? acquireImage;
  final SourceChannelImagePeek? peekImage;

  /// The Files card's compact rows (see [SourceChannelFilesProjectionView]).
  final bool compact;
  final String Function(String instant)? formatCompactDate, formatFullDate;

  /// Opens an Artifact row; default: the Artifact viewer.
  final void Function(ArtifactCard)? onOpenArtifact;

  /// The conversation's Artifacts above the files (workspace_artifacts_v0).
  final bool showArtifacts;
  @override
  State<SourceChannelFilesView> createState() => _SourceChannelFilesState();
}

class _SourceChannelFilesState extends State<SourceChannelFilesView> {
  late SourceChannelFilesStore store;
  late SourceChannelFilesActions actions;
  ConversationArtifactsStore? artifacts;
  ArtifactSession? artifactSession;
  StreamSubscription<RaftEvent>? session;
  bool tabActive = true;
  bool dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && (!dependenciesReady || !tabActive)) {
      unawaited(store.load());
      unawaited(artifacts?.load());
    }
    tabActive = active;
    dependenciesReady = true;
  }

  /// The controller-owned per-channel store outlives this view; this view only
  /// listens to it and asks for a background refresh on every open.
  void bind() {
    store = widget.controller.channelFilesStore(widget.channelId);
    actions = SourceChannelFilesActions(
      controller: widget.controller,
      authorized: store.contains,
      context: () => context,
      acquireImage: widget.acquireImage,
    );
    store.addListener(storeChanged);
    widget.controller.addListener(changed);
    session = widget.controller.client.events.listen((_) => changed());
    if (widget.showArtifacts) {
      artifacts = ConversationArtifactsStore.of(
        widget.controller,
        widget.channelId,
      );
      // The flag arrives after the first frame: read when it turns on.
      artifactSession = ArtifactSession.of(widget.controller)
        ..addListener(artifactsFlagChanged);
    }
    if (dependenciesReady && tabActive) {
      unawaited(store.load());
      unawaited(artifacts?.load());
    }
  }

  void artifactsFlagChanged() {
    if (!mounted) return;
    if (tabActive) unawaited(artifacts?.load());
    setState(() {});
  }

  // The projection listens to the store itself; only revoke open actions here.
  void storeChanged() => actions.sync();

  void changed() {
    if (!mounted) return;
    final owned = widget.controller.channelFilesStore(widget.channelId);
    if (!identical(owned, store)) {
      // The cache dropped this store (identity change): follow its successor.
      release(widget.controller);
      bind();
      setState(() {});
      return;
    }
    final rebound = store.syncAuthority();
    actions.sync();
    if (rebound && store.authorized && tabActive) unawaited(store.load());
    setState(() {});
  }

  void release(WorkspaceController oldController) {
    oldController.removeListener(changed);
    unawaited(session?.cancel());
    session = null;
    store.removeListener(storeChanged);
    artifactSession?.removeListener(artifactsFlagChanged);
    artifactSession = null;
    artifacts = null;
    actions.dispose();
  }

  @override
  void initState() {
    super.initState();
    bind();
  }

  @override
  void didUpdateWidget(SourceChannelFilesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.channelId != widget.channelId) {
      release(oldWidget.controller);
      bind();
    }
  }

  @override
  void dispose() {
    release(widget.controller);
    super.dispose();
  }

  Future<void> openSource(SourceChannelFileEntry file) async {
    final w = widget.controller;
    final channelId = widget.channelId;
    if (!mounted ||
        !tabActive ||
        w.channel?.id != channelId ||
        !store.contains(file)) {
      return;
    }
    final taskId = file.taskId;
    if (taskId != null &&
        w.sessionScope.revokedChannels.contains(file.sourceChannelId)) {
      return;
    }
    widget.beforeOpenSource?.call(file);
    if (taskId == null) {
      await w.jumpToMessage(channelId, file.messageId);
      return;
    }
    final current = w.location;
    final next = current.withTaskConversation(
      channelId,
      taskId,
      focusedMessageId: file.messageId,
      conversationId: file.sourceChannelId,
    );
    w.navigation.navigateTask(next, kind: current.panelNavigationKindTo(next));
    w.notifyListeners();
  }

  void openArtifact(ArtifactCard card) {
    final open = widget.onOpenArtifact;
    if (open != null) return open(card);
    unawaited(
      openWorkspaceArtifact(
        context,
        widget.controller,
        ArtifactLinkTarget(card.id),
        seed: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      // Visible only for the open channel; never reuse a list for another one.
      widget.controller.channel?.id != widget.channelId
      ? const SizedBox.shrink()
      : SourceChannelFilesProjectionView(
          store: store,
          formatCreatedAt: widget.formatCreatedAt,
          onPreview: actions.preview,
          onDownload: actions.download,
          onOpenSource: openSource,
          artifacts: artifacts,
          compact: widget.compact,
          formatCompactDate: widget.formatCompactDate,
          formatFullDate: widget.formatFullDate,
          onOpenArtifact: openArtifact,
          thumbnailBuilder:
              widget.thumbnailBuilder ??
              (file, authorized) => SourceChannelFileThumbnail(
                file: file,
                authorized: authorized,
                acquireImage: widget.acquireImage,
              ),
        );
}

String sourceChannelFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  var value = bytes.toDouble(), index = 0;
  const units = ['B', 'KB', 'MB', 'GB'];
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
}

SourceChannelFileGlyph channelFileType(SourceChannelFileEntry file) {
  final mime = file.mimeType.toLowerCase(), name = file.filename.toLowerCase();
  final extension = name.contains('.')
      ? name.substring(name.lastIndexOf('.'))
      : '';
  if (mime.startsWith('image/')) return SourceChannelFileGlyph.image;
  if (mime.startsWith('video/')) return SourceChannelFileGlyph.video;
  if (mime == 'application/pdf' || extension == '.pdf') {
    return SourceChannelFileGlyph.pdf;
  }
  if (['zip', 'tar', 'rar', '7z'].any(mime.contains) ||
      ['.zip', '.tar', '.gz', '.tgz', '.rar', '.7z'].contains(extension)) {
    return SourceChannelFileGlyph.archive;
  }
  return SourceChannelFileGlyph.other;
}

/// Product AvatarListRow/SurfaceListItem overrides, NOT generic FileRow chrome.
class SourceChannelFilesRecipe {
  const SourceChannelFilesRecipe(this.tokens);
  static const _hairlineWidth = .5;
  final RaftTokens tokens;
  EdgeInsets get listInset => const EdgeInsets.all(RaftSpace.x3);
  double get listGap => RaftSpace.x2;

  /// The compact list has no gap: its rows carry their own hairlines.
  double listGapFor({required bool compact}) => compact ? 0 : listGap;
  Duration get hoverTransition => const Duration(milliseconds: 150);
  EdgeInsets get rowInset => const EdgeInsets.symmetric(
    horizontal: RaftSpace.x4,
    vertical: RaftSpace.x3,
  );
  double get bodyGap => RaftSpace.x3;
  double get thumbnailSize => 56;
  double get actionBreakpoint => 560;
  double get actionSize => 28;
  double get actionGap => RaftSpace.x1_5;
  bool collapsedActions(double outerWidth, {bool hovered = false}) =>
      outerWidth - rowInset.horizontal - 2 * border(hovered).width <=
      actionBreakpoint;
  double get fetchRemainingExtent => 320;
  double get textGap => RaftSpace.x1;
  Color get background =>
      tokens.dark ? tokens.ui.layerCanvas.withValues(alpha: 0) : tokens.panel;
  Color get rowBackground => tokens.colors['layer-card']!;
  BorderRadius get radius {
    final controlRadius = tokens.size('radius.control', fallback: 8);
    return BorderRadius.circular(controlRadius);
  }

  BorderSide border(bool hovered) => BorderSide(
    color: tokens.dark
        ? tokens.ui.lineHairline.withValues(alpha: 0)
        : tokens.colors[hovered ? 'line-strong' : 'line-muted']!,
    width: _hairlineWidth,
  );
  List<BoxShadow> shadows(bool hovered) {
    if (tokens.dark) {
      return (hovered ? tokens.themeShadows.md : tokens.themeShadows.sm)
          .paintOrder;
    }
    final color = tokens.colors['fill-strong']!;
    return [
      BoxShadow(
        color: color.withValues(alpha: .071),
        offset: const Offset(0, .5),
      ),
      if (hovered) ...[
        BoxShadow(
          color: color.withValues(alpha: .012),
          offset: const Offset(0, 5),
          blurRadius: 4,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: color.withValues(alpha: .02),
          offset: const Offset(0, 3),
          blurRadius: 3,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: color.withValues(alpha: .039),
          offset: const Offset(0, 1),
          blurRadius: 2,
          spreadRadius: -1,
        ),
      ],
    ];
  }

  TextStyle get filename => tokens.scale(
    RaftTypeScale.body,
    weight: FontWeight.w600,
    color: tokens.strong,
  );
  TextStyle get metadata =>
      tokens.scale(RaftTypeScale.monoMeta, mono: true, color: tokens.muted);
}

class SourceChannelFilesProjectionView extends StatelessWidget {
  const SourceChannelFilesProjectionView({
    super.key,
    required this.store,
    required this.formatCreatedAt,
    required this.onPreview,
    required this.onDownload,
    required this.onOpenSource,
    this.thumbnailBuilder,
    this.artifacts,
    this.onOpenArtifact,
    this.compact = false,
    this.formatCompactDate,
    this.formatFullDate,
  });
  final SourceChannelFilesStore store;
  final String Function(String) formatCreatedAt;
  final Future<void> Function(SourceChannelFileEntry) onPreview,
      onDownload,
      onOpenSource;
  final ChannelFileThumbnailBuilder? thumbnailBuilder;

  /// The conversation's Artifacts, above the files (null: none shown).
  final ConversationArtifactsStore? artifacts;
  final void Function(ArtifactCard)? onOpenArtifact;

  /// The Files card's compact row (Web `variant: "compact"`): one line per
  /// file, hairlines between rows, no card per row.
  final bool compact;

  /// A compact row's time (Web `formatCompactDate`): the clock today, the
  /// month and day this year, the ISO date before. Default: [formatCreatedAt].
  final String Function(String)? formatCompactDate;

  /// The full date and time a compact time gives on hover.
  final String Function(String)? formatFullDate;

  /// Pull to refresh (Web `usePagePullToRefresh`): the first page again,
  /// swapped in when it arrives; a failure keeps the rows and toasts. By
  /// finger only: the Web hook answers a finger, on a phone width.
  Future<void> _refresh(BuildContext context) async {
    final ok = await store.refresh();
    if (!ok && context.mounted) {
      showRaftToast(
        context,
        'Could not load files.',
        tone: RaftToastRecipeTone.warning,
      );
    }
  }

  Widget _pullable(BuildContext context, Widget child) => RaftPullToRefresh(
    enabled: RaftInteraction.of(context).touch && !store.initialLoading,
    onRefresh: () => _refresh(context),
    child: child,
  );

  /// A state with no list (empty, error) still answers a pull.
  Widget _stateView(BuildContext context, Widget content) => _pullable(
    context,
    LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        recipe = SourceChannelFilesRecipe(RaftTokens.of(context));
    return ListenableBuilder(
      listenable: Listenable.merge([store, ?artifacts]),
      builder: (context, _) {
        if (!store.authorized) return const SizedBox.shrink();
        final shown = artifacts?.status ?? ConversationArtifactsStatus.hidden;
        // Web: the files never wait for the Artifacts; with no files the list
        // waits, so it does not flash empty.
        if (store.initialLoading ||
            (store.files.isEmpty &&
                shown == ConversationArtifactsStatus.loading)) {
          return Center(
            child: Text(
              raftText(context, 'Loading files…'),
              style: t.scale(RaftTypeScale.callout, mono: true),
            ),
          );
        }
        if (store.error != null && store.files.isEmpty) {
          return _stateView(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  raftText(context, 'Could not load files.'),
                  style: t.scale(
                    RaftTypeScale.callout,
                    weight: FontWeight.w700,
                    color: t.colors['danger'],
                  ),
                ),
                const SizedBox(height: RaftSpace.x2),
                // Explicit native recovery action; source error branch has no retry.
                RaftButton(
                  label: raftText(context, 'Retry'),
                  uiVariant: RaftButtonVariant.outline,
                  uiSize: RaftButtonSize.sm,
                  onPressed: () => store.load(),
                ),
              ],
            ),
          );
        }
        final artifactRows = switch (shown) {
          ConversationArtifactsStatus.hidden => 0,
          ConversationArtifactsStatus.loading ||
          ConversationArtifactsStatus.failed => 1,
          ConversationArtifactsStatus.ready =>
            artifacts!.cards.length +
                (artifacts!.nextCursor != null ||
                        artifacts!.more == ConversationArtifactsMore.failed
                    ? 1
                    : 0),
        };
        if (store.files.isEmpty &&
            (shown == ConversationArtifactsStatus.hidden ||
                (shown == ConversationArtifactsStatus.ready &&
                    artifacts!.cards.isEmpty))) {
          return _stateView(
            context,
            RaftProductEmptyState(
              icon: (context, size, color) =>
                  RaftIcon(RaftGlyph.paperclip, size: size, color: color),
              title: raftText(context, 'No files yet'),
              description: raftText(
                context,
                'Attach files in Chat, or drag files into the message composer. They will appear here after the message is sent.',
              ),
            ),
          );
        }
        final filesAt = artifactRows;
        final footer = store.nextCursor != null || store.loadingMore;
        String compactDate(String at) =>
            (formatCompactDate ?? formatCreatedAt)(at);
        Widget artifactRow(int index) {
          final art = artifacts!;
          if (shown == ConversationArtifactsStatus.loading) {
            return const ConversationArtifactsNote(
              kind: ConversationArtifactsNoteKind.loading,
            );
          }
          if (shown == ConversationArtifactsStatus.failed) {
            return ConversationArtifactsNote(
              kind: ConversationArtifactsNoteKind.failed,
              onPressed: () => unawaited(art.retry()),
            );
          }
          if (index == art.cards.length) {
            return ConversationArtifactsNote(
              kind: ConversationArtifactsNoteKind.more,
              more: art.more,
              onPressed: () => unawaited(art.showMore()),
            );
          }
          final card = art.cards[index];
          final updated = card.updatedAt?.toIso8601String();
          return ConversationArtifactRow(
            key: ValueKey('conversation-artifact-${card.id}'),
            card: card,
            compact: compact,
            divider: index > 0,
            formattedDate: updated == null
                ? ''
                : (compact ? compactDate(updated) : formatCreatedAt(updated)),
            fullDate: updated == null ? null : formatFullDate?.call(updated),
            onOpen: () => onOpenArtifact?.call(card),
          );
        }

        Widget fileRow(int index, double width) {
          final file = store.files[index];
          bool allowed() => store.contains(file);
          void guarded(Future<void> Function(SourceChannelFileEntry) run) {
            if (allowed()) unawaited(run(file));
          }

          if (compact) {
            return ChannelFilesCompactRow(
              key: ValueKey('channel-file-${file.id}'),
              file: file,
              width: width,
              divider: filesAt + index > 0,
              formattedDate: compactDate(file.createdAt),
              fullDate: formatFullDate?.call(file.createdAt),
              thumbnail: thumbnailBuilder?.call(file, allowed),
              onPreview: () => guarded(onPreview),
              onDownload: () => guarded(onDownload),
              onOpenSource: () => guarded(onOpenSource),
            );
          }
          return SourceChannelFileRow(
            key: ValueKey('channel-file-${file.id}'),
            file: file,
            width: width,
            formattedDate: formatCreatedAt(file.createdAt),
            thumbnail: thumbnailBuilder?.call(file, allowed),
            onPreview: () => guarded(onPreview),
            onDownload: () => guarded(onDownload),
            onOpenSource: () => guarded(onOpenSource),
          );
        }

        final list = _pullable(
          context,
          NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event.depth == 0 &&
                  event.metrics.extentAfter < recipe.fetchRemainingExtent &&
                  store.nextCursor != null &&
                  store.error == null &&
                  !store.loading &&
                  !store.loadingMore) {
                unawaited(store.load(more: true));
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final baseInset = t.desktop
                    ? recipe.listInset
                    : const EdgeInsets.symmetric(
                        horizontal: RaftSpace.x4,
                        vertical: RaftSpace.x3,
                      );
                final padding = raftScrollPadding(
                  context,
                  compact ? EdgeInsets.zero : baseInset,
                );
                final width = constraints.deflate(padding).maxWidth;
                return ListView.separated(
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  itemCount:
                      artifactRows + store.files.length + (footer ? 1 : 0),
                  // Compact rows carry their own hairlines.
                  separatorBuilder: (_, _) =>
                      SizedBox(height: recipe.listGapFor(compact: compact)),
                  itemBuilder: (context, index) {
                    if (index < artifactRows) return artifactRow(index);
                    index -= artifactRows;
                    if (index == store.files.length) {
                      return Padding(
                        // Source closes the p-3 FilesList before its p-4 footer.
                        // Our single scrollable has already inserted listGap.
                        padding: EdgeInsets.fromLTRB(
                          RaftSpace.x4,
                          compact
                              ? RaftSpace.x4
                              : RaftSpace.x4 +
                                    recipe.listInset.bottom -
                                    recipe.listGap,
                          RaftSpace.x4,
                          RaftSpace.x4,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (store.error != null)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: recipe.listGap,
                                  ),
                                  child: Text(
                                    raftText(
                                      context,
                                      'Could not load more files.',
                                    ),
                                    style: t.scale(
                                      RaftTypeScale.callout,
                                      color: t.colors['danger'],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              store.loadingMore
                                  ? Text(
                                      raftText(context, 'Loading more files…'),
                                      style: RaftTypography.mono(t),
                                    )
                                  : RaftButton(
                                      label: raftText(context, 'Load more'),
                                      uiVariant: RaftButtonVariant.outline,
                                      uiSize: RaftButtonSize.sm,
                                      onPressed: () => store.load(more: true),
                                    ),
                            ],
                          ),
                        ),
                      );
                    }
                    return fileRow(index, width);
                  },
                );
              },
            ),
          ),
        );
        return compact
            ? list
            : ColoredBox(color: recipe.background, child: list);
      },
    );
  }
}

/// The mounted source row uses a plain, naturally sized button. A fixed-height
/// generic control clips wrapped metadata and changes the source content flow.
class ChannelFileOpen extends StatefulWidget {
  const ChannelFileOpen({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.minHeight = 56,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// The card row's thumbnail height; a compact row sets its own.
  final double minHeight;
  @override
  State<ChannelFileOpen> createState() => _ChannelFileOpenState();
}

class _ChannelFileOpenState extends State<ChannelFileOpen> {
  final node = FocusNode();
  bool highlight = false;
  @override
  void initState() {
    super.initState();
    node.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    node.removeListener(changed);
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    focusNode: node,
    mouseCursor: SystemMouseCursors.click,
    onShowFocusHighlight: (value) {
      if (mounted) setState(() => highlight = value);
    },
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onPressed();
          return null;
        },
      ),
      ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
        onInvoke: (_) {
          widget.onPressed();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      focusable: true,
      focused: node.hasFocus,
      label: widget.label,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => node.requestFocus(),
        onTap: widget.onPressed,
        child: CustomPaint(
          foregroundPainter: highlight
              ? _FileFocusOutline(RaftTokens.of(context).strong)
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class _FileFocusOutline extends CustomPainter {
  const _FileFocusOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    (Offset.zero & size).inflate(3),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  @override
  bool shouldRepaint(_FileFocusOutline oldDelegate) =>
      color != oldDelegate.color;
}

/// The row's "⋯" menu: Jump to original message and Download file (Web
/// ChannelFileOverflowMenu). The card row and the compact row share it.
class ChannelFileOverflowMenu extends StatelessWidget {
  const ChannelFileOverflowMenu({
    super.key,
    required this.file,
    required this.onOpenSource,
    required this.onDownload,
    this.compact = false,
  });
  final SourceChannelFileEntry file;
  final VoidCallback onOpenSource, onDownload;

  /// In a compact row the touch target hangs outside the row's line instead
  /// of making the row taller (Web: the button's negative margin).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = raftFormat(context, 'Actions for {filename}', {
      'filename': file.filename,
    });
    return RaftDropdownMenu(
      label: label,
      surfaceKey: ValueKey('channel-file-overflow-menu-${file.id}'),
      kind: RaftMenuKind.dropdownMenu,
      side: RaftDropdownSide.bottom,
      align: RaftDropdownAlign.end,
      sideOffset: 4,
      entries: [
        RaftMenuEntry(
          label: raftText(context, 'Jump to original message'),
          leading: const ChannelFileGlyph(
            SourceChannelFileGlyph.jump,
            size: 16,
          ),
          onPressed: onOpenSource,
        ),
        RaftMenuEntry(
          label: raftText(context, 'Download file'),
          leading: const RaftIcon(RaftGlyph.download, size: 16),
          onPressed: onDownload,
        ),
      ],
      triggerBuilder: (context, focus, onPressed) => RaftButton(
        key: ValueKey('channel-file-overflow-${file.id}'),
        uiSize: RaftButtonSize.iconSm,
        uiVariant: RaftButtonVariant.ghost,
        layoutTouchTarget: !compact,
        expandTouchTarget: compact,
        semanticContainer: false,
        focusNode: focus,
        semanticLabel: label,
        tooltip: label,
        onPressed: onPressed,
        iconBuilder: (size, color) => ChannelFileGlyph(
          SourceChannelFileGlyph.more,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

class SourceChannelFileRow extends StatefulWidget {
  const SourceChannelFileRow({
    super.key,
    required this.file,
    required this.formattedDate,
    required this.onPreview,
    required this.onOpenSource,
    required this.onDownload,
    this.thumbnail,
    this.width,
  });
  final SourceChannelFileEntry file;
  final String formattedDate;
  final VoidCallback onPreview, onOpenSource, onDownload;
  final Widget? thumbnail;
  final double? width;
  @override
  State<SourceChannelFileRow> createState() => _FileRowState();
}

class _FileRowState extends State<SourceChannelFileRow> {
  static const _badgeMinWidth = 28.0;
  static const _badgeMinHeight = 14.0;
  var hovered = false;
  Widget _overflowMenu(BuildContext context) => ChannelFileOverflowMenu(
    file: widget.file,
    onOpenSource: widget.onOpenSource,
    onDownload: widget.onDownload,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        recipe = SourceChannelFilesRecipe(RaftTokens.of(context));
    final attachment = AttachmentComponentRecipe(t);
    final extension = widget.file.filename.split('.').last;
    final badge = attachment.semantics.badgeBackground(extension);
    final controlRadius = t.size('radius.control', fallback: 8);
    final visual = Container(
      width: recipe.thumbnailSize,
      height: recipe.thumbnailSize,
      decoration: BoxDecoration(
        color: t.ui.fillMuted,
        borderRadius: BorderRadius.circular(controlRadius),
        border: Border.all(color: t.ui.lineHairline),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child:
                widget.thumbnail ??
                Center(child: ChannelFileGlyph(channelFileType(widget.file))),
          ),
          if (badge != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                // 28x14 is a minimum: a taller line box (Android Chinese
                // control profile, larger text) grows the tag instead of
                // clipping the extension.
                constraints: const BoxConstraints(
                  minWidth: _badgeMinWidth,
                  minHeight: _badgeMinHeight,
                ),
                decoration: BoxDecoration(
                  color: badge,
                  border: attachment.badgeBorder,
                  borderRadius: attachment.badgeRadius,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    extension.toUpperCase(),
                    style: attachment.badgeLabel(extension),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    Widget row(double width) => RaftCard.item(
      interactive: true,
      padding: recipe.rowInset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ChannelFileOpen(
              key: ValueKey('channel-file-preview-${widget.file.id}'),
              label: raftText(context, 'Preview file'),
              onPressed: widget.onPreview,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  visual,
                  SizedBox(width: recipe.bodyGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftCssText(
                          widget.file.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: recipe.filename,
                        ),
                        SizedBox(height: recipe.textGap),
                        Wrap(
                          spacing: RaftSpace.x2,
                          runSpacing: RaftSpace.x1,
                          children: [
                            RaftCssText(
                              sourceChannelFileSize(widget.file.sizeBytes),
                              style: recipe.metadata,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RaftIcon(
                                  RaftGlyph.clock3,
                                  size: 12,
                                  color: recipe.metadata.color,
                                ),
                                const SizedBox(width: RaftSpace.x1),
                                Flexible(
                                  child: RaftCssText(
                                    widget.formattedDate,
                                    style: recipe.metadata,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: recipe.bodyGap),
          if (recipe.collapsedActions(width, hovered: hovered))
            _overflowMenu(context)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RaftButton(
                  key: ValueKey('channel-file-jump-${widget.file.id}'),
                  uiSize: RaftButtonSize.iconSm,
                  uiVariant: RaftButtonVariant.ghost,
                  tooltip: raftText(context, 'Jump to original message'),
                  semanticLabel: raftText(context, 'Jump to original message'),
                  onPressed: widget.onOpenSource,
                  iconBuilder: (size, color) => ChannelFileGlyph(
                    SourceChannelFileGlyph.jump,
                    size: 14,
                    color: color,
                  ),
                ),
                SizedBox(width: recipe.actionGap),
                RaftButton(
                  key: ValueKey('channel-file-download-${widget.file.id}'),
                  uiSize: RaftButtonSize.iconSm,
                  uiVariant: RaftButtonVariant.ghost,
                  glyph: RaftGlyph.download,
                  glyphSize: 14,
                  tooltip: raftText(context, 'Download file'),
                  semanticLabel: raftText(context, 'Download file'),
                  onPressed: widget.onDownload,
                ),
              ],
            ),
        ],
      ),
    );
    final width = widget.width;
    return width == null
        ? LayoutBuilder(builder: (_, constraints) => row(constraints.maxWidth))
        : row(width);
  }
}

/// Shared lease provider is reused across virtualized mounts; never Image.memory
/// a borrowed encoded buffer, which would create a different decode cache key.
class SourceChannelFileThumbnail extends StatefulWidget {
  const SourceChannelFileThumbnail({
    super.key,
    required this.file,
    required this.authorized,
    this.acquireImage,
    this.peekImage,
  });
  final SourceChannelFileEntry file;
  final bool Function() authorized;
  final SourceChannelImageAcquire? acquireImage;
  final SourceChannelImagePeek? peekImage;
  @override
  State<SourceChannelFileThumbnail> createState() => _FileThumbnailState();
}

class _FileThumbnailState extends State<SourceChannelFileThumbnail> {
  SourceChannelImageLease? lease;
  Uint8List? inlineSvg;
  var ticket = 0;
  bool get current => mounted && widget.authorized();
  @override
  void initState() {
    super.initState();
    if (!adoptReady()) unawaited(load());
  }

  /// A thumbnail the host already holds decoded is in the first frame.
  bool adoptReady() {
    final peek = widget.peekImage;
    if (peek == null) return false;
    final type = widget.file.mimeType.toLowerCase().split(';').first.trim();
    if (!type.startsWith('image/') || type == 'image/svg+xml') return false;
    final attempt = ++ticket;
    final ready = peek(
      widget.file,
      () => current && ticket == attempt,
      SourceChannelImageRendition.thumbnail,
    );
    if (ready == null) return false;
    lease = ready;
    return true;
  }

  @override
  void didUpdateWidget(SourceChannelFileThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.file, widget.file) ||
        oldWidget.acquireImage != widget.acquireImage) {
      ticket++;
      final old = lease;
      lease = null;
      inlineSvg = null;
      if (old != null) unawaited(old.release());
      if (!adoptReady()) unawaited(load());
    }
  }

  Future<void> load() async {
    final type = widget.file.mimeType.toLowerCase().split(';').first.trim();
    if (!type.startsWith('image/') ||
        (type == 'image/svg+xml' &&
            widget.file.metadata['thumbnailUrl'] == null)) {
      return;
    }
    final attempt = ++ticket;
    try {
      // Source's <img> accepts inline SVG thumbnails as well as raster URLs.
      // Render the same authorized metadata; it never enters the HTTP loader
      // or the controller's shared raster leases.
      final thumbnail = widget.file.metadata['thumbnailUrl'];
      // Browsers also accept the common `;utf8` SVG data-URL shorthand.
      // Uri.data requires the formal charset parameter; only normalize this
      // encoding spelling for decoding, without changing stored metadata.
      final uri = thumbnail is String
          ? Uri.tryParse(
              thumbnail.replaceFirst(
                RegExp(r'^data:image/svg\+xml;utf8,', caseSensitive: false),
                'data:image/svg+xml;charset=utf-8,',
              ),
            )
          : null;
      if (current &&
          uri?.scheme == 'data' &&
          uri!.data?.mimeType == 'image/svg+xml') {
        inlineSvg = uri.data!.contentAsBytes();
        return;
      }
      final acquire = widget.acquireImage;
      if (acquire == null) return;
      final next = await acquire(
        widget.file,
        () => current && ticket == attempt,
        SourceChannelImageRendition.thumbnail,
      );
      if (!current || ticket != attempt) {
        if (next != null) await next.release();
        return;
      }
      setState(() => lease = next);
    } catch (_) {
      /* Real icon fallback; never log capability/attachment payload. */
    }
  }

  @override
  void dispose() {
    ticket++;
    final old = lease;
    lease = null;
    if (old != null) unawaited(old.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLease = lease;
    if (!current || (currentLease == null && inlineSvg == null)) {
      return Center(child: ChannelFileGlyph(channelFileType(widget.file)));
    }
    final width = widget.file.metadata['width'],
        height = widget.file.metadata['height'];
    final ratio = width is num && height is num && width > 0 && height > 0
        ? width / height
        : null;
    final fit = ratio != null && (ratio >= 2.2 || ratio <= .55)
        ? BoxFit.contain
        : BoxFit.cover;
    if (inlineSvg != null) {
      return SvgPicture.memory(
        inlineSvg!,
        fit: fit,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            Center(child: ChannelFileGlyph(channelFileType(widget.file))),
      );
    }
    // ignore: raft_lints/avoid_raw_image_decode -- The provider comes from an AttachmentImageRepository lease: already decoded at the target size and shared with the message bubble.
    return Image(
      image: currentLease!.provider,
      fit: fit,
      errorBuilder: (_, _, _) =>
          Center(child: ChannelFileGlyph(channelFileType(widget.file))),
    );
  }
}
