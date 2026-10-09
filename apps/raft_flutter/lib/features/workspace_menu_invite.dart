import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// Bounded email/member path of InviteHumanDialog.tsx309–352. The complete
/// multi-person, guest feature, link and billing UI is still a separate port.
Future<bool> showWorkspaceMenuInvite(
  BuildContext context,
  WorkspaceController workspace,
) async {
  final serverId = workspace.server?.id,
      origin = workspace.client.origin,
      principal = workspace.client.user?.id,
      generation = workspace.client.generation,
      role = workspace.server?.string('role');
  bool current() =>
      context.mounted &&
      serverId != null &&
      principal != null &&
      origin == workspace.client.origin &&
      principal == workspace.client.user?.id &&
      generation == workspace.client.generation &&
      serverId == workspace.server?.id &&
      role == workspace.server?.string('role') &&
      workspace.can('inviteMembers');
  if (!current()) return false;
  final sent = await showRaftDialog<bool>(
    context: context,
    builder: (_) => RaftFormDialog(
      title: 'Invite human',
      submitLabel: 'Send invitations',
      fields: [
        RaftFormField(
          'email',
          'Email',
          required: true,
          validator: sourceInviteEmailError,
        ),
      ],
      onSubmit: (values) async {
        if (!current()) {
          throw const RaftApiException('Invitation is unavailable.');
        }
        await workspace.client.post(
          '/servers/$serverId/invites',
          data: {'email': values['email']!.trim(), 'role': 'member'},
        );
      },
    ),
  );
  return sent == true && current();
}

/// Exact shared emailValidation.ts3–22 validation, before any invitation POST.
String? sourceInviteEmailError(String value) {
  final email = value.trim(), at = value.trim().indexOf('@');
  if (email.isEmpty ||
      email.length > 254 ||
      RegExp(r'\s').hasMatch(email) ||
      at <= 0 ||
      at != email.lastIndexOf('@')) {
    return 'Enter a valid email address';
  }
  final local = email.substring(0, at), domain = email.substring(at + 1);
  if (local.length > 64 ||
      domain.isEmpty ||
      domain.startsWith('.') ||
      domain.endsWith('.') ||
      !domain.contains('.') ||
      domain.contains('..') ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address';
  }
  return null;
}
