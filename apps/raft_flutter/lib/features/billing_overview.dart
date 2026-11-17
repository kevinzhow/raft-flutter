// Settings > Plan & Billing at Web v1.24 (PlanSectionContent): one card per
// question. The plan and when it renews; what is used; on Free, what Pro
// adds; on Pro, how it is billed; and cancelling, last. Problems with the
// subscription are banners at the top. The app only shows this: every button
// that would pay, change seats, open Stripe or cancel opens the Web Plan &
// Billing page instead ([BillingOverview.onOpenWeb]).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/billing_plans.dart';
import 'billing_overview_model.dart';
import 'billing_payment_method.dart';
import '../platform/web_billing.dart' show WebBillingGate;

class BillingOverview extends StatelessWidget {
  const BillingOverview({
    super.key,
    required this.model,
    required this.serverName,
    required this.downgradedAt,
    required this.afterUsage,
    required this.paymentMethod,
    required this.onOpenWeb,
    required this.onCompare,
    required this.onRetry,
  });

  final BillingOverviewModel model;
  final String serverName;

  /// The server's `planDowngradedAt` (null when it never went back to Free).
  final String? downgradedAt;

  /// Cloud agent spend, when the viewer may read the billing summary.
  final Widget? afterUsage;

  /// The Billing card's Payment method row, for owners.
  final BillingPaymentMethodBuilder? paymentMethod;

  /// Opens the Web page; `gate` is the paywall that sent the person there.
  final void Function({String? gate}) onOpenWeb;
  final VoidCallback onCompare, onRetry;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final b = m.billing;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String tr(String s) => raftText(context, s);
    String fmt(String s, Map<String, Object?> v) => raftFormat(context, s, v);
    String date(DateTime d) => DateFormat.yMMMd(locale).format(d.toLocal());
    String usd(num amount) => NumberFormat.simpleCurrency(
      locale: locale,
      name: 'USD',
      decimalDigits: amount == amount.truncate() ? 0 : 2,
    ).format(amount);
    String seatNumber(num v) => NumberFormat('#,##0.#', locale).format(v);
    String bytes(num v) {
      const gib = 1024 * 1024 * 1024, mib = 1024 * 1024;
      return v >= gib
          ? fmt('{value} GB', {
              'value': NumberFormat('#,##0.#', locale).format(v / gib),
            })
          : fmt('{value} MB', {
              'value': NumberFormat('#,##0', locale).format((v / mib).round()),
            });
    }

    final days = RaftBillingPlans.freeMessageHistoryDays;
    final freeUpload = bytes(RaftBillingPlans.freeMonthlyFileUploadLimitBytes);
    final periodEnd = m.periodEnd == null ? null : date(m.periodEnd!);
    final prepaid = m.prepaid;
    final prepaidEnd = prepaid == null ? null : date(prepaid.endsAt);
    final prepaidGrace = prepaid == null ? null : date(prepaid.graceEndsAt);

