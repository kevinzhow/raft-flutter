// raft-ui Dialog / AlertDialog (`dialog`, `alertDialog` recipes): overlay
// (layer-backdrop, elegant blur(2px)), centered content (calc(100% - 32px),
// max-width per size), Header (title + corner close), Body, Footer, Title,
// Description; enter/exit `transition-[opacity,transform] duration-150
// ease-out` from `opacity: 0; scale: 0.98`.
import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../icons.dart';
import '../localization.dart';
import '../recipe_surface.dart';
import '../recipes/alert_dialog.g.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/dialog.g.dart';
import '../recipes/recipe_runtime.dart';
import '../components.dart';
import '../theme.dart';

enum RaftDialogSize {
  /// max-width 384
  sm,

  /// max-width 448
  md,

  /// max-width 512
  lg,
}

/// Which recipe a dialog's parts resolve against.
enum RaftDialogKind { dialog, alert }

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
  }) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final states = t.recipeStates();
    if (kind == RaftDialogKind.alert) {
      final s = RaftAlertDialogRecipe.resolve(
        theme: t.recipeTheme,
        states: states,
        tokens: rt,
      );
      return RaftDialogSlots._(
        s.overlay,
        s.content,
        s.header,
        s.body,
        s.footer,
        s.title,
        s.description,
      );
    }
    final s = RaftDialogRecipe.resolve(
      theme: t.recipeTheme,
      size: RaftDialogRecipeSize.values.byName(size.name),
      states: states,
      tokens: rt,
    );
    return RaftDialogSlots._(
      s.overlay,
      s.content,
      s.header,
      s.body,
      s.footer,
      s.title,
      s.description,
    );
  }

  final RaftSlotStyle overlay, content, header, body, footer, title;
  final RaftSlotStyle description;
}

class _DialogScope extends InheritedWidget {
  const _DialogScope({
    required this.kind,
    required this.size,
    required super.child,
  });
  final RaftDialogKind kind;
  final RaftDialogSize size;

  static _DialogScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DialogScope>();

  @override
  bool updateShouldNotify(_DialogScope old) =>
      kind != old.kind || size != old.size;
}

RaftDialogSlots _slots(BuildContext context) {
  final scope = _DialogScope.of(context);
  return RaftDialogSlots.of(
    context,
    kind: scope?.kind ?? RaftDialogKind.dialog,
    size: scope?.size ?? RaftDialogSize.md,
  );
}

/// `DialogContent` / `AlertDialogContent`: the centered panel. Compose it
/// from [RaftDialogHeader], [RaftDialogBody] and [RaftDialogFooter], or use
/// the [title] / [content] / [actions] shorthand (Material `AlertDialog`
/// shape, for mechanical migration).
class RaftDialog extends StatelessWidget {
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
  }) : assert(child != null || title != null || content != null);

  /// Full custom content (header/body/footer parts).
  final Widget? child;

  /// Shorthand parts: a String or Widget title, body content, footer actions.
  final Object? title;
  final Widget? content;
  final List<Widget>? actions;
  final RaftDialogSize size;
  final RaftDialogKind kind;

  /// Corner close in the shorthand header (Dialog only; AlertDialog never).
  final bool showClose;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return _DialogScope(
      kind: kind,
      size: size,
      child: Builder(
        builder: (context) {
          final s = _slots(context);
          final media = MediaQuery.of(context);
          final viewport = media.size;
          // width: calc(100% - 32px); max-height: calc(100dvh - 32px).
          final width = (viewport.width - 32)
              .clamp(0.0, s.content.maxWidth ?? 448.0)
              .toDouble();
          final maxHeight = (viewport.height - 32 - media.viewInsets.bottom)
              .clamp(0.0, double.infinity)
              .toDouble();
          // Like a CSS portal, inherit the captured consumer text context;
          // only named slots may override its face, size, color or weight.
          final base = raftCssText.merge(DefaultTextStyle.of(context).style);
          final body =
              child ??
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    RaftDialogHeader(
                      title: title,
                      showClose: showClose && kind == RaftDialogKind.dialog,
                    ),
                  if (content != null)
                    Flexible(child: RaftDialogBody(child: content!)),
                  if (actions != null && actions!.isNotEmpty)
                    RaftDialogFooter(children: actions!),
                ],
              );
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
                    child: RaftRecipeBox(
                      style: s.content,
                      tokens: rt,
                      width: width,
                      clip: !t.brutal,
                      child: _Gapped(gap: gap, child: body),
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
  });
  final Object? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => RaftDialog(
    kind: RaftDialogKind.alert,
    title: title,
    content: content,
    actions: actions,
    showClose: false,
    semanticLabel: semanticLabel,
    child: child,
  );
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
  });
  final Object? title;
  final bool showClose;
  final Widget? trailing;

  /// Defaults to popping the route.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context);
    final close = showClose ? RaftDialogClose(onPressed: onClose) : null;
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

/// `DialogTitle` (brutal uppercase; `text-transform` applied to the string).
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
    return Semantics(
      header: true,
      child: Text(
        s.textTransform == 'uppercase' ? value.toUpperCase() : value,
        style: style,
      ),
    );
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
  });
  final VoidCallback? onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftGlyphButton(
      glyph: RaftGlyph.x,
      semanticLabel: raftText(context, semanticLabel),
      tone: t.brutal
          ? RaftButtonRecipeVariant.outline
          : RaftButtonRecipeVariant.ghost,
      size: t.brutal
          ? RaftButtonRecipeSize.iconMd
          : RaftButtonRecipeSize.iconSm,
      glyphSize: t.brutal ? 20 : 16,
      quiet: !t.brutal,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
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
                  : t.semantic.foregroundPlaceholder)
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
    super.settings,
  }) : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final bool dismissible;
  final String? label;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => dismissible;
  @override
  String? get barrierLabel => label ?? 'Dismiss';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildModalBarrier() => _DialogBarrier(
    animation: animation!,
    dismissible: dismissible,
    label: barrierLabel,
    capturedThemes: capturedThemes,
  );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(SafeArea(child: Builder(builder: builder)));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
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

class _DialogBarrier extends StatelessWidget {
  const _DialogBarrier({
    required this.animation,
    required this.dismissible,
    required this.label,
    required this.capturedThemes,
  });
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
        final blur = t.brutal ? 0.0 : 2.0;
        Widget layer = ColoredBox(color: color, child: const SizedBox.expand());
        if (blur > 0) {
          layer = BackdropFilter(
            // CSS blur(2px) = Gaussian sigma 2.
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: layer,
          );
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
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(
    RaftDialogRoute<T>(
      builder: builder,
      dismissible: barrierDismissible,
      label: barrierLabel,
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
