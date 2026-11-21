import '../raft/button.dart';

// raft-ui Dialog / AlertDialog (`dialog`, `alertDialog` recipes): overlay
// (layer-backdrop, blur(2px)), centered content (calc(100% - 32px),
// max-width per size), Header (title + corner close), Body, Footer, Title,
// Description. Centred dialogs have no motion.
import 'dart:ui' show ImageFilter, SemanticsRole;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dialog_slots.dart';
import '../dialog_surface.dart';
import '../form_presentation.dart';
import '../stacked_actions.dart';
import '../dialog_card.dart' show RaftModalBackdrop, RaftModalCardCap;
import '../tap_slop.dart';
import '../text_scaling.dart';
import '../dismiss_scope.dart';
import '../icons.dart';
import '../localization.dart';
import '../panel_layout.dart' show RaftPanelAction;
import '../recipe_surface.dart';
import '../recipes/alert_dialog.g.dart';
import '../recipes/button_variants.g.dart';
import '../recipes/dialog.g.dart';
import '../recipes/web_dialog_card.g.dart';
import '../recipes/dialog_surface.g.dart';
import '../recipes/recipe_runtime.dart';
import '../components.dart';
import '../theme.dart';
import '../tokens/tokens.dart' show RaftDesktopMetrics;
import '../settings_layout.dart' show RaftSpace;
import '../agent_create_form.dart' show buildAgentDialog;
import '../panel_layout.dart' show RaftCssText;

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
      responsive: true,
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
      final s = RaftAlertDialogRecipe.resolve(states: states, tokens: rt);
      RaftSlotStyle bind(RaftSlotStyle style, String slot) =>
          raftDialogSlot(t, style, slot);
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
      {'size': size.name, 'bar': bar.toString()},
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
    super.key,
    required this.first,
    required this.afterHeader,
    required super.child,
  });
  final bool first, afterHeader;
  @override
  bool updateShouldNotify(_DialogPartScope old) =>
      first != old.first || afterHeader != old.afterHeader;
}

// Keep a caller's keyed children associated with the same scope when the
// children are reordered without reusing a GlobalKey on two widgets.
class _DialogPartKey extends ValueKey<Key> {
  const _DialogPartKey(super.value);
}