    // ── The plan card ──
    final planName = m.appsumo != null
        ? fmt('AppSumo Lifetime Pro · Tier {tier}', {'tier': m.appsumo!.tier})
        : switch (m.plan) {
            'pro' => tr('Pro'),
            'founder' => tr('Founder'),
            'partner' => tr('Partner'),
            _ => tr('Free'),
          };
    final price = b != null && b.hasPrice
        ? (m.annual && b.annualUsd != null
              ? fmt('{amount} a year', {'amount': usd(b.annualUsd!)})
              : fmt('{amount} a month', {'amount': usd(b.monthlyUsd ?? 0)}))
        : null;
    final String summary;
    if (m.appsumo != null) {
      summary = tr(
        'Your lifetime license is managed through AppSumo. Contact support for changes involving an existing paid subscription.',
      );
    } else if (prepaid != null && prepaidEnd != null) {
      summary = prepaid.seatQuantity == 1
          ? fmt('Paid once with Alipay · 1 seat · until {date}', {
              'date': prepaidEnd,
            })
          : fmt('Paid once with Alipay · {seats} seats · until {date}', {
              'seats': prepaid.seatQuantity,
              'date': prepaidEnd,
            });
    } else if (m.isPro &&
        m.subscription != null &&
        price != null &&
        periodEnd != null) {
      final renewal = m.ending
          ? fmt('Ends {date}', {'date': periodEnd})
          : fmt('Renews {date}', {'date': periodEnd});
      summary = m.seats == 1
          ? fmt('{price} · 1 seat · {renewal}', {
              'price': price,
              'renewal': renewal,
            })
          : fmt('{price} · {seats} seats · {renewal}', {
              'price': price,
              'seats': m.seats,
              'renewal': renewal,
            });
    } else if (m.isFree) {
      summary = fmt(
        'Messages from the last {days} days · {upload} of file uploads a month',
        {'days': days, 'upload': freeUpload},
      );
    } else {
      summary = switch (m.plan) {
        'founder' => tr('Grandfathered unlimited access.'),
        'partner' => tr('Partner access for testing and sponsored use.'),
        'pro'
            when m.billing!.provisionedHumans > 0 ||
                m.billing!.provisionedAgents > 0 =>
          m.seats == 1
              ? fmt(
                  '1 seat purchased. Each human uses 1 seat; each agent uses {fraction} seat.',
                  {'fraction': RaftBillingPlans.proAgentSeatFraction},
                )
              : fmt(
                  '{count} seats purchased. Each human uses 1 seat; each agent uses {fraction} seat.',
                  {
                    'count': m.seats,
                    'fraction': RaftBillingPlans.proAgentSeatFraction,
                  },
                ),
        'pro' => tr('For builders and teams scaling agent collaboration.'),
        _ => tr('Start building with agents.'),
      };
    }
    // A badge only says what needs a look.
    Widget? status;
    if (m.appsumo != null) {
      status = _badge(tr('Lifetime'), RaftBadgeRecipeVariant.success);
    } else if (prepaid != null && prepaid.inGrace && prepaidEnd != null) {
      status = _badge(
        fmt('Ended {date}', {'date': prepaidEnd}),
        RaftBadgeRecipeVariant.warning,
      );
    } else if (m.prepaidEndingSoon && prepaidEnd != null) {
      status = _badge(
        fmt('Ends {date}', {'date': prepaidEnd}),
        RaftBadgeRecipeVariant.muted,
      );
    } else if (m.pastDue) {
      status = _badge(tr('Payment failed'), RaftBadgeRecipeVariant.warning);
    } else if (m.ending && periodEnd != null) {
      status = _badge(
        fmt('Ends {date}', {'date': periodEnd}),
        RaftBadgeRecipeVariant.muted,
      );
    }

