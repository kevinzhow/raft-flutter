import 'overlays/dialog.dart' show RaftDialog, showRaftDialog;
// Web `member/RolePermissionHelpDialog.tsx`: a DialogCard titled "Human roles" /
// "Agent roles" holding one `Card p-3` per role (name, summary, details).
import 'card.dart' show RaftCard;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

const _humanRoles = [
  (
    'Owner',
    'Full server control.',
    'Billing and ownership. Server settings. Admins and members. Channels, computers, and agents.',
  ),
  (
    'Admin',
    'Operational server admin.',
    'Server profile. Channels and channel members. Agents and computers. Invites, join links, and admin promotion.',
  ),
  (
    'Member',
    'Regular server participant.',
    'Joined channels, DMs, and tasks. Public channel joins. No server-level settings or membership management.',
  ),
];

const _agentRoles = [
  (
    'Admin',
    'Operational server admin.',
    'Server profile. Channels and channel members. No agents, computers, invites, join links, or role promotion yet.',
  ),
  (
    'Member',
    'Regular server participant.',
    'Allowed channels, DMs, and tasks. No server-level settings, channels, or membership management.',
  ),
];

/// Opens the dialog on the Web `Modal` layer (`closeOnBackdrop`: a press on the
/// backdrop closes it).
Future<void> showRaftRolePermissionHelp(
  BuildContext context, {
  required bool agent,
}) {
  final t = RaftTokens.of(context);
  return showRaftDialog<void>(
    context: context,
    modal: true,
    legacyModal: true,
    barrierDismissible: true,
    barrierLabel: 'Close',
    // `Modal`: `backdrop-blur-[2px]` over the page (the Dialog layer has none).
    builder: (context) {
      final dialog = RaftRolePermissionHelpDialog(
        agent: agent,
        onClose: () => Navigator.of(context).pop(),
      );
      if (t.isRaftLook) return dialog;
      final blur = t.size('blur.modalBackdrop', fallback: 2);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: dialog,
      );
    },
  );
}

class RaftRolePermissionHelpDialog extends StatelessWidget {
  const RaftRolePermissionHelpDialog({
    super.key,
    required this.agent,
    required this.onClose,
  });
  final bool agent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final strong = t.strong;
    final summary = t.muted;
    final details = t.muted;
    return RaftDialog.agent(
      surfaceKey: const ValueKey('role-help-dialog'),
      title: agent ? 'Agent roles' : 'Human roles',
      onClose: onClose,
      onBackdrop: onClose,
      children: [
        // `space-y-3`
        for (final (i, (role, sum, text))
            in (agent ? _agentRoles : _humanRoles).indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          RaftCard(
            padding: const EdgeInsets.all(12), // p-3
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4), // mb-1
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8, // gap-x-2
                    runSpacing: 4, // gap-y-1
                    children: [
                      RaftCssText(
                        raftText(context, role),
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                          color: strong,
                        ),
                      ),
                      RaftCssText(
                        raftText(context, sum),
                        style: RaftTypography.body(
                          t,
                          size: 12,
                          line: 16,
                          weight: FontWeight.w700,
                          color: summary,
                        ),
                      ),
                    ],
                  ),
                ),
                RaftCssText(
                  raftText(context, text),
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 14 * 1.625,
                    color: details,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
