import 'raft/button.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'selection_toolbar_recipe.dart';
import 'system_inset.dart';
import 'separator.dart';
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;

/// Applies selection paint to the message that owns the toggle gesture.
Widget raftSelectableMessage(
  BuildContext context, {
  required bool selected,
  required VoidCallback? onTap,
  required Widget child,
}) => Semantics(
  selected: selected,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AbsorbPointer(
      child: selected
          ? ColoredBox(
              color: RaftTokens.of(context).colors['info-soft']!,
              child: child,
            )
          : child,
    ),
  ),
);

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
    tone: RaftButtonRecipeVariant.ghost,
    size: compact ? RaftButtonRecipeSize.iconMd : RaftButtonRecipeSize.md,
    physicalHeight: 28,
    visualWidth: compact ? 28 : null,
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSelectionToolbarRecipe(t);
    final count = raftFormat(context, '{count} selected', {
      'count': widget.selected,
    });
    final canAct = widget.selected > 0 && !widget.busy;
    final copyLabel = widget.copied ? 'Copied' : 'Copy link';
    final forward = widget.onForward != null;
    final copy = widget.onCopyLinks != null;
    final all = widget.onSelectAll != null;
    return RaftNavigationBarStyle(
      background: t.canvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + raftBottomInset(context)),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: Material(
            color: recipe.background,
            borderRadius: recipe.decoration.borderRadius as BorderRadius?,
            child: Container(
              key: const ValueKey('message-selection-toolbar-pill'),
              decoration: recipe.decoration,
              padding: recipe.inset.subtract(recipe.decoration.padding),
              // The authored button boxes retain their size on touch.
              child: RaftDensityScope(
                density: RaftDensity.desktop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          container: true,
                          liveRegion: true,
                          child: Text(count, style: recipe.count),
                        ),
                        SizedBox(width: recipe.gap),
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              final maxLevel =
                                  (copy ? 1 : 0) +
                                  (forward ? 1 : 0) +
                                  (all ? 1 : 0);
                              if (bounds.maxWidth > lastActionsWidth + 8) {
                                compactLevel = 0;
                              }
                              lastActionsWidth = bounds.maxWidth;
                              compactLevel = compactLevel.clamp(0, maxLevel);
                              bool isCopy(int n) => n >= 1;
                              bool isForward(int n) => n >= 1 + (copy ? 1 : 0);
                              bool isAll(int n) => n >= maxLevel;
                              measureActions(
                                bounds.maxWidth,
                                recipe.actionGap,
                                maxLevel,
                              );
                              return Wrap(
                                key: actionsKey,
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: recipe.actionGap,
                                runSpacing: recipe.actionGap,
                                children: [
                                  if (all)
                                    action(
                                      context,
                                      'Select all',
                                      RaftGlyph.listChecks,
                                      widget.busy ? null : widget.onSelectAll,
                                      compact: isAll(compactLevel),
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
                                      semanticLabel: raftText(
                                        context,
                                        'Copy link',
                                      ),
                                    ),
                                  if (forward)
                                    action(
                                      context,
                                      'Forward',
                                      RaftGlyph.forward,
                                      canAct &&
                                              widget.forwardDisabledReason ==
                                                  null
                                          ? widget.onForward
                                          : null,
                                      compact: isForward(compactLevel),
                                      tooltip: widget.forwardDisabledReason,
                                    ),
                                  RaftDropdownMenu(
                                    label: raftText(
                                      context,
                                      'More Selected Message Actions',
                                    ),
                                    enabled: widget.selected > 0,
                                    side: RaftDropdownSide.top,
                                    align: RaftDropdownAlign.end,
                                    sideOffset: 8,
                                    triggerBuilder: (context, node, pressed) =>
                                        action(
                                          context,
                                          'More Selected Message Actions',
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
                                              : 'Generate Image',
                                        ),
                                        leading: widget.busy
                                            ? Semantics(
                                                label: raftText(
                                                  context,
                                                  'Loading',
                                                ),
                                                child: const RaftSpinner(),
                                              )
                                            : const RaftIcon(
                                                RaftGlyph.image,
                                                size: 14,
                                              ),
                                        onPressed: canAct
                                            ? widget.onPreview
                                            : null,
                                      ),
                                      RaftMenuEntry(
                                        label: raftText(
                                          context,
                                          widget.copied
                                              ? 'Copied MD'
                                              : 'Copy MD',
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
                                  action(
                                    context,
                                    'Cancel',
                                    RaftGlyph.x,
                                    widget.onExit,
                                    compact: true,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (widget.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RaftErrorBanner(
                          widget.error!,
                          small: true,
                          bold: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
    this.onCopy,
    this.onSaveAll,
    this.onPreviousPage,
    this.onNextPage,
    this.pageNumber = 1,
    this.pageCount = 1,
    this.copying = false,
    this.copied = false,
    this.busy = false,
    this.error,
  });
  final Widget preview;
  final VoidCallback onClose;
  final VoidCallback? onSave, onShare;

  /// Web SelectShareLightbox "Copy image" (only where the clipboard takes a
  /// PNG).
  final VoidCallback? onCopy;
  final VoidCallback? onSaveAll, onPreviousPage, onNextPage;
  final int pageNumber, pageCount;
  final bool copying, copied;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      raftText(context, 'Share selected messages'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (pageCount > 1)
                      Text(
                        raftFormat(context, '{count} images · original order', {
                          'count': pageCount,
                        }),
                      ),
                  ],
                ),
              ),
              if (pageCount > 1) Text('$pageNumber/$pageCount'),
              RaftTooltip(
                message: raftText(context, 'Close Preview'),
                child: RaftButton.iconAction(
                  onPressed: busy ? null : onClose,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
        const RaftSeparator(),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  key: ValueKey(pageNumber),
                  padding: const EdgeInsets.all(16),
                  child: preview,
                ),
              ),
              if (pageCount > 1) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ScreenshotPageButton(
                    label: 'Previous page',
                    glyph: RaftGlyph.chevronLeft,
                    onPressed: busy ? null : onPreviousPage,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ScreenshotPageButton(
                    label: 'Next page',
                    glyph: RaftGlyph.chevronRight,
                    onPressed: busy ? null : onNextPage,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RaftErrorBanner(error!, small: true, bold: true),
          ),
        const RaftSeparator(),
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
              if (onCopy != null)
                RaftButton(
                  key: const ValueKey('image-review-copy'),
                  label: copying
                      ? 'Copying…'
                      : copied
                      ? 'Copied'
                      : pageCount == 1
                      ? 'Copy image'
                      : 'Copy this page',
                  icon: copied ? Icons.check : Icons.copy_outlined,
                  secondary: true,
                  busy: copying,
                  onPressed: busy ? null : onCopy,
                ),
              if (onSave != null)
                RaftButton(
                  label: pageCount == 1 ? 'Save image' : 'Save this page',
                  icon: Icons.download_outlined,
                  busy: busy && !copying,
                  onPressed: busy ? null : onSave,
                ),
              if (onShare != null)
                RaftButton(
                  label: pageCount == 1 ? 'Share Image' : 'Share all',
                  icon: Icons.share_outlined,
                  secondary: true,
                  onPressed: busy ? null : onShare,
                ),
              if (onSaveAll != null)
                RaftButton(
                  label: 'Download all',
                  icon: Icons.download_outlined,
                  onPressed: busy ? null : onSaveAll,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScreenshotPageButton extends StatelessWidget {
  const _ScreenshotPageButton({
    required this.label,
    required this.glyph,
    this.onPressed,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => RaftTooltip(
    message: raftText(context, label),
    child: RaftButton.iconAction(onPressed: onPressed, icon: RaftIcon(glyph)),
  );
}
