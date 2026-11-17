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
