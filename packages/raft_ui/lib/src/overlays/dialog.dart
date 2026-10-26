// raft-ui Dialog / AlertDialog (`dialog`, `alertDialog` recipes): overlay
// (layer-backdrop, elegant blur(2px)), centered content (calc(100% - 32px),
// max-width per size), Header (title + corner close), Body, Footer, Title,
// Description. Current centred dialogs have no motion; frozen looks retain
// their original transition.
import 'dart:ui' show ImageFilter, SemanticsRole;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../dialog_slots.dart';
import '../dialog_surface.dart';
import '../form_presentation.dart';
import '../dialog_card.dart' show buildFrozenDialogCard;
import '../settings_controls.dart' show buildFrozenDialogShell;
import '../tap_slop.dart';
import '../dismiss_scope.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipe_surface.dart';
import '../recipes/alert_dialog.g.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/dialog.g.dart';
import '../recipes/web_dialog_card.g.dart';
import '../recipes/dialog_surface.g.dart';
import '../recipes/recipe_runtime.dart';
import '../recipes/recipe_router.dart';
import '../components.dart';
import '../theme.dart';
import '../settings_layout.dart' show RaftSpace;
import '../agent_create_form.dart' show buildAgentDialog;

part 'dialog_card_parts.dart';
part 'dialog_shell_parts.dart';
part 'dialog_layout.dart';

enum RaftDialogSize {
  /// max-width 384
  sm,

  /// max-width 448
  md,

  /// max-width 512
  lg,

  /// The published wide form size, bounded by the viewport.
  wide,
}

/// Which recipe a dialog's parts resolve against.
enum RaftDialogKind { dialog, alert }

/// The frozen renderer of an existing call site. The current Raft look always
/// uses the same source AlertDialog slots, including migrated Material calls.
enum RaftLegacyAlert { source, material }

/// Resolved slots shared by Dialog and AlertDialog parts.
class RaftDialogSlots {
  RaftDialogSlots._(
    this.overlay,
    this.content,
    this.header,
    this.body,
    this.footer,
    this.title,
    this.description,
  );

  factory RaftDialogSlots.of(
    BuildContext context, {
    RaftDialogKind kind = RaftDialogKind.dialog,
    RaftDialogSize size = RaftDialogSize.md,
    bool first = false,
    bool afterHeader = false,
    bool bar = false,
  }) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final states = t.recipeStates(
      extra: [
        if (first) 'first-child',
        // The generated selector atom describes the source's adjacent header.
        // Supply it only for that sibling relationship, not for descendants.
        if (afterHeader)
          kind == RaftDialogKind.alert
              ? 'ancestor:data-slot=alert-dialog-header'
              : 'ancestor:data-slot=dialog-header',
      ],
    );
    if (kind == RaftDialogKind.alert) {
      final s = RaftAlertDialogRecipe.resolve(
        theme: t.recipeTheme,
        states: states,
        tokens: rt,
      );
      RaftSlotStyle bind(RaftSlotStyle style, String slot) =>
          usesLegacyRecipes(rt) ? style : raftDialogSlot(t, style, slot);
      return RaftDialogSlots._(
        s.overlay,
        bind(s.content, 'content'),
        bind(s.header, 'header'),
        bind(s.body, 'body'),
        bind(s.footer, 'footer'),
        bind(s.title, 'title'),
        s.description,
      );
    }
    final slots = RaftDialogRecipe.resolveProps(
      {
        'theme': t.recipeTheme.name,
        'size': usesLegacyRecipes(rt) && size == RaftDialogSize.wide
            ? RaftDialogSize.lg.name
            : size.name,
        'bar': bar.toString(),
      },
      states: states,
      tokens: rt,
    );
    return RaftDialogSlots._(
      slots['overlay']!,
      raftDialogSlot(t, slots['content']!, 'content'),
      raftDialogSlot(t, slots['header']!, 'header'),
      raftDialogSlot(t, slots['body']!, 'body'),
      raftDialogSlot(t, slots['footer']!, 'footer'),
      raftDialogSlot(t, slots['title']!, 'title'),
      slots['description']!,
    );
  }

  final RaftSlotStyle overlay, content, header, body, footer, title;
  final RaftSlotStyle description;
}