/// `DialogContent` / `AlertDialogContent`: the centered panel. Compose it
/// from [RaftDialogHeader], [RaftDialogBody] and [RaftDialogFooter], or use
/// the [title] / [content] / [actions] shorthand (Material `AlertDialog`
/// shape, for mechanical migration).
class RaftDialog extends StatelessWidget {
  /// Compatibility call shape for the former agent/runtime form shell, built
  /// on [RaftDialog.card].
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
       _cssShellTitle = false,
       titleGlyph = null,
       footer = null,
       cardActions = null,
       sheetCommit = null,
       footerGap = null,
       description = null,
       pinFooterAtLargeText = false,
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
    this.sheetCommit,
    this.footerGap,
    this.pinFooterAtLargeText = false,
    Widget? actions,
    this.contentKey,
    this.closeEnabled = true,
    this.showClose = true,
    this.description,
  }) : assert(!pinFooterAtLargeText || actions == null),
       _card = true,
       _shell = false,
       _cssShellTitle = false,
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
       semanticLabel = title;

  /// The standard Dialog anatomy used by Web confirmations and editors.
  const RaftDialog.shell({
    super.key,
    required String title,
    bool cssTitle = false,
    required Widget? body,
    required List<Widget> footer,
    this.onClose,
    this.maxWidth = 384,
    Key? surfaceKey,
    this.outlineClose = false,
  }) : _card = false,
       _shell = true,
       _cssShellTitle = cssTitle,
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
       sheetCommit = null,
       footerGap = null,
       description = null,
       pinFooterAtLargeText = false;

  final bool _shell, _cssShellTitle, outlineClose;

  /// DialogCard `description`: `DialogDescription` under the title with `mt-1
  /// mb-4`; the header then drops its own `mb-4`.
  final String? description;
  final bool _card;
  final double? maxWidth, footerGap;
  final RaftGlyph? titleGlyph;
  final Widget? footer, cardActions;

  /// The persistent header action for a narrow dialog. When supplied, it
  /// takes the place of the desktop footer in the sheet.
  final Widget? sheetCommit;

  /// Keep both the header and footer visible while the body scrolls at large
  /// text sizes. This preserves the controls of a form migrated from an
  /// AlertDialog; it cannot be combined with the separately pinned actions.
  final bool pinFooterAtLargeText;

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

  /// Corner close in the shorthand or card header; AlertDialog never has one.
  final bool showClose;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (_shell) return _ShellDialogParts(dialog: this);
    if (_card) return _CardDialogParts(dialog: this);
    return _DialogScope(
      kind: kind,
      size: size,
      bar: bar,
      child: Builder(
        builder: (context) {
          final s = _slots(context);
          final media = MediaQuery.of(context);
          final viewport = media.size;
          final available = Size(
            viewport.width,
            math.max(0, viewport.height - media.viewInsets.bottom),
          );
          final width =
              (_dialogLength(s.content['width'], available, horizontal: true) ??
                      available.width)
                  .clamp(0.0, maxWidth ?? s.content.maxWidth ?? 448.0)
                  .toDouble();
          final maxHeight = math.max(
            0.0,
            _dialogLength(s.content['max-height'], available) ??
                available.height,
          );
          final height = _dialogLength(s.content['height'], available);
          // A CSS portal inherits the document typography, outside the
          // trigger's decorated text ancestry.
          final base = raftCssText
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
          if (body is Column) {
            final column = body;
            body = _copyDialogColumn(
              column,
              children: [
                for (var i = 0; i < column.children.length; i++)
                  _DialogPartScope(
                    key: column.children[i].key == null
                        ? null
                        : _DialogPartKey(column.children[i].key!),
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
                      child: RaftDialogSurface(
                        key: contentKey,
                        surfaceStyle: s.content,
                        child: Material(
                          type: MaterialType.transparency,
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
            ),
          );
        },
      ),
    );
  }
}

Column _copyDialogColumn(
  Column source, {
  required List<Widget> children,
  double? spacing,
}) => Column(
  key: source.key,
  mainAxisAlignment: source.mainAxisAlignment,
  mainAxisSize: source.mainAxisSize,
  crossAxisAlignment: source.crossAxisAlignment,
  textDirection: source.textDirection,
  verticalDirection: source.verticalDirection,
  textBaseline: source.textBaseline,
  spacing: spacing ?? source.spacing,
  children: children,
);

/// Inserts the content slot's flex/grid `gap` between direct part children.
class _Gapped extends StatelessWidget {
  const _Gapped({required this.gap, required this.child});
  final double gap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = child;
    if (gap == 0 || c is! Column) return c;
    return _copyDialogColumn(c, children: c.children, spacing: c.spacing + gap);
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
  Widget build(BuildContext context) {
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
  const RaftDialogTitle(this.text, {super.key, this.cssLineBox = false});
  final String text;
  final bool cssLineBox;
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
      child: cssLineBox
          ? RaftCssText(value, style: style)
          : Text(value, style: style),
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
  const RaftDialogBody({super.key, required this.child, this.verticalPadding});
  final Widget child;
  final double? verticalPadding;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = _slots(context).body;
    if (_DialogScope.of(context)?.bar ?? false) {
      return RaftRecipeBox(
        style: s,
        tokens: t.recipeTokens,
        clip: true,
        child: child,
      );
    }
    final padding = s.padding;
    final scrollPadding = verticalPadding == null
        ? padding
        : padding.copyWith(top: verticalPadding, bottom: verticalPadding);
    return DefaultTextStyle.merge(
      style: s.text(t.recipeTokens),
      child: SingleChildScrollView(padding: scrollPadding, child: child),
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
    return RaftRecipeBox(
      style: s,
      tokens: t.recipeTokens,
      child: children.length == 1 && children.first is RaftDialogActions
          ? children.first
          : RaftDialogActions(children: children),
    );
  }
}

/// The footer's row of actions (raft-ui `stacked-actions`): one `justify-end`
/// row, or, when it does not fit, a full-width column with the commit on top
/// and the ghost Cancel framed.
class RaftDialogActions extends StatelessWidget {
  const RaftDialogActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final s = _slots(context).footer;
    return RaftActionRow(children: children, gap: s.columnGap ?? 0);
  }
}

/// `DialogClose` default rendering: `Button ghost icon-sm` + `p-0
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
    // Both X variants pull from the DialogCard close margin (`-my-1.5` and
    // the icon bar end pull: 7px by touch, 5px with a mouse at >=768) and
    // take the `icon-md` side from the Button recipe (32, 28 with a mouse).
    final product = RaftWebDialogCardRecipe.resolve(
      states: t.recipeStates(responsive: true),
      tokens: t.recipeTokens,
    );
    final sized =
        t.themeOverrides?.geometry.containsKey('size.dialogClose') == true;
    // With a mouse at >=768 the X is the 28px bar button at radius 6
    // (`BAR_BUTTON_DESKTOP`), as [RaftCloseButton] draws it.
    final barSize = !sized && t.desktop
        ? RaftDesktopMetrics.barButtonSize
        : null;
    final extent = sized
        ? null
        : barSize ??
              RaftButtonRecipe.resolve(
                variant: RaftButtonRecipeVariant.ghost,
                size: RaftButtonRecipeSize.iconMd,
                states: t.recipeStates(responsive: true),
                tokens: t.recipeTokens,
              ).root.width;
    return RaftDialogCloseOutset(
      extent: extent,
      verticalOutset: bar && !_product ? 0 : -product.close.margin.top,
      endOutset: -product.close.margin.right,
      child: RaftButton(
        label: '',
        glyph: RaftGlyph.x,
        semanticLabel: raftText(context, semanticLabel),
        tooltip: raftText(context, semanticLabel),
        uiVariant:
            this.outlined || t.option('dialog.close', or: 'ghost') == 'outline'
            ? RaftButtonVariant.outline
            : RaftButtonVariant.ghost,
        uiSize: _product ? RaftButtonSize.iconSm : RaftButtonSize.iconMd,
        physicalHeight: barSize,
        visualWidth: barSize,
        styleBuilder: barSize == null
            ? null
            : (context, state, style) => style.copyWith(
                properties: {
                  ...style.properties,
                  for (final corner in [
                    'top-left',
                    'top-right',
                    'bottom-left',
                    'bottom-right',
                  ])
                    'border-$corner-radius': const CssNum(
                      RaftDesktopMetrics.barButtonRadius,
                      'px',
                    ),
                },
              ),
        metricsKey:
            t.themeOverrides?.geometry.containsKey('size.dialogClose') == true
            ? 'dialogClose'
            : null,
        glyphSize:
            t.themeOverrides?.geometry['size.dialogCloseGlyph'] ??
            (_product ? product.glyph.width : null) ??
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
    this.tooltip,
  });
  final RaftGlyph glyph;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant tone;
  final RaftButtonRecipeSize size;
  final double? glyphSize;

  final String? tooltip;

  @override
  Widget build(BuildContext context) => RaftButton(
    glyph: glyph,
    tone: tone,
    size: size,
    glyphSize: glyphSize,
    semanticLabel: semanticLabel,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

/// The dialog route: `layer-backdrop` overlay (`backdrop-blur 2px`)
/// fading in `duration-150 ease-out`; content fades/scales from 0.98.
class RaftDialogRoute<T> extends PopupRoute<T> {
  RaftDialogRoute({
    required this.builder,
    required this.capturedThemes,
    this.dismissible = true,
    this.label,
    this.overModal = false,
    this.nestedBackdrop,
    this.motionDuration = const Duration(milliseconds: 150),
    this.modal = false,
    this.browserBackdropBlend = false,
    super.settings,
  }) : super(traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final bool dismissible;
  final String? label;

  /// Opened over another Modal's black/60 scrim (see [RaftDialogBarrier]).
  final bool overModal;

  /// Explicit backdrop scope for sibling dialog roots.
  final bool? nestedBackdrop;
  final Duration motionDuration;

  /// The product composition owns its backdrop and layout, as Web Modal does.
  final bool modal;

  /// Use the browser's 8-bit source-over blend over an opaque host.
  final bool browserBackdropBlend;

  // The live dialog routes, bottom first: one opened over another of the same
  // navigator uses the `nested` scrim, as raft-ui does for a Dialog under another overlay.
  static final List<RaftDialogRoute<dynamic>> _live = [];

  /// Over another dialog route, or flagged [overModal] by its opener.
  bool get nested =>
      nestedBackdrop ??
      (overModal ||
          _live.where((r) => r.navigator == navigator).toList().indexOf(this) >
              0);

  @override
  void install() {
    super.install();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    super.dispose();
  }

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
          nested: nested,
          browserBackdropBlend: browserBackdropBlend,
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
          ? _nestedScope(
              Material(
                type: MaterialType.transparency,
                child: Builder(builder: builder),
              ),
            )
          : DisplayFeatureSubScreen(
              child: SafeArea(child: Builder(builder: builder)),
            ),
    ),
  );

  Widget _nestedScope(Widget child) =>
      nested ? RaftDialogNested(child: child) : child;

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
/// with the 2px blur. One scrim for every floating window.
class RaftDialogBarrier extends StatelessWidget {
  const RaftDialogBarrier({
    required this.animation,
    required this.dismissible,
    required this.label,
    required this.capturedThemes,
    this.overModal = false,
    this.nested = false,
    this.browserBackdropBlend = false,
  });
  final bool overModal;

  /// Opened over another dialog: `layer-backdrop-nested` in the Raft look.
  final bool nested, browserBackdropBlend;
  final Animation<double> animation;
  final bool dismissible;
  final String? label;
  final CapturedThemes capturedThemes;

  @override
  Widget build(BuildContext context) => capturedThemes.wrap(
    Builder(
      builder: (context) {
        final t = RaftTokens.of(context);
        final blur = t.size('blur.dialogBackdrop', fallback: 0);
        final recipe = RaftDialogBackdrop.overlayOf(context, nested: nested);
        final color = recipe.backgroundColor?.resolve(t.recipeTokens);
        final opaqueBlend =
            browserBackdropBlend &&
            color != null &&
            color.r == 0 &&
            color.g == 0 &&
            color.b == 0 &&
            color.a > 0 &&
            color.a < 1;
        Widget layer = opaqueBlend
            ? const SizedBox.expand()
            : RaftDialogBackdrop(
                nested: nested,
                child: const SizedBox.expand(),
              );
        ImageFilter? filter = blur > 0
            ? ImageFilter.blur(sigmaX: blur, sigmaY: blur)
            : null;
        if (opaqueBlend) {
          final scale = (256 - (color.a * 255).round()) / 256;
          // Chromium's black source-over path truncates the scaled bytes.
          // The color filter rounds to the nearest byte.
          const bias = -0.5 + 1 / 1024;
          final dim = ColorFilter.matrix([
            scale,
            0,
            0,
            0,
            bias,
            0,
            scale,
            0,
            0,
            bias,
            0,
            0,
            scale,
            0,
            bias,
            0,
            0,
            0,
            1,
            0,
          ]);
          filter = filter == null
              ? dim
              : ImageFilter.compose(outer: dim, inner: filter);
        }
        if (filter != null) {
          layer = BackdropFilter(filter: filter, child: layer);
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
  bool? nestedBackdrop,
  bool modal = false,
  bool browserBackdropBlend = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(
    RaftDialogRoute<T>(
      builder: builder,
      dismissible: barrierDismissible,
      label: barrierLabel,
      overModal: overModal,
      nestedBackdrop: nestedBackdrop,
      modal: modal,
      browserBackdropBlend: browserBackdropBlend,
      motionDuration: Duration.zero,
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
    builder: (context) {
      return RaftAlertDialog(
        title: title,
        content:
            content ??
            (description == null ? null : RaftDialogDescription(description)),
        actions: [
          // AlertDialogCancel `size="lg"` (ghost) + AlertDialogAction `lg`.
          RaftButton(
            label: cancelLabel,
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.lg,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          RaftButton(
            label: confirmLabel,
            tone: destructive
                ? RaftButtonRecipeVariant.danger
                : RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.lg,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
