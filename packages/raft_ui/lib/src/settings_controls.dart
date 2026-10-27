import 'form_controls.dart' show RaftField, RaftLegacyField;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialog_slots.dart';
import 'banner.dart';
import 'raft/button.dart';
import 'tap_slop.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'error_presentation.dart';
import 'form_controls.dart'
    show
        RaftTextInput,
        RaftTextarea,
        RaftLegacyInput,
        RaftInputGroup,
        RaftInputGroupAddon,
        RaftLegacyGroup;
import 'dialog_card.dart' show RaftTextSteps;
import 'form_presentation.dart';
import 'hover_region.dart';
import 'icons.dart';
import 'recipe_min_height.dart';
import 'localization.dart';
import 'overlays/dialog.dart' show showRaftDialog;
import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/recipe_router.dart' show usesLegacyRecipes;
import 'recipes/recipe_runtime.dart';
import 'recipes/recipes.g.dart';
import 'recipes/token_binding.dart';
import 'settings_layout.dart';
import 'sized_image.dart';
import 'theme.dart' hide RaftFieldRecipe;
import 'text_scaling.dart' show RaftScaled;
import 'tooltip.dart' show RaftTooltip;

/// Recipe-driven controls the Settings pages compose. Every geometry, colour
/// and type value comes from the generated raft-ui recipes
/// (`buttonVariants`, `input`, `inputGroup`, `field`, `dialog`); callsite
/// class overrides from the Web JSX are passed explicitly and cited.

TextStyle _slotText(RaftTokens t, RaftSlotStyle s, {TextStyle? base}) {
  final tokens = RaftRecipeTokens(t);
  final style = s.textStyle(tokens);
  return (base ??
          RaftTypography.heading(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w400,
          ))
      .merge(style)
      .copyWith(fontVariations: const [], fontFamilyFallback: t.fontFallback);
}

/// raft-ui `Button` rendered from `RaftButtonRecipe`.
class RaftSettingsRecipeButton extends StatefulWidget {
  const RaftSettingsRecipeButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RaftButtonRecipeVariant.outline,
    this.size = RaftButtonRecipeSize.md,
    this.glyph,
    this.glyphSize,
    this.expand = false,
    this.disabledOpacity,
    this.restColor,
    this.trailingGlyph,
    this.semanticLabel,
  });

  /// Accessible name for icon-only buttons.
  final String? semanticLabel;

  /// Icon after the label (`Finish setup <ChevronRight size={14} />`).
  final RaftGlyph? trailingGlyph;
  final String label;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant variant;
  final RaftButtonRecipeSize size;
  final RaftGlyph? glyph;

  /// Callsite icon size (`<Trash2 size={14} />`); defaults to the recipe's
  /// `& svg:not([class*='size-'])` size.
  final double? glyphSize;

  /// Block layout (a flex-col parent stretches the button).
  final bool expand;

  /// Callsite `disabled:opacity-*` override (ConfirmDialog uses 80 / 30).
  final double? disabledOpacity;

  /// Callsite `text-*` colour while not hovered (DialogClose's
  /// `text-foreground-placeholder hover:text-foreground-strong`).
  final Color? restColor;
  @override
  State<RaftSettingsRecipeButton> createState() =>
      _RaftSettingsRecipeButtonState();
}

class _RaftSettingsRecipeButtonState extends State<RaftSettingsRecipeButton> {
  bool _hovered = false;

