import 'reduced_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'attachment_tokens.dart';
import 'design_primitives.dart' show RaftLightboxRecipe, RaftSpinner;
import 'recipes/spinner.g.dart' show RaftSpinnerRecipeSize;
import 'indicators.dart';
import 'panel_layout.dart' show RaftPanelHeaderBar;
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'shortcut_platform.dart';
import 'system_inset.dart';
import 'status_bar.dart';
import 'text_scaling.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';

/// Width of the comments aside (`w-80`).
const raftLightboxAsideWidth = 320.0;

/// Tailwind `sm`: below it the comments panel is a drawer / bottom sheet.
const raftLightboxSmBreakpoint = 640.0;

/// `h-14` header row of Web `ImageLightbox` / `AttachmentPreviewShell`.
const raftLightboxHeaderRow = 56.0;

/// Web `Lightbox` default backdrop, `bg-black/75`.
const raftLightboxBackdrop = Color(0xBF000000);

/// The scrim behind the lightbox: the pack's `layer-backdrop` in the Raft look,
/// `bg-black/75` otherwise.
Color raftLightboxBackdropOf(RaftTokens t) =>
    t.option('lightbox.style', or: 'recipe') == 'raft'
    ? t.colors['layer-backdrop']!
    : raftLightboxBackdrop;

/// File-type chip of the preview header (Web `AttachmentTypeBadge` with the
/// header's `!h-4 !w-8` override); null for extensions without a kind.
class RaftFileTypeBadge extends StatelessWidget {
  const RaftFileTypeBadge({
    super.key,
    required this.filename,
    this.size = const Size(32, 16),
    this.headerLabel = false,
  });
  final String filename;
  final Size size;

  /// The toolbar's file-type label (raft-ui 0.7 lightbox `headerLabel`), not the
  /// small badge of an attachment card.
  final bool headerLabel;
  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final component = AttachmentComponentRecipe(tokens);
    final extension = filename.split('.').last.toUpperCase();
    final background = component.semantics.badgeBackground(extension);
    if (background == null) return const SizedBox.shrink();
    if (headerLabel &&
        tokens.option('lightbox.style', or: 'recipe') == 'raft') {
      // `headerLabel`: `h-[22px] rounded-chip bg-fill-muted px-1.5 py-0
      // text-caption font-semibold text-foreground-muted`.
      return Container(
        // `h-[22px]`, a minimum so the label is never cut at larger text sizes.
        constraints: const BoxConstraints(minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: tokens.ui.fillMuted,
          borderRadius: BorderRadius.circular(
            tokens.size('radius.chip', fallback: 6),
          ),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            extension,
            maxLines: 1,
            style: tokens.scale(
              RaftTypeScale.caption,
              weight: FontWeight.w600,
              color: tokens.ui.foregroundMuted,
            ),
          ),
        ),
      );
    }
    // A minimum box: it grows with its label above the default text size so
    // the extension is never cut.
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: RaftScaled.extent(context, size.width, fontSize: 9),
        minHeight: RaftScaled.extent(context, size.height, fontSize: 9),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: component.badgeBorder,
          borderRadius: component.badgeRadius,
          boxShadow: component.badgeShadows,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            extension,
            maxLines: 1,
            style: component.badgeLabel(extension),
          ),
        ),
      ),
    );
  }
}

/// `Button size="icon-sm"` of the lightbox headers: `outline`, or `primary`
/// while the control it toggles is on.
class RaftLightboxIconAction extends StatelessWidget {
  const RaftLightboxIconAction({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.active = false,
  });
  final RaftGlyph glyph;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final raft =
        RaftTokens.of(context).option('lightbox.style', or: 'recipe') == 'raft';
    return RaftTooltip(
      message: label,
      excludeFromSemantics: true,
      child: RaftRecipeButton(
        // `Button size="icon-lg" variant={active ? "outline" : "ghost"}`.
        variant: raft
            ? (active
                  ? RaftButtonRecipeVariant.outline
                  : RaftButtonRecipeVariant.ghost)
            : (active
                  ? RaftButtonRecipeVariant.primary
                  : RaftButtonRecipeVariant.outline),
        size: raft ? RaftButtonRecipeSize.iconLg : RaftButtonRecipeSize.iconSm,
        glyph: glyph,
        glyphSize: 14,
        tooltip: label,
        onPressed: onPressed,
      ),
    );
  }
}