class _DialogScope extends InheritedWidget {
  const _DialogScope({
    required this.kind,
    required this.size,
    required this.bar,
    required super.child,
  });
  final RaftDialogKind kind;
  final RaftDialogSize size;
  final bool bar;

  static _DialogScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DialogScope>();

  @override
  bool updateShouldNotify(_DialogScope old) =>
      kind != old.kind || size != old.size || bar != old.bar;
}

RaftDialogSlots _slots(BuildContext context) {
  final scope = _DialogScope.of(context);
  final part = context.dependOnInheritedWidgetOfExactType<_DialogPartScope>();
  return RaftDialogSlots.of(
    context,
    kind: scope?.kind ?? RaftDialogKind.dialog,
    size: scope?.size ?? RaftDialogSize.md,
    bar: scope?.bar ?? false,
    first: part?.first ?? false,
    afterHeader: part?.afterHeader ?? false,
  );
}

class _DialogPartScope extends InheritedWidget {
  const _DialogPartScope({
    required this.first,
    required this.afterHeader,
    required super.child,
  });
  final bool first, afterHeader;
  @override
  bool updateShouldNotify(_DialogPartScope old) =>
      first != old.first || afterHeader != old.afterHeader;
}

/// `DialogContent` / `AlertDialogContent`: the centered panel. Compose it
/// from [RaftDialogHeader], [RaftDialogBody] and [RaftDialogFooter], or use
/// the [title] / [content] / [actions] shorthand (Material `AlertDialog`
/// shape, for mechanical migration).
class RaftDialog extends StatelessWidget {
  /// Compatibility call shape for the former agent/runtime form shell. The
  /// current look uses [RaftDialog.card]; only frozen looks retain the former
  /// plain-card and backdrop composition.
  static Widget agent({
    Key? key,
    required String title,
    required List<Widget> children,
    VoidCallback? onClose,
    VoidCallback? onBackdrop,
    double? maxWidth,
    Key? surfaceKey,
    bool bare = false,
    bool plainCard = false,
    Widget? footer,
    double? footerGap,
  }) => buildAgentDialog(
    key: key,
    title: title,
    children: children,
    onClose: onClose,
    onBackdrop: onBackdrop,
    maxWidth: maxWidth,
    surfaceKey: surfaceKey,
    bare: bare,
    plainCard: plainCard,
    footer: footer,
    footerGap: footerGap,
  );

  const RaftDialog({
    super.key,
    this.child,
    this.title,
    this.content,
    this.actions,
    this.size = RaftDialogSize.md,
    this.kind = RaftDialogKind.dialog,
    this.showClose = true,
    this.semanticLabel,
    this.contentKey,
    this.onClose,
    this.closeEnabled = true,
    this.maxWidth,
    this.bar = false,
    this.outlineClose = false,
  }) : _card = false,
       _shell = false,
       titleGlyph = null,
       footer = null,
       cardActions = null,
       footerGap = null,
       assert(child != null || title != null || content != null);

  /// Web's DialogCard product composition on the same dialog surface. Its
  /// header spacing differs from the standard DialogHeader / Body anatomy.
  const RaftDialog.card({
    super.key,
    required String title,
    required VoidCallback onClose,
    required Widget child,
    this.maxWidth,
    this.titleGlyph,
    this.footer,
    this.footerGap,
    Widget? actions,
    this.contentKey,
    this.closeEnabled = true,
  }) : _card = true,
       _shell = false,
       outlineClose = false,
       title = title,
       onClose = onClose,
       child = child,
       cardActions = actions,
       content = null,
       actions = null,
       size = RaftDialogSize.md,
       bar = false,
       kind = RaftDialogKind.dialog,
       showClose = true,
       semanticLabel = title;

