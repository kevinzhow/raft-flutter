import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'attachment_lightbox.dart';
import 'design_primitives.dart' show RaftLightboxRecipe, RaftSpinner;
import 'dialog_card.dart' show RaftShadowSet;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftPanelHeaderBar;
import 'shortcut_platform.dart';
import 'system_inset.dart';
import 'theme.dart';

/// What the comments panel needs to act as the mobile bottom sheet header
/// (Web `AttachmentCommentsPanel` `sheetControls` / `collapsedBody`).
@immutable
class RaftCommentsSheetControls {
  const RaftCommentsSheetControls({
    required this.expanded,
    required this.onToggle,
  });
  final bool expanded;
  final VoidCallback onToggle;
}

/// Web `AttachmentPreviewShell` (document / HTML / video / audio previews):
/// `bg-black/75` portal root, the absolute `h-14` header (type badge, name,
/// comments toggle, copy, download, close), the body below it and the
/// comments panel as a `w-80` aside from `sm` up or a 2-state bottom sheet
/// below. [canvas] is the `browser-find` layout (text, csv, xlsx, markdown):
/// the pane sits on `bg-layer-canvas-muted` (brutal cream) instead of the
/// panel surface.
class RaftAttachmentPreviewShell extends StatefulWidget {
  const RaftAttachmentPreviewShell({
    super.key,
    required this.filename,
    required this.onClose,
    required this.child,
    this.onDownload,
    this.copyText,
    this.commentsBuilder,
    this.canvas = false,
    this.dark = false,
    this.commentsOpenInitially = false,
    this.page = false,
  });
  final String filename;
  final VoidCallback onClose;
  final VoidCallback? onDownload;
  final Widget child;

  /// The pane's text; when set the header offers the copy action.
  final String? copyText;

  /// Builds the comments panel; null when the preview has no comments.
  final Widget Function(BuildContext context, RaftCommentsSheetControls? sheet)?
  commentsBuilder;
  final bool canvas;

  /// Web `VideoPreviewBody`: the stage is solid black (`bg-black`).
  final bool dark;
  final bool commentsOpenInitially;

  /// Mobile page route: a plain Material page with the shared page header
  /// instead of a fullscreen dialog.
  final bool page;
  @override
  State<RaftAttachmentPreviewShell> createState() =>
      _RaftAttachmentPreviewShellState();
}

