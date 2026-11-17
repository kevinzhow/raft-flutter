// Mounted AgentProfileEditDialog.tsx avatar branch. The dialog chrome uses
// generated Dialog slots; the 40px preset tiles are product JSX overrides.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../raft_ui.dart';
import '../recipes.dart';
import 'avatar_pixel_data.dart' show raftPixelAvatarSeries;

/// The avatars a picker offers, in picker order (every series of the shared
/// pixelAvatars.json, reserved keys excluded).
final raftAgentAvatarChoices = <String>[
  for (final series in raftPixelAvatarSeries) ...series.$2,
];

/// Heading of each avatar series (`agent.avatar.series.*`).
String raftAvatarSeriesTitle(String key) => switch (key) {
  'bots' => 'Bot family',
  'critters' => 'Critters',
  'space' => 'Space',
  'desk' => 'Desk',
  'food' => 'Food',
  'quest' => 'Quest',
  'weather' => 'Weather',
  'plants' => 'Plants',
  'spooky' => 'Spooky',
  _ => key,
};

/// AgentProfileEditDialog.tsx, avatar field: the preview and the upload tile
/// on one row, then one group per series (eight tiles, or two rows of four
/// when the body is narrower than eight tiles). The card is the Dialog family
/// card, so a narrow window presents it as the sheet.
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

  /// A body narrower than this wraps each series into two rows of four
  /// (`@min-[408px]:grid-cols-8`: eight 44px tiles and seven 8px gaps).
  static const wideBodyWidth = 408.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final heading = t.scale(
      RaftTypeScale.footnote,
      weight: FontWeight.w700,
      color: t.colors['foreground-hint'],
    );
    final card = RaftDialog.card(
      key: const ValueKey('agent-avatar-picker'),
      title: 'Change avatar',
      maxWidth: 512,
      closeEnabled: !busy,
      onClose: onClose ?? () {},
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          RaftButton(
            label: tr('Cancel'),
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.lg,
            onPressed: busy ? null : onClose,
          ),
          RaftButton(
            label: tr('Save'),
            uiVariant: RaftButtonVariant.accent,
            uiSize: RaftButtonSize.lg,
            busy: busy,
            onPressed: dirty && !busy ? onSave : null,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 16,
            children: [
              SizedBox(width: 64, height: 64, child: preview),
              _AvatarChoice(
                key: const ValueKey('avatar-upload'),
                label: tr('Upload image'),
                selected: uploadSelected,
                upload: true,
                onPressed: busy ? null : onUpload,
                child: RaftIcon(
                  RaftGlyph.upload,
                  size: 18,
                  color: t.colors['foreground-muted']!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= wideBodyWidth ? 8 : 4;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  for (final series in raftPixelAvatarSeries)
                    Semantics(
                      container: true,
                      label: tr(raftAvatarSeriesTitle(series.$1)),
                      child: Column(
                        key: ValueKey('avatar-series-${series.$1}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Semantics(
                            header: true,
                            child: RaftCssText(
                              tr(raftAvatarSeriesTitle(series.$1)),
                              style: heading,
                            ),
                          ),
                          for (var at = 0; at < series.$2.length; at += columns)
                            Row(
                              spacing: 8,
                              children: [
                                for (final key
                                    in series.$2.skip(at).take(columns))
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
                                      slot: RaftAvatarSlotContext.panelHeader,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 20),
            // Web `<Banner status="warning" size="sm" role="alert">`.
            RaftErrorBanner(error!, small: true),
          ],
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      // A presented window (sheet or dialog route) centres its own card.
      child: RaftFormFrame.framedOf(context) ? card : Center(child: card),
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
    this.upload = false,
  });
  final String label;
  final bool selected, upload;
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
    // `presetButtonClass`: a selected tile has the sticker ink border on the
    // selected fill; the upload tile is dashed; the rest have no border.
    final color = widget.selected
        ? t.ui.stickerInk
        : widget.upload
        ? t.colors['line-strong']!
        : t.colors['line-muted']!.withValues(alpha: 0);
    final fill = widget.selected
        ? t.colors['selected']
        : hovered
        ? t.colors['fill-medium']
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
          child: RaftHoverRegion(
            onEnter: (_) => setState(() => hovered = true),
            onExit: (_) => setState(() => hovered = false),
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: 44,
                height: 44,
                decoration: RaftCssBoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color, width: 1.5),
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
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: s.footer.columnGap ?? 12,
                  runSpacing: 12,
                  children: [
                    RaftButton(
                      label: raftText(context, 'Keep Editing'),
                      size: RaftButtonRecipeSize.sm,
                      tone: RaftButtonRecipeVariant.outline,
                      onPressed: onKeep,
                    ),
                    RaftButton(
                      label: raftText(context, 'Discard Changes'),
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