  /// `button.surface`: `ported` draws the shared raft-ui [RaftButton] (size,
  /// type, colour roles, edge, motion and the disabled surface from the pack;
  /// callsite overrides from the Web JSX stay explicit: icon size, disabled
  /// opacity and the rest colour of a ghost close). `recipe` keeps the a57b9dab
  /// drawing: RaftButton cannot yet reproduce its Inter text (the recipe clears
  /// the font variations and tracks the heading face), so the pre-theme looks
  /// are not routed through it.
  @override
  Widget build(BuildContext context) {
    if (RaftTokens.of(context).option('button.surface', or: 'recipe') !=
        'ported') {
      return _recipe(context);
    }
    final both = widget.glyph != null && widget.trailingGlyph != null;
    final rest = widget.restColor != null && !_hovered
        ? widget.restColor
        : null;
    Widget draw(bool expand) => RaftButton(
      label: widget.label,
      onPressed: widget.onPressed,
      uiVariant: RaftButtonVariant.fromRecipe(widget.variant),
      uiSize: RaftButtonSize.fromRecipe(widget.size),
      glyph: widget.trailingGlyph ?? widget.glyph,
      iconInlineEnd: widget.trailingGlyph != null,
      leading: both
          ? RaftIcon(widget.glyph!, size: widget.glyphSize ?? 16)
          : null,
      glyphSize: widget.glyphSize,
      expand: expand,
      disabledOpacity: widget.disabledOpacity,
      semanticLabel: widget.semanticLabel,
      foreground: rest,
    );
    // `w-full` stretches only inside a bounded parent; in a Row it was the
    // button's natural width.
    final button = widget.expand
        ? LayoutBuilder(builder: (context, box) => draw(box.hasBoundedWidth))
        : draw(false);
    if (widget.restColor == null) return button;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: button,
    );
  }

  Widget _recipe(BuildContext context) => RaftInteractive(
    onPressed: widget.onPressed,
    builder: (context, state) {
      final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
      final s = RaftButtonRecipe.resolve(
        theme: raftRecipeTheme(t),
        variant: widget.variant,
        size: widget.size,
        states: t.recipeStates(
          hovered: state.hovered,
          pressed: state.pressed,
          focusVisible: state.focusVisible,
          disabled: !state.enabled,
        ),
        tokens: tokens,
      ).root;
      final base = _slotText(t, s);
      final text = widget.restColor != null && !state.hovered
          ? base.copyWith(color: widget.restColor)
          : base;
      final svg = s.target("& svg:not([class*='size-'])");
      final opacity = !state.enabled
          ? (widget.disabledOpacity ?? s.opacity ?? 1)
          : (s.opacity ?? 1);
      final grows = RaftScaled.grows(context);
      final button = Opacity(
        opacity: opacity,
        child: RaftRecipeBox(
          style: raftGrowingHeight(context, s),
          tokens: tokens,
          applyText: false,
          applyOpacity: false,
          overflowCenter: true,
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.glyph != null) ...[
                RaftIcon(
                  widget.glyph!,
                  size: widget.glyphSize ?? svg?.width ?? 16,
                  color: text.color,
                ),
                if (widget.label.isNotEmpty) SizedBox(width: s.columnGap ?? 6),
              ],
              if (widget.label.isNotEmpty)
                // Above the default text size the label wraps inside the
                // button instead of escaping it.
                if (grows)
                  Flexible(
                    child: Text(
                      raftText(context, widget.label),
                      textAlign: TextAlign.center,
                      style: text,
                    ),
                  )
                else
                  Text(
                    raftText(context, widget.label),
                    maxLines: 1,
                    softWrap: false,
                    style: text,
                  ),
              if (widget.trailingGlyph != null) ...[
                SizedBox(width: s.columnGap ?? 6),
                RaftIcon(
                  widget.trailingGlyph!,
                  size: widget.glyphSize ?? svg?.width ?? 16,
                  color: text.color,
                ),
              ],
            ],
          ),
        ),
      );
      final name = widget.semanticLabel;
      return name == null
          ? button
          : Semantics(
              button: true,
              enabled: state.enabled,
              label: name,
              excludeSemantics: true,
              child: button,
            );
    },
  );
}