    // ── Banners ──
    Widget banner({
      Key? key,
      required RaftBannerRecipeStatus status,
      RaftBannerRecipeSize size = RaftBannerRecipeSize.md,
      RaftGlyph? glyph,
      String? title,
      String description = '',
      Widget Function(TextStyle)? body,
      Widget? action,
      bool live = true,
    }) => RaftBanner(
      key: key,
      status: status,
      size: size,
      glyph: glyph,
      title: title,
      description: description,
      descriptionBuilder: body,
      action: action,
      live: live,
    );
    final warn = RaftBannerRecipeStatus.warning;
    final info = RaftBannerRecipeStatus.info;
    final banners = <Widget>[
      if (b == null)
        banner(
          key: const ValueKey('billing-load-failed'),
          status: warn,
          size: RaftBannerRecipeSize.sm,
          live: false,
          title: tr("Couldn't load billing"),
          description: tr('The plan and usage below may be out of date.'),
          action: RaftButton(
            key: const ValueKey('billing-retry'),
            label: tr('Try again'),
            tone: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: onRetry,
          ),
        ),
      if (showsPlanDowngradeNotice(
        plan: m.serverPlan,
        planDowngradedAt: downgradedAt,
        now: m.now,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: RaftSpace.x4),
          child: banner(
            key: const ValueKey('billing-downgraded'),
            status: warn,
            glyph: RaftGlyph.triangleAlert,
            title: fmt('{server} is on Free now', {'server': serverName}),
            description: m.owner
                ? fmt(
                    'Messages over {days} days old are hidden. Pro features are off. Upgrade to bring them back.',
                    {'days': days},
                  )
                : fmt(
                    'Messages over {days} days old are hidden. Pro features are off.',
                    {'days': days},
                  ),
          ),
        ),
      if (b != null && b.appsumoBillingReserved && m.appsumo == null)
        banner(
          status: info,
          description: tr(
            'Your AppSumo license is being verified. Stripe purchases are unavailable until its status is confirmed. If this persists, contact support.',
          ),
        ),
      if (b != null &&
          b.sourceConflict == 'appsumo_stripe' &&
          b.subscription != null)
        banner(
          status: warn,
          description: '',
          body: (style) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(switch (b.subscription!.status) {
                  'active' => 'A Stripe subscription also exists alongside this AppSumo license (Stripe status: Active). Contact support to resolve the billing sources. Raft does not cancel the Stripe subscription automatically.',
                  'past_due' => 'A Stripe subscription also exists alongside this AppSumo license (Stripe status: Past due). Contact support to resolve the billing sources. Raft does not cancel the Stripe subscription automatically.',
                  _ => 'A Stripe subscription also exists alongside this AppSumo license (Stripe status: Unknown). Contact support to resolve the billing sources. Raft does not cancel the Stripe subscription automatically.',
                }),
                style: style,
              ),
              if (b.subscription!.cancelAtPeriodEnd)
                Text(
                  tr(
                    'Subscription cancellation scheduled for the end of the current billing period.',
                  ),
                  style: style,
                ),
              if (b.subscription!.currentPeriodEnd != null)
                Text(
                  fmt('Stripe current period ends {date}.', {
                    'date': date(b.subscription!.currentPeriodEnd!),
                  }),
                  style: style,
                ),
            ],
          ),
        ),
      if (m.isPro && m.pastDue)
        banner(
          key: const ValueKey('billing-past-due'),
          status: warn,
          glyph: RaftGlyph.triangleAlert,
          live: false,
          title: tr('Payment failed'),
          description: m.owner
              ? tr(
                  "Stripe couldn't charge the card on this subscription. Update the payment method in Stripe to keep Pro.",
                )
              : tr(
                  "Stripe couldn't charge the card on this subscription. An owner needs to update the payment method to keep Pro.",
                ),
          action: m.showPortal
              ? _webButton(
                  context,
                  key: const ValueKey('billing-past-due-action'),
                  label: tr('Update payment method'),
                  tone: RaftButtonRecipeVariant.outline,
                  disabled: m.stripeOff,
                  onPressed: () => onOpenWeb(),
                )
              : null,
        ),
      if (m.isPro && m.ending && !m.pastDue && periodEnd != null)
        banner(
          key: const ValueKey('billing-ending'),
          status: info,
          glyph: RaftGlyph.info,
          live: false,
          title: fmt('Pro ends on {date}', {'date': periodEnd}),
          description: fmt(
            'After that, this server moves to Free: messages older than {days} days are hidden and file uploads are limited to {upload} a month.',
            {'days': days, 'upload': freeUpload},
          ),
          action: m.owner
              ? RaftButton(
                  key: const ValueKey('billing-keep-pro'),
                  label: tr('Keep Pro'),
                  tone: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.md,
                  disabled: m.stripeOff,
                  onPressed: () => onOpenWeb(),
                )
              : null,
        ),
      if (prepaid != null &&
          m.prepaidBanner &&
          prepaidEnd != null &&
          prepaidGrace != null)
        banner(
          key: ValueKey(
            prepaid.inGrace
                ? 'billing-prepaid-grace'
                : 'billing-prepaid-ending',
          ),
          status: prepaid.inGrace ? warn : info,
          glyph: prepaid.inGrace ? RaftGlyph.triangleAlert : RaftGlyph.info,
          live: false,
          title: fmt(
            prepaid.inGrace
                ? 'Prepaid Pro ended on {date}'
                : 'Pro ends on {date}',
            {'date': prepaidEnd},
          ),
          // "Renew" only where renewing is open: the owner's button, or an
          // owner to ask.
          description: prepaid.inGrace
              ? fmt(
                  !m.prepaidEnabled
                      ? 'Pro stays on until {date}; after that this server moves to Free.'
                      : m.owner
                      ? 'Pro stays on until {date}. Renew to keep it; after that this server moves to Free.'
                      : 'Pro stays on until {date}. An owner can renew it; after that this server moves to Free.',
                  {'date': prepaidGrace},
                )
              : tr(
                  !m.prepaidEnabled
                      ? "Prepaid Pro doesn't renew on its own."
                      : m.owner
                      ? "Prepaid Pro doesn't renew on its own. Renew to keep Pro without a break."
                      : "Prepaid Pro doesn't renew on its own. An owner can renew it.",
                ),
          action: m.canRenew
              ? RaftButton(
                  key: const ValueKey('billing-prepaid-banner-renew'),
                  label: tr('Renew'),
                  tone: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.md,
                  disabled: m.stripeOff,
                  onPressed: () => onOpenWeb(),
                )
              : null,
        ),
    ];

    // ── Cards ──
    final planActions = <Widget>[
      if (m.canRenew && !m.prepaidBanner)
        RaftButton(
          key: const ValueKey('billing-prepaid-renew'),
          label: tr('Renew'),
          tone: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.md,
          disabled: m.stripeOff,
          onPressed: () => onOpenWeb(),
        ),
      if (m.canAddSeats)
        RaftButton(
          key: const ValueKey('billing-add-seats'),
          label: tr('Add seats'),
          tone: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.md,
          disabled: m.stripeOff,
          onPressed: () => onOpenWeb(),
        ),
      if (m.canAddPrepaidSeats)
        RaftButton(
          key: const ValueKey('billing-prepaid-add-seats'),
          label: tr('Add seats'),
          tone: RaftButtonRecipeVariant.outline,
          size: RaftButtonRecipeSize.md,
          disabled: m.stripeOff,
          onPressed: () => onOpenWeb(),
        ),
      if (m.showPortal)
        _webButton(
          context,
          key: const ValueKey('billing-manage-stripe'),
          label: tr('Manage in Stripe'),
          tone: RaftButtonRecipeVariant.outline,
          disabled: m.stripeOff,
          onPressed: () => onOpenWeb(),
        ),
    ];
    final planCard = _BillingCard(
      key: const ValueKey('billing-current-plan-card'),
      title: planName,
      headline: true,
      trailing: status,
      description: m.appsumo != null ? summary : null,
      content: [
        if (m.appsumo == null)
          _summaryText(
            context,
            summary,
            key: const ValueKey('billing-current-plan-summary'),
          ),
        if (m.appsumo == null && planActions.isNotEmpty)
          const SizedBox(height: RaftSpace.x3),
        if (planActions.isNotEmpty)
          Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: planActions,
          ),
      ],
    );

    final seatMeter = m.universalSeatMeter
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftMeter(
                key: const ValueKey('billing-seat-meter'),
                label: tr('Seats'),
                used: m.usedSeats,
                max: m.seatCapacity < 0.0001 ? 0.0001 : m.seatCapacity,
                valueText: fmt('{used} of {total} used', {
                  'used': seatNumber(m.usedSeats),
                  'total': seatNumber(m.seatCapacity),
                }),
              ),
              const SizedBox(height: RaftSpace.x2),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: RaftSpace.x6,
                runSpacing: RaftSpace.x2,
                children: [
                  RaftDescriptionList(
                    inline: true,
                    entries: [
                      RaftDescriptionEntry(
                        tr('People'),
                        _countSeats(context, m.humans, m.humans, seatNumber),
                      ),
                      RaftDescriptionEntry(
                        tr('Agents'),
                        _countSeats(
                          context,
                          m.agents,
                          m.agents * RaftBillingPlans.proAgentSeatFraction,
                          seatNumber,
                        ),
                      ),
                    ],
                  ),
                  if (m.canRemoveSeats)
                    RaftTextLink(
                      key: const ValueKey('billing-manage-seats'),
                      label: tr('Manage seats'),
                      variant: RaftTextLinkVariant.muted,
                      scale: RaftTypeScale.footnote,
                      onPressed: () => onOpenWeb(),
                    ),
                ],
              ),
            ],
          )
        : null;
    RaftMeter allowance(String label, num used, num max) => RaftMeter(
      label: label,
      used: used,
      max: max < 0.0001 ? 0.0001 : max,
      valueText: fmt('{used} of {total} used', {
        'used': NumberFormat.decimalPattern(locale).format(used),
        'total': NumberFormat.decimalPattern(locale).format(max),
      }),
    );
    final quota = m.uploadQuota;
    final month = quota?.month;
    final resets =
        quota != null &&
            month != null &&
            RegExp(r'^\d{4}-\d{2}$').hasMatch(month)
        ? DateFormat.MMMd(locale).format(
            DateTime.utc(
              int.parse(month.substring(0, 4)),
              int.parse(month.substring(5)) + 1,
            ),
          )
        : null;
    final usageChildren = <Widget>[
      ?seatMeter,
      if (m.appsumo != null) ...[
        allowance(tr('People'), m.humans, m.appsumo!.maxHumans),
        allowance(tr('Agents'), m.agents, m.appsumo!.maxAgents),
        allowance(
          tr('External channels you host'),
          m.appsumo!.hostedJointChannels,
          m.appsumo!.maxHostedJointChannels,
        ),
      ],
      if ((m.isFree || m.appsumo != null) && quota != null)
        RaftMeter(
          key: const ValueKey('billing-upload-meter'),
          label: tr('File uploads this month'),
          used: m.uploadUsed,
          max: quota.limitBytes,
          valueText: resets != null
              ? quota.remainingBytes <= 0
                    ? fmt('Used up · resets {date}', {'date': resets})
                    : fmt('{used} of {limit} used · resets {date}', {
                        'used': bytes(m.uploadUsed),
                        'limit': bytes(quota.limitBytes),
                        'date': resets,
                      })
              : fmt('{used} of {total} used', {
                  'used': bytes(m.uploadUsed),
                  'total': bytes(quota.limitBytes),
                }),
        ),
      // Free, and any plan without a seat count (founder, partner, or
      // billing that came back partial).
      if (!m.universalSeatMeter &&
          m.appsumo == null &&
          (m.plan == 'free' || b != null))
        RaftDescriptionList(
          entries: [
            if (m.plan == 'free')
              RaftDescriptionEntry(
                tr('Message history'),
                fmt(
                  'Last {days} days. Older messages are hidden until the server is on Pro.',
                  {'days': days},
                ),
              ),
            // Who is on the server comes with billing: without it, no count
            // rather than a wrong one.
            if (b != null)
              RaftDescriptionEntry(
                tr('Members'),
                _members(context, m.humans, m.agents),
              ),
          ],
        ),
    ];
    final usageCard = _BillingCard(
      key: const ValueKey('billing-usage-card'),
      title: tr('Usage'),
      content: [
        for (var i = 0; i < usageChildren.length; i++) ...[
          if (i > 0) const SizedBox(height: RaftSpace.x5),
          usageChildren[i],
        ],
      ],
    );

    final upgradeCard = m.isFree && b != null && m.controls.canCheckout
        ? _BillingCard(
            key: const ValueKey('billing-upgrade-card'),
            title: tr('Upgrade to Pro'),
            content: [
              _summaryText(
                context,
                m.neededSeats == 1
                    ? fmt(
                        '{monthly} per seat a month, or {annual} a month billed yearly. Each person takes 1 seat and each agent 0.1; this server needs 1 seat today.',
                        _upgradePrices(usd),
                      )
                    : fmt(
                        '{monthly} per seat a month, or {annual} a month billed yearly. Each person takes 1 seat and each agent 0.1; this server needs {seats} seats today.',
                        {..._upgradePrices(usd), 'seats': m.neededSeats},
                      ),
                key: const ValueKey('billing-upgrade-price'),
              ),
              const SizedBox(height: RaftSpace.x4),
              _ProAdds(
                items: [
                  tr('Unlimited message history'),
                  tr('Higher file upload limits'),
                  tr('Agent migration'),
                  tr('Use external channels'),
                ],
              ),
              const SizedBox(height: RaftSpace.x4),
              Wrap(
                spacing: RaftSpace.x2,
                runSpacing: RaftSpace.x2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RaftButton(
                    key: const ValueKey('billing-upgrade'),
                    label: m.owner
                        ? tr('Upgrade to Pro')
                        : tr('Ask an owner to upgrade'),
                    tone: RaftButtonRecipeVariant.accent,
                    size: RaftButtonRecipeSize.md,
                    disabled: !b.stripeConfigured,
                    onPressed: () => onOpenWeb(gate: WebBillingGate.general),
                  ),
                  _webButton(
                    context,
                    key: const ValueKey('billing-compare-plans'),
                    label: tr('Compare plans'),
                    tone: RaftButtonRecipeVariant.ghost,
                    onPressed: onCompare,
                  ),
                ],
              ),
              if (!b.stripeConfigured) ...[
                const SizedBox(height: RaftSpace.x4),
                RaftCssText(
                  tr('Paid plans are not available yet.'),
                  style: RaftTokens.of(context).scale(
                    RaftTypeScale.caption,
                    color: RaftTokens.of(context).ui.foregroundHint,
                  ),
                ),
              ],
            ],
          )
        : null;

    final billedCard = m.isPro && m.subscription != null
        ? _BillingCard(
            key: const ValueKey('billing-details-card'),
            title: tr('Billing'),
            content: [
              () {
                final before = [
                  RaftDescriptionEntry(
                    tr('Billed'),
                    m.annual ? tr('Yearly') : tr('Monthly'),
                  ),
                  if (periodEnd != null)
                    RaftDescriptionEntry(
                      m.ending ? tr('Last day of Pro') : tr('Renews'),
                      periodEnd,
                    ),
                ];
                final after = [
                  RaftDescriptionEntry(
                    tr('Seats'),
                    m.seats == 1
                        ? tr('1 seat')
                        : fmt('{count} seats', {'count': m.seats}),
                  ),
                ];
                return m.owner && paymentMethod != null
                    ? paymentMethod!(before, after)
                    : RaftDescriptionList(entries: [...before, ...after]);
              }(),
            ],
            footer: m.owner
                ? tr('Invoices, receipts and the payment method are in Stripe.')
                : tr('Only server owners can change billing or see invoices.'),
          )
        : null;

    final cancelCard =
        m.isPro &&
            m.subscription != null &&
            m.owner &&
            !m.ending &&
            periodEnd != null
        ? _BillingCard(
            key: const ValueKey('billing-cancel-card'),
            title: tr('Cancel subscription'),
            description: fmt(
              'Pro stays until {date}. After that, this server moves to Free: messages older than {days} days are hidden and file uploads are limited to {upload} a month.',
              {'date': periodEnd, 'days': days, 'upload': freeUpload},
            ),
            content: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: RaftButton(
                  key: const ValueKey('billing-cancel'),
                  label: tr('Cancel subscription'),
                  tone: RaftButtonRecipeVariant.warning,
                  size: RaftButtonRecipeSize.md,
                  disabled: m.stripeOff,
                  onPressed: () => onOpenWeb(),
                ),
              ),
            ],
          )
        : null;

    final cards = <Widget>[
      ...banners,
      planCard,
      usageCard,
      ?afterUsage,
      ?upgradeCard,
      ?billedCard,
      ?cancelCard,
    ];
    return Padding(
      key: const ValueKey('billing-overview'),
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: RaftSpace.x4),
            cards[i],
          ],
        ],
      ),
    );
  }

  static Map<String, Object?> _upgradePrices(String Function(num) usd) => {
    'monthly': usd(RaftBillingPlans.proSeatMonthlyUsd),
    'annual': usd((RaftBillingPlans.proSeatAnnualUsd / 12 * 100).round() / 100),
  };

  RaftBadge _badge(String label, RaftBadgeRecipeVariant variant) => RaftBadge(
    label: label,
    appearance: RaftBadgeRecipeAppearance.soft,
    variant: variant,
  );

  /// A button whose label ends in the leaving-Raft mark (Web LeavingRaftMark):
  /// it opens the Web in the browser.
  Widget _webButton(
    BuildContext context, {
    required Key key,
    required String label,
    required RaftButtonRecipeVariant tone,
    required VoidCallback onPressed,
    bool disabled = false,
  }) => RaftButton(
    key: key,
    label: label,
    semanticLabel: '$label ${raftText(context, '(opens in a new tab)')}',
    trailingGlyph: RaftGlyph.arrowUpRight,
    tone: tone,
    size: RaftButtonRecipeSize.md,
    disabled: disabled,
    onPressed: onPressed,
  );

  Widget _summaryText(BuildContext context, String text, {Key? key}) {
    final t = RaftTokens.of(context);
    return RaftCssText(
      text,
      key: key,
      style: t.scale(RaftTypeScale.callout, color: t.ui.foreground),
    );
  }

  /// `planBilling.usage.countSeats`: "{count} · {seats} seat(s)".
  String _countSeats(
    BuildContext context,
    num count,
    num seats,
    String Function(num) seatNumber,
  ) => raftFormat(
    context,
    seats == 1 ? '{count} · {seats} seat' : '{count} · {seats} seats',
    {'count': count, 'seats': seatNumber(seats)},
  );

  /// `planBilling.usage.membersValue`: "{people} · {agents}" with each count
  /// pluralised in its own catalog string.
  String _members(BuildContext context, num people, num agents) {
    final one = people == 1, oneAgent = agents == 1;
    final source = one
        ? (oneAgent ? '1 person · 1 agent' : '1 person · {agents} agents')
        : (oneAgent
              ? '{people} people · 1 agent'
              : '{people} people · {agents} agents');
    return raftFormat(context, source, {'people': people, 'agents': agents});
  }
}