  /// The standard Dialog anatomy used by Web confirmations and editors.
  const RaftDialog.shell({
    super.key,
    required String title,
    required Widget body,
    required List<Widget> footer,
    this.onClose,
    this.maxWidth = 384,
    Key? surfaceKey,
    this.outlineClose = false,
  }) : _card = false,
       _shell = true,
       title = title,
       content = body,
       actions = footer,
       child = null,
       size = RaftDialogSize.md,
       bar = false,
       kind = RaftDialogKind.dialog,
       showClose = true,
       closeEnabled = onClose != null,
       semanticLabel = title,
       contentKey = surfaceKey,
       titleGlyph = null,
       footer = null,
       cardActions = null,
       footerGap = null;

  final bool _shell, outlineClose;
  final bool _card;
  final double? maxWidth, footerGap;
  final RaftGlyph? titleGlyph;
  final Widget? footer, cardActions;

  /// Key of the content panel itself (the root fills the viewport).
  final Key? contentKey;
  final VoidCallback? onClose;
  final bool closeEnabled;

  /// Full custom content (header/body/footer parts).
  final Widget? child;

  /// Shorthand parts: a String or Widget title, body content, footer actions.
  final Object? title;
  final Widget? content;
  final List<Widget>? actions;
  final RaftDialogSize size;
  final bool bar;
  final RaftDialogKind kind;