/// FormField.tsx `labelStyle="plain" size="compact"`: the settings forms' compact [RaftField].
class RaftSettingsField extends StatelessWidget {
  const RaftSettingsField({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => RaftField(
    label: label,
    compact: true,
    legacy: RaftLegacyField.settings,
    child: child,
  );
}

/// raft-ui `Input` (`input` recipe) with a callsite text size.
class RaftRecipeInput extends StatelessWidget {
  const RaftRecipeInput({
    super.key,
    this.fieldKey,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.mono = false,
    this.padding,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
    this.numeric = false,
    this.upperCase = false,
    this.height,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.recipeText = false,
    this.obscure = false,
    this.readOnly = false,
  });

  /// `readOnly`.
  final bool readOnly;

  /// `type="password"`.
  final bool obscure;

  /// No callsite `text-sm`: the recipe's own size and leading (Elegant 14/20,
  /// Brutal 16/24).
  final bool recipeText;

  /// Callsite fixed box height (`box-border h-10`); content centres.
  final double? height;

  /// Caller-owned focus (e.g. commit on blur); else the field owns one.
  final FocusNode? focusNode;

  /// `disabled` (the recipe's disabled state).
  final bool enabled;

  /// `inputMode="numeric" pattern="[0-9]*"`: digits only.
  final bool numeric;

  /// Capitalise typed characters (data entry such as promotion codes; not a
  /// display transform).
  final bool upperCase;

  /// `type="number"` and friends.
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// `maxLength`.
  final int? maxLength;

  /// Key for the inner [TextField] (tests and focus lookups).
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool mono;

  /// JSX `autoFocus`.
  final bool autofocus;

  /// Callsite padding override (`theme-brutal:p-2` on the account name).
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => RaftTextInput(
    fieldKey: fieldKey,
    controller: controller,
    hintText: placeholder,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    mono: mono,
    padding: padding,
    focusNode: focusNode,
    enabled: enabled,
    numeric: numeric,
    upperCase: upperCase,
    height: height,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLength: maxLength,
    obscureText: obscure,
    readOnly: readOnly,
    autofocus: autofocus,
    // raft-ui 0.7.0 `Input` text: the Web callsites set no `text-sm` any more; the frozen looks keep it.
    legacy: recipeText
        ? RaftLegacyInput.settingsPlain
        : RaftLegacyInput.settings,
  );
}

/// raft-ui `Textarea` (`textarea` recipe) with the callsite `text-sm
/// leading-relaxed` and a `min-h-*` box (MachineDetailPanel description).
class RaftRecipeTextarea extends StatelessWidget {
  const RaftRecipeTextarea({
    super.key,
    this.fieldKey,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.minHeight = 64,
    this.maxLength,
    this.autofocus = false,
    this.lineHeight = 1.625,
    this.recipeText = false,
  });

  /// No callsite text size / leading: the recipe's own (Elegant 14/20, Brutal
  /// 16/24).
  final bool recipeText;

  /// Callsite leading (`leading-relaxed` 1.625 by default; plain `text-sm` 20/14).
  final double lineHeight;
  final Key? fieldKey;
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final double minHeight;
  final int? maxLength;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => RaftTextarea(
    fieldKey: fieldKey,
    controller: controller,
    hintText: placeholder,
    onChanged: onChanged,
    maxLength: maxLength,
    autofocus: autofocus,
    minHeight: minHeight,
    // Callsite `text-sm leading-relaxed` unless the recipe's own text is wanted.
    textStep: recipeText ? null : RaftTextSteps.sm,
    lineHeight: recipeText ? null : lineHeight,
    legacy: RaftLegacyInput.settings,
  );
}

/// SlugInput.tsx / PrefixedInput: raft-ui `InputGroup` with an
/// `InputGroupAddon.Text variant="container"` prefix.
class RaftSettingsPrefixedInput extends StatefulWidget {
  const RaftSettingsPrefixedInput({
    super.key,
    required this.prefix,
    this.controller,
    this.value,
    this.placeholder,
    this.readOnly = false,
    this.autofocus = false,
    this.mono = false,
    this.onChanged,
    this.rootColor,
    this.rootBorderColor,
    this.flat = false,
    this.textColor,
  });
  final String prefix;
  final TextEditingController? controller;

  /// Read-only value (ignored when [controller] is given).
  final String? value;
  final String? placeholder;
  final bool readOnly, mono;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Callsite root overrides (`bg-*`, `border-*`, `shadow-none`) and the
  /// input `text-*` colour.
  final Color? rootColor, rootBorderColor, textColor;
  final bool flat;
  @override
  State<RaftSettingsPrefixedInput> createState() =>
      _RaftSettingsPrefixedInputState();
}

class _RaftSettingsPrefixedInputState extends State<RaftSettingsPrefixedInput> {
  final focus = FocusNode();
  late final TextEditingController own = TextEditingController(
    text: widget.value ?? '',
  );
  TextEditingController get controller => widget.controller ?? own;
  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant RaftSettingsPrefixedInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && widget.value != oldWidget.value) {
      own.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    focus.dispose();
    own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RaftInputGroup(
    leading: RaftInputGroupAddon.text(widget.prefix),
    variant: RaftInputGroupRecipeVariant.container,
    controller: controller,
    focusNode: focus,
    hintText: widget.placeholder,
    readOnly: widget.readOnly,
    autofocus: widget.autofocus,
    mono: widget.mono,
    onChanged: widget.onChanged,
    backgroundColor: widget.rootColor,
    borderColor: widget.rootBorderColor,
    textColor: widget.textColor,
    flat: widget.flat,
    legacy: RaftLegacyGroup.settings,
  );
}

/// Inline identifier surface used by confirmation copy. The consumer owns the
/// text span and baseline; this component owns the shared slug chip chrome.
class RaftConfirmSlug extends StatelessWidget {
  const RaftConfirmSlug({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors['layer-confirm-slug'] ?? t.colors['fill-muted'],
        borderRadius: BorderRadius.circular(
          t.size('radius.sticker', fallback: 4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.size('space.confirmSlugInline', fallback: 4),
        ),
        child: RaftCssText(text, style: style),
      ),
    );
  }
}

/// ConfirmDialog.tsx on raft-ui `Dialog` (`dialog` recipe, `max-w-sm`).
class RaftConfirmDialog extends StatefulWidget {
  const RaftConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmVariant = RaftButtonRecipeVariant.danger,
    this.confirmEnabled,
    this.confirmKey,
    this.maxWidth = 384,
    this.surfaceKey,
    this.showCancel = true,
    this.onConfirm,
    this.loadingLabel,
    this.confirmGlyph,
    this.actionSize,
    this.plainMessage = false,
  });

