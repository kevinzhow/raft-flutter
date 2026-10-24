// Settings > Feedback write surfaces from the Web client:
// @botiverse/hands-feedback-react 0.4.1 (components.tsx) NewFeedbackForm,
// FeedbackTicket (conversation + reply composer), ReporterCloseSplitButton
// (+ reason DropdownMenu) and FeedbackCloseDialog, with styles.css and the
// raft-ui recipes they compose (MessageItem, Avatar, Composer,
// SegmentedControl, MessageReferenceChip, DropdownMenu, AlertDialog, Banner,
// TextareaCounter). The app owns the store and the transport; every value
// shown here arrives as data.
import 'text_selection_toolbar.dart';
import 'hover_region.dart';
import 'dismiss_scope.dart';

import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anchored_popup.dart';
import 'banner.dart';
import 'components.dart' show RaftButton;
import 'composer_recipe.dart';
import 'dialog_card.dart' show RaftRecipeButton, raftRecipeThemeOf;
import 'design_primitives.dart';
import 'feedback_inbox.dart';
import 'icons.dart';
import 'localization.dart';
import 'overlays/dialog.dart';
import 'recipe_surface.dart';
import 'recipes/avatar.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/dropdown_menu.g.dart';
import 'recipes/message_item.g.dart';
import 'recipes/message_reference.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/segmented_control.g.dart';
import 'recipes/textarea_counter.g.dart';
import 'system_inset.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'theme.dart';
import 'tooltip.dart' show RaftTooltip;
import 'sized_image.dart';

/// Reporter close reasons (`completed` / `no_longer_needed`).
enum RaftFeedbackCloseReason { completed, noLongerNeeded }

enum RaftFeedbackAuthor { reporter, staff, system }

enum RaftFeedbackUploadState { ready, uploading, failed }

/// hands-feedback `FeedbackProvider` wraps the workspace in
/// `<ThemeProvider theme={elegant|brutal} syncDom={false}>` without a mode,
/// so its portals (the close reason menu and the close dialog) render in the
/// light scheme even when the app is dark. Mirrors that Web rendering.
class RaftFeedbackPortalTheme extends StatelessWidget {
  const RaftFeedbackPortalTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (!t.dark) return child;
    final light = raftTheme(
      systemFonts: t.systemFonts,
      systemFontFamilies: t.systemFontFamilies,
    );
    return Theme(
      data: light,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: light.extension<RaftTokens>()?.strong),
        child: child,
      ),
    );
  }
}

/// `.hands-feedback-content` / composer root width.
const raftFeedbackContentWidth = 860.0;

/// The header with its back button and title (`.hands-feedback-header`
/// holding `Button outline icon-sm` + the 17px bold `h2`).
class RaftFeedbackViewHeader extends StatelessWidget {
  const RaftFeedbackViewHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final heading = raftFeedbackText(
      t,
      size: 17,
      line: 17 * 1.2,
      weight: FontWeight.w700,
    );
    return RaftFeedbackHeaderBand(
      leading: Row(
        children: [
          RaftRecipeButton(
            key: const ValueKey('feedback-back'),
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.iconSm,
            glyph: RaftGlyph.arrowLeft,
            glyphSize: 16,
            tooltip: raftText(context, 'Back'),
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                raftText(context, title),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: heading,
              ),
            ),
          ),
        ],
      ),
      trailing: trailing,
    );
  }
}

/// `.hands-feedback-field-label`: 13px, weight 650.
class RaftFeedbackFieldLabel extends StatelessWidget {
  const RaftFeedbackFieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    raftText(context, text),
    style: raftFeedbackText(
      RaftTokens.of(context),
      size: 13,
      weight: FontWeight.w600,
    ),
  );
}

/// The feedback type `SegmentedControl` (Idea / Bug) with the
/// `.hands-feedback-kind-item` override (13px / 16px, `padding: 6px 10px`).
class RaftFeedbackKindPicker extends StatelessWidget {
  const RaftFeedbackKindPicker({
    super.key,
    required this.problem,
    required this.onChanged,
  });
  final bool problem;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final root = RaftSegmentedControlRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    return Semantics(
      label: raftText(context, 'Feedback type'),
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: root.columnGap ?? 4,
        children: [
          for (final (value, label) in const [(false, 'Idea'), (true, 'Bug')])
            _KindItem(
              key: ValueKey('feedback-kind-${value ? 'bug' : 'idea'}'),
              label: raftText(context, label),
              checked: value == problem,
              onTap: onChanged == null ? null : () => onChanged!(value),
            ),
        ],
      ),
    );
  }
}