  /// Corner close in the shorthand header (Dialog only; AlertDialog never).
  final bool showClose;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    if (_shell) {
      if (usesLegacyRecipes(rt)) {
        return buildFrozenDialogShell(
          title: title! as String,
          body: content!,
          footer: actions!,
          onClose: onClose,
          maxWidth: maxWidth!,
          surfaceKey: contentKey,
          outlineClose: outlineClose,
        );
      }
      return _ShellDialogParts(dialog: this);
    }
    if (_card) {
      if (usesLegacyRecipes(rt)) {
        return buildFrozenDialogCard(
          title: title! as String,
          onClose: onClose!,
          maxWidth: maxWidth ?? 448,
          titleGlyph: titleGlyph,
          actions: cardActions,
          footer: footer,
          footerGap: footerGap ?? 16,
          child: child!,
        );
      }
      return _CardDialogParts(dialog: this);
    }
    return _DialogScope(
      kind: kind,
      size: size,
      bar: bar,
      child: Builder(
        builder: (context) {
          final s = _slots(context);
          final media = MediaQuery.of(context);
          final viewport = media.size;
          final legacy = usesLegacyRecipes(rt);
          final available = Size(
            viewport.width,
            math.max(0, viewport.height - media.viewInsets.bottom),
          );
          final width =
              (legacy
                      ? viewport.width - 32
                      : _dialogLength(
                              s.content['width'],
                              available,
                              horizontal: true,
                            ) ??
                            available.width)
                  .clamp(0.0, maxWidth ?? s.content.maxWidth ?? 448.0)
                  .toDouble();
          final maxHeight = math.max(
            0.0,
            legacy
                ? viewport.height - 32 - media.viewInsets.bottom
                : _dialogLength(s.content['max-height'], available) ??
                      available.height,
          );
          final height = legacy
              ? null
              : _dialogLength(s.content['height'], available);
          // A CSS portal inherits the document typography, outside the
          // trigger's decorated text ancestry. Frozen consumers keep theirs.
          final base = legacy
              ? raftCssText.merge(DefaultTextStyle.of(context).style)
              : raftCssText
                    .merge(Theme.of(context).textTheme.bodyMedium)
                    .copyWith(decoration: TextDecoration.none);
          Widget body =
              child ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    RaftDialogHeader(
                      title: title,
                      showClose: showClose && kind == RaftDialogKind.dialog,
                      onClose: onClose,
                      closeEnabled: closeEnabled,
                      outlineClose: outlineClose,
                    ),
                  if (content != null)
                    Flexible(child: RaftDialogBody(child: content!)),
                  if (actions != null && actions!.isNotEmpty)
                    RaftDialogFooter(children: actions!),
                ],
              );
          if (!usesLegacyRecipes(t.recipeTokens) && body is Column) {
            final column = body;
            body = Column(
              mainAxisSize: column.mainAxisSize,
              crossAxisAlignment: column.crossAxisAlignment,
              children: [
                for (var i = 0; i < column.children.length; i++)
                  _DialogPartScope(
                    first: i == 0,
                    afterHeader:
                        i > 0 && column.children[i - 1] is RaftDialogHeader,
                    child: column.children[i],
                  ),
              ],
            );
          }
          // CSS `display:flex|grid; gap` between header/body/footer.
          final gap = s.content.rowGap ?? 0;
          return Center(
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              role: kind == RaftDialogKind.alert
                  ? SemanticsRole.alertDialog
                  : SemanticsRole.dialog,
              explicitChildNodes: true,
              label:
                  semanticLabel ?? (title is String ? title as String : null),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width,
                  maxHeight: maxHeight,
                ),
                child: SizedBox(
                  width: width,
                  child: Material(
                    type: MaterialType.transparency,
                    textStyle: base,
                    child: RaftTapSlopHost(
                      child: usesLegacyRecipes(rt)
                          ? RaftRecipeBox(
                              key: contentKey,
                              style: s.content,
                              tokens: rt,
                              width: width,
                              clip: true,
                              child: _Gapped(gap: gap, child: body),
                            )
                          : RaftDialogSurface(
                              key: contentKey,
                              surfaceStyle: s.content,
                              child: height == null
                                  ? _Gapped(gap: gap, child: body)
                                  : SizedBox(
                                      height: math.min(height, maxHeight),
                                      child: _Gapped(gap: gap, child: body),
                                    ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inserts the content slot's flex/grid `gap` between direct part children.
class _Gapped extends StatelessWidget {
  const _Gapped({required this.gap, required this.child});
  final double gap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = child;
    if (gap == 0 || c is! Column) return c;
    return Column(
      mainAxisSize: c.mainAxisSize,
      crossAxisAlignment: c.crossAxisAlignment,
      children: [
        for (var i = 0; i < c.children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          c.children[i],
        ],
      ],
    );
  }
}

/// `AlertDialogContent` with the shorthand parts (Material `AlertDialog`
/// signature: title / content / actions).
class RaftAlertDialog extends StatelessWidget {
  const RaftAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.child,
    this.semanticLabel,
    this.legacy = RaftLegacyAlert.source,
  });
  final Object? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? child;
  final String? semanticLabel;
  final RaftLegacyAlert legacy;

  @override
  Widget build(BuildContext context) {
    if (legacy == RaftLegacyAlert.material &&
        usesLegacyRecipes(RaftTokens.of(context).recipeTokens)) {
      return AlertDialog(
        title: title is Widget
            ? title as Widget
            : title == null
            ? null
            : Text('$title'),
        content: content ?? child,
        actions: actions,
        semanticLabel: semanticLabel,
      );
    }
    return RaftDialog(
      kind: RaftDialogKind.alert,
      title: title,
      content: content,
      actions: actions,
      showClose: false,
      semanticLabel: semanticLabel,
      child: child,
    );
  }
}

/// `DialogHeader`: `grid-cols-[minmax(0,1fr)_max-content] items-center
/// gap-3` with the title and, for Dialog, the corner `DialogClose`.
class RaftDialogHeader extends StatelessWidget {
  const RaftDialogHeader({
    super.key,
    this.title,
    this.showClose = true,
    this.trailing,
    this.onClose,
    this.closeEnabled = true,
    this.outlineClose = false,
  });
  final Object? title;
  final bool showClose;
  final Widget? trailing;

  /// Defaults to popping the route.
  final VoidCallback? onClose;
  final bool closeEnabled;
  final bool outlineClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context);
    final close = showClose
        ? RaftDialogClose(
            onPressed: onClose,
            enabled: closeEnabled,
            bar: _DialogScope.of(context)?.bar ?? false,
            outlined: outlineClose,
          )
        : null;
    final end = trailing ?? close;
    return RaftRecipeBox(
      style: s.header,
      tokens: t.recipeTokens,
      child: Row(
        children: [
          Expanded(
            child: title is Widget
                ? DefaultTextStyle.merge(
                    style: s.title.text(t.recipeTokens),
                    child: title as Widget,
                  )
                : RaftDialogTitle(title?.toString() ?? ''),
          ),
          if (end != null) ...[SizedBox(width: s.header.columnGap ?? 12), end],
        ],
      ),
    );
  }
}

/// `DialogTitle` (sentence case; decision 0002).
class RaftDialogTitle extends StatelessWidget {
  const RaftDialogTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context).title;
    final style = s.text(
      t.recipeTokens,
      base: DefaultTextStyle.of(context).style,
    );
    final value = raftText(context, text);
    return Semantics(header: true, child: Text(value, style: style));
  }
}

