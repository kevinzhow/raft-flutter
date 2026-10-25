import 'hover_region.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anchored_popup.dart';
import 'dialog_card.dart';
import 'dismiss_scope.dart';
import 'emoji_picker.dart';
import 'form_controls.dart';
import 'form_presentation.dart';
import 'popover_surface.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/input_group.g.dart' show RaftInputGroupRecipeVariant;
import 'recipes/token_binding.dart';
import 'recipes/card.g.dart';
import 'theme.dart';

/// layout/SidebarSectionDialog.tsx: `Modal closeOnBackdrop` + `Card w-full
/// max-w-sm p-5`, a `text-base font-bold` title with a close
/// button, then the Name field (emoji picker addon + input) and the
/// Cancel / submit row. The product owns the emoji picker and persistence.
class RaftSidebarSectionDialog extends StatefulWidget {
  const RaftSidebarSectionDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.onClose,
    this.initialName = '',
    this.initialEmoji = '',
    this.emojiButtonKey,
  });
  final String title, submitLabel, initialName, initialEmoji;
  final void Function(String name, String? emoji) onSubmit;
  final VoidCallback onClose;
  final Key? emojiButtonKey;

  @override
  State<RaftSidebarSectionDialog> createState() =>
      _RaftSidebarSectionDialogState();
}