  /// ConfirmDialog `actionSize` (`xs` for confirmations in dense surfaces).
  final RaftButtonRecipeSize? actionSize;

  /// Caller-owned rich content may opt out of the default explanation frame.
  final bool plainMessage;

  /// ConfirmDialog `confirmIcon` (`<RotateCcw size={14} />`).
  final RaftGlyph? confirmGlyph;

  /// ConfirmDialog `onConfirm`: when set, Confirm runs it with the dialog
  /// open (both buttons disabled, Confirm reads [loadingLabel] beside a
  /// spinner) and closes with `true` once it completes. A failure keeps the
  /// dialog open and shows the error under the message.
  final Future<void> Function()? onConfirm;

  /// ConfirmDialog `loadingLabel` (default "Working…").
  final String? loadingLabel;

  /// Key of the dialog surface itself (`dialog-content`).
  final Key? surfaceKey;

  /// ConfirmDialog `hideCancel` inverse.
  final bool showCancel;
  final String title;

  /// Plain copy rendered in `text-sm leading-relaxed text-foreground-muted`.
  final String? message;

  /// Rich message (the caller's own layout inside the same text style).
  final Widget? content;
  final String confirmLabel, cancelLabel;
  final RaftButtonRecipeVariant confirmVariant;

  /// `confirmDisabled` inverse; null keeps the confirm action enabled.
  final ValueListenable<bool>? confirmEnabled;
  final Key? confirmKey;
  final double maxWidth;

  /// [overModal]: the confirmation opens over another Modal (the channel
  /// members dialog), so its Brutal scrim composites over that one's.
  static Future<bool?> show(
    BuildContext context,
    RaftConfirmDialog dialog, {
    bool overModal = false,
  }) => showRaftDialog<bool>(
    context: context,
    barrierDismissible: false,
    overModal: overModal,
    builder: (_) => dialog,
  );

