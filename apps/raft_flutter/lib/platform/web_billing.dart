import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content_links.dart';

/// Every paid action opens the Web (Kevin 2654e77c, plan-24 decision 7):
/// checkout, prepaid Pro, adding seats and upgrading happen on the Web's
/// Plan & Billing page on every platform. The app only shows the plan, seats,
/// usage and payment-method status, and the limit notices.
///
/// The paywall that sent the person there (`gate`, Web `UpgradeGate` in
/// shared/src/upgradeGates.ts) rides along as the Web's Stripe-return
/// parameters `?upgrade=<gate>&upgradeCanceled=1`: Web's UpgradeDialogHost
/// (UpgradeDialog.tsx) reads them on any page and opens the upgrade dialog for
/// that paywall at its first step, the same dialog the Web's own paywall
/// opens. Without a gate the page opens as it is.
abstract final class WebBillingGate {
  static const history = 'history_30d';
  static const uploadMonthlyQuota = 'upload_monthly_quota';
  static const uploadFileSize = 'upload_file_size';
  static const jointChannelFreeCap = 'joint_channel_free_cap';
  static const jointChannelHostLimit = 'joint_channel_host_limit';
  static const jointChannelOverLimit = 'joint_channel_over_limit';
  static const jointChannelReadOnly = 'joint_channel_read_only';
  static const agentMigration = 'agent_migration';
  static const planDowngraded = 'plan_downgraded';
  static const proTheme = 'pro_theme';
  static const externalChannelFreeLimit = 'external_channel_free_limit';
  static const externalChannelFrozen = 'external_channel_frozen';
  static const general = 'general';

  /// Web `UPGRADE_GATES`: anything else is dropped (Web ignores it too).
  static const all = {
    history,
    uploadMonthlyQuota,
    uploadFileSize,
    jointChannelFreeCap,
    jointChannelHostLimit,
    jointChannelOverLimit,
    jointChannelReadOnly,
    agentMigration,
    planDowngraded,
    proTheme,
    externalChannelFreeLimit,
    externalChannelFrozen,
    general,
  };
}

/// The Web's Plan & Billing page of server [slug] on the Web paired with
/// [coordinator] (ContentLinks.originFor), with the paywall [gate] when one
/// sent the person there.
Uri webBillingUri({
  required String coordinator,
  required String? slug,
  String? gate,
}) {
  final origin = ContentLinks.originFor(coordinator);
  final path = slug == null || slug.isEmpty ? '/' : '/s/$slug/settings/billing';
  return origin.replace(
    path: path,
    queryParameters: gate != null && WebBillingGate.all.contains(gate)
        ? {'upgrade': gate, 'upgradeCanceled': '1'}
        : null,
    fragment: null,
  );
}

/// Opens the system browser; tests replace it.
@visibleForTesting
Future<bool> Function(Uri uri) webBillingLauncher = _launch;

Future<bool> _launch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The one way the app starts a paid action: opens [webBillingUri] in the
/// browser. False when the browser could not be opened.
Future<bool> openWebBilling({
  required String coordinator,
  required String? slug,
  String? gate,
}) async {
  try {
    return await webBillingLauncher(
      webBillingUri(coordinator: coordinator, slug: slug, gate: gate),
    );
  } on Object {
    return false;
  }
}
