import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/auth_audit_log.dart';

/// Offers the local sign-in diagnostics for a feedback report. Shown only when
/// this device recorded something worth reporting (an unexpected sign-out, a
/// kept session, a failed restore), so the account page is otherwise unchanged.
class SignInDiagnosticsCard extends StatefulWidget {
  const SignInDiagnosticsCard({super.key, this.log});
  final AuthAuditLog? log;
  @override
  State<SignInDiagnosticsCard> createState() => _SignInDiagnosticsCardState();
}

class _SignInDiagnosticsCardState extends State<SignInDiagnosticsCard> {
  AuthAuditLog get log => widget.log ?? AuthAuditLog.shared;
  bool relevant = false, copied = false;

  @override
  void initState() {
    super.initState();
    log.open().then((_) {
      if (!mounted) return;
      final has = log.events.any((e) => e.kind != 'recovered');
      if (has) setState(() => relevant = true);
    });
  }

  Future<void> copy() async {
    final text = await log.export();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => copied = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!relevant) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: RaftSpace.x6),
      child: RaftSettingsActionCard(
        title: 'Sign-in diagnostics',
        description:
            'Copy a short log of recent sign-out and sign-in problems on this device (no passwords, tokens or messages) to paste into a feedback report.',
        action: RaftSettingsRecipeButton(
          key: const Key('account-sign-in-diagnostics'),
          label: copied ? 'Copied' : 'Copy',
          variant: RaftButtonRecipeVariant.outline,
          onPressed: copy,
        ),
      ),
    );
  }
}
