import 'raft/button.dart';
import 'raft/ui_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'card.dart';
import 'components.dart';
import 'design_primitives.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/dialog.g.dart';
import 'selection_toolbar_recipe.dart';
import 'system_inset.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

/// Routes the row tap to the selection toggle while row controls are inert.
Widget raftSelectableMessage({
  required bool selected,
  required VoidCallback? onTap,
  required Widget child,
}) => Semantics(
  selected: selected,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: AbsorbPointer(child: child),
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
        padding: EdgeInsets.fromLTRB(
          recipe.horizontalInset,
          0,
          recipe.horizontalInset,
          12 + raftBottomInset(context),
        ),
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

/// Backdrop + max-size frame for [RaftImageReview] (Web `SelectShareLightbox`).
class RaftImageReviewLightbox extends StatelessWidget {
  const RaftImageReviewLightbox({
    super.key,
    required this.onBackdrop,
    required this.child,
    this.backdropKey,
    this.backdropColor,
  });

  final VoidCallback onBackdrop;
  final Widget child;
  final Key? backdropKey;
  final Color? backdropColor;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: backdropColor ?? t.colors['layer-backdrop']!,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          key: backdropKey,
          behavior: HitTestBehavior.opaque,
          onTap: onBackdrop,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 768,
                      maxHeight: MediaQuery.sizeOf(context).height * .9,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `SelectShareLightbox`: reviewed screenshot card inside the lightbox.
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
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final headerStyle = RaftDialogRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: rt,
    ).header;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        final wellColor = raftChromeBlend(
          t.colors['fill-muted']!,
          t.colors['layer-card']!,
        );
        final floatShadows = [
          for (final layer in t.shadowLayers('elevation-float'))
            if (!layer.inset) layer.toBoxShadow(),
        ];
        final horizontalPad = narrow ? 64.0 : 80.0;
        final verticalPad = narrow ? 16.0 : 24.0;
        final chipRadius = t.size('radius.chip', fallback: 6);
        final containerRadius = t.size('radius.container', fallback: 8);
        final copyButton = onCopy == null
            ? null
            : RaftButton(
                key: const ValueKey('image-review-copy'),
                label: raftText(
                  context,
                  copying
                      ? 'Copying…'
                      : copied
                      ? 'Copied'
                      : 'Copy this page',
                ),
                glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
                glyphSize: 16,
                uiVariant: RaftButtonVariant.outline,
                uiSize: RaftButtonSize.md,
                busy: copying,
                expand: narrow,
                onPressed: busy ? null : onCopy,
              );
        final saveButton = onSave == null
            ? null
            : RaftButton(
                label: raftText(
                  context,
                  onShare == null && onSaveAll == null
                      ? 'Download all'
                      : 'Save this page',
                ),
                glyph: RaftGlyph.download,
                glyphSize: 16,
                uiVariant: onShare != null || onSaveAll != null
                    ? RaftButtonVariant.outline
                    : RaftButtonVariant.accent,
                uiSize: RaftButtonSize.md,
                busy: busy && !copying,
                expand: narrow,
                onPressed: busy ? null : onSave,
              );
        final shareButton = onShare == null
            ? null
            : RaftButton(
                label: raftText(
                  context,
                  pageCount == 1 ? 'Share Image' : 'Share all',
                ),
                glyph: RaftGlyph.share2,
                glyphSize: 16,
                uiVariant: RaftButtonVariant.accent,
                uiSize: RaftButtonSize.md,
                busy: busy && !copying,
                expand: narrow,
                onPressed: busy ? null : onShare,
              );
        final saveAllButton = onSaveAll == null
            ? null
            : RaftButton(
                label: raftText(context, 'Download all'),
                glyph: RaftGlyph.download,
                glyphSize: 16,
                uiVariant: RaftButtonVariant.accent,
                uiSize: RaftButtonSize.md,
                busy: busy && !copying,
                expand: narrow,
                onPressed: busy ? null : onSaveAll,
              );
        final actions = <Widget>[
          ?copyButton,
          ?saveButton,
          ?shareButton,
          ?saveAllButton,
        ];

        return RaftCard(
          key: const ValueKey('image-review-card'),
          clip: true,
          maxWidth: 768,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: narrow ? 56 : null,
                padding: narrow
                    ? const EdgeInsets.symmetric(horizontal: 20)
                    : headerStyle.padding.resolve(Directionality.of(context)),
                decoration: BoxDecoration(
                  color: t.colors['layer-card'],
                  border: Border(bottom: BorderSide(color: t.ui.lineHairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            header: true,
                            child: RaftCssText(
                              raftText(context, 'Share preview'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                RaftTypeScale.headline,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (pageCount > 1)
                            RaftCssText(
                              raftFormat(
                                context,
                                '{count} images · original order',
                                {'count': pageCount},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.scale(
                                RaftTypeScale.caption,
                                color: t.ui.foregroundMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (pageCount > 1) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: t.colors['info-soft'],
                          borderRadius: BorderRadius.all(
                            Radius.circular(chipRadius),
                          ),
                        ),
                        child: Text(
                          '$pageNumber/$pageCount',
                          style: t.scale(
                            RaftTypeScale.monoMeta,
                            mono: true,
                            color: t.strong,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    RaftButton(
                      label: '',
                      glyph: RaftGlyph.x,
                      glyphSize: 18,
                      tooltip: raftText(context, 'Close Preview'),
                      semanticLabel: raftText(context, 'Close Preview'),
                      uiVariant: RaftButtonVariant.ghost,
                      uiSize: narrow
                          ? RaftButtonSize.iconMd
                          : RaftButtonSize.iconSm,
                      onPressed: busy ? null : onClose,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ColoredBox(
                  color: wellColor,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SingleChildScrollView(
                        key: ValueKey(pageNumber),
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPad,
                          vertical: verticalPad,
                        ),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: wellColor,
                              borderRadius: BorderRadius.all(
                                Radius.circular(containerRadius),
                              ),
                              border: Border.all(
                                color: raftChromeBlend(
                                  t.ui.lineHairline,
                                  wellColor,
                                ),
                              ),
                              boxShadow: floatShadows,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: preview,
                          ),
                        ),
                      ),
                      if (pageCount > 1) ...[
                        Positioned(
                          left: narrow ? 12 : 24,
                          child: RaftButton(
                            label: '',
                            glyph: RaftGlyph.chevronLeft,
                            tooltip: raftText(context, 'Previous page'),
                            semanticLabel: raftText(context, 'Previous page'),
                            uiVariant: RaftButtonVariant.outline,
                            uiSize: RaftButtonSize.iconMd,
                            onPressed: busy ? null : onPreviousPage,
                          ),
                        ),
                        Positioned(
                          right: narrow ? 12 : 24,
                          child: RaftButton(
                            label: '',
                            glyph: RaftGlyph.chevronRight,
                            tooltip: raftText(context, 'Next page'),
                            semanticLabel: raftText(context, 'Next page'),
                            uiVariant: RaftButtonVariant.outline,
                            uiSize: RaftButtonSize.iconMd,
                            onPressed: busy ? null : onNextPage,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 12 : 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.colors['layer-card'],
                  border: Border(top: BorderSide(color: t.ui.lineHairline)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Text(
                        error!,
                        style: t.scale(
                          RaftTypeScale.callout,
                          weight: FontWeight.w500,
                          color: t.colors['danger-strong'],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (narrow && actions.length == 2)
                      Row(
                        children: [
                          Expanded(child: actions[0]),
                          const SizedBox(width: 8),
                          Expanded(child: actions[1]),
                        ],
                      )
                    else
                      Align(
                        alignment: narrow
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: narrow
                              ? WrapAlignment.start
                              : WrapAlignment.end,
                          children: actions,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
