// Web `describeJointInviteError` (CreateJointChannelDialog.tsx): the server's
// typed joint-invite rejections (`joint_invitee_not_found`,
// `joint_invitee_not_admin`, `joint_target_server_invalid`,
// `joint_invite_required`) become localized sentences naming the server and
// the invitee the server refused. The server's own `error` text is English
// only, so showing it verbatim would leave zh users an untranslated line.
library;

/// Formats an English catalog [source] with [values] in the UI language.
typedef JointInviteFormat = String Function(
  String source,
  Map<String, Object?> values,
);

/// The localized message for a joint-invite rejection [details] (the
/// allow-listed `RaftApiException.details`), or null when the error is not one
/// this can describe precisely; the caller then keeps its fallback (the
/// server's text, else the generic failure). [currentServerSlug] tells the two
/// causes of `joint_target_server_invalid` apart: only the slug distinguishes
/// "Cannot invite the current server" from "Target server not found".
/// `inviteeIndex` is deliberately unused: it indexes the server's
/// de-duplicated invitee list, not the list the dialog submitted.
String? describeJointInviteError(
  Map<String, dynamic> details,
  String? currentServerSlug,
  JointInviteFormat format,
) {
  final server = details['targetServerSlug'];
  final slug = server is String && server.isNotEmpty ? server : null;
  switch (details['code']) {
    case 'joint_invitee_not_found':
    case 'joint_invitee_not_admin':
      final invitee = details['invitee'];
      if (slug == null || invitee is! String || invitee.isEmpty) return null;
      return format(
        details['code'] == 'joint_invitee_not_found'
            ? 'No one matching {invitee} was found on server "{server}". Check the handle or email.'
            : '{invitee} must be an owner or admin of server "{server}" to be invited.',
        {'invitee': invitee, 'server': slug},
      );
    case 'joint_target_server_invalid':
      if (slug != null &&
          currentServerSlug != null &&
          slug == currentServerSlug) {
        return format(
          "You can't invite this server to its own joint channel.",
          const {},
        );
      }
      if (slug == null) return null;
      return format('Server "{server}" wasn\'t found. Check the slug.', {
        'server': slug,
      });
    case 'joint_invite_required':
      return format('At least one invited person is required', const {});
    default:
      return null;
  }
}
