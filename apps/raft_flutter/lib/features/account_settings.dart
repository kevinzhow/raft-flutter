import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'account_onboarding.dart';
import 'account_connections_view.dart';
import 'management_support.dart';

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
      '${controller.client.generation}|${controller.client.user?.id}';
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
  }

  void checkAccount(String sourceScope) {
    if (!mounted || sourceScope != authority) {
      throw const RaftApiException(
        'The active account changed. Reopen this form.',
      );
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
      if (mounted) setState(() => mediaBusy = false);
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

  Future<void> password(BuildContext context) async {
    final sourceScope = authority;
    await scopedDialog<void>(
      (_) => RaftFormDialog(
        title: raftText(context, 'Change password'),
        fields: [
          const RaftFormField(
            'currentPassword',
            'Current password',
            obscure: true,
            trim: false,
            required: true,
          ),
          RaftFormField(
            'newPassword',
            'New password',
            obscure: true,
            trim: false,
            required: true,
            validator: (v) =>
                v.length < 8 ? 'Use at least 8 characters.' : null,
          ),
          const RaftFormField(
            'confirmation',
            'Confirm new password',
            obscure: true,
            trim: false,
            required: true,
          ),
        ],
        onSubmit: (values) async {
          checkAccount(sourceScope);
          if (values['newPassword'] != values['confirmation']) {
            throw const RaftApiException('The new passwords must match.');
          }
          await controller.client.patch(
            '/auth/me',
            data: {
              'currentPassword': values['currentPassword'],
              'newPassword': values['newPassword'],
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.client.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raftText(context, 'Account'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        RaftAvatar(
          name: user?.name ?? '',
          size: 64,
          imageUrl: user?.string('avatarUrl').isEmpty != false
              ? null
              : user!.string('avatarUrl'),
        ),
        const SizedBox(height: 12),
        Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
        Text('@${user?.string('name') ?? ''}'),
        SelectableText(user?.string('email') ?? ''),
        if (user?.string('description').isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SelectableText(user!.string('description')),
          ),
        const SizedBox(height: 12),
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
              label: raftText(context, 'Change password'),
              secondary: true,
              onPressed: () => password(context),
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
    );
  }
}