  /// `text-sm leading-relaxed text-foreground-muted` (font-normal body).
  static TextStyle messageStyle(RaftTokens t) => RaftTypography.body(
    t,
    size: t.size('type.confirmBody.size', fallback: 14),
    line: t.size('type.confirmBody.line', fallback: 22.75),
    color: t.muted,
  );

  @override
  State<RaftConfirmDialog> createState() => _RaftConfirmDialogState();
}

class _RaftConfirmDialogState extends State<RaftConfirmDialog> {
  bool loading = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next confirm starts; the dialog state is dropped when it closes.
  String? error;

  Future<void> confirm() async {
    final run = widget.onConfirm;
    if (run == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final route = ModalRoute.of(context);
    try {
      await run();
      if (mounted && route?.isActive == true) {
        final navigator = route!.navigator;
        if (route.isCurrent) {
          navigator?.pop(true);
        } else {
          // An async action can finish after another destination opened.
          // Complete only this confirmation, never that newer route.
          navigator?.removeRoute(route, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          // Web ConfirmDialog: the server's error text, else the generic copy.
          error = raftErrorMessage(context, e);
        });
      }
    }
  }

  void cancel() {
    if (!loading) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final title = widget.title, message = widget.message;
    final content = widget.content, maxWidth = widget.maxWidth;
    final t = RaftTokens.of(context);
    final actionHeight = t.size('size.confirmAction', fallback: 44);
    final actionSize = widget.actionSize == null
        ? actionHeight <= t.size('size.control.sm', fallback: 32)
              ? RaftButtonSize.sm
              : RaftButtonSize.lg
        : RaftButtonSize.fromRecipe(widget.actionSize!);
    Widget body = DefaultTextStyle.merge(
      style: RaftConfirmDialog.messageStyle(t),
      child: content ?? RaftCssText(raftText(context, message ?? '')),
    );
    if (!widget.plainMessage &&
        widget.confirmVariant == RaftButtonRecipeVariant.danger &&
        t.option('confirm.explanation', or: 'plain') == 'dangerBanner') {
      body = RaftBanner(
        status: RaftBannerRecipeStatus.destructive,
        glyph: RaftGlyph.octagonAlert,
        live: false,
        descriptionBuilder: (style) => DefaultTextStyle.merge(
          style: style,
          child: content ?? RaftCssText(raftText(context, message ?? '')),
        ),
      );
    }
    if (error case final error?) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          // ConfirmDialog: `<Banner intent="warning" className="mt-4">`.
          const SizedBox(height: 16),
          RaftErrorBanner(error),
        ],
      );
    }
    // Web ConfirmDialog gates every close on `loading`: Escape, Back and the
    // X all wait for the running confirm.
    return PopScope(
      canPop: !loading,
      child: RaftDialogShell(
        surfaceKey: widget.surfaceKey,
        title: title,
        maxWidth: maxWidth,
        onClose: loading ? null : cancel,
        body: body,
        footer: [
          if (widget.showCancel)
            RaftButton(
              label: widget.cancelLabel,
              uiSize: actionSize,
              physicalHeight: widget.actionSize == null ? actionHeight : null,
              uiVariant:
                  t.option('dialog.cancelSurface', or: 'outline') == 'ghost'
                  ? RaftButtonVariant.ghost
                  : RaftButtonVariant.outline,
              onPressed: loading ? null : cancel,
            ),
          ValueListenableBuilder<bool>(
            valueListenable:
                widget.confirmEnabled ?? const AlwaysStoppedAnimation(true),
            builder: (context, enabled, _) => RaftButton(
              key: widget.confirmKey,
              label: loading
                  ? widget.loadingLabel ?? 'Working…'
                  : widget.confirmLabel,
              glyph: loading ? null : widget.confirmGlyph,
              leading: loading
                  ? const RaftSpinner(recipeSize: RaftSpinnerRecipeSize.xs)
                  : null,
              tone: widget.confirmVariant,
              uiSize: actionSize,
              physicalHeight: widget.actionSize == null ? actionHeight : null,
              onPressed: enabled && !loading ? confirm : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// raft-ui `Dialog` chrome as ConfirmDialog.tsx composes it: the centred
/// `dialog` recipe surface (Brutal padded content with `gap-4`; Elegant
/// unpadded header `px-6 py-3`, body `px-6 py-5`, footer `px-6 py-3`), the
/// title with its close button, the scrolling [body] and the right
/// aligned [footer] actions. [onClose] null disables the close button.
///
/// In a presented form window on a phone ([showRaftForm], below 768) the shell
/// is the sheet: the title and close button pin to the top, [body] scrolls and
/// the [footer] actions pin to the bottom, above the keyboard.
class RaftDialogShell extends StatefulWidget {
  const RaftDialogShell({
    super.key,
    required this.title,
    required this.body,
    required this.footer,
    this.onClose,
    this.maxWidth = 384,
    this.surfaceKey,
    this.outlineClose = false,
  });
  final String title;
  final Widget body;
  final List<Widget> footer;
  final VoidCallback? onClose;
  final double maxWidth;
  final Key? surfaceKey;

  /// `<Button variant="outline" size="icon-md"><X className="size-5" />`
  /// (AgentProfileEditDialog) instead of the ConfirmDialog `DialogClose`.
  final bool outlineClose;

  @override
  State<RaftDialogShell> createState() => _RaftDialogShellState();
}

class _RaftDialogShellState extends State<RaftDialogShell> {
  final _body = GlobalKey(debugLabel: 'dialog shell body');
  final _footer = GlobalKey(debugLabel: 'dialog shell footer');

  @override
  Widget build(BuildContext context) {
    final title = widget.title,
        onClose = widget.onClose,
        maxWidth = widget.maxWidth,
        footer = widget.footer;
    final body = KeyedSubtree(key: _body, child: widget.body);
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final size = MediaQuery.sizeOf(context);
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: raftText(context, title),
        onClose: onClose,
        body: body,
        footer: KeyedSubtree(
          key: _footer,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: RaftSpace.x3,
            runSpacing: RaftSpace.x3,
            children: footer,
          ),
        ),
      );
    }
    final d = RaftDialogRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates(
        {if (t.dark) RaftRecipeStates.dark},
        size.width,
        size.height,
      ),
      tokens: tokens,
    );
    // Brutal: padded content with `gap-4`; Elegant: an unpadded popup whose
    // header (`px-6 py-3`), body (`px-6 py-5`) and footer (`px-6 py-3`) own
    // their padding and sit flush.
    final contentStyle = raftDialogSlot(t, d.content, 'content');
    final headerStyle = raftDialogSlot(t, d.header, 'header');
    final bodyStyle = raftDialogSlot(t, d.body, 'body');
    final footerStyle = raftDialogSlot(t, d.footer, 'footer');
    final titleStyle = _slotText(t, raftDialogSlot(t, d.title, 'title'));
    final gap = contentStyle.rowGap ?? 0;
    final outlinedClose =
        widget.outlineClose ||
        t.option('dialog.close', or: 'ghost') == 'outline';
    Widget close = RaftSettingsRecipeButton(
      key: const Key('confirm-dialog-close'),
      label: '',
      glyph: RaftGlyph.x,
      variant: outlinedClose
          ? RaftButtonRecipeVariant.outline
          : RaftButtonRecipeVariant.ghost,
      size: outlinedClose
          ? RaftButtonRecipeSize.iconMd
          : RaftButtonRecipeSize.iconSm,
      glyphSize: outlinedClose
          ? 20
          : t.size('size.dialogCloseGlyph', fallback: 16),
      restColor: outlinedClose
          ? null
          : t.colors['foreground-dialog-close'] ??
                t.colors['foreground-placeholder'],
      onPressed: raftGuardedClose(context, onClose),
    );
    if (!widget.outlineClose) close = RaftDialogCloseOutset(child: close);
    return RaftTapSlopHost(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            key: widget.surfaceKey,
            width: (size.width - 32).clamp(0, maxWidth).toDouble(),
            constraints: BoxConstraints(maxHeight: size.height - 32),
            padding: contentStyle.padding,
            decoration: contentStyle.decoration(tokens),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: headerStyle.padding,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.displayCase(
                            'dialogShellTitle',
                            raftText(context, title),
                          ),
                          style: titleStyle,
                        ),
                      ),
                      SizedBox(width: headerStyle.columnGap ?? 12),
                      close,
                    ],
                  ),
                ),
                SizedBox(height: gap),
                Flexible(
                  child: SingleChildScrollView(
                    padding: bodyStyle.padding,
                    child: body,
                  ),
                ),
                SizedBox(height: gap),
                Padding(
                  padding: footerStyle.padding,
                  child: KeyedSubtree(
                    key: _footer,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: footerStyle.columnGap ?? 12,
                      runSpacing: footerStyle.rowGap ?? 12,
                      children: footer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SettingsPanel.tsx DangerActionCard / AccountSignOutSection card: title,
/// `mt-0.5 text-xs` description and an action. [stacked] is the
/// DangerActionCard `flex-col gap-3` below `sm`, where the button stretches.
class RaftSettingsActionCard extends StatelessWidget {
  const RaftSettingsActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    this.stacked = false,
  });
  final String title, description;
  final Widget action;
  final bool stacked;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raftText(context, title),
          style: RaftTypography.body(
            t,
            size: 14,
            line: 20,
            weight: FontWeight.w700,
            color: t.strong,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          raftText(context, description),
          style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
        ),
      ],
    );
    final wide = MediaQuery.sizeOf(context).width >= 640;
    return RaftSettingsCard(
      child: stacked && !wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 12), action],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                action,
              ],
            ),
    );
  }
}