/// The title bar both lightboxes share: `bg-layer-panel` (brutal white),
/// `border-b`, then `flex h-14 items-center gap-3 px-4`.
class RaftLightboxHeader extends StatelessWidget {
  const RaftLightboxHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.leading,
    this.meta,
    this.subtitle,
    this.actions = const [],
    this.titleBold = false,
    this.borderWidth = 1,
    this.closeLabel = 'Close Preview',
  });
  final String title, closeLabel;

  /// Second line under the title (`sender · time · size`).
  final String? subtitle;
  final Widget? leading, meta;
  final List<Widget> actions;
  final bool titleBold;

  /// Elegant `border-b-2` (image lightbox) or `border-b` (preview shell);
  /// brutal is always 2.
  final double borderWidth;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final raft = t.option('lightbox.style', or: 'recipe') == 'raft';
    final rule = borderWidth;
    // raft-ui 0.7 `toolbar`: `border-b border-line-seam bg-layer-canvas`.
    final surface = raft ? t.canvas : t.panel;
    return RaftStatusBarSource(
      color: surface,
      child: DefaultTextHeightBehavior(
        textHeightBehavior: raftCssTextHeightBehavior,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            border: Border(
              bottom: BorderSide(
                color: raft ? t.colors['line-seam']! : t.colors['line-muted']!,
                width: rule,
              ),
            ),
          ),
          // Larger text: the bar is a minimum height and the title and the
          // sender line wrap instead of being ellipsised.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: raftLightboxHeaderRow + rule,
              maxHeight: RaftScaled.grows(context)
                  ? double.infinity
                  : raftLightboxHeaderRow + rule,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, rule),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: RaftScaled.grows(context) ? null : 1,
                                softWrap: RaftScaled.grows(context),
                                overflow: RaftScaled.grows(context)
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: raft
                                    // `text-headline font-bold text-foreground`.
                                    ? t.scale(
                                        RaftTypeScale.headline,
                                        weight: FontWeight.w700,
                                      )
                                    : TextStyle(
                                        fontFamily: t.headingFont,
                                        fontSize: 14,
                                        height: 20 / 14,
                                        fontWeight: titleBold
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: t.strong,
                                      ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: RaftScaled.grows(context)
                                      ? null
                                      : 1,
                                  softWrap: RaftScaled.grows(context),
                                  overflow: RaftScaled.grows(context)
                                      ? TextOverflow.clip
                                      : TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: t.bodyFont,
                                    fontSize: 12,
                                    height: 16 / 12,
                                    color: t.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (meta != null) ...[const SizedBox(width: 12), meta!],
                  const SizedBox(width: 12),
                  for (final action in actions) ...[
                    action,
                    const SizedBox(width: 6),
                  ],
                  RaftTooltip(
                    message: closeLabel,
                    excludeFromSemantics: true,
                    child: raft
                        // `CloseButton size="icon-lg"` (a ghost icon button).
                        ? RaftRecipeButton(
                            variant: RaftButtonRecipeVariant.ghost,
                            size: RaftButtonRecipeSize.iconLg,
                            glyph: RaftGlyph.x,
                            tooltip: closeLabel,
                            onPressed: onClose,
                          )
                        : RaftCloseButton(
                            onPressed: onClose,
                            tooltip: closeLabel,
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

/// `aside`: `w-80`, `border-l` (`-2` brutal / image lightbox), panel surface.
/// The content is laid out at the full 320 and clipped by the border box, as
/// the Web `h-full w-80` inner div is.
class RaftLightboxAside extends StatelessWidget {
  const RaftLightboxAside({
    super.key,
    required this.child,
    this.borderWidth = 2,
    this.topBorder = false,
  });
  final Widget child;
  final double borderWidth;

  /// The browser-find drawer also carries `border-t`.
  final bool topBorder;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rule = borderWidth;
    final color = t.colors['line-muted']!;
    return Container(
      width: raftLightboxAsideWidth,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(
          left: BorderSide(color: color, width: rule),
          top: topBorder
              ? BorderSide(color: color, width: rule)
              : BorderSide.none,
        ),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: raftLightboxAsideWidth,
          maxWidth: raftLightboxAsideWidth,
          child: child,
        ),
      ),
    );
  }
}