class _RaftAttachmentPreviewShellState
    extends State<RaftAttachmentPreviewShell> {
  late bool open = widget.commentsOpenInitially;
  // Sticky after the first open: the panel keeps its content (and fetched
  // comments) across collapse and reopen.
  late bool mounted_ = open;
  bool copied = false;

  void setOpen(bool value) => setState(() {
    open = value;
    if (value) mounted_ = true;
  });

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyText!));
    if (!mounted) return;
    setState(() => copied = true);
    // CopyableCodeRoot useCopyToClipboard({timeout: 1400}).
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= raftLightboxSmBreakpoint;
    final comments = widget.commentsBuilder;
    final bodyColor = widget.dark
        ? Colors.black
        : widget.canvas
        ? (t.brutal
              ? t.components.brutalCream
              : t.colors['layer-canvas-muted']!)
        : (t.brutal ? Colors.white : t.panel);
    final actions = [
      if (comments != null)
        RaftLightboxIconAction(
          key: const ValueKey('attachment-preview-mode'),
          glyph: RaftGlyph.messageSquareMore,
          label: 'Comment',
          active: open,
          onPressed: () => setOpen(!open),
        ),
      if (widget.copyText != null)
        RaftLightboxIconAction(
          key: const ValueKey('attachment-preview-copy'),
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          label: 'Copy',
          onPressed: copy,
        ),
      RaftLightboxIconAction(
        key: const ValueKey('attachment-preview-download'),
        glyph: RaftGlyph.download,
        label: 'Download',
        onPressed: widget.onDownload,
      ),
    ];
    final pageRecipe = RaftLightboxRecipe(t);
    final Widget header = widget.page
        // Native page: no Web counterpart, so it wears the same Web
        // PanelHeader (boxed Back, file badge, title, actions) as every phone
        // page; the file badge is the identity icon.
        ? RaftPanelHeaderBar(
            title: widget.filename,
            iconSlot: RaftFileTypeBadge(filename: widget.filename),
            iconAlwaysVisible: true,
            onBack: widget.onClose,
            backTooltip: 'Close preview',
            actions: actions,
          )
        : RaftLightboxHeader(
            title: widget.filename,
            leading: RaftFileTypeBadge(filename: widget.filename),
            borderWidth: 1,
            onClose: widget.onClose,
            actions: actions,
          );
    final rule = t.brutal ? 2.0 : 1.0;
    final inset = raftBottomInset(context);
    // Collapsed, the sheet is exactly its header row (`py-2` around the 28px
    // expand button or the scaled 12/16 title) plus the system inset: a fixed
    // 40 left the header's bottom padding, and at larger text its title,
    // inside the gesture / navigation bar. [rule] is the sheet's own top
    // border.
    final titleLine = 16 * MediaQuery.textScalerOf(context).scale(12) / 12;
    final collapsedHeader = math.max(40.0, 16 + math.max(28.0, titleLine));
    final collapsedBar = collapsedHeader + rule + inset;
    final bottomSheet = comments != null && !wide;
    // The body background runs under the system bar and the comments bar.
    // The content itself ends above the collapsed bar (or, with no bar, above
    // the system bar), so its last line and the card's border can scroll
    // clear of it. The open sheet is an overlay: the body does not move.
    Widget body = ColoredBox(
      color: bodyColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSheet ? collapsedBar : inset),
        child: widget.child,
      ),
    );
    if (comments != null && wide) {
      body = Row(
        children: [
          Expanded(child: body),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: open ? raftLightboxAsideWidth : 0,
            child: !mounted_
                ? null
                : open
                ? RaftLightboxAside(
                    borderWidth: 1,
                    child: comments(context, null),
                  )
                : Offstage(
                    child: RaftLightboxAside(
                      borderWidth: 1,
                      child: comments(context, null),
                    ),
                  ),
          ),
        ],
      );
    }
    Widget? sheet;
    if (bottomSheet) {
      // The sheet's own background reaches the screen bottom; collapsed it
      // grows by the system inset, open the composer pads itself.
      final height = open ? size.height * .45 : collapsedBar;
      sheet = Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: RaftNavigationBarStyle(
          background: t.brutal ? Colors.white : t.panel,
          child: AnimatedContainer(
            key: const ValueKey('attachment-comments-sheet'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: height,
            decoration: BoxDecoration(
              color: t.brutal ? Colors.white : t.panel,
              border: Border(
                top: BorderSide(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: rule,
                ),
              ),
            ),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: size.height * .45,
                child: SizedBox(
                  height: size.height * .45,
                  child: comments(
                    context,
                    RaftCommentsSheetControls(
                      expanded: open,
                      onToggle: () => setOpen(!open),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        SingleActivator(
          LogicalKeyboardKey.keyW,
          control: !usesCommandShortcuts(),
          meta: usesCommandShortcuts(),
        ): widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: raftLightboxHeaderRow,
                bottom: 0,
                child: body,
              ),
              Positioned(left: 0, right: 0, top: 0, child: header),
              ?sheet,
            ],
          ),
        ),
      ),
    );
    return widget.page
        ? Material(color: pageRecipe.backdrop, child: content)
        : Dialog.fullscreen(
            backgroundColor: raftLightboxBackdrop,
            child: content,
          );
  }
}

/// Web `HtmlPreviewBody` before the sandboxed frame reports its link
/// inventory: the white frame under `bg-layer-panel/75` (brutal `bg-white/75`)
/// and the centred "Preparing interactive preview…" chip.
class RaftPreviewPreparing extends StatelessWidget {
  const RaftPreviewPreparing({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final panel = t.brutal ? Colors.white : t.panel;
    final rule = t.brutal ? 2.0 : 1.0;
    return ColoredBox(
      color: Colors.white,
      child: ColoredBox(
        color: panel.withValues(alpha: panel.a * .75),
        child: Center(
          child: DefaultTextHeightBehavior(
            textHeightBehavior: raftCssTextHeightBehavior,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: panel,
                border: Border.all(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: rule,
                ),
                boxShadow: t.brutal
                    ? RaftShadowSet.brutalSm
                    : t.themeShadows.sm.outer,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: raftText(context, 'Loading'),
                    child: const RaftSpinner(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    raftText(context, 'Preparing interactive preview…'),
                    style: TextStyle(
                      fontFamily: t.headingFont,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w700,
                      color: t.brutal ? Colors.black : t.strong,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
