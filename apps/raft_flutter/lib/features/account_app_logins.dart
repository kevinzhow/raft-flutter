// Web v1.24.0 Settings › Account › Apps you signed in to with Raft
// (features/settings/account/AppLoginsSection.tsx, AppLoginRow.tsx; RFC 079
// phase 3a): the account-mode Apps that know who the person is, each with
// Revoke → confirm → DELETE /me/app-logins/:clientId.
//
// The section renders only while the list has an entry; a failed load renders
// nothing either. The Revoke that opened the dialog goes with its row, so a
// revoke moves focus to the next row's Revoke (the one before it after the
// last row), or to [AppLoginsSection.emptiedFocus] when the section goes with
// the last one. The dialog opens on Cancel.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'account_security_answer.dart';
import 'integrations_views.dart' show integrationInitials;

class AppLoginsSection extends StatefulWidget {
  const AppLoginsSection({
    super.key,
    required this.controller,
    this.emptiedFocus,
  });
  final WorkspaceController controller;

  /// Where focus goes when revoking the last App removes the section.
  final FocusNode? emptiedFocus;

  @override
  State<AppLoginsSection> createState() => _AppLoginsState();
}

class _AppLoginsState extends State<AppLoginsSection> {
  RaftClient get client => widget.controller.client;
  List<AppLogin> logins = const [];
  final revokeFocus = <String, FocusNode>{};

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    for (final node in revokeFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Web `useEffect`: read once on mount; a failure leaves the section hidden.
  Future<void> load() async {
    try {
      final list = await client.listAppLogins();
      if (mounted) setState(() => logins = list);
    } catch (_) {
      // Nothing to show: the section stays hidden.
    }
  }

  FocusNode focusFor(String clientId) => revokeFocus.putIfAbsent(
    clientId,
    () => FocusNode(debugLabel: 'revoke $clientId'),
  );

  Future<void> revoke(AppLogin login) async {
    FocusNode? after;
    final revoked = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        surfaceKey: const ValueKey('app-login-revoke-dialog'),
        title: raftFormat(context, 'Revoke {appName}?', {
          'appName': login.name,
        }),
        message: raftFormat(
          context,
          '{appName} loses access right away. To use it again, sign in with Raft again.',
          {'appName': login.name},
        ),
        confirmLabel: 'Revoke',
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: const ValueKey('app-login-revoke-confirm'),
        initialFocusCancel: true,
        onConfirm: () async {
          final failure = raftFormat(
            context,
            "Couldn't revoke {appName}. Try again.",
            {'appName': login.name},
          );
          try {
            await client.revokeAppLogin(login.clientId);
          } catch (_) {
            // The dialog shows this and stays open; the row stays.
            throw RaftUserError(failure);
          }
          if (!mounted) return;
          final index = logins.indexWhere((l) => l.clientId == login.clientId);
          // The next row's Revoke, else the one before it (none: the last App).
          final neighbour = index < 0
              ? null
              : index + 1 < logins.length
              ? logins[index + 1]
              : index > 0
              ? logins[index - 1]
              : null;
          after = neighbour == null ? null : focusFor(neighbour.clientId);
          setState(
            () => logins = [
              for (final l in logins)
                if (l.clientId != login.clientId) l,
            ],
          );
          final gone = revokeFocus.remove(login.clientId);
          if (gone != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => gone.dispose());
          }
          showRaftToast(
            context,
            raftFormat(context, '{appName} revoked', {'appName': login.name}),
            tone: RaftToastRecipeTone.success,
          );
        },
      ),
    );
    if (revoked != true || !mounted) return;
    final target = after ?? widget.emptiedFocus;
    if (target == null) return;
    // The dialog gives focus back as its route leaves; the row it named is gone.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && target.context != null) target.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (logins.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return Padding(
      key: const ValueKey('app-logins-section'),
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SectionHeader `mb-1`, then the description `mb-3`.
          const RaftSettingsSectionHeader(
            label: 'Apps you signed in to with Raft',
            glyph: RaftGlyph.logIn,
            bottom: RaftSpace.x1,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            child: Text(
              raftText(
                context,
                'These apps know who you are. Revoking signs you out of the app right away.',
              ),
              key: const ValueKey('app-logins-description'),
              style: RaftTypography.body(t, size: 13, line: 18, color: t.muted),
            ),
          ),
          RaftListRowGroup(
            key: const ValueKey('app-logins-rows'),
            children: [
              for (final login in logins)
                _AppLoginRow(
                  key: ValueKey('app-login-row-${login.clientId}'),
                  client: client,
                  login: login,
                  revokeFocus: focusFor(login.clientId),
                  onRevoke: () => revoke(login),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One App the person signed in to: logo, name, when, and Revoke.
class _AppLoginRow extends StatelessWidget {
  const _AppLoginRow({
    super.key,
    required this.client,
    required this.login,
    required this.revokeFocus,
    required this.onRevoke,
  });
  final RaftClient client;
  final AppLogin login;
  final FocusNode revokeFocus;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final granted = login.grantedAt;
    final initials = RaftAvatarInitials(
      integrationInitials(login.name),
      size: RaftAvatarSize.md,
    );
    final logo = login.logoUrl;
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      semanticLabel: login.name,
      children: [
        // AvatarSlot `list-row` `type="app"`: the logo, else the initials.
        RaftAvatar(
          name: login.name,
          kind: RaftAvatarKind.app,
          uiSize: RaftAvatarSize.md,
          content: logo == null
              ? initials
              : RaftSizedImage.avatar(
                  logo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
        RaftListRowBody(
          children: [
            RaftListRowTitle(login.name),
            if (granted != null)
              RaftListRowDescription(
                raftFormat(context, 'Signed in {date}', {
                  'date': secondFactorCompactDate(context, client, granted),
                }),
              ),
          ],
        ),
        RaftButton(
          key: ValueKey('app-login-revoke-${login.clientId}'),
          label: raftText(context, 'Revoke'),
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          focusNode: revokeFocus,
          onPressed: onRevoke,
        ),
      ],
    );
  }
}
