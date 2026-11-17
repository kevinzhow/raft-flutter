import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/billing_info.dart';
import '../data/billing_plans.dart';
import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import '../platform/web_billing.dart' show openInBrowser;
import 'agent_hosted_spend.dart';
import 'billing_overview.dart';
import 'billing_overview_model.dart';
import 'billing_overview_parts.dart';
import 'billing_payment_method.dart';
import 'management_support.dart';
import 'workspace_web_billing.dart';

export '../data/billing_plans.dart' show RaftBillingPlans;

/// Settings > Plan & Billing (Web v1.24 BillingTabContent + PlanSection):
/// GET /billing/subscription and /servers/:id/usage, shown as the overview
/// cards. The app only shows the plan, seats, usage and payment-method
/// status; every button that would pay or change billing opens the Web's
/// Plan & Billing page ([WorkspaceWebBilling.openWebBilling]). The page
/// renders its last accepted projection at once on a revisit and revalidates
/// in the background; a plan update (`server:plan-updated`) reloads it.
class BillingView extends StatefulWidget {
  const BillingView({super.key, required this.controller, this.now});
  final WorkspaceController controller;

  /// Clock for the downgrade notice and the prepaid reminder (tests and
  /// parity freeze it).
  final DateTime Function()? now;
  @override
  State<BillingView> createState() => _BillingState();
}

class _BillingState extends ManagementState<BillingView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic>? billing, usage;
  bool prepaidEnabled = false;

  @override
  void initState() {
    super.initState();
    prepaidEnabled = cachedServerFlag(w, RaftFeatureFlags.proPrepaid) ?? false;
    startManagement();
    seenPlanRevision = w.planRevision;
    w.addListener(reloadOnPlanUpdate);
  }

  /// Web `server:plan-updated`: patch the plan, then reload billing and usage.
  int seenPlanRevision = 0;
  void reloadOnPlanUpdate() {
    if (!mounted || w.planRevision == seenPlanRevision) return;
    seenPlanRevision = w.planRevision;
    reload();
  }

  @override
  void dispose() {
    w.removeListener(reloadOnPlanUpdate);
    super.dispose();
  }

  @override
  void clearData() {
    billing = null;
    usage = null;
    prepaidEnabled = false;
  }

  @override
  String get snapshotKey => 'billing';
  @override
  Map<String, Object?> captureSnapshot() => {
    'billing': billing,
    'usage': usage,
    'prepaidEnabled': prepaidEnabled,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    billing = fields['billing'] as Map<String, dynamic>?;
    usage = fields['usage'] as Map<String, dynamic>?;
    prepaidEnabled = fields['prepaidEnabled'] == true;
    return true;
  }

  /// serverStore loadUsage + loadBilling: each read fails on its own and
  /// keeps the value it had (Web leaves the store field untouched).
  @override
  Future<void> loadData(int request, int generation) async {
    final server = w.server;
    if (server == null) return;
    Future<Map<String, dynamic>?> read(String path) async {
      try {
        final value = await w.client.get(path);
        return value is Map ? Map<String, dynamic>.from(value) : null;
      } on RaftApiException catch (e) {
        if ([401, 403].contains(e.status)) rethrow;
        return null;
      }
    }

    final identity = authority;
    final results = await Future.wait([
      read('/billing/subscription'),
      read('/servers/${server.id}/usage'),
    ]);
    if (!accepts(generation, request)) return;
    billing = results[0] ?? billing;
    usage = results[1] ?? usage;
    // Renewing prepaid Pro is gated by the server's pro_prepaid flag; only a
    // prepaid server needs to know it.
    if (billing?['source'] == 'prepaid') {
      final enabled = await _prepaidFlag(server.id);
      if (!accepts(generation, request)) return;
      if (enabled != null) {
        prepaidEnabled = enabled;
        rememberServerFlag(w, RaftFeatureFlags.proPrepaid, enabled, identity);
      }
    }
  }

  Future<bool?> _prepaidFlag(String serverId) async {
    try {
      final value = await w.client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [RaftFeatureFlags.proPrepaid],
          serverId: serverId,
        ),
      );
      final rows = value is Map ? value['evaluations'] : null;
      if (rows is! List) return null;
      for (final row in rows) {
        if (row is Map && row['key'] == RaftFeatureFlags.proPrepaid) {
          final enabled = row['enabled'];
          return enabled is bool ? enabled : null;
        }
      }
    } on RaftApiException catch (e) {
      // Unknown is not permission: only a denial turns the flag off.
      if ([401, 403].contains(e.status)) return false;
    } catch (_) {}
    return null;
  }

  DateTime get now => widget.now?.call() ?? DateTime.now();

  Future<void> _openWeb({String? gate}) =>
      openWebBillingOrToast(context, w, gate: gate);

  Future<void> _compare() async {
    // The pricing page, in the browser like every page that leaves Raft.
    final opened = await openInBrowser(
      Uri.parse(RaftBillingPlans.comparePlansUrl),
    );
    if (!opened && mounted) {
      showRaftToast(
        context,
        'Could not open this address.',
        tone: RaftToastRecipeTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = w.server;
    // The skeleton only until there is something to show: a reload keeps the
    // page in place.
    if (server == null || (loading && (billing == null || usage == null))) {
      return const BillingOverviewLoading();
    }
    if (!w.can('viewBilling')) return const BillingRestricted();
    final info = billing == null ? null : BillingInfo.fromJson(billing!);
    final model = BillingOverviewModel(
      serverPlan: server.string('plan'),
      billing: info,
      usageAgents: usage?['agents'] is num ? usage!['agents'] as num : null,
      now: now,
      prepaidEnabled: prepaidEnabled,
    );
    return BillingOverview(
      model: model,
      serverName: server.string('name'),
      downgradedAt: server.string('planDowngradedAt').isEmpty
          ? null
          : server.string('planDowngradedAt'),
      afterUsage: info?.canReadBillingSummary == true
          ? AgentHostedSpendCard(controller: w)
          : null,
      paymentMethod: (before, after) =>
          BillingPaymentMethodList(controller: w, before: before, after: after),
      onOpenWeb: _openWeb,
      onCompare: _compare,
      onRetry: reload,
    );
  }
}