/// raft-ui `Badge` rendered from `RaftBadgeRecipe`.
class RaftSettingsRecipeBadge extends StatelessWidget {
  const RaftSettingsRecipeBadge({
    super.key,
    required this.label,
    this.variant,
    this.appearance,
    this.glyph,
  });
  final String label;
  final RaftBadgeRecipeVariant? variant;
  final RaftBadgeRecipeAppearance? appearance;

  /// Leading icon (callsite size, e.g. `<Shield size={10} />`).
  final RaftGlyph? glyph;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), tokens = RaftRecipeTokens(t);
    final s = RaftBadgeRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: variant,
      appearance: appearance,
      states: RaftRecipeStates({
        if (glyph != null) 'has:svg',
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: tokens,
    ).root;
    final text =
        _slotText(
          t,
          s,
          base: RaftTypography.body(t, size: 10, line: 10),
        ).copyWith(
          fontFamily: RaftInheritedFontScope.active(context)
              ? t.headingFont
              : null,
        );
    final value = raftText(context, label);
    return Container(
      // The recipe height is a minimum: a taller line box (Android Chinese
      // control profile, larger text) grows the capsule instead of clipping.
      constraints: BoxConstraints(minHeight: s.height ?? 0),
      padding: s.padding,
      decoration: s.decoration(tokens),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            // Raft: `[&_svg]:size-3.5` overrides the callsite `<Shield size={10}>`.
            RaftIcon(
              glyph!,
              size: usesLegacyRecipes(tokens)
                  ? 10
                  : (s.target('& svg')?.width ?? 10),
              color: text.color,
            ),
            SizedBox(width: s.columnGap ?? 4),
          ],
          Text(value, maxLines: 1, softWrap: false, style: text),
        ],
      ),
    );
  }
}

