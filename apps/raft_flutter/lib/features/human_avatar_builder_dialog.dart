import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'human_avatar_option_tiles.dart';
import 'human_avatar_save.dart';
import 'sender_avatar_projection.dart' show raftUploadedHumanAvatar;

/// Opens the human avatar builder (Web `HumanAvatarBuilderDialog`), a dialog
/// from 768 and the bottom sheet below (Web `DialogSheetContent`). A fresh
/// builder per opening: the stored look, the first tab, no error.
Future<void> showHumanAvatarBuilder(
  BuildContext context, {
  required RaftClient client,
  required String? avatarUrl,
  VoidCallback? onSaved,
}) => Navigator.of(context, rootNavigator: true).push(
  raftFormRoute<void>(
    context,
    // The builder guards its own close: nothing is stored until Save, and a
    // choice is not "text the person typed" (Web asks nothing on Cancel).
    guardUnsaved: false,
    // Web `DialogSheetContent size="lg"`.
    dialogMaxWidth: 640,
    builder: (_) => HumanAvatarBuilderDialog(
      client: client,
      avatarUrl: avatarUrl,
      onSaved: onSaved,
    ),
  ),
);

/// Build a pixel avatar from the shared layers: the 99px preview with Shuffle
/// beside it, five tabs of options, Cancel and Save. Every option is drawn as
/// you wearing it; the chosen one carries an ink ring. Nothing is stored until
/// Save, which is off while the look is the stored one; a failed save keeps the
/// dialog and every choice, with the old avatar still in place. Opens on the
/// stored look, or (over a photo or no avatar) on the default with a note that
/// saving replaces the photo.
class HumanAvatarBuilderDialog extends StatefulWidget {
  const HumanAvatarBuilderDialog({
    super.key,
    required this.client,
    required this.avatarUrl,
    this.onSaved,
    this.save = saveHumanAvatarRecipe,
  });
  final RaftClient client;

  /// The avatar now: the builder opens on it when it is a built one.
  final String? avatarUrl;

  /// After a save the server confirmed.
  final VoidCallback? onSaved;

  /// Overridable for tests.
  final Future<void> Function(RaftClient, RaftHumanAvatarRecipe) save;

  @override
  State<HumanAvatarBuilderDialog> createState() => _BuilderState();
}

class _BuilderState extends State<HumanAvatarBuilderDialog> {
  late RaftHumanAvatarRecipe recipe =
      RaftHumanAvatarRecipe.read(widget.avatarUrl) ??
      RaftHumanAvatarRecipe.defaults;
  late final RaftHumanAvatarRecipe? stored = RaftHumanAvatarRecipe.read(
    widget.avatarUrl,
  );
  late final bool replacesPhoto = raftUploadedHumanAvatar(widget.avatarUrl);
  HumanAvatarTab tab = HumanAvatarTab.background;
  bool saving = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears on the next choice, Shuffle or save; the dialog state is dropped when it closes.
  bool failed = false;
  // The signed-in account when it opened: a save for another one is dropped.
  late final String account =
      '${widget.client.authenticationGeneration}|${widget.client.user?.id}';

  bool get changed => stored == null || stored != recipe;

  void pick(RaftHumanAvatarField field, String id) {
    if (saving) return;
    // A new choice clears a failed save's banner: its "save again" would be
    // wrong once Save is off (back to the stored look).
    setState(() {
      failed = false;
      recipe = recipe.withOption(field, id);
    });
  }

  void shuffle() => setState(() {
    failed = false;
    recipe = RaftHumanAvatarRecipe.randomLook();
  });

  void close() {
    if (!saving && mounted) Navigator.of(context).maybePop();
  }