class _RaftSidebarSectionDialogState extends State<RaftSidebarSectionDialog> {
  late final controller = TextEditingController(text: widget.initialName)
    ..addListener(() => setState(() {}));
  late String emoji = widget.initialEmoji;
  final emojiAnchor = GlobalKey(debugLabel: 'section-emoji-trigger');
  final emojiPortal = OverlayPortalController();
  final _body = GlobalKey(debugLabel: 'section dialog body');
  final _footer = GlobalKey(debugLabel: 'section dialog footer');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final e = emoji.trim();
    widget.onSubmit(name, e.isEmpty ? null : e);
  }

  void chooseEmoji(String value) {
    setState(() {
      emoji = value;
      emojiPortal.hide();
    });
  }

  /// SidebarSectionEmojiPicker `PopoverContent align="start" p-0 z-[70]`: an
  /// optional "No emoji" row, then the picker (`width: min(340px, 100vw - 48px)`,
  /// `height: 360`), anchored below the trigger.
  Widget emojiPopover(BuildContext context) {
    final width = math.min(340.0, MediaQuery.sizeOf(context).width - 48);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(emojiPortal.hide),
          ),
        ),
        RaftAnchoredPopup(
          anchorKey: emojiAnchor,
          gap: 4,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  setState(emojiPortal.hide),
            },
            child: Semantics(
              label: raftText(context, 'Choose Section Emoji'),
              container: true,
              child: SizedBox(
                width: width,
                child: RaftPopoverSurface(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (emoji.isNotEmpty)
                        _NoEmojiRow(onPressed: () => chooseEmoji('')),
                      RaftEmojiPicker(
                        width: width - (0),
                        onEmojiClick: chooseEmoji,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = RaftRecipeTokens(t);
    final titleSlot = RaftCardRecipe.resolve(
      theme: raftRecipeThemeOf(t),
      tokens: tokens,
    ).title;
    final canSubmit = controller.text.trim().isNotEmpty;
    final body = KeyedSubtree(
      key: _body,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              raftText(context, 'Name'),
              style: raftCssTextStyle(
                family: t.headingFont,
                step: RaftTextSteps.xs,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          RaftPrefixedInput(
            prefix: '',
            variant: RaftInputGroupRecipeVariant.default_,
            controller: controller,
            maxLength: 80,
            autofocus: true,
            hintText: raftText(context, 'My Project'),
            semanticLabel: raftText(context, 'Name'),
            onSubmitted: (_) => submit(),
            leading: OverlayPortal(
              controller: emojiPortal,
              overlayChildBuilder: raftBackDismissed(
                () => setState(emojiPortal.hide),
                emojiPopover,
              ),
              child: KeyedSubtree(
                key: emojiAnchor,
                // The open popover keeps the trigger out of hover.
                child: IgnorePointer(
                  ignoring: emojiPortal.isShowing,
                  child: _EmojiButton(
                    key: widget.emojiButtonKey ?? sectionEmojiButtonKey,
                    emoji: emoji,
                    onPressed: () => setState(emojiPortal.toggle),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final footer = KeyedSubtree(
      key: _footer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RaftRecipeButton(
            label: raftText(context, 'Cancel'),
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStep: RaftTextSteps.sm,
            onPressed: raftExplicitClose(context, widget.onClose),
          ),
          const SizedBox(width: 8),
          RaftRecipeButton(
            label: raftText(context, widget.submitLabel),
            variant: RaftButtonRecipeVariant.accent,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStep: RaftTextSteps.sm,
            disabled: !canSubmit,
            // `disabled:opacity-50` on the submit Button.
            disabledOpacity: .5,
            onPressed: canSubmit ? submit : null,
          ),
        ],
      ),
    );
    // A bottom sheet below 768 ([showRaftForm]): the pinned title, the field
    // and the pinned actions.
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: raftText(context, widget.title),
        onClose: widget.onClose,
        body: body,
        footer: footer,
      );
    }
    return RaftRecipeCard(
      dialog: true,
      maxWidth: 384, // max-w-sm
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      raftText(context, widget.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: raftCssTextStyle(
                        family: titleSlot.fontFamily ?? t.headingFont,
                        step: RaftTextSteps.base,
                        weight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                RaftCloseButton(
                  onPressed: raftGuardedClose(context, widget.onClose),
                ),
              ],
            ),
          ),
          body,
          const SizedBox(height: 16),
          footer,
        ],
      ),
    );
  }
}

/// Key of the section dialog's emoji trigger (the `Choose section emoji` button).
const sectionEmojiButtonKey = ValueKey('sidebar-section-emoji');

/// `flex h-9 w-full items-center justify-center gap-2 border-b border-line-muted
/// bg-layer-panel px-3 text-xs font-bold hover:bg-fill-muted` clearing the emoji.
class _NoEmojiRow extends StatefulWidget {
  const _NoEmojiRow({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_NoEmojiRow> createState() => _NoEmojiRowState();
}

class _NoEmojiRowState extends State<_NoEmojiRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      button: true,
      child: RaftHoverRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            key: const ValueKey('section-no-emoji'),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: hovered ? t.colors['fill-muted'] : t.panel,
              border: Border(
                bottom: BorderSide(color: t.colors['line-muted']!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RaftIcon(RaftGlyph.x, size: 14, color: t.strong),
                const SizedBox(width: 8),
                Text(
                  raftText(context, 'No Emoji'),
                  style: raftCssTextStyle(
                    family: t.headingFont,
                    step: RaftTextSteps.xs,
                    weight: FontWeight.w700,
                    color: t.strong,
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

/// SidebarSectionEmojiPicker trigger: `Button ghost icon-md text-xl` showing
/// the chosen emoji or a `SmilePlus 18` glyph.
class _EmojiButton extends StatelessWidget {
  const _EmojiButton({super.key, required this.emoji, required this.onPressed});
  final String emoji;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftRecipeButton(
    variant: RaftButtonRecipeVariant.ghost,
    size: RaftButtonRecipeSize.iconMd,
    glyph: emoji.isEmpty ? RaftGlyph.smilePlus : null,
    // `<SmilePlus size={18}>` inside Button's `[&_svg]:size-4`.
    glyphSize: 16,
    child: emoji.isEmpty
        ? null
        : Text(emoji, style: const TextStyle(fontSize: 20, height: 28 / 20)),
    onPressed: onPressed ?? () {},
  );
}

/// Opens [RaftSidebarSectionDialog] as a form: a bottom sheet below 768, a
/// centered dialog from 768 that closes on a scrim press (`Modal
/// closeOnBackdrop`). [cardKey] marks the card.
Future<void> showRaftSidebarSectionDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required void Function(String name, String? emoji) onSubmit,
  String initialName = '',
  String initialEmoji = '',
  Key? cardKey,
}) => showRaftForm<void>(
  context,
  dismissible: true,
  builder: (dialogContext) {
    void close() => Navigator.of(dialogContext).pop();
    return KeyedSubtree(
      key: cardKey,
      child: RaftSidebarSectionDialog(
        title: title,
        submitLabel: submitLabel,
        initialName: initialName,
        initialEmoji: initialEmoji,
        onClose: close,
        onSubmit: (name, emoji) {
          close();
          onSubmit(name, emoji);
        },
      ),
    );
  },
);