/// ProfileSection read-only name: `w-full border border-line-muted
/// bg-layer-inset p-2 text-sm font-mono text-foreground-muted
/// theme-brutal:border-2 theme-brutal:border-black/30 theme-brutal:bg-gray-50
/// theme-brutal:text-black/60`.
class RaftSettingsReadonlyValue extends StatelessWidget {
  const RaftSettingsReadonlyValue({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: text.insetFill,
        border: Border.all(color: text.softEdge, width: 1),
      ),
      child: Text(value, style: text.mono.copyWith(color: text.muted)),
    );
  }
}

/// AvatarSlot `profile-tile` for a server: `!size-16 !border-2`, `text-2xl
/// font-display font-bold theme-brutal:bg-soft-signal theme-brutal:text-black`.
///
/// With [onUpload] (ProfileSection `canEdit`) the tile is the Web upload
/// `<label>`: a tooltip, and a `bg-black/40` overlay with a white upload icon
/// while hovered or focused; [busy] dims it (`opacity-70`) and disables it.
class RaftServerProfileTile extends StatelessWidget {
  const RaftServerProfileTile({
    super.key,
    required this.initial,
    this.imageUrl,
    this.onUpload,
    this.busy = false,
    this.uploadLabel = 'Upload image',
    this.busyLabel = 'Uploading avatar',
  });
  final String initial;