/// One of Plan & Billing's cards: header (title, trailing badge, description),
/// body and footer, as raft-ui `Card` parts.
class _BillingCard extends StatelessWidget {
  const _BillingCard({
    super.key,
    required this.title,
    this.headline = false,
    this.trailing,
    this.description,
    this.content = const [],
    this.footer,
  });
  final String title;

  /// The plan card's title is the plan's name (`text-headline`).
  final bool headline;
  final Widget? trailing;
  final String? description;
  final List<Widget> content;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final titleStyle = headline
        ? t.scale(
            RaftTypeScale.headline,
            weight: FontWeight.w600,
            color: t.ui.foreground,
          )
        : null;
    return RaftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftCardSectionHeader(
            aboveContent: content.isNotEmpty,
            title: RaftCardTitle(
              Semantics(
                header: true,
                child: titleStyle == null
                    ? Text(title)
                    : RaftCssText(title, style: titleStyle),
              ),
            ),
            trailing: trailing == null ? null : RaftCardTrailing(trailing!),
            description: description == null
                ? null
                : RaftCardDescription(Text(description!)),
          ),
          if (content.isNotEmpty)
            RaftCardContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: content,
              ),
            ),
          if (footer != null) RaftCardFooter(children: [Text(footer!)]),
        ],
      ),
    );
  }
}

/// What Pro adds over Free: a check and a line each, two columns when wide.
class _ProAdds extends StatelessWidget {
  const _ProAdds({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = t.scale(RaftTypeScale.callout, color: t.ui.foreground);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 480;
        final width = wide ? (box.maxWidth - 24) / 2 : box.maxWidth;
        return Wrap(
          spacing: RaftSpace.x6,
          runSpacing: RaftSpace.x2,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: RaftSpace.half),
                      child: RaftIcon(
                        RaftGlyph.check,
                        size: 16,
                        color: t.colors['success-strong'],
                      ),
                    ),
                    const SizedBox(width: RaftSpace.x2),
                    Expanded(child: RaftCssText(item, style: style)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
