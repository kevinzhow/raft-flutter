import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'selection_toolbar_recipe.dart';
import 'theme.dart';

/// Source SelectModeToolbar: measured compact row; less frequent actions in
/// a top/end More menu. Callbacks and selection authority belong to the app.
class RaftSelectionToolbar extends StatefulWidget {
  const RaftSelectionToolbar({
    super.key,
    required this.selected,
    required this.total,
    required this.onExit,
    this.onSelectAll,
    this.onCopyMarkdown,
    this.onCopyLinks,
    this.onPreview,
    this.onForward,
    this.forwardDisabledReason,
    this.busy = false,
    this.copied = false,
    this.error,
    this.limit = 30,
  });
  final int selected, total, limit;
  final VoidCallback onExit;
  final VoidCallback? onSelectAll,
      onCopyMarkdown,
      onCopyLinks,
      onPreview,
      onForward;
  final bool busy, copied;
  final String? error, forwardDisabledReason;
  @override
  State<RaftSelectionToolbar> createState() => _RaftSelectionToolbarState();
}

class _RaftSelectionToolbarState extends State<RaftSelectionToolbar> {
  int compactLevel = 0;
  double lastActionsWidth = 0;
  final actionsKey = GlobalKey();
  bool measureQueued = false;
  double measurementWidth = 0, measurementGap = 0;
  int measurementMax = 0;

