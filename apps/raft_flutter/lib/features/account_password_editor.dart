import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/user_error.dart';
import '../data/workspace_controller.dart';

/// Source SettingsPanel inline password form. Credentials remain in controllers
/// only and are cleared on collapse, accepted save, account change and disposal.
class AccountPasswordEditor extends StatefulWidget {
  const AccountPasswordEditor({
    super.key,
    required this.controller,
    this.onUpdated,
  });
  final WorkspaceController controller;
  final VoidCallback? onUpdated;
  @override
  State<AccountPasswordEditor> createState() => _AccountPasswordEditorState();
}

class _AccountPasswordEditorState extends State<AccountPasswordEditor> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirmation = TextEditingController();
  bool expanded = false, saving = false, saved = false;

  /// A rejected save (server text). Cleared when the next save starts.
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next save starts, a validation attempt runs, the form is collapsed or the account changes.
  String? error;

  /// The form was submitted incomplete: the problem is then shown live and
  /// ends as soon as the fields stop having it.
  bool attempted = false;

  /// Web hides "Password updated!" after 2 seconds.
  Timer? savedTimer;
  late String scope;
  String get authority =>
      '${identityHashCode(widget.controller.client)}|${widget.controller.client.origin}|${widget.controller.client.generation}|${widget.controller.client.user?.id}';
  bool accepts(String captured) =>
      mounted && captured == scope && captured == authority;
  @override
  void initState() {
    super.initState();
    scope = authority;
    widget.controller.addListener(accountChanged);
    for (final c in [current, next, confirmation]) {
      c.addListener(fieldChanged);
    }
  }

  void fieldChanged() {
    if (attempted && mounted) setState(() {});
  }

  String? get problem => current.text.isEmpty
      ? 'Enter your current password.'
      : next.text.length < 8
      ? 'New password must be at least 8 characters'
      : next.text != confirmation.text
      ? 'Passwords do not match'
      : null;

  void clearSaved() {
    savedTimer?.cancel();
    savedTimer = null;
    saved = false;
  }

  void clearCredentials() {
    current.clear();
    next.clear();
    confirmation.clear();
  }

  void accountChanged() {
    if (scope == authority) return;
    scope = authority;
    clearCredentials();
    clearSaved();
    setState(() {
      expanded = false;
      saving = false;
      error = null;
      attempted = false;
    });
  }

  @override
  void didUpdateWidget(AccountPasswordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(accountChanged);
      widget.controller.addListener(accountChanged);
    }
    accountChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(accountChanged);
    savedTimer?.cancel();
    for (final c in [current, next, confirmation]) {
      c.removeListener(fieldChanged);
    }
    clearCredentials();
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final captured = authority;
    if (saving || !accepts(captured)) return;
    if (problem != null) {
      setState(() {
        attempted = true;
        error = null;
      });
      return;
    }
    clearSaved();
    setState(() {
      saving = true;
      error = null;
      attempted = false;
    });
    try {
      await widget.controller.client.patch(
        '/auth/me',
        data: {'currentPassword': current.text, 'newPassword': next.text},
      );
      if (!accepts(captured)) return;
      clearCredentials();
      setState(() => saved = true);
      savedTimer = Timer(const Duration(seconds: 2), () {
        savedTimer = null;
        if (mounted) setState(() => saved = false);
      });
      widget.onUpdated?.call();
    } catch (cause) {
      if (accepts(captured)) {
        setState(
          () => error = userErrorText(
            cause,
            fallback: 'Failed to change password',
            where: 'change password',
          ),
        );
      }
    } finally {
      if (accepts(captured)) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    // SettingsPanel FormField (labelStyle plain, size compact) + raft-ui Input `w-full text-sm`.
    Widget field(
      String label,
      TextEditingController controller,
      String hint,
      Key fieldKey,
    ) => RaftSettingsField(
      label: label,
      child: RaftRecipeInput(
        fieldKey: fieldKey,
        controller: controller,
        placeholder: hint.isEmpty ? null : tr(hint),
        obscure: true,
        enabled: !saving,
        onSubmitted: (_) => submit(),
      ),
    );
    final strong = RaftTypography.heading(tokens, size: 14, line: 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `flex items-center gap-2 text-sm font-bold` button with a 14px chevron (rotated 90deg when open).
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            key: const ValueKey('account-change-password'),
            behavior: HitTestBehavior.opaque,
            onTap: saving
                ? null
                : () => setState(() {
                    expanded = !expanded;
                    clearSaved();
                    error = null;
                    attempted = false;
                    if (!expanded) clearCredentials();
                  }),
            child: Semantics(
              button: true,
              label: tr('Change Password'),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftIcon(
                    expanded ? RaftGlyph.chevronDown : RaftGlyph.chevronRight,
                    size: 14,
                    color: strong.color,
                  ),
                  const SizedBox(width: RaftSpace.x2),
                  Text(tr('Change Password'), style: strong),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: RaftSpace.x3),
          field(
            'Current Password',
            current,
            '',
            const ValueKey('account-current-password'),
          ),
          const SizedBox(height: RaftSpace.x3),
          field(
            'New Password',
            next,
            'Min 8 characters',
            const ValueKey('account-new-password'),
          ),
          const SizedBox(height: RaftSpace.x3),
          field(
            'Confirm Password',
            confirmation,
            '',
            const ValueKey('account-confirm-password'),
          ),
          if (error ?? (attempted ? problem : null) case final shown?)
            Padding(
              padding: const EdgeInsets.only(top: RaftSpace.x3),
              child: RaftErrorBanner(shown, small: true, bold: true),
            ),
          if (saved)
            Padding(
              padding: const EdgeInsets.only(top: RaftSpace.x3),
              child: Semantics(
                liveRegion: true,
                child: RaftSettingsSavedNote(tr('Password updated!')),
              ),
            ),
          const SizedBox(height: RaftSpace.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftSettingsRecipeButton(
              key: const ValueKey('account-password-submit'),
              label: saving ? 'Updating…' : 'Change Password',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              onPressed: saving ? null : submit,
            ),
          ),
        ],
      ],
    );
  }
}
