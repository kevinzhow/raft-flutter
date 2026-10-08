import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show
        RaftBadgeRecipeAppearance,
        RaftBadgeRecipeVariant,
        RaftButtonRecipeSize,
        RaftButtonRecipeVariant;
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/personal_presentation.dart';
import 'account_onboarding.dart';
import 'account_connections_view.dart';
import 'management_support.dart';
import 'public_avatar_url.dart';
import 'page_component_recipes.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key, required this.controller, this.onLogout});
  final WorkspaceController controller;

  /// AccountSignOutSection; the host owns the session teardown.
  final Future<void> Function()? onLogout;
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
        t = RaftTokens.of(context);
    final muted = t.brutal ? Colors.black.withValues(alpha: .6) : t.muted;
    // `border-t-2 border-line-muted theme-brutal:border-black`
    final divider = Container(
      height: 2,
      color: t.brutal ? Colors.black : t.colors['line-muted'],
    );
    final card = RaftSettingsProfileCard(
      avatar: Tooltip(
        message: raftText(context, 'Change profile image'),
        child: InkWell(
          key: const Key('account-profile-image'),
          onTap: mediaBusy ? null : () => image(),
          child: Opacity(
            opacity: mediaBusy ? .7 : 1,
            child: RaftAvatar(
              key: const Key('account-profile-avatar'),
              name: user?.name ?? '',
              size: RaftSettingsProfileRecipe.avatarSize,
              imageUrl: raftPublicAvatarUrl(
                controller.client.origin,
                user?.string('avatarUrl'),
              ),
            ),
          ),
        ),
      ),
      title: user?.name ?? '',
      subtitle: '@${user?.string('name') ?? ''}',
      // SettingsProfileCard children: `space-y-3`.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mediaError != null) ...[
            // `text-xs font-bold text-brutal-red` alert above the form.
            Semantics(
              liveRegion: true,
              child: Text(
                mediaError!,
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: t.colors['color-brutal-red'] ?? t.colors['danger'],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          RaftSettingsField(
            label: 'Display Name',
            child: RaftRecipeInput(
              key: const Key('account-profile-display-name'),
              controller: profileName,
              // `theme-brutal:p-2`
              padding: t.brutal ? const EdgeInsets.all(8) : null,
              onChanged: (_) => setState(() => profileSaved = false),
              onSubmitted: (_) => saveProfile(),
            ),
          ),
          const SizedBox(height: 12),
          RaftSettingsField(
            label: 'Username',
            // PrefixedInput "@": `border-line-muted bg-fill-muted
            // shadow-none`, input `text-sm text-foreground-muted`.
            child: RaftPrefixedInput(
              key: ValueKey(
                'account-username-${user?.id}-${user?.string('name')}',
              ),
              prefix: '@',
              value: user?.string('name') ?? '',
              readOnly: true,
              flat: true,
              rootColor: t.colors['fill-muted'],
              rootBorderColor: t.colors['line-muted'],
              textColor: t.muted,
            ),
          ),
          const SizedBox(height: 12),
          RaftSettingsField(
            label: 'Email',
            child: Row(
              children: [
                Flexible(
                  child: SelectableText(
                    user?.string('email') ?? '',
                    maxLines: 1,
                    style: RaftTypography.mono(
                      t,
                      size: 14,
                      line: 20,
                      color: t.brutal ? Colors.black : t.strong,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                user?.json['emailVerified'] == true
                    ? const RaftRecipeBadge(
                        label: 'Verified',
                        variant: RaftBadgeRecipeVariant.success,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        uppercase: true,
                        glyph: RaftGlyph.shield,
                      )
                    : const RaftRecipeBadge(
                        label: 'Unverified',
                        variant: RaftBadgeRecipeVariant.warning,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        uppercase: true,
                      ),
              ],
            ),
          ),
          if (profileError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                profileError!,
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: t.colors['danger'],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            // `size="sm" variant="outline"` + `disabled:opacity-50`.
            child: RaftRecipeButton(
              key: const Key('account-save-profile'),
              label: profileBusy
                  ? 'Saving...'
                  : profileSaved
                  ? 'Saved'
                  : 'Save Profile',
              glyph: profileSaved && !profileBusy ? RaftGlyph.check : null,
              glyphSize: 14,
              size: RaftButtonRecipeSize.sm,
              disabledOpacity: .5,
              onPressed:
                  profileBusy ||
                      profileName.text.trim().isEmpty ||
                      profileName.text.trim() == savedProfileName
                  ? null
                  : saveProfile,
            ),
          ),
          const SizedBox(height: 12),
          divider,
          const SizedBox(height: 12),
          AccountConnectionsView(
            key: ValueKey('account-sign-in-$authority'),
            controller: controller,
            inline: true,
          ),
          if (user?.string('description').isNotEmpty == true) ...[
            const SizedBox(height: 12),
            SelectableText(
              user!.string('description'),
              style: RaftTypography.body(t, size: 14, line: 20, color: muted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
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
            ],
          ),
        ],
      ),
    );
    // AccountSection: `mb-6` sections (SectionHeader mb-3 + card), then the
    // sibling AccountSignOutSection.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Account',
          glyph: RaftGlyph.user,
        ),
        card,
        const SizedBox(height: 24),
        const RaftSettingsSectionHeader(
          label: 'Session',
          glyph: RaftGlyph.logOut,
        ),
        RaftSettingsActionCard(
          title: 'Log out',
          description:
              'Log out of this browser. Your account and data stay; you can log back in any time.',
          // `variant="warning" size="md"`, text only.
          action: RaftRecipeButton(
            key: const Key('account-logout'),
            label: 'Log out',
            variant: RaftButtonRecipeVariant.warning,
            onPressed: widget.onLogout == null
                ? null
                : () => confirmLogout(context),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> confirmLogout(BuildContext context) async {
    final ok = await RaftConfirmDialog.show(
      context,
      const RaftConfirmDialog(
        title: 'Log out',
        message:
            'Log out of this browser? Your account and data are kept; you can log back in any time.',
        confirmLabel: 'Log out',
        // confirmColor="bg-brutal-orange" -> warning tone.
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: Key('account-logout-confirm-button'),
      ),
    );
    if (ok == true) await widget.onLogout?.call();
  }
}
