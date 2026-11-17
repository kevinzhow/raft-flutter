// Pure ports of the Web Administration rules (raft-source 26f77ef):
// utils/serverAdminSettings.ts (owner/admin principals, candidates, role
// options, removal) and shared serverPermissions.ts canChangeMemberRole.

/// shared/serverPermissions.ts `canChangeMemberRole`.
bool canChangeMemberRole(String? actor, String? target, String next) {
  if (actor == null || target == null) return false;
  if (actor == 'owner') return true;
  if (actor == 'admin') return target == 'member' && next == 'admin';
  return false;
}

/// shared/serverPermissions.ts `canChangeAgentMemberRole` (v1.24): as
/// [canChangeMemberRole], plus an admin demoting an admin agent to member (an
/// agent is not a peer).
bool canChangeAgentMemberRole(String? actor, String? target, String next) =>
    canChangeMemberRole(actor, target, next) ||
    (actor == 'admin' && target == 'admin' && next == 'member');

/// `ServerAdminSettingsPrincipal`: a human member or an agent.
class AdminPrincipal {
  const AdminPrincipal({
    required this.agent,
    required this.id,
    required this.name,
    required this.role,
    this.displayName,
    this.email,
    this.avatarUrl,
  });
  final bool agent;
  final String id, name, role;
  final String? displayName, email, avatarUrl;

  /// `getAdminPrincipalKey`.
  String get key => '${agent ? 'agent' : 'human'}:$id';

  static String? _string(Object? v) => v is String && v.isNotEmpty ? v : null;

  static AdminPrincipal? human(Map<String, dynamic> m) {
    final id = m['userId'] ?? m['id'];
    if (id is! String) return null;
    return AdminPrincipal(
      agent: false,
      id: id,
      name: m['name'] is String ? m['name'] as String : '',
      displayName: _string(m['displayName']),
      email: _string(m['email']),
      avatarUrl: _string(m['avatarUrl']),
      role: '${m['role'] ?? 'member'}',
    );
  }

  /// `toAgentPrincipal`: only agents with an admin/member server role.
  static AdminPrincipal? agentRow(Map<String, dynamic> m) {
    final role = m['serverRole'];
    if (m['deletedAt'] != null || m['id'] is! String) return null;
    if (role != 'admin' && role != 'member') return null;
    return AdminPrincipal(
      agent: true,
      id: m['id'] as String,
      name: m['name'] is String ? m['name'] as String : '',
      displayName: _string(m['displayName']),
      avatarUrl: _string(m['avatarUrl']),
      role: role as String,
    );
  }

  String get _sortLabel => displayName ?? (agent ? '@$name' : name);

  /// `getAdminPrincipalLabel` (agents) / `getMemberLabel` (humans).
  String get label =>
      displayName ??
      (agent
          ? (name.isEmpty ? 'Unknown member' : '@$name')
          : name.isNotEmpty
          ? name
          : email ?? 'Unknown member');

  /// Picker option text.
  String get optionLabel => agent
      ? '${displayName ?? (name.isEmpty ? 'Unknown member' : '@$name')} · Agent'
      : email == null
      ? (displayName ?? (name.isEmpty ? 'Unknown member' : name))
      : '${displayName ?? (name.isEmpty ? 'Unknown member' : name)} · $email';

  static String roleLabel(String role) => switch (role) {
    'owner' => 'Owner',
    'admin' => 'Admin',
    'member' => 'Member',
    _ => role,
  };

  /// `getPrincipalSubtitle`.
  String get subtitle => agent
      ? 'Agent · ${roleLabel(role)}'
      : email == null
      ? roleLabel(role)
      : '$email · ${roleLabel(role)}';
}

int _compare(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// `getAdminPrincipals`: owners, then admins (humans and agents), by label.
List<AdminPrincipal> adminPrincipals(
  List<AdminPrincipal> members,
  List<AdminPrincipal> agents,
) =>
    [
      ...members.where((m) => m.role == 'owner' || m.role == 'admin'),
      ...agents.where((a) => a.role == 'admin'),
    ]..sort((l, r) {
      if (l.role != r.role) {
        if (l.role == 'owner') return -1;
        if (r.role == 'owner') return 1;
      }
      return _compare(l._sortLabel, r._sortLabel);
    });

/// `getAdminCandidatePrincipals`.
List<AdminPrincipal> adminCandidates(
  List<AdminPrincipal> members,
  List<AdminPrincipal> agents,
  String? actor,
) => [
  ...members.where(
    (m) =>
        m.role != 'owner' &&
        (canChangeMemberRole(actor, m.role, 'owner') ||
            canChangeMemberRole(actor, m.role, 'admin')),
  ),
  ...agents.where(
    (a) => a.role != 'admin' && canChangeMemberRole(actor, a.role, 'admin'),
  ),
]..sort((l, r) => _compare(l._sortLabel, r._sortLabel));

/// `getAdminPrincipalRoleOptions`.
List<String> adminRoleOptions(String? actor, AdminPrincipal principal) {
  if (principal.agent) {
    return principal.role == 'admin' ||
            !canChangeMemberRole(actor, principal.role, 'admin')
        ? const []
        : const ['admin'];
  }
  return [
    for (final role in const ['owner', 'admin'])
      if (role != principal.role &&
          canChangeMemberRole(actor, principal.role, role))
        role,
  ];
}

/// `canRemoveAdminPrincipal`.
bool canRemoveAdmin(String? actor, AdminPrincipal principal, int ownerCount) {
  if (principal.agent) {
    return principal.role == 'admin' &&
        canChangeAgentMemberRole(actor, principal.role, 'member');
  }
  if (principal.role != 'owner' && principal.role != 'admin') return false;
  if (principal.role == 'owner' && ownerCount <= 1) return false;
  return canChangeMemberRole(actor, principal.role, 'member');
}
