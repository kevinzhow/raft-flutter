import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import 'account_onboarding.dart' show AccountMediaActions;

/// Web `HumanDetailPanel` MAX_HUMAN_DESCRIPTION_LENGTH.
const maxHumanDescriptionLength = 3000;

/// Your own profile: pick and upload a new picture (Web `handleUploadAvatar`).
/// Returns the sentence to show when it failed, null when it worked or the
/// picker was cancelled.
Future<String?> uploadOwnAvatar(RaftClient client) async {
  try {
    await AccountMediaActions.uploadAvatar(client);
    return null;
  } catch (error) {
    return userErrorText(
      error,
      fallback: 'Failed to upload avatar',
      where: 'member avatar',
    );
  }
}

/// The "Edit description" form of your own profile (Web `handleSaveDescription`):
/// at most 3000 characters, an empty text clears it.
Widget ownDescriptionDialog(
  BuildContext context, {
  required RaftClient client,
  required String initial,
  required Future<void> Function() onSaved,
}) => RaftFormDialog(
  title: raftText(context, 'Edit Description'),
  fields: [
    RaftFormField(
      'description',
      'Description',
      initial: initial,
      multiline: true,
      validator: (value) => value.trim().length > maxHumanDescriptionLength
          ? raftFormat(
              context,
              'Description must be {count} characters or fewer.',
              {'count': maxHumanDescriptionLength},
            )
          : null,
    ),
  ],
  onSubmit: (values) async {
    final text = (values['description'] ?? '').trim();
    await client.patch(
      '/auth/me',
      data: {'description': text.isEmpty ? null : text},
    );
    await client.reloadUser();
    await onSaved();
  },
);
