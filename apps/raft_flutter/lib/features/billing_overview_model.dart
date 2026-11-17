// What Web v1.24 PlanSectionContent decides before it draws: which plan this
// is, who may change billing, which banners and cards show and which buttons
// they carry. Pure (no widgets, no requests), so the page and its tests read
// the same conditions the Web does.
import 'dart:math' as math;

import '../data/billing_info.dart';

/// Web `PREPAID_REMINDER_DAYS`.
const prepaidReminderDays = 7;

/// Web `DOWNGRADE_GRACE_PERIOD_DAYS` (utils/planDowngrade.ts).
const downgradeNoticeDays = 7;

/// Web `showsPlanDowngradeNotice`: a server that went back to Free tells its
/// people for a week. An unreadable timestamp is no notice.
bool showsPlanDowngradeNotice({
  required String? plan,
  required String? planDowngradedAt,
  required DateTime now,
}) {
  if (plan != 'free' || planDowngradedAt == null) return false;
  final at = DateTime.tryParse(planDowngradedAt);
  return at != null &&
      now.isBefore(at.add(const Duration(days: downgradeNoticeDays)));
}

class BillingOverviewModel {
  BillingOverviewModel({
    required this.serverPlan,
    required this.billing,
    required this.usageAgents,
    required this.now,
    required this.prepaidEnabled,
  }) : plan = (billing?.plan ?? serverPlan).isEmpty
           ? 'free'
           : (billing?.plan ?? serverPlan),
       owner = billing?.canManageBilling == true {
    final b = billing;
    appsumo = b?.appsumo;
    controls = billingControls(
      source: b?.source,
      appsumoBillingReserved: b?.appsumoBillingReserved ?? false,
      plan: plan,
      subscriptionStatus: b?.subscription?.status,
    );
    isFree = plan == 'free' && appsumo == null;
    isPro = plan == 'pro' && appsumo == null;
    subscription = controls.hasEntitlingSubscription ? b?.subscription : null;
    pastDue = subscription?.status == 'past_due';
    ending = subscription?.cancelAtPeriodEnd == true;
    periodEnd = subscription?.currentPeriodEnd;
    annual = (subscription?.billingInterval ?? b?.priceInterval) == 'annual';
    seats = math.max(0, (b?.proPackQuantity ?? 0).toInt());
    usedSeats = math.max<num>(0, b?.universalSeats ?? 0);
    neededSeats = math.max(1, usedSeats.ceil());
    humans = b?.humans ?? 0;
    agents = b?.agents ?? usageAgents ?? 0;
    // Why the buttons that change billing are off: no Stripe on this server.
    stripeOff = !(b?.stripeConfigured ?? false);
    prepaid = b?.source == 'prepaid' ? b?.prepaid : null;
    prepaidEndingSoon =
        prepaid != null &&
        !prepaid!.inGrace &&
        prepaid!.endsAt.difference(now) <=
            const Duration(days: prepaidReminderDays);
    canRenew = owner && prepaid != null && prepaidEnabled;
    canAddPrepaidSeats = canRenew && !(prepaid?.inGrace ?? false);
    prepaidBanner = prepaid != null && (prepaid!.inGrace || prepaidEndingSoon);
    // Seats are added from here only on a subscription that is paid up and
    // renewing: adding to one being cancelled would quietly take the
    // cancellation back.
    canAddSeats = owner && controls.canUpdatePacks && !pastDue && !ending;
    canRemoveSeats = canAddSeats && seats > neededSeats;
    showPortal = owner && controls.canOpenPortal;
    final q = b?.uploadQuota;
    uploadQuota = q != null && q.limited && q.limitBytes > 0 ? q : null;
    uploadUsed = uploadQuota == null
        ? 0
        : math.min<num>(
            uploadQuota!.limitBytes,
            math.max<num>(
              0,
              uploadQuota!.limitBytes -
                  math.max<num>(0, uploadQuota!.remainingBytes),
            ),
          );
    universalSeatMeter = isPro && (b?.maxUniversalSeats ?? -1) != -1;
    seatCapacity = math.max<num>(0, b?.maxUniversalSeats ?? 0);
  }

  final String serverPlan;
  final BillingInfo? billing;
  final num? usageAgents;
  final DateTime now;
  final bool prepaidEnabled;
  final String plan;
  final bool owner;

  late final BillingAppsumo? appsumo;
  late final RaftBillingControls controls;
  late final bool isFree, isPro, pastDue, ending, annual, stripeOff;
  late final BillingSubscription? subscription;
  late final DateTime? periodEnd;
  late final int seats, neededSeats;
  late final num usedSeats, humans, agents;
  late final BillingPrepaid? prepaid;
  late final bool prepaidEndingSoon, canRenew, canAddPrepaidSeats;
  late final bool prepaidBanner, canAddSeats, canRemoveSeats, showPortal;
  late final BillingUploadQuota? uploadQuota;
  late final num uploadUsed;
  late final bool universalSeatMeter;
  late final num seatCapacity;
}
