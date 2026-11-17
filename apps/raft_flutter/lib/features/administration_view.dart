import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../platform/content_links.dart';
import 'administration_context_grants.dart';
import 'administration_model.dart';
import 'administration_onboarding_section.dart';
import 'administration_support.dart';
import 'administration_switch_sections.dart';
import 'agent_detail_view.dart' show agentTimeFormatter;
import 'member_removal_impact.dart';
import 'management_support.dart'
    show
        managementMap,
        managementRows,
        pageIdentity;

/// Settings > Workspace > Administration: SettingsPanel.tsx
/// AdministrationTabContent. Each section owns its data and requests like the
/// Web component it ports, under the same permission gate:
///
/// | section | gate | data |
/// | --- | --- | --- |
/// | Owners & Admins | changeMemberRoles | entity directory members + agents |
/// | System Channels | changeChannelVisibility | #all in the channel list |
/// | Pending Invites | inviteMembers | GET /servers/:id/invites |
/// | Invite Links | inviteMembers | GET /servers/:id/join-links |
/// | Pre-join Agreement | editServerSettings | GET /servers/:id/agreement |
/// | Onboarding | editServerSettings | GET /servers/:id/settings + setup-projection |
/// | Translation | (server) | translation store gate |
/// | Product analytics | editServerSettings | GET .../product-analytics-settings |
/// | Member Permissions | (server); edit needs editServerSettings | server `hideHumansFromMembers` |
/// | Context access | owner/admin + `agent_context_view_v0` | GET .../agent-context-view-grants |
///
/// Revisits paint each section's last accepted reads (in-memory page
/// snapshots under [pageIdentity]) and revalidate in place.
class AdministrationView extends StatelessWidget {
  const AdministrationView({
    super.key,
    required this.controller,
    this.frontendOrigin,
    this.standalone = false,
  });
  final WorkspaceController controller;

  /// Mounted as its own route (not inside the Settings page's scrolling
  /// panel): scrolls with the panel content inset itself.
  final bool standalone;

  /// Web origin for invite-link URLs (`shareableWebOrigin()`).
  final Uri? frontendOrigin;

  @override
  Widget build(BuildContext context) {
    final w = controller;
    if (w.server == null) return const SizedBox.shrink();
    final origin = frontendOrigin ?? ContentLinks.originFor(w.client.origin);
    // Sections rebuild with the server identity (account, server, role).
    final sections = KeyedSubtree(
      key: ValueKey((identityHashCode(w), pageIdentity(w))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (w.can('changeMemberRoles')) _AdminsSection(w: w),
          if (w.can('changeChannelVisibility'))
            AdminSystemChannelsSection(w: w),
          if (w.can('inviteMembers')) _InvitesSection(w: w),
          if (w.can('inviteMembers'))
            _JoinLinksSection(w: w, origin: origin.origin),
          if (w.can('editServerSettings')) _AgreementSection(w: w),
          if (w.can('editServerSettings')) AdminOnboardingSection(w: w),
          AdminTranslationSection(w: w),
          if (w.can('editServerSettings')) _ProductAnalyticsSection(w: w),
          AdminMemberPermissionsSection(w: w),
          AdminContextViewGrantsSection(w: w),
        ],
      ),
    );
    return standalone
        ? ListView(
            key: const PageStorageKey('administration-page'),
            padding: raftScrollPadding(
              context,
              RaftSettingsPanelFrame.contentInset,
            ),
            children: [sections],
          )
        : sections;
  }
}

/// The `saved` flag Web clears after a delay (1.5 s / 2 s).
mixin _SavedFlash<T extends StatefulWidget> on State<T> {
  bool saved = false;
  Timer? _savedTimer;
  void flashSaved(Duration duration) {
    setState(() => saved = true);
    _savedTimer?.cancel();
    _savedTimer = Timer(duration, () {
      if (mounted) setState(() => saved = false);
    });
  }

  void clearSaved() {
    _savedTimer?.cancel();
    saved = false;
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }
}

RaftAdminSaveState _saveState(bool saving, bool saved) => saving
    ? RaftAdminSaveState.saving
    : saved
    ? RaftAdminSaveState.saved
    : RaftAdminSaveState.idle;

// ------------------------------------------------------------ Owners & Admins

class _AdminsSection extends StatefulWidget {
  const _AdminsSection({required this.w});
  final WorkspaceController w;
  @override
  State<_AdminsSection> createState() => _AdminsSectionState();
}

