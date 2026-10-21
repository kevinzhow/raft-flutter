import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Web `DeleteServerConfirmDialog`: the one delete-server confirmation (type
/// the slug to confirm), shared by the Settings danger zone and the blocking
/// server-setup footer so both doors to the same irreversible action ask the
/// same question. Deletes the current workspace when confirmed.
Future<void> confirmDeleteServer(
  BuildContext context,
  WorkspaceController w,
) async {
  final server = w.server;
  if (server == null) return;
  final matches = ValueNotifier(false);
  final ok = await RaftConfirmDialog.show(
    context,
    RaftConfirmDialog(
      title: 'Delete Server',
      confirmLabel: 'Delete Server',
      surfaceKey: const ValueKey('server-danger-dialog'),
      confirmKey: const Key('server-delete-confirm-button'),
      content: _DeleteServerConfirm(
        name: server.name,
        slug: server.string('slug'),
        matches: matches,
      ),
      confirmEnabled: matches,
    ),
  );
  matches.dispose();
  if (ok != true) return;
  await w.client.exitServer(server.id, delete: true);
  w.sessionScope.revokeServer(server.id);
  await w.recoverMembership();
}

/// SetupSessionFooter "Delete this server": owners only (Web
/// `useServerPermissions().isOwner`), and not while the step is busy. Null
/// hides the link.
VoidCallback? setupDeleteServerAction(
  BuildContext context,
  WorkspaceController w, {
  bool busy = false,
}) => w.server?.string('role') == 'owner' && !busy
    ? () => confirmDeleteServer(context, w)
    : null;

/// The setup surfaces' session links ("Switch server", owner-only "Delete this
/// server"); null when neither applies.
Widget? setupSessionActions(
  BuildContext context,
  WorkspaceController w, {
  required VoidCallback? onSwitchServer,
  required bool busy,
}) => onSwitchServer == null && !setupShowsDeleteServer(w)
    ? null
    : RaftCindySessionFooter(
        onSwitchServer: busy ? null : onSwitchServer,
        onDeleteServer: setupDeleteServerAction(context, w, busy: busy),
        showDeleteServer: setupShowsDeleteServer(w),
      );

/// Whether the setup footer shows the link at all (it stays visible, dimmed,
/// while a step is busy).
bool setupShowsDeleteServer(WorkspaceController w) =>
    w.server?.string('role') == 'owner';

/// DangerZoneSection delete confirmation body: `space-y-4`, warning copy
/// with the bold server name, then "Type `slug` to confirm:" over SlugInput.
class _DeleteServerConfirm extends StatefulWidget {
  const _DeleteServerConfirm({
    required this.name,
    required this.slug,
    required this.matches,
  });
  final String name, slug;
  final ValueNotifier<bool> matches;
  @override
  State<_DeleteServerConfirm> createState() => _DeleteServerConfirmState();
}

class _DeleteServerConfirmState extends State<_DeleteServerConfirm> {
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    // `<span className="font-bold">` inside the dialog copy.
    final bold = RaftConfirmDialog.messageStyle(t)
        .merge(text.title)
        .copyWith(
          fontSize: RaftConfirmDialog.messageStyle(t).fontSize,
          height: RaftConfirmDialog.messageStyle(t).height,
          color: RaftConfirmDialog.messageStyle(t).color,
        );
    // `text-sm text-foreground-muted theme-brutal:text-black/60 mb-2`
    final prompt = text.bodyMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: raftText(context, 'This will permanently delete '),
              ),
              TextSpan(text: widget.name, style: bold),
              TextSpan(
                text: raftText(
                  context,
                  ' and all its data (agents, channels, messages). This cannot be undone.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x4),
        Text.rich(
          // CSS gives the inline mono span the paragraph's 20px line box.
          strutStyle: StrutStyle.fromTextStyle(prompt, forceStrutHeight: true),
          TextSpan(
            style: prompt,
            children: [
              TextSpan(text: raftText(context, 'Type ')),
              TextSpan(text: widget.slug, style: text.monoBold),
              TextSpan(text: raftText(context, ' to confirm:')),
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x2),
        RaftSettingsPrefixedInput(
          key: const Key('server-delete-slug-input'),
          prefix: '/',
          placeholder: widget.slug,
          mono: true,
          // Inherits the confirm copy's `text-foreground-muted`.
          textColor: RaftConfirmDialog.messageStyle(t).color,
          onChanged: (v) => widget.matches.value = v == widget.slug,
        ),
      ],
    );
  }
}
