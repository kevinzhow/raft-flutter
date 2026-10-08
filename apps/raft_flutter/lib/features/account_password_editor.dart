import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

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
  String? error;
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
    setState(() {
      expanded = false;
      saving = false;
      saved = false;
      error = null;
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
    clearCredentials();
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final captured = authority;
    if (saving || !accepts(captured)) return;
    if (current.text.isEmpty ||
        next.text.length < 8 ||
        next.text != confirmation.text) {
      setState(
        () => error = current.text.isEmpty
            ? 'Enter your current password.'
            : next.text.length < 8
            ? 'Use at least 8 characters.'
            : 'The new passwords must match.',
      );
      return;
    }
    setState(() {
      saving = true;
      saved = false;
      error = null;
    });
    try {
      await widget.controller.client.patch(
        '/auth/me',
        data: {'currentPassword': current.text, 'newPassword': next.text},
      );
      if (!accepts(captured)) return;
      clearCredentials();
      setState(() => saved = true);
      widget.onUpdated?.call();
    } catch (cause) {
      if (accepts(captured)) {
        setState(
          () => error = cause is RaftApiException
              ? cause.message
              : 'Could not update your password. Try again.',
        );
      }
    } finally {
      if (accepts(captured)) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    Widget field(
      String label,
      TextEditingController controller,
      String hint,
      String autofill,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          raftText(context, label),
          style: RaftTypography.body(
            tokens,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: raftText(context, label),
          child: TextField(
            controller: controller,
            obscureText: true,
            enabled: !saving,
            autofillHints: [autofill],
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: hint.isEmpty ? null : raftText(context, hint),
            ),
            onSubmitted: (_) => submit(),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RaftTextButton(
            label: 'Change password',
            glyph: expanded ? RaftGlyph.chevronDown : RaftGlyph.chevronRight,
            onPressed: saving
                ? null
                : () => setState(() {
                    expanded = !expanded;
                    saved = false;
                    error = null;
                    if (!expanded) clearCredentials();
                  }),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          field('Current password', current, '', AutofillHints.password),
          const SizedBox(height: 12),
          field(
            'New password',
            next,
            'At least 8 characters',
            AutofillHints.newPassword,
          ),
          const SizedBox(height: 12),
          field(
            'Confirm new password',
            confirmation,
            '',
            AutofillHints.newPassword,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  raftText(context, error!),
                  style: RaftTypography.body(
                    tokens,
                    size: 12,
                    line: 16,
                    color: tokens.colors['danger'],
                  ),
                ),
              ),
            ),
          if (saved)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  raftText(context, 'Password updated.'),
                  style: RaftTypography.body(tokens, size: 12, line: 16),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: RaftButton(
              label: 'Change password',
              visualHeight: 28,
              busy: saving,
              onPressed: saving ? null : submit,
            ),
          ),
        ],
      ],
    );
  }
}