class _KindItem extends StatelessWidget {
  const _KindItem({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
  });
  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: onTap,
      selected: checked,
      semanticLabel: label,
      builder: (context, state) {
        final item = RaftSegmentedControlRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(
            hovered: state.hovered,
            focusVisible: state.focusVisible,
            extra: [checked ? 'data-checked' : 'data-unchecked'],
          ),
          tokens: rt,
        ).item;
        final base = item.textStyle(rt);
        final text = raftFeedbackText(
          t,
          size: 13,
          line: 16,
          weight: base.fontWeight ?? FontWeight.w500,
          color: base.color,
        );
        return RaftRecipeBox(
          style: item,
          tokens: rt,
          padding: EdgeInsets.symmetric(
            horizontal: 10 + item.borderWidth.left,
            vertical: 6 + item.borderWidth.top,
          ),
          applyText: false,
          child: Text(label, maxLines: 1, softWrap: false, style: text),
        );
      },
    );
  }
}

/// A picked file in a composer (`PendingAttachment`).
@immutable
class RaftFeedbackPendingFile {
  const RaftFeedbackPendingFile({
    required this.id,
    required this.name,
    required this.contentType,
    this.bytes,
    this.state = RaftFeedbackUploadState.ready,
    this.progress = 0,
  });
  final String id, name, contentType;
  final Uint8List? bytes;
  final RaftFeedbackUploadState state;
  final double progress;
}

