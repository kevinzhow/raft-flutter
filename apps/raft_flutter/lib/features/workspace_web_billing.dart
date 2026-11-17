import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/web_billing.dart' as web;

export '../platform/web_billing.dart' show WebBillingGate;

/// [web.openWebBilling] for the current server: the helper every paid action
/// (paywalls, limit notices, Plan & Billing, action cards, onboarding) calls.
extension WorkspaceWebBilling on WorkspaceController {
  Future<bool> openWebBilling({String? gate}) => web.openWebBilling(
    coordinator: client.origin,
    slug: server?.string('slug'),
    gate: gate,
  );
}

/// [WorkspaceWebBilling.openWebBilling] from a button: the browser opens at
/// once (no request first); when it cannot, an error toast says so instead
/// of the press doing nothing.
Future<void> openWebBillingOrToast(
  BuildContext context,
  WorkspaceController w, {
  String? gate,
}) async {
  if (!await w.openWebBilling(gate: gate) && context.mounted) {
    showRaftToast(
      context,
      'Could not open this address.',
      tone: RaftToastRecipeTone.error,
    );
  }
}
