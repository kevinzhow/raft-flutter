import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/personal_presentation.dart';
import 'account_onboarding.dart';
import 'account_connections_view.dart';
import 'management_support.dart';
import 'public_avatar_url.dart';
import 'page_component_recipes.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends ManagementState<AccountSettings> {
  WorkspaceController get controller => widget.controller;
  @override
  WorkspaceController get w => controller;
  @override
  String get authority =>
      '${identityHashCode(controller.client)}|${controller.client.origin}|${controller.client.generation}|${controller.client.user?.id}';
  @override
  void initState() {
    super.initState();
    startManagement();
  }

  @override
  Future<void> loadData(int request, int generation) async {}
  @override
  void clearData() {
    mediaError = null;
    profileError = null;
    profileAccount = null;
    mediaBusy = false;
    profileBusy = false;
  }

  void checkAccount(String sourceScope) {
    if (!mounted || sourceScope != authority) {
      throw const RaftApiException(
        'The active account changed. Reopen this form.',
      );
    }
  }

  final profileName = TextEditingController();
  String? profileAccount, savedProfileName;
  bool profileBusy = false, profileSaved = false;
  String? profileError;
  @override
  void dispose() {
    profileName.dispose();
    super.dispose();
  }

  void hydrateProfile() {
    final user = controller.client.user;
    final key = authority;
    final display = user == null
        ? ''
        : user.string('displayName', user.string('name'));
    // Empty display names use the canonical handle, as SettingsProfileCard does.
    final visibleName = display.isEmpty
        ? (user?.string('name') ?? '')
        : display;
    if (key != profileAccount) {
      profileAccount = key;
      savedProfileName = visibleName;
      profileName.text = visibleName;
      profileBusy = false;
      profileSaved = false;
      profileError = null;
    } else if (savedProfileName != visibleName) {
      final unchangedDraft = profileName.text.trim() == savedProfileName;
      savedProfileName = visibleName;
      if (unchangedDraft) profileName.text = visibleName;
      profileSaved = false;
    }
  }

  Future<void> saveProfile() async {
    final scope = authority, name = profileName.text.trim();
    if (profileBusy || name.isEmpty || name == savedProfileName) return;
    setState(() {
      profileBusy = true;
      profileError = null;
    });
    try {
      checkAccount(scope);
      await controller.client.patch('/auth/me', data: {'displayName': name});
      checkAccount(scope);
      await controller.client.reloadUser();
      checkAccount(scope);
      setState(() {
        savedProfileName = name;
        profileSaved = profileName.text.trim() == name;
      });
    } catch (e) {
      if (mounted && scope == authority) setState(() => profileError = '$e');
    } finally {
      if (mounted && scope == authority) setState(() => profileBusy = false);
    }
  }

  bool mediaBusy = false;
  String? mediaError;

  Future<void> image({bool remove = false}) async {
    if (mediaBusy) return;
    final sourceScope = authority;
    if (remove) {
      final accepted = await scopedDialog<bool>(
        (context) => AlertDialog(
          title: Text(raftText(context, 'Remove profile image?')),
          content: Text(
            raftText(
              context,
              'Your profile image will be replaced by your initials.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(raftText(context, 'Cancel')),
            ),
            RaftButton(
              label: raftText(context, 'Remove'),
              destructive: true,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || sourceScope != authority) return;
    }
    setState(() {
      mediaBusy = true;
      mediaError = null;
    });
    try {
      if (remove) {
        await AccountMediaActions.removeAvatar(controller.client);
      } else {
        await AccountMediaActions.uploadAvatar(controller.client);
      }
    } catch (error) {
      if (mounted && sourceScope == authority) {
        setState(() => mediaError = '$error');
      }
    } finally {
      if (mounted && sourceScope == authority) {
        setState(() => mediaBusy = false);
      }
    }
  }

  Future<void> edit(BuildContext context) async {
    final sourceScope = authority;
    final user = controller.client.user!;
    await scopedDialog<void>(
      (_) => RaftFormDialog(
        title: raftText(context, 'Edit profile'),
        fields: [
          RaftFormField(
            'displayName',
            'Display name',
            initial: user.string('displayName', user.string('name')),
            required: true,
          ),
          RaftFormField(
            'description',
            'About you',
            initial: user.string('description'),
            multiline: true,
          ),
        ],
        onSubmit: (values) async {
          checkAccount(sourceScope);
          await controller.client.patch('/auth/me', data: values);
          checkAccount(sourceScope);
          await controller.client.reloadUser();
        },
      ),
    );
  }

  Future<void> preferences(BuildContext context) async {
    final local = PersonalPresentationScope.maybeOf(context);
    final localKey = local?.key;
    final sourceScope = authority;
    final user = controller.client.user!;
    await scopedDialog<void>(
      (_) => RaftFormDialog(
        title: raftText(context, 'Reading preferences'),
        fields: [
          RaftFormField(
            'preferredTimeFormat',
            'Time format',
            initial: user.string('preferredTimeFormat', 'auto'),
            choices: const {
              'auto': 'Device default',
              '12h': '12-hour',
              '24h': '24-hour',
            },
          ),
          RaftFormField(
            'preferredMessageBodyFontSize',
            'Message text size',
            initial: user.string('preferredMessageBodyFontSize', 'md'),
            choices: const {
              'sm': 'Small · 12 px',
              'md': 'Medium · 14 px',
              'lg': 'Large · 16 px',
            },
          ),
        ],
        onSubmit: (values) async {
          checkAccount(sourceScope);
          await controller.client.patch(
            '/auth/me',
            data: {
              ...values,
              'preferredTimeFormat': values['preferredTimeFormat'] == 'auto'
                  ? null
                  : values['preferredTimeFormat'],
            },
          );
          checkAccount(sourceScope);
          await controller.client.reloadUser();
          checkAccount(sourceScope);
          local?.update(localKey, font: values['preferredMessageBodyFontSize']);
        },
      ),
    );
  }

  Future<void> language(BuildContext context) async {
    final sourceScope = authority;
    final user = controller.client.user!;
    await scopedDialog<void>(
      (_) => RaftFormDialog(
        title: raftText(context, 'Display language'),
        fields: [
          RaftFormField(
            'displayLanguage',
            raftText(context, 'Display language'),
            initial: user.string('displayLanguage').isEmpty
                ? 'auto'
                : user.string('displayLanguage'),
            choices: {
              'auto': raftText(context, 'Device default'),
              'en': 'English',
              'zh-cn': '简体中文',
            },
          ),
        ],
        onSubmit: (values) async {
          checkAccount(sourceScope);
          await controller.client.patch(
            '/auth/me',
            data: {
              'displayLanguage': values['displayLanguage'] == 'auto'
                  ? null
                  : values['displayLanguage'],
            },
          );
          checkAccount(sourceScope);
          await controller.client.reloadUser();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    hydrateProfile();
    final user = controller.client.user,
        t = RaftTokens.of(context),
        recipe = RaftSettingsProfileRecipe(RaftTokens.of(context));
    Widget label(String value, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(raftText(context, value), style: recipe.label),
        const SizedBox(height: 6),
        field,
      ],
    );
    return RaftSettingsProfileCard(
      avatar: Tooltip(
        message: raftText(context, 'Change profile image'),
        child: InkWell(
          key: const Key('account-profile-avatar'),
          onTap: mediaBusy ? null : () => image(),
          child: RaftAvatar(
            name: user?.name ?? '',
            size: RaftSettingsProfileRecipe.avatarSize,
            imageUrl: raftPublicAvatarUrl(
              controller.client.origin,
              user?.string('avatarUrl'),
            ),
          ),
        ),
      ),
      title: user?.name ?? '',
      subtitle: '@${user?.string('name') ?? ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(
            'Display name',
            TextField(
              key: const Key('account-profile-display-name'),
              controller: profileName,
              style: RaftTypography.body(t, size: 14, line: 20),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (_) => setState(() => profileSaved = false),
              onSubmitted: (_) => saveProfile(),
            ),
          ),
          const SizedBox(height: RaftSettingsProfileRecipe.fieldGap),
          label(
            'Username',
            TextFormField(
              key: ValueKey(
                'account-username-${user?.id}-${user?.string('name')}',
              ),
              initialValue: user?.string('name') ?? '',
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                prefixText: '@',
                filled: true,
                fillColor: t.colors['fill-muted'],
                contentPadding: const EdgeInsets.all(8),
              ),
              style: RaftTypography.body(t, size: 14, line: 20, color: t.muted),
            ),
          ),
          const SizedBox(height: RaftSettingsProfileRecipe.fieldGap),
          label(
            'Email',
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  user?.string('email') ?? '',
                  style: recipe.subtitle,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        t.colors[user?.json['emailVerified'] == true
                            ? 'success-soft'
                            : 'warning-soft'],
                    borderRadius: BorderRadius.circular(t.brutal ? 0 : 12),
                  ),
                  child: Text(
                    raftText(
                      context,
                      user?.json['emailVerified'] == true
                          ? 'Verified'
                          : 'Unverified',
                    ),
                    style: RaftTypography.body(
                      t,
                      size: 10,
                      line: 14,
                      weight: FontWeight.w700,
                      color:
                          t.colors[user?.json['emailVerified'] == true
                              ? 'success-strong'
                              : 'warning-strong'],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (profileError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  profileError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          const SizedBox(height: RaftSettingsProfileRecipe.fieldGap),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              key: const Key('account-save-profile'),
              label: profileSaved ? 'Saved' : 'Save profile',
              secondary: true,
              visualHeight: 28,
              busy: profileBusy,
              onPressed:
                  profileBusy ||
                      profileName.text.trim().isEmpty ||
                      profileName.text.trim() == savedProfileName
                  ? null
                  : saveProfile,
            ),
          ),
          if (user?.string('description').isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                user!.string('description'),
                style: RaftTypography.body(t, size: 14, line: 20),
              ),
            ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: t.brutal ? 2 : 1, color: t.line),
          const SizedBox(height: 16),
          AccountConnectionsView(
            key: ValueKey('account-sign-in-$authority'),
            controller: controller,
            inline: true,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: t.line),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              RaftButton(
                key: const Key('account-profile-image'),
                label: raftText(context, 'Change profile image'),
                secondary: true,
                busy: mediaBusy,
                onPressed: () => image(),
              ),
              if (user?.string('avatarUrl').isNotEmpty == true)
                RaftButton(
                  label: raftText(context, 'Remove profile image'),
                  secondary: true,
                  onPressed: mediaBusy ? null : () => image(remove: true),
                ),
              RaftButton(
                key: const Key('account-display-language'),
                label: raftText(context, 'Display language'),
                secondary: true,
                onPressed: () => language(context),
              ),
              RaftButton(
                label: raftText(context, 'Edit profile'),
                secondary: true,
                onPressed: () => edit(context),
              ),
              RaftButton(
                label: raftText(context, 'Reading preferences'),
                secondary: true,
                onPressed: () => preferences(context),
              ),
              RaftButton(
                key: const Key('account-connections'),
                label: raftText(context, 'Connected sign-in accounts'),
                secondary: true,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(
                          raftText(context, 'Connected sign-in accounts'),
                        ),
                      ),
                      body: AccountConnectionsView(controller: controller),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (mediaError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  mediaError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