  Future<void> save() async {
    if (saving || !changed) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.save(widget.client, recipe);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved?.call();
    } catch (_) {
      // The dialog stays with every choice; the old avatar is untouched.
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    final body = _body(context, tr);
    final saveButton = RaftButton(
      key: const ValueKey('human-avatar-builder-save'),
      label: tr(saving ? 'Saving…' : 'Save'),
      uiVariant: RaftButtonVariant.primary,
      // The footer buttons measure 34px on Web (the Shuffle button's md).
      uiSize: RaftButtonSize.md,
      busy: saving,
      // Nothing to save while it is the stored look; over a photo or no
      // avatar, Save always does something.
      onPressed: changed && !saving ? save : null,
    );
    final cancel = RaftButton(
      key: const ValueKey('human-avatar-builder-cancel'),
      label: tr('Cancel'),
      uiVariant: RaftButtonVariant.ghost,
      uiSize: RaftButtonSize.md,
      onPressed: saving ? null : close,
    );
    return PopScope(
      // Esc, ×, the scrim, Back and a drag down close it, except while a save
      // is in flight (Web `handleOpenChange`).
      canPop: !saving,
      child: RaftDismissScope(
        onDismiss: close,
        child: RaftFormFrame.sheetOf(context)
            ? RaftFormSheet(
                title: tr('Build an avatar'),
                onClose: saving ? null : close,
                body: body,
                commit: RaftButton(
                  key: const ValueKey('human-avatar-builder-save'),
                  label: tr(saving ? 'Saving…' : 'Save'),
                  uiVariant: RaftButtonVariant.primary,
                  uiSize: RaftButtonSize.md,
                  busy: saving,
                  onPressed: changed && !saving ? save : null,
                ),
              )
            : RaftDialog.shell(
                surfaceKey: const ValueKey('human-avatar-builder'),
                title: tr('Build an avatar'),
                maxWidth: 640,
                // Esc, the X and the scrim ask the route; PopScope refuses
                // them while a save is in flight (the X is off then).
                onClose: saving ? null : close,
                body: body,
                footer: [cancel, saveButton],
              ),
      ),
    );
  }

  Widget _body(BuildContext context, String Function(String) tr) {
    final look = recipe.serialize();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x4,
      children: [
        // One layout at every width: the preview with Shuffle beside it, then
        // the tabs at the body's full width, then the options.
        Row(
          spacing: RaftSpace.x4,
          children: [
            Semantics(
              image: true,
              label: tr('Avatar preview'),
              child: ExcludeSemantics(
                child: RaftAvatarSlot(
                  key: ValueKey('human-avatar-builder-preview:$look'),
                  name: '',
                  agent: false,
                  slot: RaftAvatarSlotContext.profileTile,
                  sizeOverride: 99,
                  avatarUrl: look,
                ),
              ),
            ),
            RaftButton(
              key: const ValueKey('human-avatar-builder-shuffle'),
              label: tr('Shuffle'),
              glyph: RaftGlyph.shuffle,
              uiVariant: RaftButtonVariant.standard,
              uiSize: RaftButtonSize.md,
              onPressed: saving ? null : shuffle,
            ),
          ],
        ),
        if (replacesPhoto)
          RaftBanner(
            key: const ValueKey('human-avatar-builder-replaces-photo'),
            status: RaftBannerRecipeStatus.info,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.info,
            description: tr('This replaces your current photo when you save.'),
          ),
        if (failed)
          // Something went wrong in a dialog: an orange banner in it. Save,
          // still there, is the way out; the sentence says so.
          RaftBanner(
            key: const ValueKey('human-avatar-builder-error'),
            status: RaftBannerRecipeStatus.warning,
            size: RaftBannerRecipeSize.sm,
            glyph: RaftGlyph.triangleAlert,
            description: tr(
              "Couldn't save your avatar. Your old one is still there. Try saving again.",
            ),
          ),
        RaftTabs<HumanAvatarTab>(
          value: tab,
          onChanged: (next) => setState(() => tab = next),
          tabs: [
            for (final t in HumanAvatarTab.values)
              RaftTabItem(
                value: t,
                label: tr(t.label),
                itemKey: ValueKey('human-avatar-builder-tab-${t.name}'),
              ),
          ],
          gap: 12,
          panels: {
            tab: HumanAvatarTabPanel(
              tab: tab,
              recipe: recipe,
              disabled: saving,
              onPick: pick,
            ),
          },
        ),
      ],
    );
  }
}
