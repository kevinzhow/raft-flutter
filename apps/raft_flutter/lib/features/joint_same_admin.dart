// Web utils/jointSameAdmin.ts (RFC 075 section 4.5): a joint invite whose
// invitee is the inviter, on a target server the inviter owns or administers,
// connects directly without an email. This only decides whether the form shows
// the confirmation; the server re-checks the inviter's authority on both
// servers before accepting.
library;

import 'package:raft_client/raft_client.dart';

/// Whether any of [invitedPeople] names [user] (same token rules as the
/// server's `resolveJointInvitees`: `a@b` is an email, compared without case;
/// anything else is a handle with an optional `@`).
bool jointInvitesSelf(
  Iterable<String> invitedPeople,
  ({String name, String email})? user,
) {
  if (user == null) return false;
  return invitedPeople.any((raw) {
    final token = raw.trim();
    if (token.contains('@') && !token.startsWith('@')) {
      return user.email.isNotEmpty &&
          token.toLowerCase() == user.email.toLowerCase();
    }
    return user.name.isNotEmpty &&
        token.replaceFirst(RegExp(r'^@'), '') == user.name;
  });
}

/// The server [targetServerSlug] when the invite is a same-admin connection
/// (not the current server, invites the user themselves, and the user owns or
/// administers the target), else null.
RaftRecord? findSameAdminJointTarget({
  required Iterable<RaftRecord> servers,
  required String? currentServerSlug,
  required ({String name, String email})? user,
  required String targetServerSlug,
  required Iterable<String> invitedPeople,
}) {
  final slug = targetServerSlug.trim();
  if (slug.isEmpty || slug == currentServerSlug) return null;
  if (!jointInvitesSelf(invitedPeople, user)) return null;
  final target = servers.where((s) => s.string('slug') == slug).firstOrNull;
  final role = target?.string('role');
  if (target == null || (role != 'owner' && role != 'admin')) return null;
  return target;
}

/// The signed-in user's handle and email as the same-admin rule reads them.
({String name, String email})? jointSelf(RaftRecord? user) => user == null
    ? null
    : (name: user.string('name'), email: user.string('email'));

/// Invite dialogs take people separated by commas or new lines (Web
/// `parseInvitedPeopleText`); repeats are dropped.
List<String> jointPeople(String value) => value
    .split(RegExp(r'[\n,]+'))
    .map((v) => v.trim())
    .where((v) => v.isNotEmpty)
    .toSet()
    .toList();