class _AdminsSectionState extends State<_AdminsSection> {
  WorkspaceController get w => widget.w;
  WorkspaceEntityDirectory get directory => w.services.entityDirectory;
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears when the next role change starts (Web setError('') in handlePromote/handleDemote); the section is remounted on server/account change.
  String? selectedKey, savingKey, error;
  String selectedRole = 'admin';
  late final impact = MemberRemovalImpactRead(w, _changed);

  @override
  void initState() {
    super.initState();
    directory.addListener(_changed);
    // Web loadMembers() + loadAgents() on mount (store-coalesced reads that
    // replace the accepted lists in place).
    unawaited(directory.refresh(WorkspaceEntityKind.members));
    unawaited(directory.refresh(WorkspaceEntityKind.agents));
  }

  @override
  void dispose() {
    directory.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  String? get role => w.server?.string('role');

  List<AdminPrincipal> get members => [
    for (final row in directory.authorMembers)
      ?AdminPrincipal.human(Map<String, dynamic>.from(row)),
  ];

  List<AdminPrincipal> get agents => [
    for (final row in directory.authorAgents)
      ?AdminPrincipal.agentRow(Map<String, dynamic>.from(row)),
  ];

  Future<void> setRole(AdminPrincipal principal, String next) async {
    final server = w.server!.id;
    if (principal.agent) {
      await w.command(
        'PATCH',
        '/agents/${principal.id}',
        data: {'serverRole': next == 'member' ? 'member' : 'admin'},
      );
      await directory.refresh(WorkspaceEntityKind.agents, force: true);
    } else {
      await w.command(
        'PATCH',
        '/servers/$server/members/${principal.id}',
        data: {'role': next},
      );
      await directory.refresh(WorkspaceEntityKind.members, force: true);
    }
  }

  Future<void> change(
    AdminPrincipal principal,
    String next,
    String failure,
  ) async {
    final identity = pageIdentity(w);
    setState(() {
      savingKey = principal.key;
      error = null;
    });
    try {
      await setRole(principal, next);
      if (!mounted || identity != pageIdentity(w)) return;
      if (next != 'member') selectedKey = null;
    } catch (e) {
      if (mounted && identity == pageIdentity(w)) {
        error = adminApiError(e, failure);
      }
    } finally {
      if (mounted) setState(() => savingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = this.members, agents = this.agents;
    final admins = adminPrincipals(members, agents);
    final candidates = adminCandidates(members, agents, role);
    final selected = candidates.where((c) => c.key == selectedKey).firstOrNull;
    final options = selected == null
        ? const <String>[]
        : adminRoleOptions(role, selected);
    // List-dependent narrowing of the chosen role.
    final effectiveRole = selected == null
        ? 'admin'
        : options.contains(selectedRole)
        ? selectedRole
        : options.firstOrNull ?? 'admin';
    final owners = members.where((m) => m.role == 'owner').length;
    RaftAdminPrincipal present(AdminPrincipal p) => RaftAdminPrincipal(
      key: p.key,
      label: p.label,
      agent: p.agent,
      subtitle: p.subtitle,
      optionLabel: p.optionLabel,
      avatarUrl: p.avatarUrl,
      // Web filters on `label identity`: a human's `email name`, an agent's
      // `@name`.
      searchText: p.agent
          ? '@${p.name}'
          : [p.email, p.name].where((v) => v != null && v.isNotEmpty).join(' '),
    );
    // An owner about to make someone else owner: what becomes of the Computers
    // they attached here, from their own removal impact.
    final grantsOwner =
        role == 'owner' &&
        effectiveRole == 'owner' &&
        selected != null &&
        !selected.agent;
    impact.sync(
      w.server?.id,
      grantsOwner ? w.client.user?.id : null,
    );
    return RaftAdminSection(
      regionKey: adminRegion('admins'),
      label: 'Owners & admins',
      glyph: RaftGlyph.shield,
      count: admins.length,
      child: RaftAdminsCard(
        candidates: [for (final c in candidates) present(c)],
        selectedKey: selected?.key,
        onSelect: (key) => setState(() => selectedKey = key),
        role: effectiveRole,
        roleOptions: options.toSet(),
        onRole: (value) => setState(() => selectedRole = value),
        saving: savingKey != null,
        promoting: selected != null && savingKey == selected.key,
        error: error,
        note: ownComputersTransferNote(context, impact),
        onPromote: () {
          if (selected != null) {
            change(selected, effectiveRole, 'Failed to update role');
          }
        },
        rows: [
          for (final admin in admins)
            canRemoveAdmin(role, admin, owners)
                ? RaftAdminRow(
                    principal: present(admin),
                    removeLabel: admin.role == 'owner'
                        ? 'Remove owner'
                        : 'Remove admin',
                    saving: savingKey == admin.key,
                    onRemove: () =>
                        change(admin, 'member', 'Failed to remove role'),
                  )
                : RaftAdminRow(
                    principal: present(admin),
                    note: admin.role == 'owner' && owners <= 1
                        ? 'Last owner'
                        : 'Owner only',
                  ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Pending Invites

class _InvitesSection extends StatefulWidget {
  const _InvitesSection({required this.w});
  final WorkspaceController w;
  @override
  State<_InvitesSection> createState() => _InvitesState();
}

class _InvitesState extends State<_InvitesSection>
    with AdminSectionLoad<_InvitesSection> {
  @override
  WorkspaceController get w => widget.w;
  @override
  String get snapshotKey => 'admin:invites';
  List<Map<String, dynamic>> invites = [];
  bool loading = true;

  @override
  Map<String, Object?> captureSnapshot() => {'invites': invites};

  @override
  void initState() {
    super.initState();
    final snapshot = readSnapshot();
    if (snapshot != null) {
      invites = snapshot['invites'] as List<Map<String, dynamic>>;
      loading = false;
    }
    reload();
  }

  /// Revalidates in place: the rows stay (and a restored empty list keeps its
  /// "No pending invites" line); only a cold first read shows the blank state.
  Future<void> reload() {
    return load(
      () => w.query('/servers/${w.server!.id}/invites'),
      (value) => invites = managementRows(value),
      // Web ignores a failed read and keeps the current rows.
      done: () => loading = false,
    );
  }

  Future<void> revoke(Map<String, dynamic> invite) => adminConfirm(
    context,
    title: 'Revoke invite',
    message: raftFormat(
      context,
      'Are you sure you want to revoke the invite to {email}? They will no longer be able to join using this invite link.',
      {'email': invite['invitedEmail']},
    ),
    confirmLabel: 'Revoke invite',
    cancelLabel: 'Cancel',
    loadingLabel: 'Revoking…',
    onConfirm: () async {
      try {
        await w.command(
          'DELETE',
          '/servers/${w.server!.id}/invites/${invite['id']}',
        );
        await reload();
      } catch (_) {
        // Web ignores revoke failures.
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final f = agentTimeFormatter(context, w);
    return RaftAdminSection(
      regionKey: adminRegion('invites'),
      label: 'Pending invites',
      glyph: RaftGlyph.mail,
      count: invites.isEmpty ? null : invites.length,
      child: RaftAdminInvitesCard(
        loading: loading,
        invites: [
          for (final invite in invites)
            RaftAdminInvite(
              id: '${invite['id']}',
              email: '${invite['invitedEmail'] ?? invite['email'] ?? ''}',
              date: f.shortDate(invite['createdAt']),
              onRevoke: () => revoke(invite),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Invite Links

class _JoinLinksSection extends StatefulWidget {
  const _JoinLinksSection({required this.w, required this.origin});
  final WorkspaceController w;
  final String origin;
  @override
  State<_JoinLinksSection> createState() => _JoinLinksState();
}

class _JoinLinksState extends State<_JoinLinksSection>
    with AdminSectionLoad<_JoinLinksSection> {
  @override
  WorkspaceController get w => widget.w;
  @override
  String get snapshotKey => 'admin:join-links';
  List<Map<String, dynamic>> links = [];
  bool loading = true, creating = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- createError clears when the next create starts; copiedId expires after 1.5 s; the section is remounted on server/account change.
  String? createError, copiedId;
  DateTime? expiresAt;
  final maxUses = TextEditingController();
  Timer? copiedTimer;

  @override
  Map<String, Object?> captureSnapshot() => {'links': links};

  @override
  void initState() {
    super.initState();
    final snapshot = readSnapshot();
    if (snapshot != null) {
      links = snapshot['links'] as List<Map<String, dynamic>>;
      loading = false;
    }
    load(
      () => w.query('/servers/${w.server!.id}/join-links'),
      (value) => links = managementRows(value),
      done: () => loading = false,
    );
  }

  @override
  void dispose() {
    copiedTimer?.cancel();
    maxUses.dispose();
    super.dispose();
  }

  String url(Object? token) => '${widget.origin}/join/$token';

  Future<void> create() async {
    final identity = pageIdentity(w);
    setState(() {
      creating = true;
      createError = null;
    });
    try {
      final data = await w.command(
        'POST',
        '/servers/${w.server!.id}/join-links',
        data: {
          'maxUses': maxUses.text.isEmpty ? null : int.parse(maxUses.text),
          'expiresAt': expiresAt?.toUtc().toIso8601String(),
        },
      );
      final link = managementMap(managementMap(data)['link']);
      if (!mounted || identity != pageIdentity(w) || link.isEmpty) return;
      setState(() => links = [link, ...links]);
      saveSnapshot();
    } catch (e) {
      if (mounted) {
        setState(
          () => createError = adminApiError(e, 'Failed to create join link'),
        );
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> copy(Map<String, dynamic> link) async {
    await Clipboard.setData(ClipboardData(text: url(link['token'])));
    if (!mounted) return;
    final id = '${link['id']}';
    setState(() => copiedId = id);
    copiedTimer?.cancel();
    copiedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && copiedId == id) setState(() => copiedId = null);
    });
  }

  Future<void> revoke(Map<String, dynamic> link) => adminConfirm(
    context,
    title: 'Revoke invite link',
    message: 'Revoke this invite link? Anyone who still has the URL will stop being able to join with it.',
    confirmLabel: 'Revoke link',
    cancelLabel: 'Cancel',
    loadingLabel: 'Revoking…',
    onConfirm: () async {
      try {
        await w.command(
          'DELETE',
          '/servers/${w.server!.id}/join-links/${link['id']}',
        );
        if (!mounted) return;
        setState(
          () => links = [
            for (final l in links)
              if (l['id'] != link['id']) l,
          ],
        );
        saveSnapshot();
      } catch (_) {
        // Web ignores revoke failures.
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final f = agentTimeFormatter(context, w);
    String meta(Map<String, dynamic> link) {
      final used = link['useCount'] ?? 0, max = link['maxUses'];
      final uses = max != null
          ? raftFormat(context, '{used}/{max} uses', {'used': used, 'max': max})
          : raftFormat(context, '{used} uses', {'used': used});
      final expiry = link['expiresAt'] != null
          ? raftFormat(context, 'expires {when}', {
              'when': f.shortDateTime(link['expiresAt']),
            })
          : raftText(context, 'no expiry');
      return '$uses · $expiry';
    }

    return RaftAdminSection(
      regionKey: adminRegion('join-links'),
      label: 'Invite links',
      glyph: RaftGlyph.link2,
      count: links.isEmpty ? null : links.length,
      child: RaftAdminJoinLinksCard(
        maxUses: maxUses,
        expiresAt: expiresAt,
        onExpiresAt: (value) => setState(() => expiresAt = value),
        onCreate: create,
        creating: creating,
        loading: loading,
        createError: createError,
        links: [
          for (final link in links)
            RaftAdminJoinLink(
              id: '${link['id']}',
              url: url(link['token']),
              meta: meta(link),
              copied: copiedId == '${link['id']}',
              onCopy: () => copy(link),
              onRevoke: () => revoke(link),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Agreement

class _AgreementSection extends StatefulWidget {
  const _AgreementSection({required this.w});
  final WorkspaceController w;
  @override
  State<_AgreementSection> createState() => _AgreementState();
}

class _AgreementState extends State<_AgreementSection>
    with AdminSectionLoad<_AgreementSection>, _SavedFlash {
  @override
  WorkspaceController get w => widget.w;
  @override
  String get snapshotKey => 'admin:agreement';
  static const maxLength = 5000;
  final title = TextEditingController(), body = TextEditingController();
  bool enabled = false, savedEnabled = false, loading = true, saving = false;
  String savedTitle = '', savedBody = '';
  // ignore: raft_lints/avoid_imperative_notice_state -- Each section's error clears when its next save/action starts, on a successful load, and when the real server state it describes changes (_resync); sections are remounted on server/account change.
  String? error;

  @override
  Map<String, Object?> captureSnapshot() => {
    'enabled': savedEnabled,
    'title': savedTitle,
    'body': savedBody,
  };

  void adopt(bool nextEnabled, String nextTitle, String nextBody) {
    enabled = savedEnabled = nextEnabled;
    title.text = savedTitle = nextTitle;
    body.text = savedBody = nextBody;
  }

  @override
  void initState() {
    super.initState();
    title.addListener(_edited);
    body.addListener(_edited);
    final snapshot = readSnapshot();
    if (snapshot != null) {
      adopt(
        snapshot['enabled'] as bool,
        snapshot['title'] as String,
        snapshot['body'] as String,
      );
      loading = false;
    }
    load(
      () => w.query('/servers/${w.server!.id}/agreement'),
      (value) {
        final data = managementMap(value);
        final agreement = managementMap(data['agreement']);
        adopt(
          data['enabled'] == true,
          '${agreement['title'] ?? ''}',
          '${agreement['bodyMarkdown'] ?? ''}',
        );
        clearSaved();
      },
      failed: (e) => error = adminApiError(e, 'Failed to load pre-join agreement'),
      done: () => loading = false,
    );
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  String _seenTitle = '', _seenBody = '';

  /// Typing clears `saved`; selection/composing changes (focus moves) do not.
  void _edited() {
    if (!mounted) return;
    if (title.text == _seenTitle && body.text == _seenBody) return;
    _seenTitle = title.text;
    _seenBody = body.text;
    setState(clearSaved);
  }

  bool get dirty =>
      enabled != savedEnabled ||
      title.text != savedTitle ||
      body.text != savedBody;

  Future<void> save() async {
    if (body.text.length > maxLength) return;
    final identity = pageIdentity(w);
    setState(() {
      saving = true;
      clearSaved();
      error = null;
    });
    try {
      final data = managementMap(
        await w.command(
          'PUT',
          '/servers/${w.server!.id}/agreement',
          data: {
            'enabled': enabled,
            'title': title.text,
            'bodyMarkdown': body.text,
          },
        ),
      );
      if (!mounted || identity != pageIdentity(w)) return;
      final agreement = managementMap(data['agreement']);
      adopt(
        data['enabled'] == true,
        '${agreement['title'] ?? title.text}',
        '${agreement['bodyMarkdown'] ?? body.text}',
      );
      saveSnapshot();
      flashSaved(const Duration(milliseconds: 1500));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = adminApiError(e, 'Failed to save pre-join agreement'),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = saving || loading;
    return RaftAdminSection(
      regionKey: adminRegion('pre-join-agreement'),
      label: 'Pre-join agreement',
      glyph: RaftGlyph.fileText,
      child: RaftAdminAgreementCard(
        enabled: enabled,
        onEnabled: (value) => setState(() {
          enabled = value;
          clearSaved();
        }),
        title: title,
        body: body,
        busy: busy,
        error: error,
        maxLength: maxLength,
        save: _saveState(saving, saved),
        onSave: dirty && body.text.length <= maxLength && !busy ? save : null,
      ),
    );
  }
}

// ------------------------------------------------------------ Product analytics

class _ProductAnalyticsSection extends StatefulWidget {
  const _ProductAnalyticsSection({required this.w});
  final WorkspaceController w;
  @override
  State<_ProductAnalyticsSection> createState() => _ProductAnalyticsState();
}

class _ProductAnalyticsState extends State<_ProductAnalyticsSection>
    with AdminSectionLoad<_ProductAnalyticsSection> {
  @override
  WorkspaceController get w => widget.w;
  @override
  String get snapshotKey => 'admin:product-analytics';
  Map<String, dynamic>? settings;
  bool saving = false, failed = false;

  @override
  Map<String, Object?> captureSnapshot() => {'settings': settings};

  @override
  void initState() {
    super.initState();
    settings = readSnapshot()?['settings'] as Map<String, dynamic>?;
    load(
      () => w.query('/servers/${w.server!.id}/product-analytics-settings'),
      (value) => settings = managementMap(value),
      failed: (_) => failed = true,
    );
  }

  Future<void> change(bool checked) async {
    final identity = pageIdentity(w);
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      final data = await w.command(
        'PATCH',
        '/servers/${w.server!.id}/product-analytics-settings',
        data: {'productAnalyticsEnabled': checked},
      );
      if (!mounted || identity != pageIdentity(w)) return;
      setState(() => settings = managementMap(data));
      saveSnapshot();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return RaftAdminSection(
      regionKey: adminRegion('product-analytics'),
      label: 'Product analytics',
      glyph: RaftGlyph.barChart3,
      child: RaftAdminSwitchCard(
        switchKey: const ValueKey('admin-product-analytics'),
        title: 'Product analytics for this workspace',
        description: 'When off, no usage data is recorded for anyone in this workspace, whatever their own setting.',
        checked: s == null ? true : s['productAnalyticsEnabled'] == true,
        onChanged: saving || s == null || s['canManageProductAnalytics'] != true
            ? null
            : change,
        error: failed ? "Couldn't save this setting. Try again." : null,
      ),
    );
  }
}

