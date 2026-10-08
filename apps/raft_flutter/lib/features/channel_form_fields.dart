// Field/avatar pieces shared by the channel dialogs (create channel, channel
// settings sheet, add member): raft-ui `Input`/`Textarea` over the app's
// field theme, the `relative` + `Search size={14} absolute left-3` +
// `pl-9` search input, `Banner intent="warning"` and the `AvatarSlot`
// adapter for candidate rows.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'create_channel_dialog.dart';
import 'public_avatar_url.dart';

/// raft-ui `Input` (single line) or `Textarea rows={2}` (multiline:
/// textarea recipe `min-height: 96px`, scrolling inside that box).
class ChannelTextInput extends StatelessWidget {
  const ChannelTextInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.multiline = false,
    this.autofocus = false,
    this.enabled = true,
    this.leadingGlyph,
    this.onSubmitted,
    this.fieldKey,
  });
  final TextEditingController controller;
  final String? placeholder;
  final bool multiline, autofocus, enabled;
  final RaftGlyph? leadingGlyph;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final base = Theme.of(context).inputDecorationTheme.contentPadding;
    final resolved = base?.resolve(Directionality.of(context));
    Widget field = TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      style: t.fieldStyle,
      minLines: multiline ? null : 1,
      maxLines: multiline ? null : 1,
      expands: multiline,
      textAlignVertical: multiline ? TextAlignVertical.top : null,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: placeholder == null ? null : raftText(context, placeholder!),
        // `pl-9` replaces the input's left padding when a glyph leads.
        contentPadding: leadingGlyph == null || resolved == null
            ? null
            : resolved.copyWith(left: resolved.left - 12 + 36),
      ),
    );
    if (multiline) field = SizedBox(height: 96, child: field);
    if (leadingGlyph != null) {
      field = Stack(
        alignment: Alignment.centerLeft,
        children: [
          field,
          Positioned(
            left: 12 + t.border, // left-3 inside the border box
            child: IgnorePointer(
              child: RaftIcon(
                leadingGlyph!,
                size: 14,
                color: t.colors['foreground-muted'],
              ),
            ),
          ),
        ],
      );
    }
    return RaftFieldSurface(child: field);
  }
}

/// Web `Banner intent="warning" className="font-bold"`.
class ChannelFormBanner extends StatelessWidget {
  const ChannelFormBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.colors['warning-soft'],
          border: Border.all(
            color: t.brutal ? t.colors['line-strong']! : t.colors['warning']!,
            width: t.border,
          ),
        ),
        child: Text(
          message,
          style: raftCssTextStyle(
            family: t.headingFont,
            step: RaftTextSteps.sm,
            weight: FontWeight.w700,
            color: t.strong,
          ),
        ),
      ),
    );
  }
}

/// `AvatarSlot` for a picker candidate: agents paint their pixel artwork or
/// public upload; humans use the `humanPlaceholder` User glyph when asked.
class ChannelCandidateAvatar extends StatelessWidget {
  const ChannelCandidateAvatar({
    super.key,
    required this.candidate,
    required this.avatarContext,
    this.humanPlaceholder = false,
    this.origin,
    this.presence,
  });
  final ChannelMemberCandidate candidate;
  final RaftMountedAvatarContext avatarContext;
  final bool humanPlaceholder;
  final String? origin;
  final RaftAvatarPresence? presence;
  @override
  Widget build(BuildContext context) {
    final agent = candidate.kind == 'agent';
    final url = candidate.avatarUrl;
    final pixel = agent && url != null && url.startsWith('pixel:')
        ? url.substring(6)
        : null;
    final uploaded = pixel == null && origin != null
        ? raftPublicAvatarUrl(origin!, url)
        : null;
    return RaftMountedAvatarFrame(
      name: candidate.label,
      avatarContext: avatarContext,
      identity: agent
          ? RaftMountedAvatarIdentity.agent
          : RaftMountedAvatarIdentity.human,
      presence: presence,
      child: agent && (pixel != null || uploaded != null)
          ? RaftAvatarContent(
              name: candidate.label,
              kind: RaftAvatarContentKind.agent,
              pixelKey: pixel,
              uploadedUrl: uploaded,
            )
          : !agent && !humanPlaceholder && uploaded != null
          ? RaftAvatarContent(name: candidate.label, uploadedUrl: uploaded)
          : null,
    );
  }
}