/// `DialogDescription`.
class RaftDialogDescription extends StatelessWidget {
  const RaftDialogDescription(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context).description;
    return Text(
      raftText(context, text),
      style: s.text(t.recipeTokens, base: DefaultTextStyle.of(context).style),
    );
  }
}

/// `DialogBody`: `min-w-0 flex-1 overflow-y-auto` with the recipe padding.
class RaftDialogBody extends StatelessWidget {
  const RaftDialogBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context).body;
    if ((_DialogScope.of(context)?.bar ?? false) &&
        !usesLegacyRecipes(t.recipeTokens)) {
      return RaftRecipeBox(
        style: s,
        tokens: t.recipeTokens,
        clip: true,
        child: child,
      );
    }
    return DefaultTextStyle.merge(
      style: s.text(t.recipeTokens),
      child: SingleChildScrollView(padding: s.padding, child: child),
    );
  }
}

/// `DialogFooter`: `flex items-center justify-end gap-3`.
class RaftDialogFooter extends StatelessWidget {
  const RaftDialogFooter({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context).footer;
    final gap = s.columnGap ?? 12;
    return RaftRecipeBox(
      style: s,
      tokens: t.recipeTokens,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: children,
      ),
    );
  }
}

/// `DialogClose` default rendering: brutal `Button outline icon-md` with an
/// X `size-5`; elegant `Button ghost icon-sm` + `p-0
/// text-foreground-placeholder hover:bg-transparent
/// hover:text-foreground-strong` with an X `size-4`.
class RaftDialogClose extends StatelessWidget {
  const RaftDialogClose({
    super.key,
    this.onPressed,
    this.semanticLabel = 'Close',
    this.enabled = true,
    this.bar = false,
    this.outlined = false,
  }) : _product = false;
  const RaftDialogClose._product({this.onPressed, this.enabled = true})
    : semanticLabel = 'Close',
      bar = false,
      outlined = false,
      _product = true;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool enabled;
  final bool bar;
  final bool outlined;
  final bool _product;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (!usesLegacyRecipes(t.recipeTokens)) {
      final product = _product
          ? RaftWebDialogCardRecipe.resolve(
              states: t.recipeStates(),
              tokens: t.recipeTokens,
            )
          : null;
      return RaftDialogCloseOutset(
        verticalOutset: product == null
            ? (bar ? 0 : null)
            : -product.close.margin.top,
        endOutset: product == null ? null : -product.close.margin.right,
        child: RaftButton(
          label: '',
          glyph: RaftGlyph.x,
          semanticLabel: raftText(context, semanticLabel),
          uiVariant:
              this.outlined ||
                  t.option('dialog.close', or: 'ghost') == 'outline'
              ? RaftButtonVariant.outline
              : RaftButtonVariant.ghost,
          uiSize: _product ? RaftButtonSize.iconSm : RaftButtonSize.iconMd,
          metricsKey:
              t.themeOverrides?.geometry.containsKey('size.dialogClose') == true
              ? 'dialogClose'
              : null,
          glyphSize:
              t.themeOverrides?.geometry['size.dialogCloseGlyph'] ??
              product?.glyph.width ??
              t.size('size.dialogCloseGlyph', fallback: 18),
          foreground:
              t.themeOverrides?.colors.containsKey('foreground-dialog-close') ==
                  true
              ? t.colors['foreground-dialog-close']
              : null,
          onPressed: enabled
              ? onPressed ?? () => Navigator.of(context).maybePop()
              : null,
        ),
      );
    }
    final outlined =
        this.outlined || t.option('dialog.close', or: 'ghost') == 'outline';
    return RaftDialogCloseOutset(
      child: RaftGlyphButton(
        glyph: RaftGlyph.x,
        semanticLabel: raftText(context, semanticLabel),
        tone: outlined
            ? RaftButtonRecipeVariant.outline
            : RaftButtonRecipeVariant.ghost,
        size: outlined
            ? RaftButtonRecipeSize.iconMd
            : RaftButtonRecipeSize.iconSm,
        glyphSize: t.size('size.dialogCloseGlyph', fallback: 16),
        quiet: !outlined,
        restColor: t.colors['foreground-dialog-close'],
        onPressed: enabled
            ? onPressed ?? () => Navigator.of(context).maybePop()
            : null,
      ),
    );
  }
}

