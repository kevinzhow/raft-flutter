import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/source_channel_files_store.dart';
import '../data/workspace_controller.dart';
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
    this.onOpenSource,
    this.thumbnailBuilder,
    this.acquireImage,
    this.peekImage,
  });
  final WorkspaceController controller;
  final String channelId;
  // Actual useTimeFormatter.formatShortDateTime: preferred IANA zone, locale,
  // short month/day + two-digit hour/minute + chosen12/24h; not host-local UTC.
  final String Function(String instant) formatCreatedAt;
  final Future<void> Function(SourceChannelFileEntry)? onOpenSource;
  final ChannelFileThumbnailBuilder? thumbnailBuilder;
  final SourceChannelImageAcquire? acquireImage;
  final SourceChannelImagePeek? peekImage;
  @override
  State<SourceChannelFilesView> createState() => _SourceChannelFilesState();
}

class _SourceChannelFilesState extends State<SourceChannelFilesView> {
  late SourceChannelFilesStore store;
  late SourceChannelFilesActions actions;
  StreamSubscription<RaftEvent>? session;
  bool tabActive = true;
  bool dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active && (!dependenciesReady || !tabActive)) unawaited(store.load());
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
    if (dependenciesReady && tabActive) unawaited(store.load());
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
    if (!store.contains(file)) return;
    if (widget.onOpenSource != null) {
      await widget.onOpenSource!(file);
      return;
    }
    // Existing mounted controller resolves canonicalTarget and actual parent
    // context, then opens the correct thread/DM surface with focused reply.
    await widget.controller.jumpToMessage(widget.channelId, file.messageId);
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
  final RaftTokens tokens;
  EdgeInsets get listInset => const EdgeInsets.all(12);
  double get listGap => 8;
  EdgeInsets get rowInset =>
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  double get bodyGap => 12;
  double get thumbnailSize => 56;
  double get actionBreakpoint => 560;
  double get actionSize => 28;
  double get actionGap => 6;
  bool collapsedActions(double outerWidth, {bool hovered = false}) =>
      outerWidth - rowInset.horizontal - 2 * border(hovered).width <=
      actionBreakpoint;
  double get fetchRemainingExtent => 320;
  double get textGap => 4;
  Color get background => tokens.dark ? Colors.transparent : tokens.panel;
  Color get rowBackground => tokens.colors['layer-card']!;
  BorderRadius get radius => BorderRadius.circular(8);
  BorderSide border(bool hovered) => BorderSide(
    color: tokens.dark
        ? Colors.transparent
        : tokens.colors[hovered ? 'line-strong' : 'line-muted']!,
    width: .5,
  );
  List<BoxShadow> shadows(bool hovered) {
    if (tokens.dark) {
      return hovered
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: .45),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .15),
                offset: const Offset(0, 6),
                blurRadius: 6,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .25),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: .4),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ];
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

  TextStyle get filename => RaftTypography.body(
    tokens,
    size: 14,
    line: 20,
    weight: FontWeight.w700,
    color: tokens.strong,
  );
  TextStyle get metadata =>
      RaftTypography.mono(tokens, size: 12, line: 16, color: tokens.muted);
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
  });
  final SourceChannelFilesStore store;
  final String Function(String) formatCreatedAt;
  final Future<void> Function(SourceChannelFileEntry) onPreview,
      onDownload,
      onOpenSource;
  final ChannelFileThumbnailBuilder? thumbnailBuilder;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        recipe = SourceChannelFilesRecipe(RaftTokens.of(context));
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.authorized) return const SizedBox.shrink();
        if (store.initialLoading) {
          return Center(
            child: Text(
              raftText(context, 'Loading files…'),
              style: RaftTypography.mono(t, size: 14, line: 20),
            ),
          );
        }
        if (store.error != null && store.files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  raftText(context, 'Could not load files.'),
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    weight: FontWeight.w700,
                    color: t.colors['danger'],
                  ),
                ),
                // Explicit native recovery action; source error branch has no retry.
                RaftTextButton(
                  label: raftText(context, 'Retry'),
                  onPressed: () => store.load(),
                ),
              ],
            ),
          );
        }
        if (store.files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RaftIcon(RaftGlyph.paperclip, size: 36),
                Text(
                  raftText(context, 'No files yet'),
                  style: RaftTypography.heading(t, size: 18, line: 24),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    raftText(
                      context,
                      'Attach files in Chat, or drag files into the message composer. They will appear here after the message is sent.',
                    ),
                    style: RaftTypography.body(t, size: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }
        return ColoredBox(
          color: recipe.background,
          child: NotificationListener<ScrollNotification>(
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
            child: ListView.separated(
              primary: false,
              padding: raftScrollPadding(context, recipe.listInset),
              itemCount:
                  store.files.length +
                  (store.nextCursor != null || store.loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => SizedBox(height: recipe.listGap),
              itemBuilder: (context, index) {
                if (index == store.files.length) {
                  return Padding(
                    // Source closes the p-3 FilesList before its p-4 footer.
                    // Our single scrollable has already inserted listGap.
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16 + recipe.listInset.bottom - recipe.listGap,
                      16,
                      16,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (store.error != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: recipe.listGap),
                              child: Text(
                                raftText(context, 'Could not load more files.'),
                                style: RaftTypography.body(
                                  t,
                                  size: 14,
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
                                  label: raftText(context, 'Load More'),
                                  variant: RaftControlVariant.outline,
                                  size: RaftButtonRecipeSize.sm,
                                  onPressed: () => store.load(more: true),
                                ),
                        ],
                      ),
                    ),
                  );
                }
                final file = store.files[index];
                bool allowed() => store.contains(file);
                return SourceChannelFileRow(
                  key: ValueKey('channel-file-${file.id}'),
                  file: file,
                  formattedDate: formatCreatedAt(file.createdAt),
                  thumbnail: thumbnailBuilder?.call(file, allowed),
                  onPreview: () {
                    if (allowed()) unawaited(onPreview(file));
                  },
                  onDownload: () {
                    if (allowed()) unawaited(onDownload(file));
                  },
                  onOpenSource: () {
                    if (allowed()) unawaited(onOpenSource(file));
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The mounted source row uses a plain, naturally sized button. A fixed-height
/// generic control clips wrapped metadata and changes the source content flow.
class _FileOpen extends StatefulWidget {
  const _FileOpen({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget child;
  @override
  State<_FileOpen> createState() => _FileOpenState();
}

class _FileOpenState extends State<_FileOpen> {
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
            constraints: const BoxConstraints(minHeight: 56),
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

class SourceChannelFileRow extends StatefulWidget {
  const SourceChannelFileRow({
    super.key,
    required this.file,
    required this.formattedDate,
    required this.onPreview,
    required this.onOpenSource,
    required this.onDownload,
    this.thumbnail,
  });
  final SourceChannelFileEntry file;
  final String formattedDate;
  final VoidCallback onPreview, onOpenSource, onDownload;
  final Widget? thumbnail;
  @override
  State<SourceChannelFileRow> createState() => _FileRowState();
}

class _FileRowState extends State<SourceChannelFileRow> {
  var hovered = false;
  final menu = MenuController();
  Widget _menuItem(
    BuildContext context,
    VoidCallback action,
    Widget icon,
    String label,
  ) {
    final recipe = RaftMenuRecipe(
      RaftTokens.of(context),
      viewportHeight: MediaQuery.sizeOf(context).height,
    );
    final height = RaftDensityScope.of(context) == RaftDensity.touch
        ? recipe.rowTargetHeight
        : recipe.rowVisualHeight;
    return MenuItemButton(
      onPressed: action,
      leadingIcon: icon,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(recipe.rowInset),
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
        textStyle: WidgetStatePropertyAll(recipe.label),
        foregroundColor: WidgetStatePropertyAll(recipe.foreground),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) &&
                      RaftHoverScope.of(context) ||
                  states.contains(WidgetState.focused)
              ? recipe.highlightedBackground
              : Colors.transparent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
      child: Text(raftText(context, label)),
    );
  }

  Widget _overflowMenu(BuildContext context, SourceChannelFilesRecipe recipe) {
    if (RaftTokens.of(context).isRaftLook) {
      final label = 'Actions for ${widget.file.filename}';
      return RaftDropdownMenu(
        label: label,
        surfaceKey: ValueKey('channel-file-overflow-menu-${widget.file.id}'),
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
            onPressed: widget.onOpenSource,
          ),
          RaftMenuEntry(
            label: raftText(context, 'Download file'),
            leading: const RaftIcon(RaftGlyph.download, size: 16),
            onPressed: widget.onDownload,
          ),
        ],
        triggerBuilder: (context, focus, onPressed) => RaftButton(
          key: ValueKey('channel-file-overflow-${widget.file.id}'),
          uiSize: RaftButtonSize.iconSm,
          uiVariant: RaftButtonVariant.ghost,
          layoutTouchTarget: true,
          expandTouchTarget: false,
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
    return MenuAnchor(
      controller: menu,
      alignmentOffset: const Offset(0, 4),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        RaftMenuPanel(
          onDismiss: menu.close,
          children: [
            _menuItem(
              context,
              () {
                menu.close();
                widget.onOpenSource();
              },
              const ChannelFileGlyph(SourceChannelFileGlyph.jump, size: 14),
              'Jump to Original Message',
            ),
            _menuItem(
              context,
              () {
                menu.close();
                widget.onDownload();
              },
              const RaftIcon(RaftGlyph.download, size: 14),
              'Download File',
            ),
          ],
        ),
      ],
      builder: (context, controller, _) => RaftControl(
        key: ValueKey('channel-file-overflow-${widget.file.id}'),
        visualHeight: recipe.actionSize,
        semanticLabel: 'Actions for ${widget.file.filename}',
        tooltip: 'Actions for ${widget.file.filename}',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: const ChannelFileGlyph(SourceChannelFileGlyph.more, size: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        recipe = SourceChannelFilesRecipe(RaftTokens.of(context));
    final attachment = AttachmentComponentRecipe(t);
    final extension = widget.file.filename.split('.').last;
    final badge = attachment.semantics.badgeBackground(extension);
    final visual = Container(
      width: recipe.thumbnailSize,
      height: recipe.thumbnailSize,
      decoration: BoxDecoration(
        color: t.colors['layer-card'],
        border: Border.all(color: t.colors['line-muted']!, width: 1),
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
                constraints: const BoxConstraints(minWidth: 28, minHeight: 14),
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
    return LayoutBuilder(
      builder: (context, constraints) => RaftHoverRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          decoration: RaftCssBoxDecoration(
            color: recipe.rowBackground,
            borderRadius: recipe.radius,
            border: Border.fromBorderSide(recipe.border(hovered)),
            boxShadow: recipe.shadows(hovered),
          ),
          padding: recipe.rowInset,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _FileOpen(
                  key: ValueKey('channel-file-preview-${widget.file.id}'),
                  label: raftText(context, 'Preview File'),
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
                            Text(
                              widget.file.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: recipe.filename,
                            ),
                            SizedBox(height: recipe.textGap),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
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
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
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
              if (recipe.collapsedActions(
                constraints.maxWidth,
                hovered: hovered,
              ))
                _overflowMenu(context, recipe)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftControl(
                      key: ValueKey('channel-file-jump-${widget.file.id}'),
                      visualHeight: recipe.actionSize,
                      tooltip: raftText(context, 'Jump to Original Message'),
                      variant: RaftControlVariant.ghost,
                      onPressed: widget.onOpenSource,
                      child: const ChannelFileGlyph(
                        SourceChannelFileGlyph.jump,
                        size: 14,
                      ),
                    ),
                    SizedBox(width: recipe.actionGap),
                    RaftIconButton(
                      key: ValueKey('channel-file-download-${widget.file.id}'),
                      visualSize: recipe.actionSize,
                      glyphSize: 14,
                      glyph: RaftGlyph.download,
                      tooltip: raftText(context, 'Download File'),
                      variant: RaftControlVariant.ghost,
                      onPressed: widget.onDownload,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
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