/// Source Lightbox viewport shell (Web `ImageLightbox` frame): `bg-black/75`
/// backdrop, the shared title bar, the stage and the optional comments
/// aside. The caller owns route scope and private media. SafeArea keeps
/// interactive controls above native system bars and gestures.
class RaftAttachmentLightbox extends StatelessWidget {
  const RaftAttachmentLightbox({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.actions = const [],
    this.footer,
    this.titleBold = false,
    this.closeLabel = 'Close Preview',
    this.onResetZoom,
    this.meta,
    this.subtitle,
    this.leading,
    this.aside,
    this.asideOpen = false,
    this.overlay,
    this.overlayInset = 0,
    this.page = false,
    this.shortcuts = const {},
  });
  final String title, closeLabel;
  final Widget child;
  final VoidCallback onClose;
  final List<Widget> actions;

  /// Extra key bindings of the stage (gallery ArrowLeft / ArrowRight).
  final Map<ShortcutActivator, VoidCallback> shortcuts;
  final Widget? footer;
  final bool titleBold;

  /// Header chip after the title (Web gallery counter badge).
  final Widget? meta;

  /// Sub-line under the title and the kind glyph before it.
  final String? subtitle;
  final Widget? leading;

  /// Comments panel; shown beside the stage from `sm` up, as a drawer over
  /// it below. Collapsed (`asideOpen` false) it takes no space.
  final Widget? aside;
  final bool asideOpen;

  /// Painted over the stage (gallery arrows, thumbnail strip).
  final Widget? overlay;

  /// Height of the [overlay] band along the bottom edge. The stage keeps
  /// this much free above and below its centre line ([RaftLightboxStageInset])
  /// so a fitted image never lies under the overlay (centred images stay
  /// where Web puts them).
  final double overlayInset;

  /// Mobile page route: the host pushes a platform route, so the shell is a
  /// plain Material page with the shared page header instead of a dialog.
  final bool page;

  /// Source ImageLightbox: the 0 key resets zoom and pan.
  final VoidCallback? onResetZoom;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pageRecipe = RaftLightboxRecipe(t);
    final wide = MediaQuery.sizeOf(context).width >= raftLightboxSmBreakpoint;
    Widget stage = Stack(
      children: [
        Positioned.fill(
          child: RaftLightboxStageInset(
            vertical: overlay == null ? 0 : overlayInset,
            child: child,
          ),
        ),
        if (overlay != null) Positioned.fill(child: overlay!),
      ],
    );
    final Widget body;
    if (aside == null) {
      body = stage;
    } else if (wide) {
      body = Row(
        children: [
          Expanded(child: stage),
          AnimatedContainer(
            duration: raftMotionDuration(
              context,
              const Duration(milliseconds: 300),
            ),
            curve: Curves.easeInOut,
            width: asideOpen ? raftLightboxAsideWidth : 0,
            child: asideOpen
                ? RaftLightboxAside(child: aside!)
                : Offstage(child: RaftLightboxAside(child: aside!)),
          ),
        ],
      );
    } else {
      body = Stack(
        children: [
          Positioned.fill(child: stage),
          if (asideOpen)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border(
                    left: BorderSide(color: t.colors['line-muted']!, width: 2),
                    top: BorderSide(color: t.colors['line-muted']!, width: 2),
                  ),
                ),
                child: aside!,
              ),
            ),
        ],
      );
    }
    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
        SingleActivator(
          LogicalKeyboardKey.keyW,
          control: !usesCommandShortcuts(),
          meta: usesCommandShortcuts(),
        ): onClose,
        if (onResetZoom != null) ...{
          const SingleActivator(LogicalKeyboardKey.digit0): onResetZoom!,
          const SingleActivator(LogicalKeyboardKey.numpad0): onResetZoom!,
        },
        ...shortcuts,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (page)
                // Native page: no Web counterpart, so it wears the same Web
                // PanelHeader (boxed Back, title, actions) as every phone page.
                RaftPanelHeaderBar(
                  title: title,
                  onBack: onClose,
                  backTooltip: closeLabel,
                  // The gallery counter chip (Web header badge) leads the actions.
                  actions: [if (meta != null) meta!, ...actions],
                )
              else
                RaftLightboxHeader(
                  title: title,
                  subtitle: subtitle,
                  leading: leading,
                  titleBold: titleBold,
                  meta: meta,
                  actions: actions,
                  borderWidth: 2,
                  closeLabel: closeLabel,
                  onClose: onClose,
                ),
              // Without a footer the stage ends above the system bar so the
              // thumbnails and controls stay reachable; the footer extends its
              // own background under the bar instead.
              Expanded(
                child: footer == null
                    ? Padding(
                        padding: EdgeInsets.only(
                          bottom: raftBottomInset(context),
                        ),
                        child: body,
                      )
                    : body,
              ),
              if (footer != null)
                RaftBottomInsetSurface(
                  color: t.panel,
                  child: SizedBox(width: double.infinity, child: footer!),
                ),
            ],
          ),
        ),
      ),
    );
    return page
        ? Material(color: pageRecipe.backdrop, child: content)
        : Dialog.fullscreen(
            backgroundColor: raftLightboxBackdropOf(RaftTokens.of(context)),
            child: content,
          );
  }
}