/// Icon-only raft-ui `Button` (`icon-*` sizes) on the buttonVariants recipe.
class RaftGlyphButton extends StatelessWidget {
  const RaftGlyphButton({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    this.onPressed,
    this.tone = RaftButtonRecipeVariant.ghost,
    this.size = RaftButtonRecipeSize.iconSm,
    this.glyphSize,
    this.quiet = false,
    this.restColor,
    this.tooltip,
  });
  final RaftGlyph glyph;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant tone;
  final RaftButtonRecipeSize size;
  final double? glyphSize;

  /// Elegant DialogClose overrides: no padding/background, placeholder ink
  /// that turns foreground-strong on hover.
  final bool quiet;
  final Color? restColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      tooltip: tooltip,
      builder: (context, st) {
        final s = RaftButtonRecipe.resolve(
          theme: t.recipeTheme,
          variant: tone,
          size: size,
          states: t.recipeStates(
            hovered: st.hovered,
            pressed: st.pressed,
            focusVisible: st.focusVisible,
            disabled: onPressed == null,
          ),
          tokens: rt,
        ).root;
        final svg = s.target("& svg:not([class*='size-'])");
        final color = quiet
            ? (st.hovered
                  ? t.semantic.foregroundStrong
                  : restColor ?? t.semantic.foregroundPlaceholder)
            : null;
        return RaftRecipeBox(
          style: s,
          tokens: rt,
          padding: quiet ? EdgeInsets.zero : null,
          alignment: Alignment.center,
          decorationOverride: quiet
              ? (d) => d.copyWith(color: Colors.transparent)
              : null,
          child: Builder(
            builder: (context) => RaftIcon(
              glyph,
              size: glyphSize ?? svg?.width ?? 16,
              color: color ?? DefaultTextStyle.of(context).style.color,
            ),
          ),
        );
      },
    );
  }
}

/// The dialog route: `layer-backdrop` overlay (elegant `backdrop-blur 2px`)
/// fading in `duration-150 ease-out`; content fades/scales from 0.98.
class RaftDialogRoute<T> extends PopupRoute<T> {
  RaftDialogRoute({
    required this.builder,
    required this.capturedThemes,
    this.dismissible = true,
    this.label,
    this.overModal = false,
    this.motionDuration = const Duration(milliseconds: 150),
    this.modal = false,
    super.settings,
  }) : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final bool dismissible;
  final String? label;

  /// Opened over another Modal's black/60 scrim (see [RaftDialogBarrier]).
  final bool overModal;
  final Duration motionDuration;

  /// The product composition owns its backdrop and layout, as Web Modal does.
  final bool modal;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => !modal && dismissible;
  @override
  String? get barrierLabel => label ?? 'Dismiss';
  @override
  Duration get transitionDuration => motionDuration;

