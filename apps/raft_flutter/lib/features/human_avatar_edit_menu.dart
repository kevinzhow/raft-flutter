import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'human_avatar_builder_dialog.dart';
import 'human_avatar_flag.dart';

/// Your own avatar where you can change it (Web `HumanAvatarEditMenu`:
/// Settings > Account, your profile, account setup): the avatar itself is the
/// button, with the pencil veil, and opens a menu: "Upload a photo" ([onUpload]
/// chooses a file and stores it the way that page does) and "Build an avatar"
/// (the builder, which saves on its own). There is no Remove: to change an
/// avatar you upload or build another (product decision). "Build an avatar",
/// the builder's only way in, shows only while `human_avatar_builder_v0` is on
/// for the current server (off with no [workspace], e.g. account setup before
/// joining one).
class HumanAvatarEditMenu extends StatefulWidget {
  const HumanAvatarEditMenu({
    super.key,
    required this.client,
    required this.avatarUrl,
    required this.avatar,
    required this.onUpload,
    this.workspace,
    this.busy = false,
    this.onBuilt,
  });

  final RaftClient client;

  /// The stored avatar: where the builder opens.
  final String? avatarUrl;

  /// What the button shows (the avatar in its frame; a photo not uploaded
  /// yet, say).
  final Widget avatar;

  /// "Upload a photo": choose a file and store it. Not called while [busy].
  final VoidCallback onUpload;
  final WorkspaceController? workspace;

  /// An upload in flight: the veil stays up and the menu is off.
  final bool busy;

  /// After the builder saved.
  final VoidCallback? onBuilt;

  @override
  State<HumanAvatarEditMenu> createState() => _HumanAvatarEditMenuState();
}

class _HumanAvatarEditMenuState extends State<HumanAvatarEditMenu> {
  late bool builderOn = humanAvatarBuilderCached(widget.workspace);

  @override
  void initState() {
    super.initState();
    final w = widget.workspace;
    evaluateHumanAvatarBuilder(w).then((on) {
      if (mounted && on != null && on != builderOn) {
        setState(() => builderOn = on);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, 'Change avatar');
    // While a photo is saving the avatar says so (it is off until then).
    final triggerLabel = widget.busy
        ? raftText(context, 'Uploading avatar')
        : label;
    return RaftDropdownMenu(
      label: label,
      enabled: !widget.busy,
      align: RaftDropdownAlign.start,
      sideOffset: 6,
      entries: [
        RaftMenuEntry(
          label: raftText(context, 'Upload a photo'),
          glyph: RaftGlyph.upload,
          onPressed: widget.onUpload,
        ),
        if (builderOn)
          RaftMenuEntry(
            label: raftText(context, 'Build an avatar'),
            glyph: RaftGlyph.smile,
            onPressed: () => showHumanAvatarBuilder(
              context,
              client: widget.client,
              avatarUrl: widget.avatarUrl,
              onSaved: widget.onBuilt,
            ),
          ),
      ],
      triggerBuilder: (context, focusNode, onPressed) => RaftInteractive(
        focusNode: focusNode,
        onPressed: widget.busy ? null : onPressed,
        semanticLabel: triggerLabel,
        busy: widget.busy,
        builder: (context, state) => _AvatarEditTrigger(
          avatar: widget.avatar,
          veil: widget.busy || state.hovered || state.focusVisible,
          focusVisible: state.focusVisible,
        ),
      ),
    );
  }
}

const double _circle = 999;

/// The avatar with Web's `AvatarEditVeil` over it: the scrim (`layer-backdrop`)
/// with a pencil in HUD ink covering the avatar to its corners, shown on hover,
/// on keyboard focus and the whole time an upload is in flight.
class _AvatarEditTrigger extends StatelessWidget {
  const _AvatarEditTrigger({
    required this.avatar,
    required this.veil,
    required this.focusVisible,
  });
  final Widget avatar;
  final bool veil, focusVisible;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final square = t.option('avatar.shape', or: 'circle') == 'square';
    final veilFill = ColoredBox(
      color: t.colors['layer-backdrop']!,
      child: Center(
        child: RaftIcon(
          RaftGlyph.pencil,
          size: 20,
          color: t.colors['foreground-on-hud'],
        ),
      ),
    );
    return CustomPaint(
      foregroundPainter: RaftCssFocusOutline.rounded(
        enabled: focusVisible,
        color: t.colors['line-strong']!,
        radius: square ? t.size('radius.avatar', fallback: 0) : _circle,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          avatar,
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: veil ? 1 : 0,
                  child: square
                      ? ClipRRect(
                          borderRadius: raftRoundedBorder(
                            t.size('radius.avatar', fallback: 0),
                          ),
                          child: veilFill,
                        )
                      : ClipOval(child: veilFill),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
