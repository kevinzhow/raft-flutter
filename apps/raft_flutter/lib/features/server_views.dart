import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../platform/content_links.dart';
import 'account_onboarding.dart' show AccountMediaActions, PickedAvatar;
import 'archived_channels_section.dart';
import 'member_profile_rules.dart';
import 'invite_accept_view.dart';
import 'public_avatar_url.dart';
import 'public_visibility_view.dart';
import 'delete_server_confirm.dart';

class WorkspaceActions {
  static Future<void> create(
    BuildContext context,
    WorkspaceController w,
  ) async {
    await showRaftForm<void>(
      context,
      builder: (_) => RaftFormDialog(
        title: 'Create workspace',
        submitLabel: 'Create',
        fields: [
          const RaftFormField('name', 'Workspace name', required: true),
          RaftFormField(
            'slug',
            'Workspace address',
            required: true,
            help: 'Lowercase letters, numbers and hyphens.',
            validator: (v) => RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v)
                ? null
                : 'Use lowercase letters, numbers and hyphens.',
          ),
        ],
        onSubmit: (values) async {
          final created = await w.client.post('/servers', data: values);
          await w.recoverMembership();
          final next = w.servers
              .where((s) => s.id == created['id'])
              .firstOrNull;
          if (next != null) await w.selectServer(next);
        },
      ),
    );
  }

  /// Join workspace: paste an invite link or code; the invite page (the Web
  /// InviteAcceptPage) then shows the invitation and joins.
  static Future<void> join(BuildContext context, WorkspaceController w) async {
    await showRaftForm<void>(
      context,
      builder: (dialogContext) => RaftFormDialog(
        title: 'Join workspace',
        submitLabel: 'Review invitation',
        fields: [
          RaftFormField(
            'token',
            'Invitation link or code',
            required: true,
            obscure: true,
          ),
        ],
        onSubmit: (values) async {
          // ignore: raft_lints/avoid_render_index_assertion -- Submit values of the form dialog: every field id is present in the submitted map.
          final link = InviteLink.fromInput(values['token']!);
          if (link == null) {
            throw const RaftApiException(
              'Enter a valid invitation link or code.',
            );
          }
          InviteRequests.instance.open(link);
        },
      ),
    );
  }

  static Future<void> leave(
    BuildContext context,
    WorkspaceController w, {
    bool delete = false,
  }) async {
    final server = w.server;
    if (server == null) return;
    await showRaftForm<void>(
      context,
      builder: (_) => RaftFormDialog(
        title: delete ? 'Delete workspace?' : 'Leave workspace?',
        description: delete
            ? raftFormat(
                context,
                'Delete {workspace}, its channels and messages. This cannot be undone.',
                {'workspace': server.name},
              )
            : raftFormat(
                context,
                'Leave {workspace}. A new invitation is required to return.',
                {'workspace': server.name},
              ),
        fields: [
          RaftFormField(
            'confirm',
            'Type workspace name',
            required: true,
            validator: (v) => v == server.name
                ? null
                : raftFormat(context, 'The name must match {name}.', {
                    'name': server.name,
                  }),
          ),
        ],
        submitLabel: delete ? 'Delete' : 'Leave',
        destructive: delete,
        onSubmit: (_) async {
          await w.client.exitServer(server.id, delete: delete);
          w.sessionScope.revokeServer(server.id);
          await w.recoverMembership();
        },
      ),
    );
  }
}

/// SettingsPanel.tsx ServerTabContent for the fixture capabilities:
/// ProfileSection + PublicVisibilitySection + ArchivedChannelsSection +
/// DangerZoneSection (the middle two render nothing without public
/// visibility / archived channels). Invitations live under Administration and the
/// workspace push mode under Notifications.
class ServerSettingsView extends StatefulWidget {
  const ServerSettingsView({
    super.key,
    required this.controller,
    this.pickAvatar,
  });
  final WorkspaceController controller;

  /// Image chooser for the server avatar (tests); defaults to the account
  /// avatar picker (system photo picker on Android/iOS, file picker on desktop).
  final Future<PickedAvatar?> Function(RaftClient client)? pickAvatar;
  @override
  State<ServerSettingsView> createState() => _ServerSettingsViewState();
}

class _ServerSettingsViewState extends State<ServerSettingsView> {
  WorkspaceController get w => widget.controller;
  final name = TextEditingController();
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears when the next save starts; the page is remounted on server/account change (WorkspaceSettings key). avatarError is scoped to _avatarServerId and clears on retry, on a successful upload, on switching server and when the user loses edit permission (server_avatar_test).
  String? savedName, error, avatarError, _avatarServerId;
  bool saving = false, saved = false, avatarSaving = false;
  Timer? savedReset;

