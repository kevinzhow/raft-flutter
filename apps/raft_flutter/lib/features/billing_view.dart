import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/user_error.dart';
import '../data/billing_plans.dart';

import '../data/workspace_controller.dart';
import '../platform/content_links.dart';
import 'agent_hosted_spend.dart';
import 'management_support.dart';

export '../data/billing_plans.dart' show RaftBillingPlans;

/// `getFinitePlanLimitExcess`.
int billingLimitExcess(num usage, int limit) {
  if (limit < 0) return 0;
  final used = usage.isFinite ? usage.ceil().clamp(0, 1 << 31) : 0;
  return (used - limit).clamp(0, 1 << 31);
}

String _seats(int count) => count == 1 ? '1 seat' : '$count seats';
String _plural(num count, String one, String other) => count == 1 ? one : other;

/// `formatUsd`.
String billingUsd(num value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(2);

/// `formatSeatUsageNumber`.
String billingSeatNumber(num value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// `formatBillingAmount` (Intl currency, minor units).
String billingAmount(num amount, String currency, String locale) =>
    NumberFormat.simpleCurrency(
      locale: locale.toLowerCase().startsWith('zh') ? 'zh_CN' : 'en_US',
      name: currency.toUpperCase(),
    ).format(amount / 100);

/// `getBillingControlsState`.
({
  bool hasEntitlingSubscription,
  bool canCheckout,
  bool canUpdatePacks,
  bool canOpenPortal,
})
billingControls(String? plan, String? subscriptionStatus) {
  final internal = plan == 'founder' || plan == 'partner';
  final entitled =
      !internal &&
      (subscriptionStatus == 'active' || subscriptionStatus == 'past_due');
  return (
    hasEntitlingSubscription: entitled,
    canCheckout: !entitled && !internal,
    canUpdatePacks: entitled && plan == 'pro',
    canOpenPortal: entitled,
  );
}

/// `getBillingPlanPresentation` (English catalog values).
({
  String name,
  String description,
  List<String> included,
  List<String> notIncluded,
})
billingPlanPresentation(
  String plan, {
  required int humans,
  required int agents,
  required int seats,
}) {
  const pro = [
    'Everything in Free',
    'Agent migration',
    'Unlimited message history',
    'Higher file upload limits',
    'Use Joint Channels',
    'More professional features coming soon',
  ];
  return switch (plan) {
    'founder' => (
      name: 'Founder',
      description: 'Grandfathered unlimited access.',
      included: const ['Everything without any limitations'],
      notIncluded: const <String>[],
    ),
    'partner' => (
      name: 'Partner',
      description: 'Partner access for testing and sponsored use.',
      included: const [
        'Raft features enabled for partner testing and sponsored collaboration',
      ],
      notIncluded: const <String>[],
    ),
    'pro' when humans > 0 || agents > 0 => (
      name: 'Pro',
      description:
          '${_seats(seats)} purchased. Each human uses 1 seat; each agent uses ${RaftBillingPlans.proAgentSeatFraction} seat.',
      included: pro,
      notIncluded: const <String>[],
    ),
    'pro' => (
      name: 'Pro',
      description: 'For builders and teams scaling agent collaboration.',
      included: pro,
      notIncluded: const <String>[],
    ),
    _ => (
      name: 'Free',
      description: 'Start building with agents.',
      included: const [
        'Channels',
        'Tasks',
        'Agents on your own computers',
        'Agent reminders',
        'Basic observability',
        '30 days of message history',
        '100 MB file uploads/month',
        'Use Joint Channels (each Joint Channel has 2 free-server slots)',
      ],
      notIncluded: const [
        'Agent migration',
        'Higher file upload limits',
        'Unlimited message history',
        'More professional features coming soon',
      ],
    ),
  };
}

enum _BillingAction { checkout, portal, preview, update, cancel }

/// Settings > Plan & Billing (SettingsPanel.tsx BillingTabContent +
/// PlanSection): GET /billing/subscription and /servers/:id/usage, Stripe
/// checkout / portal opened in the browser, seat updates with the preview
/// endpoint, and cancellation. The page renders its last accepted projection
/// at once on a revisit and revalidates in the background.
class BillingView extends StatefulWidget {
  const BillingView({
    super.key,
    required this.controller,
    this.now,
    this.openExternal,
  });
  final WorkspaceController controller;

  /// Opens Stripe Checkout / the portal / the pricing page in the browser
  /// (Web navigates the tab there); tests substitute it.
  final Future<bool> Function(Uri uri)? openExternal;

  /// Clock for the trial / grace-period copy (tests and parity freeze it).
  final DateTime Function()? now;
  @override
  State<BillingView> createState() => _BillingState();
}

class _BillingState extends ManagementState<BillingView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic>? billing, usage;
  _BillingAction? pending;
  // ignore: raft_lints/avoid_imperative_notice_state -- Both clear when the next billing action starts (Web setBillingError/Notice('') at each handler) and on account/server change (clearData).
  String billingError = '', billingNotice = '';
  int? desiredSeatOverride;

  /// Web `desiredSeatInput`: the raw text while it differs from the value.
  bool editingSeats = false;
  bool annual = true;
  Map<String, dynamic>? seatPreview;
  final seatInput = TextEditingController();
  final promotion = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    seatInput.dispose();
    promotion.dispose();
    super.dispose();
  }

  @override
  void clearData() {
    billing = null;
    usage = null;
    pending = null;
    billingError = '';
    billingNotice = '';
    desiredSeatOverride = null;
    editingSeats = false;
    seatPreview = null;
    promotion.clear();
  }

  @override
  String get snapshotKey => 'billing';
  @override
  Map<String, Object?> captureSnapshot() => {
    'billing': billing,
    'usage': usage,
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    billing = fields['billing'] as Map<String, dynamic>?;
    usage = fields['usage'] as Map<String, dynamic>?;
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

    final results = await Future.wait([
      read('/billing/subscription'),
      read('/servers/${server.id}/usage'),
    ]);
    if (!accepts(generation, request)) return;
    billing = results[0] ?? billing;
    usage = results[1] ?? usage;
  }

  DateTime get now => widget.now?.call() ?? DateTime.now();

  /// Web passes `window.location.href` (this settings page) as the Stripe
  /// return address.
  String get returnUrl {
    final origin = ContentLinks.originFor(w.client.origin);
    final slug = w.server?.string('slug') ?? '';
    return origin
        .replace(path: slug.isEmpty ? '/' : '/s/$slug/settings/billing')
        .toString();
  }

  Future<bool> _launch(Uri uri) =>
      widget.openExternal?.call(uri) ??
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _open(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        !await _launch(uri)) {
      throw StateError('Could not open this address.');
    }
  }

  String _error(Object e, String fallback) => userErrorText(
    e,
    fallback: fallback,
    // Web `promotion_code_unavailable` on checkout.
    codeText: {
      'promotion_code_unavailable': raftText(
        context,
        'This promotion code is unavailable. Check it or remove it to continue.',
      ),
    },
    where: 'billing',
  );

  Future<void> _mutate(
    _BillingAction kind,
    Future<void> Function() body,
    String fallback,
  ) async {
    final generation = w.client.generation, source = authority;
    setState(() {
      billingError = '';
      billingNotice = '';
      pending = kind;
    });
    try {
      await body();
    } catch (e) {
      if (!accepts(generation) || source != authority) return;
      if (invalidateDeniedMutation(e)) return;
      if (mounted) {
        setState(() => billingError = _error(e, raftText(context, fallback)));
      }
    } finally {
      if (mounted && accepts(generation) && source == authority) {
        setState(() => pending = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = w.server;
    if (server == null || (loading && billing == null && usage == null)) {
      return const RaftPlanBillingLoading();
    }
    if (!w.can('viewBilling')) {
      return const RaftBillingRestricted(
        message: 'Only server owners and admins can view billing.',
      );
    }
    return _plan(context, server);
  }

  Widget _plan(BuildContext context, RaftRecord server) {
    String tr(String source, [Map<String, Object?> values = const {}]) =>
        raftFormat(context, source, values);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final b = billing;
    final plan = '${b?['plan'] ?? server.string('plan')}'.isEmpty
        ? 'free'
        : '${b?['plan'] ?? server.string('plan')}';
    final capacity = managementMap(b?['capacity']);
    final bUsage = managementMap(b?['usage']);
    final provisioned = managementMap(b?['provisioned']);
    final subscription = b?['subscription'] is Map
        ? managementMap(b!['subscription'])
        : null;
    final price = b?['price'] is Map ? managementMap(b!['price']) : null;
    num n(Object? v, [num fallback = 0]) => v is num ? v : fallback;

    final agentCount = n(bUsage['agents'], n(usage?['agents'])).toInt();
    final humanCount = bUsage['humans'] is num ? n(bUsage['humans']) : null;
    final usesUniversal =
        b?['capacity'] is Map && n(capacity['maxUniversalSeats'], -1) != -1;
    final universalLimit = usesUniversal ? n(capacity['maxUniversalSeats']) : 0;
    final usedHuman = (humanCount ?? 0).clamp(0, double.infinity);
    final usedAgent = (agentCount * RaftBillingPlans.proAgentSeatFraction)
        .clamp(0, double.infinity);
    final usedUniversal = n(
      bUsage['universalSeats'],
      usedHuman + usedAgent,
    ).clamp(0, double.infinity);
    final scale = universalLimit > 0 && usedUniversal > universalLimit
        ? universalLimit / usedUniversal
        : 1;
    double pct(num used) => universalLimit > 0
        ? (used * scale / universalLimit * 100).clamp(0, 100).toDouble()
        : 0;
    final canManageBilling =
        managementMap(b?['permissions'])['canManageBilling'] == true;
    final controls = billingControls(
      b?['plan'] as String? ?? server.string('plan'),
      subscription?['status'] as String?,
    );
    final isPro = plan == 'pro';
    final disabledReason = !canManageBilling
        ? tr('Only server owners can change billing.')
        : b?['stripeConfigured'] != true
        ? tr('Paid plans are not available yet.')
        : null;
    String formatLimit(num? value) => value == null
        ? '...'
        : value == -1
        ? tr('Unlimited')
        : '$value';
    String formatBytes(num? value) {
      if (value == null || value < 0) return tr('Unlimited');
      if (value >= 1024 * 1024) return '${(value / 1024 / 1024).round()} MB';
      return '${(value / 1024).round()} KB';
    }

    final currentHumanSeats = n(provisioned['humans']).toInt();
    final currentAgentSeats = n(provisioned['agents']).toInt();
    final currentSeatQuantity = n(provisioned['proPackQuantity']).toInt();
    final minimumUsageSeats = usedUniversal.ceil().clamp(1, 1 << 31);
    final minimumSeats = isPro ? currentSeatQuantity.clamp(1, 1 << 31) : 1;
    final checkoutMode = controls.canCheckout;
    final manageSeatMode = !checkoutMode && controls.canUpdatePacks && isPro;
    final showManage = checkoutMode || controls.canUpdatePacks;
    final cancelScheduled = subscription?['cancelAtPeriodEnd'] == true;
    final minimumManageSeats = minimumUsageSeats;
    final defaultSeats = manageSeatMode
        ? (currentSeatQuantity > minimumManageSeats
              ? currentSeatQuantity
              : minimumManageSeats)
        : (minimumUsageSeats > minimumSeats ? minimumUsageSeats : minimumSeats);
    final requestedInput = desiredSeatOverride ?? defaultSeats;
    // getBillingSeatDraftState
    final draftMinimum = [
      minimumUsageSeats,
      manageSeatMode ? 1 : minimumSeats,
    ].reduce((a, c) => a > c ? a : c);
    final requestedSeats = requestedInput > draftMinimum
        ? requestedInput
        : draftMinimum;
    final draftSeats = requestedSeats;
    final belowCoverage = requestedInput < minimumUsageSeats;
    final draftAgentSeats = draftSeats * RaftBillingPlans.proAgentSeatBlockSize;
    final currentInterval =
        (subscription?['billingInterval'] ?? price?['billingInterval']) ==
            'monthly'
        ? 'monthly'
        : (subscription?['billingInterval'] ?? price?['billingInterval']) ==
              null
        ? 'annual'
        : 'annual';
    final intervalLabel = currentInterval == 'annual'
        ? tr('Yearly')
        : tr('Monthly');
    String perPeriod(String interval, String amount) => interval == 'annual'
        ? tr(r'${amount} / year', {'amount': amount})
        : tr(r'${amount} / month', {'amount': amount});
    final currentTotal = price == null
        ? null
        : currentInterval == 'annual'
        ? perPeriod(
            'annual',
            billingUsd(
              price['annualUsd'] is num
                  ? price['annualUsd'] as num
                  : n(price['monthlyUsd']) * 12,
            ),
          )
        : perPeriod('monthly', billingUsd(n(price['monthlyUsd'])));
    final presentation = billingPlanPresentation(
      plan,
      humans: currentHumanSeats,
      agents: currentAgentSeats,
      seats: currentSeatQuantity,
    );
    final selectedInterval = manageSeatMode
        ? currentInterval
        : (annual ? 'annual' : 'monthly');
    final selectedTotal = selectedInterval == 'annual'
        ? perPeriod(
            'annual',
            billingUsd(RaftBillingPlans.proSeatAnnualUsd * draftSeats),
          )
        : perPeriod(
            'monthly',
            billingUsd(RaftBillingPlans.proSeatMonthlyUsd * draftSeats),
          );
    final selectedOriginal = selectedInterval == 'annual'
        ? perPeriod(
            'annual',
            billingUsd(RaftBillingPlans.proSeatMonthlyUsd * 12 * draftSeats),
          )
        : null;
    final seatDelta = draftSeats - currentSeatQuantity;
    final added = seatDelta > 0 ? seatDelta : 0;
    final removed = seatDelta < 0 ? -seatDelta : 0;
    final promotionCode = promotion.text.trim();
    String seatLabel(int count) =>
        count == 1 ? tr('1 seat') : tr('{count} seats', {'count': count});
    String humanCapacity(int count) => count == 1
        ? tr('up to 1 Human')
        : tr('up to {count} Humans', {'count': count});
    String agentCapacity(int count) => count == 1
        ? tr('or 1 Agent')
        : tr('or {count} Agents', {'count': count});
    final noSeatChange = requestedSeats == currentSeatQuantity;
    final updateDisabled =
        disabledReason != null ||
        belowCoverage ||
        pending != null ||
        (!cancelScheduled && noSeatChange);
    final updateTooltip =
        disabledReason ??
        (belowCoverage
            ? tr('Keep at least {min} seats to cover current server usage.', {
                'min': minimumUsageSeats,
              })
            : null) ??
        (cancelScheduled
            ? noSeatChange
                  ? tr(
                      'Reactivate this Pro subscription before the current period ends.',
                    )
                  : tr('Reactivate this subscription and update seats.')
            : noSeatChange
            ? tr('Enter a different seat total.')
            : tr('Review the Pro seat update before confirming.'));
    final updateLabel =
        pending == _BillingAction.update || pending == _BillingAction.preview
        ? pending == _BillingAction.preview
              ? tr('Reviewing...')
              : cancelScheduled && noSeatChange
              ? tr('Reactivating...')
              : tr('Updating...')
        : cancelScheduled
        ? noSeatChange
              ? tr('Reactivate subscription')
              : tr('Reactivate and update seats')
        : tr('Review seat update');
    final capacityLabel = manageSeatMode
        ? seatDelta > 0
              ? tr('Adds {seats}', {'seats': seatLabel(added)})
              : seatDelta < 0
              ? tr('Removes {seats}', {'seats': seatLabel(removed)})
              : tr('Keeps current seats')
        : tr('{seats} selected', {'seats': seatLabel(draftSeats)});
    final draftError = belowCoverage
        ? manageSeatMode
              ? tr('Keep at least {min} seats to cover current server usage.', {
                  'min': minimumUsageSeats,
                })
              : tr(
                  'Enter at least {min} seats to cover current server usage.',
                  {'min': minimumUsageSeats},
                )
        : null;
    if (!editingSeats) {
      final text = '$requestedInput';
      if (seatInput.text != text) seatInput.text = text;
    }
    final controlsLocked = disabledReason != null || pending != null;
    final seatHelp =
        '${manageSeatMode ? tr('Enter the total seats to keep. {capacity}.', {'capacity': capacityLabel}) : tr('{capacity}.', {'capacity': capacityLabel})} '
        '${tr(minimumUsageSeats == 1 ? r'Each seat covers 1 human or 10 agents. Current usage requires at least 1 seat. Each seat is ${price}/month.' : r'Each seat covers 1 human or 10 agents. Current usage requires at least {min} seats. Each seat is ${price}/month.', {'min': minimumUsageSeats, 'price': RaftBillingPlans.proSeatMonthlyUsd})}';
    final seatCopy = manageSeatMode
        ? (
            quantity: tr('Total seats'),
            summary: tr('Seats after update'),
            billable: tr('Total seats after update'),
            capacity: tr('Capacity after update'),
          )
        : (
            quantity: tr('Seats to buy'),
            summary: tr('Seats to buy'),
            billable: tr('Billable seats'),
            capacity: tr('Capacity'),
          );
    final totalLabel = manageSeatMode ? tr('Total after update') : tr('Total');
    final currentTotalLabel = manageSeatMode
        ? (currentInterval == 'annual'
              ? tr('Current yearly total')
              : tr('Current monthly total'))
        : null;

    // ── Handlers (PlanSection) ──
    Future<void> checkout() => _mutate(_BillingAction.checkout, () async {
      final data = managementMap(
        await w.client.post(
          '/billing/checkout',
          data: {
            'targetPlan': 'pro',
            if (promotionCode.isNotEmpty) 'promotionCode': promotionCode,
            'billingInterval': annual ? 'annual' : 'monthly',
            'seatQuantity': requestedSeats,
            'humanSeatQuantity': requestedSeats,
            'agentSeatQuantity':
                requestedSeats * RaftBillingPlans.proAgentSeatBlockSize,
            'successUrl': returnUrl,
            'cancelUrl': returnUrl,
          },
        ),
      );
      await _open(data['url'] as String?);
    }, 'Failed to start checkout');
    Future<void> portal() => _mutate(_BillingAction.portal, () async {
      final data = managementMap(
        await w.client.post('/billing/portal', data: {'returnUrl': returnUrl}),
      );
      await _open(data['url'] as String?);
    }, 'Failed to open billing portal');
    Future<void> update() => _mutate(_BillingAction.update, () async {
      final data = managementMap(
        await w.client.post(
          '/billing/seat-pack-quantity',
          data: {
            'seatQuantity': requestedSeats,
            'humanSeatQuantity': requestedSeats,
            'agentSeatQuantity':
                requestedSeats * RaftBillingPlans.proAgentSeatBlockSize,
            if (seatPreview != null)
              'previewToken': seatPreview!['previewToken'],
          },
        ),
      );
      if (!mounted) return;
      final status = data['status'];
      billingNotice = raftText(this.context, switch (status) {
        'pending_payment' =>
          'Seat update is pending Stripe payment confirmation.',
        'unchanged' => 'Seat quantities are already up to date.',
        'reactivated' => 'Subscription reactivated. Your current Pro seat capacity stays active.',
        _ when status == 'updated' || data['effectiveAt'] == 'current' =>
          'Seat update confirmed. Capacity has been refreshed from Stripe.',
        _ => 'Seat update requested. Capacity will update after Stripe confirms the subscription change.',
      });
      final notice = billingNotice;
      await reload();
      if (!mounted) return;
      setState(() {
        billingNotice = notice;
        desiredSeatOverride = null;
        editingSeats = false;
        promotion.clear();
        seatPreview = null;
      });
    }, 'Failed to update seats');
    Future<void> cancel() => _mutate(_BillingAction.cancel, () async {
      await w.client.post('/billing/cancel');
      await reload();
      if (mounted) {
        setState(
          () => billingNotice = raftText(
            context,
            'Subscription cancellation scheduled for the end of the current billing period.',
          ),
        );
      }
    }, 'Failed to cancel subscription');

    Future<void> confirmCheckout() async {
      if (disabledReason != null || draftError != null) return;
      final ok = await scopedDialog<bool>(
        (context) => RaftConfirmDialog(
          surfaceKey: const ValueKey('billing-confirm-dialog'),
          confirmKey: const ValueKey('billing-confirm'),
          title: tr('Confirm Pro Checkout'),
          confirmLabel: tr('Continue to Stripe'),
          confirmVariant: RaftButtonRecipeVariant.accent,
          content: RaftBillingConfirmMessage(
            lead: tr('You are about to start Pro checkout.'),
            note: promotionCode.isEmpty
                ? null
                : tr(
                    'Promotion code: {code}. The final discount is confirmed on Stripe Checkout.',
                    {'code': promotionCode},
                  ),
            lines: [
              '${tr('Seats')}: $draftSeats',
              '${tr('Capacity')}: ${humanCapacity(draftSeats)} ${agentCapacity(draftAgentSeats)}',
              '$totalLabel: $selectedTotal',
            ],
            closing: [
              tr(
                'The next page is Stripe Checkout, where the payment amount is shown before you pay.',
              ),
            ],
          ),
        ),
      );
      if (ok == true && mounted) await checkout();
    }

    Future<void> confirmUpdate() async {
      if (updateDisabled) return;
      setState(() {
        billingError = '';
        billingNotice = '';
        seatPreview = null;
      });
      if (seatDelta > 0 && promotionCode.isNotEmpty) {
        var previewed = false;
        await _mutate(_BillingAction.preview, () async {
          final data = managementMap(
            await w.client.post(
              '/billing/seat-pack-quantity/preview',
              data: {
                'seatQuantity': requestedSeats,
                'humanSeatQuantity': requestedSeats,
                'agentSeatQuantity':
                    requestedSeats * RaftBillingPlans.proAgentSeatBlockSize,
                'promotionCode': promotionCode,
              },
            ),
          );
          seatPreview = data;
          previewed = true;
        }, 'Failed to preview seat update');
        if (!previewed || !mounted) return;
      }
      final preview = seatPreview;
      final currency = '${preview?['currency'] ?? 'usd'}';
      final ok = await scopedDialog<bool>(
        (context) => RaftConfirmDialog(
          surfaceKey: const ValueKey('billing-confirm-dialog'),
          confirmKey: const ValueKey('billing-confirm'),
          title: tr('Confirm Seat Update'),
          confirmLabel: tr('Confirm and update seats'),
          confirmVariant: RaftButtonRecipeVariant.accent,
          content: RaftBillingConfirmMessage(
            lead: tr('You are about to update this Pro subscription.'),
            lines: [
              '${tr('Current seats')}: $currentSeatQuantity',
              if (seatDelta > 0) '${tr('Seats to add')}: $added',
              if (seatDelta < 0) '${tr('Seats to remove')}: $removed',
              '${tr('Total seats after update')}: $draftSeats',
              '${tr('Capacity after update')}: ${humanCapacity(draftSeats)} ${agentCapacity(draftAgentSeats)}',
              if (preview != null) ...[
                if (managementMap(preview['promotion'])['code'] != null)
                  '${tr('Applied promotion')}: ${managementMap(preview['promotion'])['code']}',
                '${tr('Estimated prorated charge')}: ${billingAmount(n(preview['prorationAmount']), currency, locale)}',
                if (n(preview['discountAmount']) > 0)
                  '${tr('Discount')}: ${billingAmount(-n(preview['discountAmount']), currency, locale)}',
                '${currentInterval == 'annual' ? tr('Estimated next yearly total') : tr('Estimated next monthly total')}: ${billingAmount(n(preview['recurringAmount']), currency, locale)}',
              ],
              '$totalLabel: $selectedTotal',
            ],
            closing: [
              seatDelta > 0
                  ? tr(
                      'Stripe may bill this seat increase immediately after you confirm.',
                    )
                  : seatDelta < 0
                  ? tr(
                      'Stripe will update the subscription quantity after you confirm; the lower total must still cover current usage.',
                    )
                  : tr(
                      'Stripe will reactivate this subscription without changing seat count.',
                    ),
              if (preview != null)
                tr(
                  'This Stripe estimate expires after 5 minutes. Reopen the review if it expires.',
                ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (ok == true) {
        await update();
      } else {
        setState(() => seatPreview = null);
      }
    }

    Future<void> confirmCancel() async {
      final ok = await scopedDialog<bool>(
        (context) => RaftConfirmDialog(
          surfaceKey: const ValueKey('billing-confirm-dialog'),
          confirmKey: const ValueKey('billing-confirm'),
          title: tr('Cancel Subscription'),
          message: tr(
            'Cancel the whole Pro subscription at the end of the current billing period. The server keeps Pro capacity until the cancellation date, then returns to Free.',
          ),
          confirmLabel: tr('Cancel subscription'),
          cancelLabel: tr('Cancel'),
          confirmVariant: RaftButtonRecipeVariant.warning,
        ),
      );
      if (ok == true && mounted) await cancel();
    }

    void commitSeats() {
      if (!editingSeats) return;
      final minimum = manageSeatMode
          ? minimumManageSeats
          : (minimumUsageSeats > minimumSeats
                ? minimumUsageSeats
                : minimumSeats);
      final parsed = int.tryParse(seatInput.text);
      setState(() {
        desiredSeatOverride = parsed == null || parsed < minimum
            ? minimum
            : parsed;
        editingSeats = false;
      });
    }

    // ── Notices ──
    final notices = <RaftBillingNotice>[];
    final downgradedAt = DateTime.tryParse(server.string('planDowngradedAt'));
    if (downgradedAt != null) {
      final graceEnd = downgradedAt.add(
        const Duration(days: RaftBillingPlans.downgradeGracePeriodDays),
      );
      final expired = !now.isBefore(graceEnd);
      final daysLeft = expired
          ? 0
          : (graceEnd.difference(now).inMilliseconds / 86400000).ceil();
      final limits = RaftBillingPlans.freeLimits(now);
      final agents = n(usage?['agents']).toInt();
      final machines = n(usage?['machines']).toInt();
      final channels = n(usage?['channels']).toInt();
      final excess = (
        agents: billingLimitExcess(agents, limits.agents),
        machines: billingLimitExcess(machines, limits.machines),
        channels: billingLimitExcess(channels, limits.channels),
      );
      final days = daysLeft == 1
          ? tr('1 day')
          : tr('{n} days', {'n': daysLeft});
      notices.add(
        RaftBillingNotice(
          tone: RaftBillingNoticeTone.downgrade,
          bodyMargin: !expired,
          title: expired ? tr('Grace Period Expired') : tr('Plan Downgraded'),
          body: expired
              ? tr(
                  'The grace period has ended. Excess agents have been stopped. Upgrade to reactivate them.',
                )
              : excess.agents == 0 &&
                    excess.machines == 0 &&
                    excess.channels == 0
              ? tr(
                  '**{days}** remaining in grace period. All resources are within free limits.',
                  {'days': days},
                )
              : tr(
                  '**{days}** remaining in grace period. After the grace period, excess agents will be stopped automatically.',
                  {'days': days},
                ),
          lines: expired
              ? const []
              : [
                  if (excess.agents > 0)
                    '${tr(_plural(excess.agents, '**{count}** agent over limit', '**{count}** agents over limit'), {'count': excess.agents})} ($agents/${limits.agents})',
                  if (excess.machines > 0)
                    '${tr(_plural(excess.machines, '**{count}** computer over limit', '**{count}** computers over limit'), {'count': excess.machines})} ($machines/${limits.machines})',
                  if (excess.channels > 0)
                    '${tr(_plural(excess.channels, '**{count}** channel over limit', '**{count}** channels over limit'), {'count': excess.channels})} ($channels/${limits.channels})',
                ],
        ),
      );
    }
    if (plan == 'free' && RaftBillingPlans.trialActive(now)) {
      notices.add(
        RaftBillingNotice(
          tone: RaftBillingNoticeTone.trial,
          title: tr('Final Trial Period'),
          body: tr(
            'Full-featured free trial remains active through {date} in every time zone. Paid plans begin after this global cutoff. All features currently unlocked — enjoy unlimited computers, agents, channels, and message history while the trial lasts.',
            {'date': RaftBillingPlans.trialCutoffDate(locale)},
          ),
        ),
      );
    }

    // ── Usage strip ──
    RaftBillingSeatUsage? seatUsage;
    final seatStats = <RaftBillingStat>[];
    if (isPro && usesUniversal) {
      // Web `billing.humansUsingSeats` / `agentsUsingSeats`: one catalog string
      // per singular/plural combination so each has a Chinese entry.
      String usingSeats(num people, bool human, num seats) {
        final values = {'count': people, 'seats': billingSeatNumber(seats)};
        final seat = seats == 1;
        return switch ((human, people == 1, seat)) {
          (true, true, true) => tr('1 human using {seats} seat', values),
          (true, true, false) => tr('1 human using {seats} seats', values),
          (true, false, true) => tr(
            '{count} humans using {seats} seat',
            values,
          ),
          (true, false, false) => tr(
            '{count} humans using {seats} seats',
            values,
          ),
          (false, true, true) => tr('1 agent using {seats} seat', values),
          (false, true, false) => tr('1 agent using {seats} seats', values),
          (false, false, true) => tr(
            '{count} agents using {seats} seat',
            values,
          ),
          (false, false, false) => tr(
            '{count} agents using {seats} seats',
            values,
          ),
        };
      }

      seatUsage = RaftBillingSeatUsage(
        label: tr('Seat'),
        value:
            '${billingSeatNumber(usedUniversal)} / ${formatLimit(universalLimit)} ${tr('used')}',
        humanPercent: pct(usedHuman),
        agentPercent: pct(usedAgent),
        humanTooltip: usingSeats(humanCount ?? 0, true, usedHuman),
        agentTooltip: usingSeats(agentCount, false, usedAgent),
        humansLabel: tr('Humans'),
        agentsLabel: tr('Agents'),
      );
    } else if (isPro) {
      if (humanCount != null) {
        seatStats.add(
          RaftBillingStat(
            tr('Humans'),
            '${humanCount.toInt()} / ${formatLimit(capacity['maxHumans'] as num?)}',
          ),
        );
      }
      seatStats.add(
        RaftBillingStat(
          tr('Agents'),
          '$agentCount / ${formatLimit(capacity['maxAgents'] as num? ?? RaftBillingPlans.proAgentSeatBlockSize)}',
        ),
      );
    }
    final quota = b?['fileUploadQuota'] is Map
        ? managementMap(b!['fileUploadQuota'])
        : null;
    final limitStats = [
      if (plan == 'free')
        RaftBillingStat(
          tr('Message History'),
          '${RaftBillingPlans.freeMessageHistoryDays} ${tr('days')}',
        ),
      if (plan == 'free' && quota != null)
        RaftBillingStat(
          tr('File uploads'),
          quota['limited'] == true
              ? '${formatBytes(quota['usedBytes'] as num?)} / ${formatBytes(quota['limitBytes'] as num?)} ${tr('this month')}'
              : '${formatBytes(RaftBillingPlans.freeMonthlyFileUploadLimitBytes)}/${tr('month')}',
        ),
    ];

    final locked = disabledReason != null || pending != null;
    return RaftPlanBillingSection(
      planName: tr(presentation.name),
      planDescription: tr(presentation.description),
      included: [for (final f in presentation.included) tr(f)],
      notIncluded: [for (final f in presentation.notIncluded) tr(f)],
      notices: notices,
      seatUsage: seatUsage,
      seatStats: seatStats,
      limitStats: limitStats,
      portalActions: controls.canOpenPortal
          ? [
              RaftBillingAction(
                actionKey: const ValueKey('billing-portal'),
                label: pending == _BillingAction.portal
                    ? tr('Opening...')
                    : tr('Billing portal'),
                tooltip: disabledReason ?? tr('Open Stripe billing portal.'),
                onPressed: locked ? null : portal,
              ),
              if (!cancelScheduled)
                RaftBillingAction(
                  actionKey: const ValueKey('billing-cancel'),
                  label: tr('Cancel subscription'),
                  tooltip:
                      disabledReason ??
                      tr('Cancel the whole Pro subscription at period end.'),
                  onPressed: locked ? null : confirmCancel,
                ),
            ]
          : null,
      compare: RaftBillingAction(
        actionKey: const ValueKey('billing-compare-plans'),
        label: tr('See all features and compare plans'),
        onPressed: () => _launch(Uri.parse(RaftBillingPlans.comparePlansUrl)),
      ),
      afterPlan:
          managementMap(b?['permissions'])['canReadBillingSummary'] == true
          ? AgentHostedSpendCard(controller: w)
          : null,
      manage: !showManage
          ? null
          : RaftBillingManagePlan(
              title: checkoutMode
                  ? tr('Upgrade to Pro')
                  : manageSeatMode
                  ? tr('Manage Seats')
                  : tr('Manage Plan'),
              checkout: checkoutMode,
              interval: checkoutMode
                  ? RaftBillingInterval(
                      title: tr('How often do you want to be billed?'),
                      label: tr('Billing interval'),
                      annual: annual,
                      monthlyLabel: tr('Monthly'),
                      yearlyLabel: tr('Yearly'),
                      saveLabel: tr('Save {percent}%', {
                        'percent':
                            RaftBillingPlans.proPackAnnualDiscountPercent,
                      }),
                      onChanged: locked
                          ? null
                          : (value) => setState(() => annual = value),
                    )
                  : null,
              intervalLine: subscription == null
                  ? null
                  : '${tr('Billing interval')}: ${cancelScheduled ? tr('{interval} · cancellation scheduled', {'interval': intervalLabel}) : intervalLabel}',
              prompt: checkoutMode
                  ? tr('Enter the number of seats to buy.')
                  : tr('Enter the total seats after this update.'),
              seatLabel: seatCopy.quantity,
              seatController: seatInput,
              seatEnabled: !controlsLocked,
              onSeatChanged: (value) {
                final parsed = int.tryParse(value);
                setState(() {
                  editingSeats = true;
                  if (parsed != null) desiredSeatOverride = parsed;
                });
              },
              onSeatCommitted: commitSeats,
              promotionLabel: checkoutMode || (manageSeatMode && seatDelta > 0)
                  ? tr('Promotion code (optional)')
                  : null,
              promotionController:
                  checkoutMode || (manageSeatMode && seatDelta > 0)
                  ? promotion
                  : null,
              onPromotionChanged: (_) => setState(() => seatPreview = null),
              promotionHint: checkoutMode
                  ? tr(
                      'Stripe checks this code at Checkout. Leave blank to enter a code there.',
                    )
                  : manageSeatMode && seatDelta > 0
                  ? tr('Enter a code approved for existing seat updates.')
                  : null,
              help: seatHelp,
              draftError: draftError,
              actions: [
                if (checkoutMode)
                  RaftBillingAction(
                    actionKey: const ValueKey('billing-upgrade'),
                    variant: RaftButtonRecipeVariant.accent,
                    label: pending == _BillingAction.checkout
                        ? tr('Opening...')
                        : tr('Upgrade to Pro'),
                    tooltip:
                        disabledReason ??
                        draftError ??
                        tr(
                          'Start {interval} Pro checkout for {seats} billable seats.',
                          {
                            'interval': annual ? tr('Yearly') : tr('Monthly'),
                            'seats': requestedSeats,
                          },
                        ),
                    onPressed:
                        disabledReason != null ||
                            draftError != null ||
                            pending != null
                        ? null
                        : confirmCheckout,
                  ),
                if (controls.canUpdatePacks)
                  RaftBillingAction(
                    actionKey: const ValueKey('billing-update-seats'),
                    variant: RaftButtonRecipeVariant.accent,
                    label: updateLabel,
                    tooltip: updateTooltip,
                    onPressed: updateDisabled ? null : confirmUpdate,
                  ),
              ],
              disabledReason: disabledReason,
              notice: billingNotice,
              error: billingError,
              summaryTitle: checkoutMode
                  ? 'Checkout summary'
                  : manageSeatMode
                  ? 'Manage seats summary'
                  : 'Subscription summary',
              summaryRows: [
                RaftBillingSummaryRow(seatCopy.summary, ['$draftSeats']),
                RaftBillingSummaryRow(seatCopy.billable, ['$draftSeats']),
                RaftBillingSummaryRow(seatCopy.capacity, [
                  humanCapacity(draftSeats),
                  agentCapacity(draftAgentSeats),
                ]),
                if (checkoutMode)
                  RaftBillingSummaryRow(totalLabel, [
                    selectedTotal,
                  ], struck: selectedOriginal),
                if (!checkoutMode && manageSeatMode) ...[
                  RaftBillingSummaryRow(tr('Current seats'), [
                    '$currentSeatQuantity',
                  ]),
                  if (seatDelta != 0)
                    RaftBillingSummaryRow(
                      seatDelta > 0
                          ? tr('Added capacity')
                          : tr('Removed capacity'),
                      [
                        humanCapacity(seatDelta.abs()),
                        agentCapacity(
                          seatDelta.abs() *
                              RaftBillingPlans.proAgentSeatBlockSize,
                        ),
                      ],
                    ),
                  if (currentTotal != null && currentTotalLabel != null)
                    RaftBillingSummaryRow(currentTotalLabel, [currentTotal]),
                  RaftBillingSummaryRow(totalLabel, [
                    selectedTotal,
                  ], struck: selectedOriginal),
                ],
              ],
              summaryFootnote: checkoutMode
                  ? null
                  : tr(
                      'Seat increases may bill immediately after Stripe confirms payment. Seat decreases apply to this subscription after Stripe confirms the change.',
                    ),
            ),
    );
  }
}