/// FeedbackComposer: `ComposerRoot` (pending attachments, upload summary,
/// error banner) over the raft-ui `Composer` (textarea + toolbar with the
/// image / file buttons, the optional counter and the actions).
class RaftFeedbackComposer extends StatefulWidget {
  const RaftFeedbackComposer({
    super.key,
    required this.controller,
    required this.label,
    required this.actions,
    this.focusNode,
    this.inputKey,
    this.placeholder,
    this.newFeedback = false,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.onOpenAttachment,
    this.onAttachImage,
    this.onAttachFile,
    this.busy = false,
    this.error,
    this.onSubmit,
    this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Key? inputKey;
  final String label;
  final String? placeholder;

  /// The New feedback form: `rows={5}`, `min-height: 120px` and the
  /// 10,000-character counter.
  final bool newFeedback;
  final List<RaftFeedbackPendingFile> attachments;
  final ValueChanged<String>? onRemoveAttachment;

  /// A not-yet-sent attachment was tapped (Web `onOpenPendingAttachment`).
  final ValueChanged<String>? onOpenAttachment;
  final VoidCallback? onAttachImage, onAttachFile;
  final bool busy;
  final String? error;

  /// Enter without Shift (outside IME composition) submits (reply only).
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;
  final List<Widget> actions;

  static const limit = 10000;

  @override
  State<RaftFeedbackComposer> createState() => _RaftFeedbackComposerState();
}

class _RaftFeedbackComposerState extends State<RaftFeedbackComposer> {
  FocusNode? _ownedFocus;
  FocusNode get focus => widget.focusNode ?? (_ownedFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(RaftFeedbackComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownedFocus)?.removeListener(_changed);
      focus.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    focus.removeListener(_changed);
    widget.controller.removeListener(_changed);
    _ownedFocus?.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final submit = widget.onSubmit;
    if (submit == null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        HardwareKeyboard.instance.isShiftPressed ||
        widget.controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    submit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftComposerRecipe(t, desktop: true);
    final style = recipe.editorText;
    final attachmentsFull = widget.busy || widget.attachments.length >= 3;
    final minimum = widget.newFeedback ? 120.0 : 64.0;
    // `max-h-32` (border-box) caps the autosized textarea.
    final editor = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minimum,
        maxHeight: minimum > 128 ? minimum : 128,
      ),
      child: Padding(
        padding: recipe.editorInset,
        child: Focus(
          onKeyEvent: _key,
          canRequestFocus: false,
          skipTraversal: true,
          child: Semantics(
            container: true,
            label: raftText(context, widget.label),
            textField: true,
            child: TextField(
              contextMenuBuilder: RaftTextSelectionToolbar.editableText,
              key: widget.inputKey,
              controller: widget.controller,
              focusNode: focus,
              onChanged: widget.onChanged,
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(RaftFeedbackComposer.limit),
              ],
              style: style,
              strutStyle: StrutStyle.fromTextStyle(
                style,
                forceStrutHeight: true,
              ),
              cursorColor: style.color,
              decoration: InputDecoration(
                isCollapsed: true,
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: widget.placeholder == null
                    ? null
                    : raftText(context, widget.placeholder!),
                hintStyle: recipe.placeholder,
              ),
            ),
          ),
        ),
      ),
    );
    final toolbar = Transform.translate(
      offset: recipe.toolbarPaintOffset,
      child: Padding(
        padding: recipe.toolbarInset,
        child: Row(
          spacing: recipe.toolbarGap,
          children: [
            Expanded(
              child: Row(
                spacing: 16,
                children: [
                  RaftComposerAction(
                    key: const ValueKey('feedback-attach-image'),
                    glyph: RaftGlyph.imagePlus,
                    tooltip: 'Attach Image',
                    onPressed: attachmentsFull ? null : widget.onAttachImage,
                  ),
                  RaftComposerAction(
                    key: const ValueKey('feedback-attach-file'),
                    glyph: RaftGlyph.paperclip,
                    tooltip: 'Attach File',
                    onPressed: attachmentsFull ? null : widget.onAttachFile,
                  ),
                  if (widget.newFeedback)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _Counter(length: widget.controller.text.length),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: recipe.actionGap,
              children: widget.actions,
            ),
          ],
        ),
      ),
    );
    final shell = Container(
      padding: recipe.shellInset,
      clipBehavior: Clip.antiAlias,
      decoration: recipe.shellDecoration(focused: focus.hasFocus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: recipe.shellGap,
        children: [editor, toolbar],
      ),
    );
    final progress = widget.attachments.isEmpty
        ? 0
        : (widget.attachments.fold<double>(0, (s, a) => s + a.progress) /
                  widget.attachments.length *
                  100)
              .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        if (widget.attachments.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final file in widget.attachments)
                _PendingAttachment(
                  key: ValueKey('feedback-pending-${file.id}'),
                  file: file,
                  busy: widget.busy,
                  onRemove: widget.onRemoveAttachment == null
                      ? null
                      : () => widget.onRemoveAttachment!(file.id),
                  onOpen: widget.onOpenAttachment == null || file.bytes == null
                      ? null
                      : () => widget.onOpenAttachment!(file.id),
                ),
            ],
          ),
        if (widget.busy && widget.attachments.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftFormat(context, 'Uploading {progress}%', {
                  'progress': progress,
                }),
                style: raftFeedbackText(
                  t,
                  size: 12,
                  line: 12 * 1.4,
                  weight: FontWeight.w600,
                  color: t.colors['foreground-muted'],
                ),
              ),
            ),
          ),
        if (widget.error != null) RaftFeedbackErrorBanner(widget.error!),
        shell,
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.length});
  final int length;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftTextareaCounterRecipe.resolve(
      theme: t.recipeTheme,
      overLimit: length > RaftFeedbackComposer.limit,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    final style = s.text(rt, base: DefaultTextStyle.of(context).style);
    return Text(
      '$length/${RaftFeedbackComposer.limit}',
      style: style.copyWith(
        color: t.colors['foreground-muted'],
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// ComposerAttachment: the 64px thumbnail (image) or file tile, the
/// uploading / failed overlays and the remove button.
class _PendingAttachment extends StatelessWidget {
  const _PendingAttachment({
    super.key,
    required this.file,
    required this.busy,
    required this.onRemove,
    this.onOpen,
  });
  final RaftFeedbackPendingFile file;
  final bool busy;
  final VoidCallback? onRemove, onOpen;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final radius = BorderRadius.circular(8);
    final image = file.bytes != null && file.contentType.startsWith('image/');
    Widget tile = Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.colors['layer-panel'],
        borderRadius: radius,
        border: Border.all(color: t.colors['line-muted']!, width: 1),
      ),
      child: image
          ? RaftSizedImage.memory(
              file.bytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              evictOnDispose: true,
            )
          : Center(
              child: RaftIcon(
                RaftGlyph.paperclip,
                size: 16,
                color: t.colors['foreground-muted'],
              ),
            ),
    );
    final overlay = switch (file.state) {
      RaftFeedbackUploadState.uploading => Semantics(
        label: raftFormat(context, 'Upload progress for {name}', {
          'name': file.name,
        }),
        value: '${(file.progress * 100).round()}%',
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: file.progress.clamp(0, 1),
            alignment: Alignment.centerLeft,
            child: Container(height: 3, color: t.colors['accent-500']),
          ),
        ),
      ),
      RaftFeedbackUploadState.failed => Semantics(
        liveRegion: true,
        child: Container(
          color: t.colors['danger-muted']!.withValues(alpha: .85),
          alignment: Alignment.center,
          child: Text(
            raftText(context, 'Upload failed'),
            textAlign: TextAlign.center,
            style: raftFeedbackText(
              t,
              size: 10,
              line: 12,
              weight: FontWeight.w700,
              color: t.colors['danger'],
            ),
          ),
        ),
      ),
      RaftFeedbackUploadState.ready => null,
    };
    return RaftTooltip(
      message: '${file.name} · ${file.contentType}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          onOpen == null
              ? tile
              : _FeedbackTap(
                  key: ValueKey('feedback-pending-open-${file.id}'),
                  label: '${raftText(context, 'Open')} ${file.name}',
                  onTap: onOpen!,
                  child: tile,
                ),
          if (overlay != null) Positioned.fill(child: overlay),
          Positioned(
            top: -6,
            right: -6,
            child: RaftRecipeButton(
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.iconXs,
              squareExtent: 24,
              glyph: RaftGlyph.x,
              glyphSize: 12,
              tooltip: '${raftText(context, 'Remove')} ${file.name}',
              disabled: busy || onRemove == null,
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// FeedbackErrorBanner: `Banner status="destructive" size="sm"`, with the
/// optional outline retry action.
class RaftFeedbackErrorBanner extends StatelessWidget {
  const RaftFeedbackErrorBanner(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => RaftBanner(
    status: RaftBannerRecipeStatus.destructive,
    size: RaftBannerRecipeSize.sm,
    description: raftText(context, message),
    action: onRetry == null
        ? null
        : RaftRecipeButton(
            label: 'Try Again',
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            onPressed: onRetry,
          ),
  );
}

/// NewFeedbackForm: the header (back + "New feedback"), then the centred
/// `.hands-feedback-new-fields` grid (`gap: 12px`, `padding: 2px`,
/// `margin: 18px auto`): Type, the kind picker, the question label, the
/// composer and the attachment hint.
class RaftFeedbackNewForm extends StatelessWidget {
  const RaftFeedbackNewForm({
    super.key,
    required this.onBack,
    required this.problem,
    required this.onKind,
    required this.composer,
  });
  final VoidCallback onBack;
  final bool problem;
  final ValueChanged<bool>? onKind;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final narrow = MediaQuery.sizeOf(context).width <= 640;
    return ColoredBox(
      color: t.colors['layer-canvas']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftFeedbackViewHeader(title: 'New Feedback', onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: raftScrollPadding(
                context,
                EdgeInsets.symmetric(
                  vertical: narrow ? 16 : 18,
                  horizontal: narrow ? 16 : 18,
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: raftFeedbackContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      2,
                      2,
                      2 + raftFeedbackScrollGutter(context),
                      2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        const RaftFeedbackFieldLabel('Type'),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: RaftFeedbackKindPicker(
                            problem: problem,
                            onChanged: onKind,
                          ),
                        ),
                        const RaftFeedbackFieldLabel(
                          'What would you like us to know?',
                        ),
                        composer,
                        Text(
                          raftFormat(context, 'Up to {count} images.', {
                            'count': 3,
                          }),
                          style: raftFeedbackText(
                            t,
                            size: 12,
                            color: t.colors['foreground-muted'],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One conversation message (`FeedbackConversationMessage`).
@immutable
class RaftFeedbackMessageData {
  const RaftFeedbackMessageData({
    required this.id,
    required this.author,
    required this.sender,
    required this.time,
    required this.body,
    this.attachments = const [],
    this.onOpenAttachment,
    this.footer = const [],
  });
  final String id, sender, time, body;
  final RaftFeedbackAuthor author;

  /// `(filename, size label)` rows.
  final List<(String, String)> attachments;

  /// A sent attachment row was tapped, with its index in [attachments] (Web
  /// `onOpenAttachment`). Null leaves the rows as plain text.
  final ValueChanged<int>? onOpenAttachment;
  final List<Widget> footer;
}

/// raft-ui `MessageItem` (avatar slot, sender + time header, body,
/// attachments, footer).
class RaftFeedbackMessage extends StatefulWidget {
  const RaftFeedbackMessage({super.key, required this.message});
  final RaftFeedbackMessageData message;
  @override
  State<RaftFeedbackMessage> createState() => _RaftFeedbackMessageState();
}

class _RaftFeedbackMessageState extends State<RaftFeedbackMessage> {
  bool hovered = false;

  Widget _attachmentRow(
    RaftTokens t,
    RaftFeedbackMessageData m,
    int index,
    String name,
    String size,
  ) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        RaftIcon(RaftGlyph.file, size: 14, color: t.colors['foreground-muted']),
        Text(
          '$name · $size',
          style: raftFeedbackText(
            t,
            size: 12,
            color: t.colors['foreground-muted'],
          ),
        ),
      ],
    );
    final open = m.onOpenAttachment;
    return open == null
        ? row
        : _FeedbackTap(
            key: ValueKey('feedback-attachment-${m.id}-$index'),
            label: '${raftText(context, 'Open')} $name',
            onTap: () => open(index),
            child: row,
          );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final m = widget.message;
    // MessageItem's `max-md:` padding, gap and avatar (below 768px).
    final width = MediaQuery.sizeOf(context).width;
    // (Brutal keeps the desktop item at every width.)
    final compact = width < 768;
    final base = t.recipeStates(hovered: hovered);
    final s = RaftMessageItemRecipe.resolve(
      theme: t.recipeTheme,
      states: compact ? RaftRecipeStates(base.flags, width) : base,
      tokens: rt,
    );
    final inherited = raftFeedbackText(t, size: 16);
    TextStyle text(RaftSlotStyle slot) => slot.text(rt, base: inherited);
    final content = text(s.content);
    final sender = text(s.sender);
    final time = text(s.time);
    final body = s.body.text(rt, base: content);
    // HTML collapses the message's newlines (MessageItemBody is not
    // pre-wrap).
    final bodyText = m.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: s.header.columnGap ?? 6,
      children: [
        Text(raftText(context, m.sender), maxLines: 1, style: sender),
        Flexible(
          child: Text(
            m.time,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: time.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
    final root = s.root;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Padding(
        padding: root.margin,
        child: RaftRecipeBox(
          style: root,
          tokens: rt,
          applyText: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (root.minHeight ?? 48) - root.padding.vertical,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: root.columnGap ?? 12,
              children: [
                _FeedbackAvatar(
                  author: m.author,
                  sender: m.sender,
                  compact: compact,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: s.header.padding, child: header),
                      // Block flow: adjacent vertical margins collapse
                      // (body mb 6 + footer mt 6 = 6); the flex item keeps
                      // the last child's bottom margin.
                      SizedBox(height: s.body.margin.top),
                      SelectableText(
                        bodyText,
                        key: ValueKey('feedback-comment-${m.id}'),
                        style: body,
                      ),
                      if (m.attachments.isNotEmpty) ...[
                        SizedBox(
                          height: math.max(
                            s.body.margin.bottom,
                            s.attachments.margin.top,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            for (final (i, (name, size))
                                in m.attachments.indexed)
                              _attachmentRow(t, m, i, name, size),
                          ],
                        ),
                      ],
                      if (m.footer.isNotEmpty) ...[
                        SizedBox(
                          height: math.max(
                            m.attachments.isEmpty
                                ? s.body.margin.bottom
                                : s.attachments.margin.bottom,
                            s.footer.margin.top,
                          ),
                        ),
                        Wrap(
                          spacing: s.footer.columnGap ?? 6,
                          runSpacing: s.footer.rowGap ?? 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: m.footer,
                        ),
                      ] else if (m.attachments.isEmpty)
                        SizedBox(height: s.body.margin.bottom),
                    ],
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

/// raft-ui `Avatar size="md"` (human for the reporter, agent otherwise)
/// with the sender's initial as `AvatarFallback`.
class _FeedbackAvatar extends StatelessWidget {
  const _FeedbackAvatar({
    required this.author,
    required this.sender,
    this.compact = false,
  });
  final RaftFeedbackAuthor author;
  final String sender;

  /// Below 768px the avatar is 24px in a 32px slot.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftAvatarRecipe.resolve(
      theme: t.recipeTheme,
      type_: author == RaftFeedbackAuthor.reporter
          ? RaftAvatarRecipeType.human
          : RaftAvatarRecipeType.agent,
      size: RaftAvatarRecipeSize.md,
      states: t.recipeStates(),
      tokens: rt,
    );
    final label = raftText(context, sender);
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    final fallback = s.fallback;
    final style = fallback.text(rt, base: raftFeedbackText(t, size: 14));
    final size = compact ? 24.0 : 36.0;
    return ExcludeSemantics(
      child: SizedBox(
        width: compact ? 32 : 36,
        height: size,
        child: Align(
          alignment: Alignment.topLeft,
          child: RaftRecipeBox(
            style: s.root,
            tokens: rt,
            width: size,
            height: size,
            clip: true,
            applyText: false,
            decorationOverride: (d) => d.copyWith(),
            child: RaftRecipeBox(
              style: fallback,
              tokens: rt,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
              applyText: false,
              // Initials fill a fixed-size avatar: they grow with the text size
              // only up to the chrome bound.
              child: Text(
                initial,
                style: style,
                textScaler: RaftChrome.boundedScalerOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// FeedbackTicket body: the centred conversation (`MessageList`,
/// `padding: 2px 0 12px`) over the reply footer. Elegant floats the footer
/// over the list (`md:absolute bottom-0`); Brutal stacks it under a 2px rule.
class RaftFeedbackConversation extends StatelessWidget {
  const RaftFeedbackConversation({
    super.key,
    required this.onBack,
    required this.messages,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onLoadMore,
    this.loadingMore = false,
    this.composer,
    this.controller,
  });
  final VoidCallback onBack;
  final List<RaftFeedbackMessageData> messages;

  /// No detail to show yet (the skeleton).
  final bool loading;
  final String? error;
  final VoidCallback? onRetry, onLoadMore;
  final bool loadingMore;

  /// The reply composer (null once the ticket is closed).
  final Widget? composer;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final narrow = MediaQuery.sizeOf(context).width <= 640;
    final background = t.dark
        ? t.colors['layer-card']!
        : t.colors['layer-panel']!;
    final list = ListView(
      key: const ValueKey('feedback-conversation'),
      controller: controller,
      padding: raftScrollPadding(
        context,
        EdgeInsets.only(top: 2, bottom: 12 + (composer != null ? 160 : 0)),
      ),
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: RaftFeedbackErrorBanner(error!, onRetry: onRetry),
          ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: RaftUiSkeleton(height: 160),
          ),
        for (final message in messages)
          RaftFeedbackMessage(
            key: ValueKey('feedback-message-${message.id}'),
            message: message,
          ),
        if (onLoadMore != null || loadingMore)
          Align(
            alignment: Alignment.centerLeft,
            child: RaftRecipeButton(
              label: loadingMore ? 'Loading Replies…' : 'Load More Replies',
              variant: RaftButtonRecipeVariant.outline,
              disabled: loadingMore,
              onPressed: onLoadMore,
            ),
          ),
      ],
    );
    final centred = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: raftFeedbackContentWidth),
        child: list,
      ),
    );
    Widget? footer;
    if (composer != null) {
      footer = Container(
        key: const ValueKey('feedback-reply-footer'),
        padding:
            (narrow
                    ? const EdgeInsets.fromLTRB(14, 12, 14, 14)
                    : const EdgeInsets.fromLTRB(18, 14, 18, 18))
                .copyWith(
                  bottom: (narrow ? 14 : 18) + raftBottomInset(context),
                ),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: raftFeedbackContentWidth),
          child: composer,
        ),
      );
    }
    return ColoredBox(
      color: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: t.colors['layer-canvas']!,
            child: RaftFeedbackViewHeader(title: 'My Feedback', onBack: onBack),
          ),
          Expanded(
            child: footer == null
                ? centred
                : Stack(
                    children: [
                      Positioned.fill(child: centred),
                      Positioned(left: 0, right: 0, bottom: 0, child: footer),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// `.hands-feedback-closure-reason`: muted 12px / 20px, weight 650.
class RaftFeedbackClosureReason extends StatelessWidget {
  const RaftFeedbackClosureReason(this.reason, {super.key});
  final String reason;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      raftFormat(context, 'Closed as {reason}', {
        'reason': raftText(context, reason),
      }),
      style: raftFeedbackText(
        t,
        size: 12,
        line: 20,
        weight: FontWeight.w600,
        color: t.colors['foreground-muted'],
      ),
    );
  }
}

/// ReporterCloseSplitButton: the accent `MessageReferenceChip` "Close
/// ticket" (default reason) joined to the caret that opens the reason menu.
class RaftFeedbackCloseSplit extends StatefulWidget {
  const RaftFeedbackCloseSplit({
    super.key,
    required this.defaultReason,
    required this.onChoose,
    this.disabled = false,
    this.keySuffix = '',
  });
  final RaftFeedbackCloseReason defaultReason;
  final ValueChanged<RaftFeedbackCloseReason> onChoose;
  final bool disabled;

  /// Appended to the part keys (`feedback-close-main<suffix>`).
  final String keySuffix;

  @override
  State<RaftFeedbackCloseSplit> createState() => _RaftFeedbackCloseSplitState();
}

class _RaftFeedbackCloseSplitState extends State<RaftFeedbackCloseSplit> {
  final anchor = GlobalKey();
  OverlayEntry? menu;

  @override
  void dispose() {
    _closeMenu(rebuild: false);
    super.dispose();
  }

  void _closeMenu({bool rebuild = true}) {
    menu?.remove();
    menu?.dispose();
    menu = null;
    if (rebuild && mounted) setState(() {});
  }

  void _openMenu() {
    if (menu != null) return _closeMenu();
    final overlay = Overlay.of(context);
    final theme = Theme.of(context);
    final text = DefaultTextStyle.of(context).style;
    menu = OverlayEntry(
      builder: (_) => RaftBackDismiss(
        routeContext: this.context,
        onDismiss: _closeMenu,
        child: Theme(
          data: theme,
          child: RaftFeedbackPortalTheme(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeMenu,
                  ),
                ),
                RaftAnchoredPopup(
                  anchorKey: anchor,
                  alignRight: true,
                  snapToPixel: true,
                  gap: 6,
                  child: Material(
                    type: MaterialType.transparency,
                    textStyle: text,
                    child: RaftFeedbackCloseMenu(
                      defaultReason: widget.defaultReason,
                      onChoose: (reason) {
                        _closeMenu();
                        widget.onChoose(reason);
                      },
                      onDismiss: _closeMenu,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(menu!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftMessageReferenceRecipe.resolve(
      theme: t.recipeTheme,
      variant: RaftMessageReferenceRecipeVariant.accent,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    final decoration = s.decoration(rt);
    // `.hands-feedback-close-main/caret { color: inherit }`: the message's
    // foreground, not the chip recipe colour.
    final fg = t.colors['foreground'] ?? t.strong;
    final text = TextStyle(
      fontFamily: raftSystemUiFont,
      fontFamilyFallback: const ['sans-serif'],
      fontSize: 10.5,
      height: 1,
      fontWeight: FontWeight.w700,
      color: fg,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final border = decoration.border is Border
        ? decoration.border! as Border
        : null;
    final radius = decoration.borderRadius is BorderRadius
        ? decoration.borderRadius! as BorderRadius
        : BorderRadius.zero;
    Widget part({
      required Key key,
      required String label,
      required bool main,
      required VoidCallback onTap,
      required Widget child,
    }) => RaftInteractive(
      key: key,
      onPressed: widget.disabled ? null : onTap,
      semanticLabel: label,
      builder: (context, state) => Container(
        height: 20,
        constraints: main ? null : const BoxConstraints(minWidth: 20),
        padding: main
            ? const EdgeInsets.only(left: 8, right: 6)
            : const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: decoration.copyWith(
          border: border == null
              ? null
              : main
              ? Border(
                  top: border.top,
                  bottom: border.bottom,
                  left: border.left,
                )
              : border,
          borderRadius: main
              ? BorderRadius.only(
                  topLeft: radius.topLeft,
                  bottomLeft: radius.bottomLeft,
                )
              : BorderRadius.only(
                  topRight: radius.topRight,
                  bottomRight: radius.bottomRight,
                ),
        ),
        child: child,
      ),
    );
    final open = menu != null;
    Widget split = Row(
      key: anchor,
      mainAxisSize: MainAxisSize.min,
      children: [
        part(
          key: ValueKey('feedback-close-main${widget.keySuffix}'),
          label: raftText(context, 'Close Ticket'),
          main: true,
          onTap: () => widget.onChoose(widget.defaultReason),
          child: Text(
            raftText(context, 'Close Ticket'),
            maxLines: 1,
            softWrap: false,
            style: text,
          ),
        ),
        part(
          key: ValueKey('feedback-close-caret${widget.keySuffix}'),
          label: raftText(context, 'Choose a Close Reason'),
          main: false,
          onTap: _openMenu,
          child: RaftIcon(RaftGlyph.chevronDown, size: 10, color: fg),
        ),
      ],
    );
    if (widget.disabled) split = Opacity(opacity: .4, child: split);
    if (open) {
      // `[data-menu-open]`: 4px hard shadow, lifted 1px.
      split = Transform.translate(
        offset: const Offset(0, -1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: t.colors['line-strong']!,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: split,
        ),
      );
    }
    return split;
  }
}

/// The close reason `DropdownMenuContent` (align end): Completed / No
/// longer needed, the default reason checked, each with its description.
class RaftFeedbackCloseMenu extends StatelessWidget {
  const RaftFeedbackCloseMenu({
    super.key,
    required this.defaultReason,
    required this.onChoose,
    this.onDismiss,
  });
  final RaftFeedbackCloseReason defaultReason;
  final ValueChanged<RaftFeedbackCloseReason> onChoose;
  final VoidCallback? onDismiss;

  static const options = [
    (
      RaftFeedbackCloseReason.completed,
      'Completed',
      'Confirm resolved and close.',
    ),
    (
      RaftFeedbackCloseReason.noLongerNeeded,
      'No longer needed',
      'Close — no further action needed.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final content = RaftDropdownMenuRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      states: t.recipeStates(),
      tokens: rt,
    ).content;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            onDismiss?.call(),
      },
      child: FocusScope(
        autofocus: true,
        child: Focus(
          autofocus: true,
          child: Semantics(
            role: SemanticsRole.menu,
            child: RaftRecipeBox(
              key: const ValueKey('feedback-close-menu'),
              style: content,
              tokens: rt,
              clip: true,
              child: _PixelSnappedIntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (reason, label, description) in options)
                      _CloseMenuItem(
                        key: ValueKey('feedback-close-reason-${reason.name}'),
                        label: raftText(context, label),
                        description: raftText(context, description),
                        checked: reason == defaultReason,
                        onPressed: () => onChoose(reason),
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

/// `width: max-content` laid out like Chromium's pixel-snapped box: the
/// intrinsic width rounds to a whole pixel, so a right-aligned popup keeps
/// both edges (and the text inside) on the same pixel grid as Web.
class _PixelSnappedIntrinsicWidth extends SingleChildRenderObjectWidget {
  const _PixelSnappedIntrinsicWidth({required Widget super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPixelSnappedIntrinsicWidth();
}

class _RenderPixelSnappedIntrinsicWidth extends RenderProxyBox {
  @override
  void performLayout() {
    final c = child!;
    final width = constraints
        .constrainWidth(c.getMaxIntrinsicWidth(constraints.maxHeight))
        .roundToDouble();
    c.layout(
      constraints.copyWith(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    size = c.size;
  }
}

class _CloseMenuItem extends StatelessWidget {
  const _CloseMenuItem({
    super.key,
    required this.label,
    required this.description,
    required this.checked,
    required this.onPressed,
  });
  final String label, description;
  final bool checked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    return RaftInteractive(
      onPressed: onPressed,
      button: false,
      semanticRole: SemanticsRole.menuItem,
      semanticLabel: '$label. $description',
      builder: (context, state) {
        final item = RaftDropdownMenuRecipe.resolve(
          theme: raftRecipeThemeOf(t),
          states: t.recipeStates(
            extra: [
              if (state.hovered || state.focusVisible) 'data-highlighted',
            ],
          ),
          tokens: rt,
        ).item;
        // A portal outside `.hands-feedback-root`: the app face.
        final base = item.text(
          rt,
          base: raftCssText.merge(DefaultTextStyle.of(context).style),
        );
        final glyph = 16.0;
        final caption = base.copyWith(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: t.colors['foreground-muted'],
        );
        return RaftRecipeBox(
          style: item,
          tokens: rt,
          applyText: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: item.columnGap ?? 8,
            children: [
              Transform.translate(
                offset: const Offset(-1, 1),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox.square(
                    dimension: glyph,
                    child: checked
                        ? RaftIcon(
                            RaftGlyph.check,
                            size: glyph,
                            strokeWidth: 1.5,
                            color: (state.hovered || state.focusVisible
                                ? t.colors['foreground']
                                : t.colors['foreground-muted']),
                          )
                        : null,
                  ),
                ),
              ),
              Flexible(
                // `.hands-feedback-close-menu-item span`: the label span
                // (`dropdown-menu-item-label`) and its description span are
                // both 12px / 1.4 / muted with `margin-top: 2px`, so the
                // `strong` title inherits 12px and the muted colour.
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Transform.translate(
                    offset: const Offset(0, -1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The CSS line box (16.8px), not the ceiled paragraph.
                        RaftScaled.lineBox(
                          context,
                          height: 16.8,
                          child: Text(
                            label,
                            style: caption.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        RaftScaled.lineBox(
                          context,
                          height: 16.8,
                          child: Text(description, style: caption),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// FeedbackCloseDialog: `AlertDialog` with the reason's confirm title and
/// description, the error banner, Cancel (`outline sm`) and Close ticket
/// (`accent sm`, loading while closing). Nothing dismisses it while busy.
class RaftFeedbackCloseDialog extends StatelessWidget {
  const RaftFeedbackCloseDialog({
    super.key,
    required this.reason,
    required this.onCancel,
    required this.onConfirm,
    this.busy = false,
    this.error,
  });
  final RaftFeedbackCloseReason reason;
  final VoidCallback onCancel, onConfirm;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final completed = reason == RaftFeedbackCloseReason.completed;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) onCancel();
      },
      child: RaftFeedbackPortalTheme(
        child: RaftDialog(
          kind: RaftDialogKind.alert,
          contentKey: const ValueKey('feedback-close-dialog'),
          semanticLabel: raftText(
            context,
            completed
                ? 'Issue resolved — close this ticket?'
                : 'No longer need help — close this ticket?',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftDialogHeader(
                showClose: false,
                title: completed
                    ? 'Issue resolved — close this ticket?'
                    : 'No longer need help — close this ticket?',
              ),
              Flexible(
                child: RaftDialogBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RaftDialogDescription(
                        completed
                            ? 'You won’t be able to reply after closing. If the issue comes back, submit new feedback.'
                            : 'This will close the ticket even if the issue isn’t resolved. If you still need help, submit new feedback.',
                      ),
                      if (error != null) RaftFeedbackErrorBanner(error!),
                    ],
                  ),
                ),
              ),
              RaftDialogFooter(
                children: [
                  RaftRecipeButton(
                    key: const ValueKey('feedback-close-cancel'),
                    label: 'Cancel',
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    disabled: busy,
                    onPressed: onCancel,
                  ),
                  RaftButton(
                    key: const ValueKey('feedback-close-confirm'),
                    label: 'Close Ticket',
                    semanticLabel: raftText(
                      context,
                      busy ? 'Closing…' : 'Close Ticket',
                    ),
                    tone: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.sm,
                    busy: busy,
                    onPressed: busy ? null : onConfirm,
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

/// A tappable attachment (a sent row or a pending tile): a button for the
/// pointer, the keyboard and assistive technology.
class _FeedbackTap extends StatelessWidget {
  const _FeedbackTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    ),
  );
}