  @override
  void initState() {
    super.initState();
    name.text = savedName = w.server?.name ?? '';
  }

  @override
  void didUpdateWidget(covariant ServerSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = w.server?.name ?? '';
    if (current != savedName) name.text = savedName = current;
    if (_avatarServerId != w.server?.id) avatarError = null;
  }

  /// Web ProfileSection `handleUploadAvatar`. The error is local to this page:
  /// it clears on the next attempt, on success and when the server changes.
  Future<void> uploadAvatar() async {
    final id = w.server?.id;
    if (id == null || avatarSaving) return;
    _avatarServerId = id;
    setState(() {
      avatarError = null;
      avatarSaving = true;
    });
    bool current() => mounted && w.server?.id == id;
    try {
      final picked =
          await (widget.pickAvatar ?? AccountMediaActions.pickAvatar)(w.client);
      if (picked == null || !current()) return;
      final data = await w.command(
        'POST',
        '/servers/$id/avatar',
        data: picked.form,
      );
      final url = data is Map ? data['avatarUrl'] : null;
      w.applyServerAvatar(id, url is String ? url : null);
    } catch (e) {
      if (current()) {
        setState(
          () => avatarError = userErrorText(
            e,
            fallback: 'Failed to upload server avatar',
            where: 'server avatar',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => avatarSaving = false);
    }
  }

  @override
  void dispose() {
    savedReset?.cancel();
    name.dispose();
    super.dispose();
  }

  bool get dirty =>
      name.text.trim().isNotEmpty && name.text.trim() != w.server?.name;

  Future<void> save() async {
    final id = w.server?.id;
    if (id == null || !dirty || saving) return;
    setState(() {
      error = null;
      saved = false;
      saving = true;
    });
    try {
      await w.command(
        'PATCH',
        '/servers/$id',
        data: {'name': name.text.trim()},
      );
      await w.recoverMembership();
      if (!mounted) return;
      savedName = name.text.trim();
      setState(() => saved = true);
      savedReset?.cancel();
      savedReset = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => saved = false);
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = userErrorText(
            e,
            fallback: 'Failed to update server',
            where: 'server profile',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> confirmDelete() => confirmDeleteServer(context, w);

  Future<void> confirmLeave() async {
    final server = w.server;
    if (server == null) return;
    final ok = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: 'Leave Server',
        message: raftFormat(
          context,
          "You'll lose access to {serverName} and all of its channels. You can be re-invited later.",
          {'serverName': server.name},
        ),
        confirmLabel: 'Leave Server',
        surfaceKey: const ValueKey('server-danger-dialog'),
        // confirmColor="bg-brutal-orange" -> warning tone.
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: const Key('server-leave-confirm-button'),
      ),
    );
    if (ok == true) await exitServer(delete: false);
  }

  Future<void> exitServer({required bool delete}) async {
    final server = w.server;
    if (server == null) return;
    await w.client.exitServer(server.id, delete: delete);
    w.sessionScope.revokeServer(server.id);
    await w.recoverMembership();
  }

  @override
  Widget build(BuildContext context) {
    final server = w.server;
    if (server == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final canEdit = w.can('editServerSettings');
    final role = server.string('role');
    final canLeave = role == 'admin' || role == 'member' || role == 'guest';
    final slug = server.string('slug');
    final initial = (server.name.trim().isEmpty ? 'S' : server.name.trim())
        .substring(0, 1)
        .toUpperCase();
    return ListView(
      primary: false,
      padding: raftScrollPadding(context, RaftSettingsPanelFrame.contentInset),
      children: [
        const RaftSettingsSectionHeader(
          label: 'Profile',
          glyph: RaftGlyph.building2,
        ),
        RaftSettingsProfileCard(
          avatar: RaftServerProfileTile(
            key: const Key('server-profile-avatar'),
            initial: initial,
            imageUrl: raftPublicAvatarUrl(
              w.client.origin,
              server.json['avatarUrl'] as String?,
            ),
            onUpload: canEdit ? uploadAvatar : null,
            busy: avatarSaving,
            uploadLabel: 'Upload image',
            busyLabel: 'Uploading avatar',
          ),
          title: server.name,
          subtitle: '/$slug',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (avatarError != null && canEdit) ...[
                // `<p className="text-xs font-bold text-brutal-red" role="alert">`
                Semantics(
                  liveRegion: true,
                  child: Text(
                    raftText(context, avatarError!),
                    key: const Key('server-profile-avatar-error'),
                    style: RaftSettingsText(t).alert,
                  ),
                ),
                const SizedBox(height: RaftSpace.x3),
              ],
              RaftSettingsField(
                label: 'Name',
                child: canEdit
                    ? RaftRecipeInput(
                        fieldKey: const Key('server-profile-name-input'),
                        controller: name,
                        onChanged: (_) => setState(() => saved = false),
                        onSubmitted: (_) => save(),
                      )
                    : RaftSettingsReadonlyValue(
                        key: const Key('server-profile-name-readonly'),
                        value: server.name,
                      ),
              ),
              const SizedBox(height: RaftSpace.x3),
              RaftSettingsField(
                label: 'Slug',
                // SlugInput readOnly: `border-line-strong bg-layer-inset
                // shadow-none theme-brutal:border-black/30
                // theme-brutal:bg-gray-50`, input `text-sm
                // text-foreground-muted theme-brutal:text-black/60`.
                child: RaftSettingsPrefixedInput(
                  prefix: '/',
                  value: slug,
                  readOnly: true,
                  flat: true,
                  rootColor: RaftSettingsText(t).readonlyGroupFill,
                  rootBorderColor: RaftSettingsText(t).readonlyGroupBorder,
                  textColor: RaftSettingsText(t).muted,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: RaftSpace.x3),
                // `<Banner intent="warning" density="sm" className="font-bold">`
                RaftErrorBanner(error!, small: true, bold: true),
              ],
              if (canEdit) ...[
                const SizedBox(height: RaftSpace.x3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RaftSettingsRecipeButton(
                    key: const Key('server-profile-save-button'),
                    label: saving
                        ? 'Saving...'
                        : saved
                        ? 'Saved'
                        : 'Save Profile',
                    glyph: saved && !saving ? RaftGlyph.check : null,
                    glyphSize: 14,
                    variant: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: dirty && !saving ? save : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RaftSpace.x6),
        // PublicVisibilitySection (owner, public_server_v0); its own
        // `mb-6` follows it.
        PublicVisibilitySection(
          controller: w,
          webOrigin: ContentLinks.originFor(w.client.origin).origin,
        ),
        // ArchivedChannelsSection (may archive channels, any archived).
        ArchivedChannelsSection(controller: w),
        const RaftSettingsSectionHeader(
          label: 'Danger Zone',
          glyph: RaftGlyph.triangleAlert,
        ),
        if (canLeave) ...[
          RaftSettingsActionCard(
            title: 'Leave Server',
            description: "You will lose access to this server's channels and DMs. You can rejoin if invited again.",
            action: RaftSettingsRecipeButton(
              key: const Key('server-danger-leave-button'),
              label: 'Leave Server',
              variant: RaftButtonRecipeVariant.warning,
              onPressed: confirmLeave,
            ),
          ),
          const SizedBox(height: RaftSpace.x3),
        ],
        if (role == 'owner')
          RaftSettingsActionCard(
            key: const Key('server-danger-delete-card'),
            stacked: true,
            title: 'Delete Server',
            description: 'Permanently remove this server and all its data. This cannot be undone.',
            action: RaftSettingsRecipeButton(
              key: const Key('server-danger-delete-button'),
              label: 'Delete Server',
              glyph: RaftGlyph.trash2,
              glyphSize: 14,
              variant: RaftButtonRecipeVariant.danger,
              expand: true,
              onPressed: confirmDelete,
            ),
          ),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }
}

/// Workspace push mode and invitations (Administration).
class MembersView extends StatefulWidget {
  const MembersView({
    super.key,
    required this.controller,
    this.mobileRoot = false,
    this.onOpenProfile,
  });
  final WorkspaceController controller;
  final bool mobileRoot;
  final ValueChanged<String>? onOpenProfile;
  @override
  State<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<MembersView> {
  WorkspaceController get w => widget.controller;
  // The workspace directory already holds this list (same endpoint); the page
  // opens with it and the read below revalidates in place.
  late List<Map<String, dynamic>> members = [
    if (w.server != null && w.client.user != null)
      ...w.services.entityDirectory.rows(WorkspaceEntityKind.members),
  ];
  late bool loading =
      members.isEmpty &&
      !w.services.entityDirectory.state(WorkspaceEntityKind.members).loaded;
  // ignore: raft_lints/avoid_imperative_notice_state -- Members load/profile error clears on the next successful load or Retry; the page is disposed on navigation.
  String? error;
  StreamSubscription<RaftEvent>? events;
  @override
  void initState() {
    super.initState();
    load();
    events = w.client.events.listen((event) {
      if (event.name.startsWith('server:member')) load();
    });
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final generation = w.client.generation;
    try {
      final result = await w.query('/servers/${w.server!.id}/members');
      if (mounted && generation == w.client.generation) {
        setState(() {
          members = [for (final p in result) Map<String, dynamic>.from(p)];
          // A retry that succeeds ends the load error it was offered for.
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = userErrorText(e, where: 'members'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> profile(Map<String, dynamic> member) async {
    if (widget.onOpenProfile != null) {
      final id = member['userId'] ?? member['id'];
      if (id is String && w.can('viewMembers')) widget.onOpenProfile!(id);
      return;
    }
    try {
      final userId = '${member['userId'] ?? member['id']}';
      // The dialog opens at once from the directory's row (else the list row);
      // the profile read fills the detail fields in place.
      final profile = ValueNotifier<Map<String, dynamic>>({
        ...member,
        ...?w.services.entityDirectory.member(userId),
      });
      final owner = w;
      unawaited(
        w
            .query('/servers/${w.server!.id}/members/$userId/profile')
            .then<void>(
              (value) {
                if (value is Map && identical(owner, w)) {
                  profile.value = {
                    ...profile.value,
                    ...Map<String, dynamic>.from(value),
                  };
                }
              },
              onError: (Object e) {
                if (mounted) {
                  setState(() => error = userErrorText(e, where: 'member'));
                }
              },
            ),
      );
      await showDialog(
        context: context,
        builder: (context) => ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: profile,
          builder: (context, value, _) => AlertDialog(
            title: Text(humanDisplayName(value)),
            content: SelectableText(
              '${value['description'] ?? ''}\n\n${value['email'] ?? ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(raftText(context, 'Close')),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = userErrorText(e, where: 'member'));
    }
  }

  Future<void> change(Map<String, dynamic> member, String role) async {
    final id = member['userId'] ?? member['id'],
        server = w.server!.id,
        name = humanDisplayName(member);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RaftFormDialog(
        title: role == 'remove'
            ? raftFormat(context, 'Remove {name}?', {'name': name})
            : raftText(context, 'Change role?'),
        description: role == 'remove'
            ? raftFormat(
                context,
                'Remove this member from {workspace}. They will lose workspace access.',
                {'workspace': w.server!.name},
              )
            : raftFormat(context, 'Make {name} a {role} in {workspace}.', {
                'name': name,
                'role': raftText(
                  context,
                  '${role[0].toUpperCase()}${role.substring(1)}',
                ),
                'workspace': w.server!.name,
              }),
        fields: [],
        submitLabel: role == 'remove' ? 'Remove' : 'Confirm',
        destructive: role == 'remove',
        onSubmit: (_) async {
          await w.command(
            role == 'remove' ? 'DELETE' : 'PATCH',
            '/servers/$server/members/$id',
            data: role == 'remove' ? null : {'role': role},
          );
        },
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.mobileRoot)
        RaftMobileRootHeader(
          title: 'Members',
          actions: [
            RaftIconButton(
              tooltip: 'Refresh members',
              onPressed: load,
              glyph: RaftGlyph.refreshCw,
            ),
          ],
        ),
      Expanded(
        child: loading
            ? Center(child: CircularProgressIndicator())
            : ListView(
                padding: raftScrollPadding(context, const EdgeInsets.all(24)),
                children: [
                  if (!widget.mobileRoot)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            raftText(context, 'Members'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        RaftTooltip(
                          message: raftText(context, 'Refresh members'),
                          child: IconButton(
                            onPressed: load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ),
                  if (error != null)
                    RaftLoadError(error!, onRetry: load, expand: false),
                  for (final member in members)
                    ListTile(
                      leading: RaftAvatar(name: humanDisplayName(member)),
                      title: Text(humanDisplayName(member)),
                      subtitle: Text(
                        '${member['role']} · ${member['email'] ?? ''}',
                      ),
                      onTap: () => profile(member),
                      trailing:
                          w.can('changeMemberRoles') || w.can('removeMembers')
                          ? RaftTooltip(
                              message: raftText(context, 'Member actions'),
                              child: PopupMenuButton<String>(
                                onSelected: (role) => change(member, role),
                                itemBuilder: (_) => [
                                  if (w.can('changeMemberRoles')) ...[
                                    for (final role
                                        in w.server!.string('role') == 'owner'
                                            ? [
                                                'owner',
                                                'admin',
                                                'member',
                                                'guest',
                                              ]
                                            : ['member', 'guest'])
                                      PopupMenuItem(
                                        value: role,
                                        child: Text(
                                          raftFormat(context, 'Make {role}', {
                                            'role': raftText(
                                              context,
                                              '${role[0].toUpperCase()}${role.substring(1)}',
                                            ),
                                          }),
                                        ),
                                      ),
                                  ],
                                  if (w.can('removeMembers') &&
                                      member['userId'] != w.client.user!.id)
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text(
                                        raftText(context, 'Remove member'),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : null,
                    ),
                ],
              ),
      ),
    ],
  );
}
