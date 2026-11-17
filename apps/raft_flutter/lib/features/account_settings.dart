import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/personal_presentation.dart';
import 'account_onboarding.dart';
import 'account_connections_view.dart';
import 'account_security_passkeys.dart';
import 'account_security_two_step.dart';
import 'human_avatar_edit_menu.dart';
import 'management_support.dart';
import 'public_avatar_url.dart';
import 'usage_data_card.dart';
import 'sign_in_diagnostics_card.dart';

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
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the next save starts and on account change (clearData/hydrateProfile).
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
      if (mounted && scope == authority) {
        setState(
          () => profileError = userErrorText(
            e,
            fallback: 'Failed to update profile',
            where: 'account profile',
          ),
        );
      }
    } finally {
      if (mounted && scope == authority) setState(() => profileBusy = false);
    }
  }

  bool mediaBusy = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the next avatar action starts and on account change (clearData).
  String? mediaError;

  Future<void> image() async {
    if (mediaBusy) return;
    final sourceScope = authority;
    setState(() {
      mediaBusy = true;
      mediaError = null;
    });
    try {
      await AccountMediaActions.uploadAvatar(controller.client);
    } catch (error) {
      if (mounted && sourceScope == authority) {
        setState(
          () => mediaError = userErrorText(
            error,
            fallback: 'Failed to upload avatar',
            where: 'account avatar',
          ),
        );
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
      form: true,
      (_) => RaftFormDialog(
        title: raftText(context, 'Edit Profile'),
        fields: [
          RaftFormField(
            'displayName',
            'Display name',
            initial: user.firstNonEmpty(const ['displayName', 'name']),
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
      form: true,
      (_) => RaftFormDialog(
        title: raftText(context, 'Reading Preferences'),
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
      form: true,
      (_) => RaftFormDialog(
        title: raftText(context, 'Display Language'),
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

  /// What RaftAvatarSlot draws for the signed-in person: their uploaded photo
  /// (resolved against the API origin), else the avatar they built.
  String? _avatarValue(RaftRecord? user) {
    final stored = user?.string('avatarUrl');
    return isHumanAvatarUrl(stored)
        ? stored
        : raftPublicAvatarUrl(controller.client.origin, stored);
  }

  @override
  Widget build(BuildContext context) {
    hydrateProfile();
    final user = controller.client.user, t = RaftTokens.of(context);
    final muted = RaftSettingsText(t).muted;
    // `border-t-2 border-line-muted theme-brutal:border-black`
    final divider = Container(height: 2, color: RaftSettingsText(t).edge);
    final card = RaftSettingsProfileCard(
      // AccountSection: the avatar is the way to change it (HumanAvatarEditMenu:
      // pencil veil, Upload a photo / Build an avatar).
      avatar: HumanAvatarEditMenu(
        key: const Key('account-profile-image'),
        client: controller.client,
        workspace: controller,
        avatarUrl: user?.string('avatarUrl'),
        busy: mediaBusy,
        onUpload: image,
        // `onBuilt`: a built avatar clears an upload error.
        onBuilt: () => setState(() => mediaError = null),
        avatar: t.option('sticker.ring', or: 'none') == 'dieCut'
            ? RaftAvatarSlot(
                key: const Key('account-profile-avatar'),
                name: user?.name ?? '',
                agent: false,
                slot: RaftAvatarSlotContext.profileTile,
                avatarUrl: _avatarValue(user),
              )
            : RaftAvatar(
                key: const Key('account-profile-avatar'),
                name: user?.name ?? '',
                size: RaftSettingsProfileRecipe.avatarSize,
                imageUrl: raftPublicAvatarUrl(
                  controller.client.origin,
                  user?.string('avatarUrl'),
                ),
                content: isHumanAvatarUrl(user?.string('avatarUrl'))
                    ? RaftHumanPixelAvatar(avatarUrl: user!.string('avatarUrl'))
                    : null,
              ),
      ),
      title: user?.name ?? '',
      subtitle: '@${user?.string('name') ?? ''}',
      // SettingsProfileCard children: `space-y-3`.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mediaError != null) ...[
            // `<p className="text-xs font-bold text-brutal-red" role="alert">`
            Semantics(
              liveRegion: true,
              child: Text(
                raftText(context, mediaError!),
                style: RaftSettingsText(t).alert,
              ),
            ),
            const SizedBox(height: RaftSpace.x3),
          ],
          RaftSettingsField(
            label: 'Display name',
            child: RaftRecipeInput(
              fieldKey: const Key('account-profile-display-name'),
              controller: profileName,
              // `theme-brutal:p-2`
              onChanged: (_) => setState(() => profileSaved = false),
              onSubmitted: (_) => saveProfile(),
            ),
          ),
          const SizedBox(height: RaftSpace.x3),
          RaftSettingsField(
            label: 'Username',
            // PrefixedInput "@": `border-line-muted bg-fill-muted
            // shadow-none`, input `text-sm text-foreground-muted`.
            child: RaftSettingsPrefixedInput(
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
          const SizedBox(height: RaftSpace.x3),
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
                      // `text-mono-code`: 13/20.
                      size: 13,
                      line: 20,
                      color: RaftSettingsText(t).strong,
                    ),
                  ),
                ),
                const SizedBox(width: RaftSpace.x2),
                user?.json['emailVerified'] == true
                    ? const RaftSettingsRecipeBadge(
                        label: 'Verified',
                        variant: RaftBadgeRecipeVariant.success,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        glyph: RaftGlyph.shield,
                      )
                    : const RaftSettingsRecipeBadge(
                        label: 'Unverified',
                        variant: RaftBadgeRecipeVariant.warning,
                        appearance: RaftBadgeRecipeAppearance.soft,
                      ),
              ],
            ),
          ),
          if (profileError != null) ...[
            const SizedBox(height: RaftSpace.x3),
            // `<Banner intent="warning" density="sm" className="font-bold">`
            // after Email, before the save control; the avatar failure is its
            // own `text-xs` alert above the form.
            RaftErrorBanner(profileError!, small: true, bold: true),
          ],
          const SizedBox(height: RaftSpace.x3),
          Align(
            alignment: Alignment.centerLeft,
            // `size="sm" variant="outline"` + `disabled:opacity-50`.
            child: RaftSettingsRecipeButton(
              key: const Key('account-save-profile'),
              label: profileBusy
                  ? 'Saving...'
                  : profileSaved
                  ? 'Saved'
                  : 'Save profile',
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
          const SizedBox(height: RaftSpace.x3),
          divider,
          const SizedBox(height: RaftSpace.x3),
          AccountConnectionsView(
            key: ValueKey('account-sign-in-$authority'),
            controller: controller,
            inline: true,
          ),
          if (user?.string('description').isNotEmpty == true) ...[
            const SizedBox(height: RaftSpace.x3),
            SelectableText(
              user!.string('description'),
              style: RaftTypography.body(t, size: 14, line: 20, color: muted),
            ),
          ],
          const SizedBox(height: RaftSpace.x3),
          Wrap(
            spacing: RaftSpace.x3,
            runSpacing: RaftSpace.x3,
            children: [
              RaftButton(
                key: const Key('account-display-language'),
                label: raftText(context, 'Display Language'),
                secondary: true,
                onPressed: () => language(context),
              ),
              RaftButton(
                label: raftText(context, 'Edit Profile'),
                secondary: true,
                onPressed: () => edit(context),
              ),
              RaftButton(
                label: raftText(context, 'Reading Preferences'),
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
        const SizedBox(height: RaftSpace.x6),
        AccountSecuritySections(
          key: ValueKey('account-security-$authority'),
          controller: controller,
          passkeys: (s) => PasskeysSection(controller: controller, settings: s),
        ),
        const RaftSettingsSectionHeader(
          label: 'Session',
          glyph: RaftGlyph.logOut,
        ),
        RaftSettingsActionCard(
          title: 'Sign out',
          description: 'Sign out of this browser. Your account and data stay; you can sign back in any time.',
          // `variant="warning" size="md"`, text only.
          action: RaftSettingsRecipeButton(
            key: const Key('account-logout'),
            label: 'Sign out',
            variant: RaftButtonRecipeVariant.warning,
            onPressed: widget.onLogout == null
                ? null
                : () => confirmLogout(context),
          ),
        ),
        UsageDataSettingsCard(controller: controller),
        const SignInDiagnosticsCard(),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }

  Future<void> confirmLogout(BuildContext context) async {
    final ok = await RaftConfirmDialog.show(
      context,
      const RaftConfirmDialog(
        title: 'Sign out',
        message: 'Sign out of this browser? Your account and data are kept; you can sign back in any time.',
        confirmLabel: 'Sign out',
        cancelLabel: 'Cancel',
        surfaceKey: ValueKey('account-logout-dialog'),
        // confirmColor="bg-brutal-orange" -> warning tone.
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: Key('account-logout-confirm-button'),
      ),
    );
    if (ok == true) await widget.onLogout?.call();
  }
}