  void measureActions(double width, double gap, int maximum) {
    measurementWidth = width;
    measurementGap = gap;
    measurementMax = maximum;
    if (measureQueued) return;
    measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measureQueued = false;
      if (!mounted) return;
      final row = actionsKey.currentContext?.findRenderObject();
      if (row is! RenderWrap || !row.hasSize) return;
      double requiredWidth = 0;
      var count = 0;
      double? firstY;
      var wrapped = false;
      row.visitChildren((child) {
        if (child is RenderBox && child.hasSize) {
          requiredWidth += child.size.width;
          final data = child.parentData;
          if (data is WrapParentData) {
            firstY ??= data.offset.dy;
            wrapped = wrapped || (data.offset.dy - firstY!).abs() > .5;
          }
          count++;
        }
      });
      if (count > 1) requiredWidth += (count - 1) * measurementGap;
      // Source sums actual DOM offsetWidth rather than predicting text fonts.
      // Use actual shared controls after their inherited face/box is laid out.
      // CSS offsetWidth/clientWidth are integral. RenderWrap can start a
      // second run for a subpixel excess inside that 1px measurement tolerance.
      // A real second run is overflow too; compact without any viewport pin.
      if ((requiredWidth > measurementWidth + 1 || wrapped) &&
          compactLevel < measurementMax) {
        setState(() => compactLevel++);
      }
    });
  }

  Widget action(
    BuildContext context,
    String label,
    RaftGlyph glyph,
    VoidCallback? pressed, {
    bool compact = false,
    bool accent = false,
    FocusNode? focusNode,
    String? tooltip,
    String? semanticLabel,
  }) => RaftButton(
    label: compact ? '' : label,
    glyph: glyph,
    tooltip: tooltip ?? raftText(context, label),
    onPressed: pressed,
    // SelectModeToolbar renders bare lucide icons (no `data-icon`), so the
    // size's plain px-2.5 applies, not `has-data-[icon=inline-start]:pl-2`.
    iconInlineStart: false,
    focusNode: focusNode,
    semanticLabel: semanticLabel ?? raftText(context, label),
    tone: accent
        ? RaftButtonRecipeVariant.accent
        : RaftButtonRecipeVariant.outline,
    size: compact ? RaftButtonRecipeSize.iconSm : RaftButtonRecipeSize.sm,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSelectionToolbarRecipe(
      t,
      viewportWidth: MediaQuery.sizeOf(context).width,
    );
    final count = raftFormat(context, '{count} selected', {
      'count': widget.selected,
    });
    final canAct = widget.selected > 0 && !widget.busy;
    final copyLabel = widget.copied ? 'Copied' : 'Copy link';
    final forward = widget.onForward != null;
    final copy = widget.onCopyLinks != null;
    final all = widget.onSelectAll != null;
    return Material(
      color: recipe.background,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: recipe.border, width: recipe.borderWidth),
          ),
        ),
        padding: recipe.inset,
        // These are source-sized sm/icon-sm controls, including coarse input.
        // Platform touch expansion must not replace this authored row's boxes.
        child: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(count, style: recipe.count),
                  SizedBox(width: recipe.gap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final maxLevel =
                            1 +
                            (copy ? 1 : 0) +
                            (forward ? 1 : 0) +
                            (all ? 1 : 0);
                        if (bounds.maxWidth > lastActionsWidth + 8)
                          compactLevel = 0;
                        lastActionsWidth = bounds.maxWidth;
                        compactLevel = compactLevel.clamp(0, maxLevel);
                        bool isCopy(int n) => n >= 1;
                        bool isForward(int n) => n >= 1 + (copy ? 1 : 0);
                        bool isCancel(int n) =>
                            n >= 1 + (copy ? 1 : 0) + (forward ? 1 : 0);
                        bool isAll(int n) => n >= maxLevel;
                        measureActions(bounds.maxWidth, recipe.gap, maxLevel);
                        return Wrap(
                          key: actionsKey,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: recipe.gap,
                          runSpacing: recipe.gap,
                          children: [
                            if (all)
                              action(
                                context,
                                'Select All',
                                RaftGlyph.listChecks,
                                widget.busy ? null : widget.onSelectAll,
                                compact: isAll(compactLevel),
                              ),
                            action(
                              context,
                              'Cancel',
                              RaftGlyph.x,
                              widget.onExit,
                              compact: isCancel(compactLevel),
                            ),
                            if (forward)
                              action(
                                context,
                                'Forward',
                                RaftGlyph.send,
                                canAct && widget.forwardDisabledReason == null
                                    ? widget.onForward
                                    : null,
                                compact: isForward(compactLevel),
                                accent: true,
                                tooltip: widget.forwardDisabledReason,
                              ),
                            if (copy)
                              action(
                                context,
                                copyLabel,
                                widget.copied
                                    ? RaftGlyph.check
                                    : RaftGlyph.copy,
                                widget.selected == 0
                                    ? null
                                    : widget.onCopyLinks,
                                compact: isCopy(compactLevel),
                                tooltip: raftText(context, 'Copy link'),
                                semanticLabel: raftText(context, 'Copy link'),
                              ),
                            RaftDropdownMenu(
                              label: raftText(
                                context,
                                'More selected message actions',
                              ),
                              enabled: widget.selected > 0,
                              side: RaftDropdownSide.top,
                              align: RaftDropdownAlign.end,
                              sideOffset: 8,
                              triggerBuilder: (context, node, pressed) =>
                                  action(
                                    context,
                                    'More selected message actions',
                                    RaftGlyph.ellipsis,
                                    pressed,
                                    compact: true,
                                    focusNode: node,
                                    tooltip: raftText(context, 'More'),
                                  ),
                              entries: [
                                RaftMenuEntry(
                                  label: raftText(
                                    context,
                                    widget.busy
                                        ? 'Rendering...'
                                        : 'Generate image',
                                  ),
                                  leading: widget.busy
                                      ? Semantics(
                                          label: raftText(context, 'Loading'),
                                          child: const RaftSpinner(),
                                        )
                                      : const RaftIcon(
                                          RaftGlyph.image,
                                          size: 14,
                                        ),
                                  onPressed: canAct ? widget.onPreview : null,
                                ),
                                RaftMenuEntry(
                                  label: raftText(
                                    context,
                                    widget.copied ? 'Copied MD' : 'Copy MD',
                                  ),
                                  leading: RaftIcon(
                                    widget.copied
                                        ? RaftGlyph.check
                                        : RaftGlyph.copy,
                                    size: 14,
                                  ),
                                  onPressed: widget.selected == 0
                                      ? null
                                      : widget.onCopyMarkdown,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (widget.error != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.error!,
                      style: TextStyle(color: t.colors['danger-strong']),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-content clone uses the conversation's current theme and layout width.
/// API state, platform export and rasterization belong to the application.
class RaftMessageExportSurface extends StatelessWidget {
  const RaftMessageExportSurface({
    super.key,
    required this.width,
    required this.messages,
  });
  final double width;
  final List<Widget> messages;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: RaftTokens.of(context).canvas,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: messages,
      ),
    ),
  );
}

/// Actions become available only after the complete image exists for review.
class RaftImageReview extends StatelessWidget {
  const RaftImageReview({
    super.key,
    required this.preview,
    required this.onClose,
    this.onSave,
    this.onShare,
    this.busy = false,
    this.error,
  });
  final Widget preview;
  final VoidCallback onClose;
  final VoidCallback? onSave, onShare;
  final bool busy;
  final String? error;
  @override
  Widget build(BuildContext context) => Material(
    color: RaftTokens.of(context).panel,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  raftText(context, 'Share selected messages'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: raftText(context, 'Close preview'),
                onPressed: busy ? null : onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: preview,
          ),
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error!),
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RaftButton(
                label: 'Cancel',
                secondary: true,
                onPressed: busy ? null : onClose,
              ),
              if (onSave != null)
                RaftButton(
                  label: 'Save image',
                  icon: Icons.download_outlined,
                  busy: busy,
                  onPressed: onSave,
                ),
              if (onShare != null)
                RaftButton(
                  label: 'Share image',
                  icon: Icons.share_outlined,
                  secondary: true,
                  onPressed: busy ? null : onShare,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