/// Vertical space the stage content keeps free above and below the stage's
/// centre line (the thumbnail strip's band, mirrored so the content stays
/// centred). Read with [RaftLightboxStageInset.of].
class RaftLightboxStageInset extends InheritedWidget {
  const RaftLightboxStageInset({
    super.key,
    required this.vertical,
    required super.child,
  });
  final double vertical;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftLightboxStageInset>()
          ?.vertical ??
      0;

  @override
  bool updateShouldNotify(RaftLightboxStageInset oldWidget) =>
      vertical != oldWidget.vertical;
}

/// Web `ImageLightbox` stage: "Empty-stage clicks close the lightbox", and a
/// click that lands inside the (zoomed / panned) image does not. A plain tap
/// (not a drag or pinch, which win the gesture arena) outside the painted
/// image behind [imageKey] calls [onClose].
class RaftLightboxStageTap extends StatelessWidget {
  const RaftLightboxStageTap({
    super.key,
    required this.imageKey,
    required this.onClose,
    required this.child,
  });
  final GlobalKey imageKey;
  final VoidCallback onClose;
  final Widget child;
  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('lightbox-stage'),
    behavior: HitTestBehavior.translucent,
    onTapUp: (details) {
      final box = imageKey.currentContext?.findRenderObject();
      // `globalToLocal` includes the zoom / pan transform above the image.
      if (box is! RenderBox || !box.hasSize) return;
      final local = box.globalToLocal(details.globalPosition);
      if (!(Offset.zero & box.size).contains(local)) onClose();
    },
    child: child,
  );
}

/// Gallery counter chip of the header (`<Badge variant="primary">2 / 3`).
class RaftLightboxCounter extends StatelessWidget {
  const RaftLightboxCounter({
    super.key,
    required this.index,
    required this.count,
  });
  final int index, count;
  @override
  Widget build(BuildContext context) => RaftBadge(
    label: '${index + 1} / $count',
    variant: RaftBadgeRecipeVariant.primary,
  );
}

/// Stage placeholder while the original loads and nothing else can stand in
/// (`size-64` box, inverse `lg` spinner).
class RaftLightboxLoading extends StatelessWidget {
  const RaftLightboxLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 256,
      child: Center(
        child: RaftTokens.of(context).isRaftLook
            ? const RaftSpinner(
                inverse: true,
                recipeSize: RaftSpinnerRecipeSize.lg,
              )
            : const RaftSpinner(inverse: true, size: 32),
      ),
    ),
  );
}

/// Stage failure card (`size-64`, ImageOff, name, message, `text-white/40`).
class RaftLightboxFailure extends StatelessWidget {
  const RaftLightboxFailure({
    super.key,
    required this.title,
    required this.message,
  });
  final String title, message;
  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: .4);
    return Center(
      child: SizedBox.square(
        dimension: 256,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: muted),
          textAlign: TextAlign.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RaftIcon(RaftGlyph.imageOff, size: 48, color: muted),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(title, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 12),
              Text(
                raftText(context, message),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
