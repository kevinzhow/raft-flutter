// Web store/billingInfo.ts (BillingInfo, GET /billing/subscription) and
// utils/billingControls.ts (getBillingControlsState), read from the wire map.
// The app only shows this: every paid action opens the Web (web_billing.dart).

num? _num(Object? v) => v is num && v.isFinite ? v : null;
Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `BillingControlsStateInput` -> `BillingControlsState`.
typedef RaftBillingControls = ({
  bool hasEntitlingSubscription,
  bool canCheckout,
  bool canUpdatePacks,
  bool canOpenPortal,
});

/// `isInternalBillingPlan`.
bool isInternalBillingPlan(String? plan) =>
    plan == 'founder' || plan == 'partner';

/// `getBillingControlsState`: prepaid Pro is renewed, never changed in Stripe
/// or put under a subscription; an AppSumo license (or one reserved for the
/// server) is managed outside Stripe.
RaftBillingControls billingControls({
  String? source,
  bool appsumoBillingReserved = false,
  String? plan,
  String? subscriptionStatus,
}) {
  final prepaid = source == 'prepaid';
  final internal =
      isInternalBillingPlan(plan) ||
      source == 'appsumo' ||
      appsumoBillingReserved;
  final entitling =
      !internal &&
      !prepaid &&
      (subscriptionStatus == 'active' || subscriptionStatus == 'past_due');
  return (
    hasEntitlingSubscription: entitling,
    canCheckout: !entitling && !internal && !prepaid,
    canUpdatePacks: entitling && plan == 'pro',
    canOpenPortal: entitling,
  );
}

/// `SubscriptionInfo`.
class BillingSubscription {
  const BillingSubscription({
    required this.status,
    required this.billingInterval,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
  });
  final String? status, billingInterval;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
}

/// `PrepaidEntitlement`: prepaid Pro time that makes the server Pro.
class BillingPrepaid {
  const BillingPrepaid({
    required this.endsAt,
    required this.graceEndsAt,
    required this.inGrace,
    required this.seatQuantity,
  });
  final DateTime endsAt, graceEndsAt;
  final bool inGrace;
  final int seatQuantity;
}

/// `BillingInfo.appsumo`.
class BillingAppsumo {
  const BillingAppsumo({
    required this.tier,
    required this.maxHumans,
    required this.maxAgents,
    required this.maxHostedJointChannels,
    required this.hostedJointChannels,
  });
  final num tier, maxHumans, maxAgents;
  final num maxHostedJointChannels, hostedJointChannels;
}

/// `BillingInfo.fileUploadQuota`.
class BillingUploadQuota {
  const BillingUploadQuota({
    required this.month,
    required this.limited,
    required this.limitBytes,
    required this.remainingBytes,
  });
  final String? month;
  final bool limited;
  final num limitBytes, remainingBytes;
}

/// `BillingInfo`: the part of GET /billing/subscription the overview reads.
class BillingInfo {
  const BillingInfo({
    required this.plan,
    required this.source,
    required this.sourceConflict,
    required this.appsumoBillingReserved,
    required this.appsumo,
    required this.prepaid,
    required this.maxUniversalSeats,
    required this.humans,
    required this.agents,
    required this.universalSeats,
    required this.provisionedHumans,
    required this.provisionedAgents,
    required this.proPackQuantity,
    required this.uploadQuota,
    required this.priceInterval,
    required this.monthlyUsd,
    required this.annualUsd,
    required this.hasPrice,
    required this.subscription,
    required this.stripeConfigured,
    required this.canReadBillingSummary,
    required this.canManageBilling,
  });

  factory BillingInfo.fromJson(Map<String, dynamic> json) {
    final capacity = _map(json['capacity']);
    final usage = _map(json['usage']);
    final provisioned = _map(json['provisioned']);
    final price = _map(json['price']);
    final quota = _map(json['fileUploadQuota']);
    final sub = _map(json['subscription']);
    final perms = _map(json['permissions']);
    final prepaid = _map(json['prepaid']);
    final appsumo = _map(json['appsumo']);
    final endsAt = _time(prepaid?['endsAt']);
    final graceEndsAt = _time(prepaid?['graceEndsAt']);
    return BillingInfo(
      plan: json['plan'] as String?,
      source: json['source'] as String?,
      sourceConflict: json['sourceConflict'] as String?,
      appsumoBillingReserved: json['appsumoBillingReserved'] == true,
      appsumo: appsumo == null
          ? null
          : BillingAppsumo(
              tier: _num(appsumo['tier']) ?? 0,
              maxHumans: _num(appsumo['maxHumans']) ?? 0,
              maxAgents: _num(appsumo['maxAgents']) ?? 0,
              maxHostedJointChannels:
                  _num(appsumo['maxHostedJointChannels']) ?? 0,
              hostedJointChannels: _num(appsumo['hostedJointChannels']) ?? 0,
            ),
      prepaid: endsAt == null || graceEndsAt == null
          ? null
          : BillingPrepaid(
              endsAt: endsAt,
              graceEndsAt: graceEndsAt,
              inGrace: prepaid?['inGrace'] == true,
              seatQuantity: _num(prepaid?['seatQuantity'])?.toInt() ?? 0,
            ),
      maxUniversalSeats: _num(capacity?['maxUniversalSeats']) ?? -1,
      humans: _num(usage?['humans']),
      agents: _num(usage?['agents']),
      universalSeats: _num(usage?['universalSeats']) ?? 0,
      provisionedHumans: _num(provisioned?['humans']) ?? 0,
      provisionedAgents: _num(provisioned?['agents']) ?? 0,
      proPackQuantity: _num(provisioned?['proPackQuantity']) ?? 0,
      uploadQuota: quota == null
          ? null
          : BillingUploadQuota(
              month: quota['month'] as String?,
              limited: quota['limited'] == true,
              limitBytes: _num(quota['limitBytes']) ?? 0,
              remainingBytes: _num(quota['remainingBytes']) ?? 0,
            ),
      priceInterval: price?['billingInterval'] as String?,
      monthlyUsd: _num(price?['monthlyUsd']),
      annualUsd: _num(price?['annualUsd']),
      hasPrice: price != null,
      subscription: sub == null
          ? null
          : BillingSubscription(
              status: sub['status'] as String?,
              billingInterval: sub['billingInterval'] as String?,
              currentPeriodEnd: _time(sub['currentPeriodEnd']),
              cancelAtPeriodEnd: sub['cancelAtPeriodEnd'] == true,
            ),
      stripeConfigured: json['stripeConfigured'] == true,
      canReadBillingSummary: perms?['canReadBillingSummary'] == true,
      canManageBilling: perms?['canManageBilling'] == true,
    );
  }

  final String? plan, source, sourceConflict;
  final bool appsumoBillingReserved;
  final BillingAppsumo? appsumo;
  final BillingPrepaid? prepaid;
  final num maxUniversalSeats;
  final num? humans, agents;
  final num universalSeats;
  final num provisionedHumans, provisionedAgents, proPackQuantity;
  final BillingUploadQuota? uploadQuota;
  final String? priceInterval;
  final num? monthlyUsd, annualUsd;
  final bool hasPrice;
  final BillingSubscription? subscription;
  final bool stripeConfigured, canReadBillingSummary, canManageBilling;
}
