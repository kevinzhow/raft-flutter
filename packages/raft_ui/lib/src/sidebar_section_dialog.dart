import 'card.dart' show RaftCard;
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
import 'interaction.dart';
import 'popover_surface.dart';
import 'presentation.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/input_group.g.dart' show RaftInputGroupRecipeVariant;
import 'recipes/token_binding.dart';
import 'recipes/card.g.dart';
import 'overlays/dialog.dart';
import 'raft/button.dart';
import 'raft/checkbox.dart';
import 'space.dart';
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
    this.stepLabel,
    this.conversations,
  });
  final String title, submitLabel, initialName, initialEmoji;
  final String? stepLabel;
  final Widget? conversations;
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
    final titleSlot = RaftCardRecipe.resolve(tokens: tokens).title;
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
          if (widget.conversations case final picker?) ...[
            const SizedBox(height: RaftSpace.x4),
            Text(raftText(context, 'Conversations')),
            const SizedBox(height: RaftSpace.x2),
            picker,
          ],
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
    if (widget.stepLabel != null || widget.conversations != null) {
      return RaftDialog.card(
        title: raftText(context, widget.title),
        description: widget.stepLabel == null
            ? null
            : raftText(context, widget.stepLabel!),
        onClose: widget.onClose,
        actions: footer,
        child: body,
      );
    }
    return RaftCard(
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

class RaftSidebarConversationPicker extends StatefulWidget {
  const RaftSidebarConversationPicker({
    super.key,
    required this.candidates,
    required this.initialSelection,
    required this.onChanged,
    this.autofocus = false,
  });

  final Map<String, String> candidates;
  final Set<String> initialSelection;
  final ValueChanged<Set<String>> onChanged;
  final bool autofocus;

  @override
  State<RaftSidebarConversationPicker> createState() =>
      _RaftSidebarConversationPickerState();
}

class RaftSidebarAddConversationsDialog extends StatefulWidget {
  const RaftSidebarAddConversationsDialog({
    super.key,
    required this.name,
    required this.candidates,
    required this.initial,
    required this.onClose,
    required this.onSubmit,
  });

  final String name;
  final Map<String, String> candidates;
  final Set<String> initial;
  final VoidCallback onClose;
  final ValueChanged<Set<String>> onSubmit;

  @override
  State<RaftSidebarAddConversationsDialog> createState() =>
      _RaftSidebarAddConversationsDialogState();
}

class _RaftSidebarAddConversationsDialogState
    extends State<RaftSidebarAddConversationsDialog> {
  late Set<String> selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final added = selected.difference(widget.initial).length;
    final changed = added > 0 || widget.initial.difference(selected).isNotEmpty;
    final caption = switch (added) {
      0 => 'Add',
      1 => 'Add {count} conversation',
      _ => 'Add {count} conversations',
    };
    final title = raftFormat(context, 'Add conversations to {name}', {
      'name': widget.name,
    });
    final step = raftText(context, 'Step 2 of 2');
    final submit = RaftButton(
      label: raftFormat(context, caption, {'count': added}),
      tone: RaftButtonRecipeVariant.accent,
      onPressed: changed ? () => widget.onSubmit(selected) : null,
    );
    final picker = RaftSidebarConversationPicker(
      autofocus: true,
      candidates: widget.candidates,
      initialSelection: widget.initial,
      onChanged: (value) => setState(() => selected = value),
    );
    if (RaftFormFrame.sheetOf(context)) {
      return RaftFormSheet(
        title: title,
        onClose: widget.onClose,
        commit: submit,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x4,
          children: [Text(step), picker],
        ),
      );
    }
    return RaftDialog.card(
      title: title,
      description: step,
      onClose: widget.onClose,
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: RaftSpace.x2,
        children: [
          RaftButton(
            label: raftText(context, 'Skip'),
            tone: RaftButtonRecipeVariant.ghost,
            onPressed: widget.onClose,
          ),
          submit,
        ],
      ),
      child: picker,
    );
  }
}

Future<Set<String>?> showRaftSidebarAddConversations(
  BuildContext context, {
  required String name,
  required Map<String, String> candidates,
  required Set<String> initial,
}) => showRaftForm<Set<String>>(
  context,
  dialogMaxWidth: 448,
  guardUnsaved: false,
  builder: (dialogContext) => RaftSidebarAddConversationsDialog(
    key: const ValueKey('sidebar-section-add-conversations'),
    name: name,
    candidates: candidates,
    initial: initial,
    onClose: () => Navigator.of(dialogContext).pop(),
    onSubmit: (selected) => Navigator.of(dialogContext).pop(selected),
  ),
);

class _RaftSidebarConversationPickerState
    extends State<RaftSidebarConversationPicker> {
  late final selected = {...widget.initialSelection};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final visible = widget.candidates.entries.where(
      (entry) => entry.value.toLowerCase().contains(query),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftTextInput(
          fieldKey: const ValueKey('sidebar-section-conversation-filter'),
          hintText: raftText(context, 'Filter by name'),
          leadingGlyph: RaftGlyph.search,
          autofocus: widget.autofocus && !RaftInteraction.of(context).touch,
          onChanged: (value) =>
              setState(() => query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: RaftSpace.x2),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.colors['line-hairline']!),
            borderRadius: BorderRadius.circular(RaftSpace.x2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 288),
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(RaftSpace.x6),
                    child: Text(
                      raftText(context, 'No matching conversations'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaftSpace.x3,
                    ),
                    children: [
                      for (final entry in visible)
                        RaftCheckboxRow(
                          key: ValueKey(
                            'sidebar-section-add-option-${entry.key}',
                          ),
                          title: entry.value,
                          value: selected.contains(entry.key),
                          onChanged: (checked) {
                            setState(() {
                              if (checked) {
                                selected.add(entry.key);
                              } else {
                                selected.remove(entry.key);
                              }
                            });
                            widget.onChanged(Set.of(selected));
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
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
  String? stepLabel,
  Widget? conversations,
}) => showRaftForm<void>(
  context,
  dismissible: true,
  policy: stepLabel == null
      ? RaftPresentationPolicy.form
      : RaftPresentationPolicy.confirm,
  guardUnsaved: stepLabel == null && conversations == null,
  dialogMaxWidth: stepLabel == null && conversations == null ? 384 : 448,
  builder: (dialogContext) {
    void close() => Navigator.of(dialogContext).pop();
    return KeyedSubtree(
      key: cardKey,
      child: RaftSidebarSectionDialog(
        title: title,
        submitLabel: submitLabel,
        initialName: initialName,
        initialEmoji: initialEmoji,
        stepLabel: stepLabel,
        conversations: conversations,
        onClose: close,
        onSubmit: (name, emoji) {
          close();
          onSubmit(name, emoji);
        },
      ),
    );
  },
);
