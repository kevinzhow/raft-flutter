// Mounted AgentProfileEditDialog.tsx avatar branch. The dialog chrome uses
// generated Dialog slots; the 40px preset tiles are product JSX overrides.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../raft_ui.dart';
import '../recipes.dart';

const raftAgentAvatarChoices = <String>[
  'robot',
  'cat',
  'ghost',
  'skull',
  'alien',
  'heart',
  'star',
  'flame',
  'diamond',
  'mushroom',
  'eye',
  'crown',
  'cloud',
  'sun',
  'bell',
  'tree',
];

class RaftAgentAvatarPicker extends StatelessWidget {
  const RaftAgentAvatarPicker({
    super.key,
    required this.name,
    required this.preview,
    required this.selectedKey,
    required this.onChoice,
    required this.onUpload,
    required this.onClose,
    required this.onSave,
    this.busy = false,
    this.dirty = false,
    this.error,
    this.uploadSelected = false,
  });
  final String name;
  final Widget preview;
  final String? selectedKey, error;
  final ValueChanged<String>? onChoice;
  final VoidCallback? onUpload, onClose, onSave;
  final bool busy, dirty, uploadSelected;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        rt = RaftRecipeTokens(RaftTokens.of(context));
    final states = RaftRecipeStates({
      if (t.dark) RaftRecipeStates.dark,
    }, MediaQuery.sizeOf(context).width);
    final slots = RaftDialogRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: states,
      tokens: rt,
    );
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: math.min(512, MediaQuery.sizeOf(context).width - 32),
          child: RaftRecipeBox(
            style: slots.content,
            tokens: rt,
            applyTransform: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftRecipeBox(
                  style: slots.header,
                  tokens: rt,
                  child: Row(
                    children: [
                      Expanded(
                        child: RaftCssText(
                          t.brutal
                              ? raftText(context, 'Choose Avatar').toUpperCase()
                              : raftText(context, 'Choose Avatar'),
                          style: slots.title.textStyle(rt),
                        ),
                      ),
                      RaftRecipeButton(
                        label: raftText(context, 'Close'),
                        glyphSize: 20,
                        glyph: RaftGlyph.x,
                        size: RaftButtonRecipeSize.iconMd,
                        variant: RaftButtonRecipeVariant.outline,
                        onPressed: busy ? null : onClose,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: slots.content.rowGap ?? 0),
                Flexible(
                  child: SingleChildScrollView(
                    child: RaftRecipeBox(
                      style: slots.body,
                      tokens: rt,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 64, height: 64, child: preview),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _AvatarChoice(
                                      key: const ValueKey('avatar-upload'),
                                      label: raftText(context, 'Upload image'),
                                      selected: uploadSelected,
                                      onPressed: busy ? null : onUpload,
                                      child: RaftIcon(
                                        RaftGlyph.upload,
                                        size: 16,
                                        color: raftPanelInk(
                                          t,
                                          .6,
                                          t.colors['foreground-muted']!,
                                        ),
                                      ),
                                    ),
                                    for (final key in raftAgentAvatarChoices)
                                      _AvatarChoice(
                                        key: ValueKey('avatar-choice-$key'),
                                        label: key,
                                        selected: key == selectedKey,
                                        onPressed: busy
                                            ? null
                                            : () => onChoice?.call(key),
                                        child: RaftAvatarSlot(
                                          name: name,
                                          avatarUrl: 'pixel:$key',
                                          slot:
                                              RaftAvatarSlotContext.panelHeader,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 20),
                            RaftAgentBanner(
                              status: RaftAgentBannerStatus.warning,
                              description: error!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: slots.content.rowGap ?? 0),
                RaftRecipeBox(
                  style: slots.footer,
                  tokens: rt,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      RaftButton(
                        label: raftText(context, 'Cancel'),
                        size: RaftButtonRecipeSize.sm,
                        tone: RaftButtonRecipeVariant.outline,
                        onPressed: busy ? null : onClose,
                      ),
                      const SizedBox(width: 12),
                      RaftButton(
                        label: raftText(context, 'Save'),
                        size: RaftButtonRecipeSize.sm,
                        tone: RaftButtonRecipeVariant.accent,
                        busy: busy,
                        onPressed: dirty && !busy ? onSave : null,
                      ),
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

class _AvatarChoice extends StatefulWidget {
  const _AvatarChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.child,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget child;
  @override
  State<_AvatarChoice> createState() => _AvatarChoiceState();
}

class _AvatarChoiceState extends State<_AvatarChoice> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = widget.selected
        ? (t.brutal ? t.product.brutalPink : t.colors['accent']!)
        : hovered
        ? t.colors['line-strong']!
        : t.colors['line-muted']!;
    final fill = widget.selected
        ? (t.brutal
              ? t.product.brutalPink.withValues(alpha: .2)
              : t.colors['accent-soft']!)
        : null;
    return RaftTooltip(
      message: widget.label,
      child: FocusableActionDetector(
        enabled: widget.onPressed != null,
        onShowFocusHighlight: (v) => setState(() => focused = v),
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => hovered = true),
            onExit: (_) => setState(() => hovered = false),
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
                  border: Border.all(
                    color: t.brutal && !widget.selected ? Colors.black : color,
                    width: t.brutal ? 2 : 1,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: t.colors['line-strong']!,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Generated AlertDialog slots, used only for this staged field's discard flow.
class RaftAvatarDiscardConfirmation extends StatelessWidget {
  const RaftAvatarDiscardConfirmation({
    super.key,
    required this.onKeep,
    required this.onDiscard,
  });
  final VoidCallback onKeep, onDiscard;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context),
        rt = RaftRecipeTokens(RaftTokens.of(context));
    final s = RaftAlertDialogRecipe.resolve(
      theme: raftRecipeTheme(t),
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    return Center(
      child: SizedBox(
        width: math.min(
          s.content.maxWidth ?? 512,
          MediaQuery.sizeOf(context).width - 32,
        ),
        child: RaftRecipeBox(
          style: s.content,
          tokens: rt,
          applyTransform: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftRecipeBox(
                style: s.header,
                tokens: rt,
                child: RaftCssText(
                  raftText(context, 'Unsaved changes'),
                  style: s.title.textStyle(rt),
                ),
              ),
              RaftRecipeBox(
                style: s.body,
                tokens: rt,
                child: RaftCssText(
                  raftText(context, 'Discard your changes?'),
                  style: s.body.textStyle(rt),
                ),
              ),
              RaftRecipeBox(
                style: s.footer,
                tokens: rt,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    RaftButton(
                      label: raftText(context, 'Keep editing'),
                      size: RaftButtonRecipeSize.sm,
                      tone: RaftButtonRecipeVariant.outline,
                      onPressed: onKeep,
                    ),
                    SizedBox(width: s.footer.columnGap ?? 12),
                    RaftButton(
                      label: raftText(context, 'Discard'),
                      size: RaftButtonRecipeSize.sm,
                      tone: RaftButtonRecipeVariant.danger,
                      onPressed: onDiscard,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