  /// Resolved public avatar URL; the initial shows while it is absent or fails.
  final String? imageUrl;
  final VoidCallback? onUpload;
  final bool busy;
  final String uploadLabel, busyLabel;
  @override
  Widget build(BuildContext context) {
    if (onUpload == null) return _tile(context);
    // The control is labelled by its action, not by the initial it paints.
    final tile = ExcludeSemantics(child: _tile(context));
    final label = raftText(context, busy ? busyLabel : uploadLabel);
    return RaftTooltip(
      message: label,
      child: Opacity(
        opacity: busy ? .7 : 1,
        child: RaftInteractive(
          semanticLabel: label,
          onPressed: busy ? null : onUpload,
          builder: (context, state) {
            final active = state.hovered || state.focusVisible;
            return Stack(
              fit: StackFit.passthrough,
              children: [
                tile,
                if (active && !busy)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: RaftIcon(
                            RaftGlyph.upload,
                            size: 18,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget image(Widget fallback) => imageUrl == null
        ? fallback
        : RaftSizedImage.avatar(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
    // Elegant Avatar (human recipe): `border-2 border-transparent
    // bg-clip-padding`, the `rounded-full bg-fill-muted` fallback whose
    // `text-sm text-foreground-placeholder/70` wins over the slot's
    // text-2xl (font-display bold carries through).
    return SizedBox.square(
      dimension: 64,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.colors['fill-muted'],
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: image(
              Center(
                child: Text(
                  initial,
                  style:
                      RaftTypography.heading(
                        t,
                        size: 14,
                        line: 20,
                        weight: FontWeight.w700,
                      ).copyWith(
                        color: t.colors['foreground-placeholder']!.withValues(
                          alpha: t.colors['foreground-placeholder']!.a * .7,
                        ),
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

/// SettingsPanel.tsx preference block (`space-y-3`): a `text-sm font-bold`
/// title, a `text-xs` muted description (`mt-0.5`), an optional notice
/// (`mt-1 text-xs font-bold text-warning-strong
/// theme-brutal:text-brutal-orange`), then the control 12px below and an
/// optional error under it.
class RaftSettingsPreference extends StatelessWidget {
  const RaftSettingsPreference({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.notice,
    this.error,
    this.gapBefore = 0,
  });
  final String title;
  final String? description, notice, error;
  final Widget child;

  /// Space above the block (the form's `space-y-4` between blocks).
  final double gapBefore;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), text = RaftSettingsText(t);
    return Padding(
      padding: EdgeInsets.only(top: gapBefore),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(raftText(context, title), style: text.title),
          if (description case final description?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                raftText(context, description),
                style: text.description,
              ),
            ),
          if (notice case final notice?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftText(context, notice),
                style: text.description.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.colors['warning-strong'],
                ),
              ),
            ),
          const SizedBox(height: 12),
          child,
          if (error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(raftText(context, error), style: text.alert),
              ),
            ),
        ],
      ),
    );
  }
}

/// SettingsPanel success note: `border border-line-muted theme-brutal:border-2 theme-brutal:border-black
/// bg-brutal-lime/30 p-2 text-xs font-bold` (the "Password updated!" line).
class RaftSettingsSavedNote extends StatelessWidget {
  const RaftSettingsSavedNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          t.product.brutalLime.withValues(alpha: .3),
          t.panel,
        ),
        border: Border.all(color: t.semantic.lineMuted, width: 1),
      ),
      child: Text(text, style: RaftTypography.heading(t, size: 12, line: 16)),
    );
  }
}