  @override
  Widget buildModalBarrier() => modal
      ? const SizedBox.shrink()
      : RaftDialogBarrier(
          animation: animation!,
          dismissible: dismissible,
          label: barrierLabel,
          capturedThemes: capturedThemes,
          overModal: overModal,
        );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(
    // Web Dialog / AlertDialog close on Escape even where the scrim tap is
    // off (`disablePointerDismissal`, confirm dialogs).
    RaftDismissScope(
      child: modal
          ? Material(
              type: MaterialType.transparency,
              child: Builder(builder: builder),
            )
          : SafeArea(child: Builder(builder: builder)),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (motionDuration == Duration.zero) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeOut));
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: .98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

/// The scrim behind a dialog, side panel or sheet: `layer-backdrop` fading in,
/// with the elegant 2px blur. One scrim for every floating window.
class RaftDialogBarrier extends StatelessWidget {
  const RaftDialogBarrier({
    required this.animation,
    required this.dismissible,
    required this.label,
    required this.capturedThemes,
    this.overModal = false,
  });
  final bool overModal;
  final Animation<double> animation;
  final bool dismissible;
  final String? label;
  final CapturedThemes capturedThemes;

  @override
  Widget build(BuildContext context) => capturedThemes.wrap(
    Builder(
      builder: (context) {
        final t = RaftTokens.of(context);
        final s = RaftDialogSlots.of(context).overlay;
        final color =
            s.backgroundColor?.resolve(t.recipeTokens) ??
            t.semantic.layerBackdrop;
        // Brutal `--layer-backdrop` is black at alpha 0.650858 (its 0.0007
        // channel tint quantizes to 0 in Chromium). Over another Modal's
        // black/60 scrim (102) Chromium lands on 35 where Skia's float blend
        // rounds 35.6 up to 36 and the tint tips two channels: pure black at
        // 0.6525 gives 35 there. Only for dialogs stacked on a Modal; over a
        // page the tinted token already matches.
        Widget layer;
        if (usesLegacyRecipes(t.recipeTokens)) {
          final blur = t.size('blur.dialogBackdrop', fallback: 2);
          layer = ColoredBox(color: color, child: const SizedBox.expand());
          if (blur > 0) {
            layer = BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: layer,
            );
          }
        } else {
          layer = const RaftDialogBackdrop(child: SizedBox.expand());
          final blur = t.size('blur.dialogBackdrop', fallback: 0);
          if (blur > 0) {
            layer = BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: layer,
            );
          }
        }
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: Semantics(
            label: dismissible ? label : null,
            button: dismissible,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissible
                  ? () => Navigator.of(context).maybePop()
                  : null,
              child: layer,
            ),
          ),
        );
      },
    ),
  );
}

/// Drop-in for Material `showDialog` with the raft-ui dialog route.
Future<T?> showRaftDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  String? barrierLabel,
  RouteSettings? routeSettings,
  bool overModal = false,
  bool modal = false,
  bool legacyMaterial = false,
  bool legacyModal = false,
  Color? legacyBarrierColor,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  if (legacyMaterial &&
      usesLegacyRecipes(RaftTokens.of(context).recipeTokens)) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: legacyBarrierColor,
      useRootNavigator: useRootNavigator,
      barrierLabel: barrierLabel,
      routeSettings: routeSettings,
    );
  }
  if (legacyModal && usesLegacyRecipes(RaftTokens.of(context).recipeTokens)) {
    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      barrierDismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: RaftTokens.of(context).colors['layer-backdrop']!,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) => RaftDismissScope(child: builder(context)),
    );
  }
  return navigator.push(
    RaftDialogRoute<T>(
      builder: builder,
      dismissible: barrierDismissible,
      label: barrierLabel,
      overModal: overModal,
      modal: modal,
      motionDuration:
          !modal && usesLegacyRecipes(RaftTokens.of(context).recipeTokens)
          ? const Duration(milliseconds: 150)
          : Duration.zero,
      settings: routeSettings,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// AlertDialog shorthand: title, optional description, Cancel (`Button
/// outline`, closes with false) and the confirm action (`accent`, or
/// `danger` when [destructive]) which closes with true.
Future<bool> showRaftAlertDialog({
  required BuildContext context,
  required String title,
  String? description,
  Widget? content,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool barrierDismissible = true,
}) async {
  final result = await showRaftDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => RaftAlertDialog(
      title: title,
      content:
          content ??
          (description == null ? null : RaftDialogDescription(description)),
      actions: [
        RaftButton(
          label: cancelLabel,
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        RaftButton(
          label: confirmLabel,
          tone: destructive
              ? RaftButtonRecipeVariant.danger
              : RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.md,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}
