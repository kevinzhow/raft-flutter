import 'package:intl/intl.dart';

/// Plan constants from `@botiverse/raft-shared` (raft-source 26f77ef).
abstract final class RaftBillingPlans {
  static const proSeatMonthlyUsd = 10;
  static const proSeatAnnualUsd = 105.6;
  static const proAgentSeatBlockSize = 10;
  static const proAgentSeatFraction = 1 / proAgentSeatBlockSize;
  static const proPackAnnualDiscountPercent = 12;
  static const freeMonthlyFileUploadLimitBytes = 100 * 1024 * 1024;
  static const freeMessageHistoryDays = 30;
  static const freeLimitedMaxAgents = -1;
  static const downgradeGracePeriodDays = 7;
  static final trialStart = DateTime.utc(2026, 4, 18);
  static final trialEnd = DateTime.utc(2026, 6, 23, 12);
  static const comparePlansUrl = 'https://raft.build/#pricing';

  /// `isTrialActive(now)`.
  static bool trialActive(DateTime now) =>
      !now.isBefore(trialStart) && now.isBefore(trialEnd);

  /// `formatGlobalTrialCutoffDate`: the last instant of the trial in UTC-12.
  static String trialCutoffDate(String locale) => DateFormat.yMMMd(locale)
      .format(trialEnd.subtract(const Duration(milliseconds: 1, hours: 12)));

  /// `getEffectiveLimits(plan)` for the free-plan limits DowngradeWarningCard
  /// compares against (`-1` = unlimited; the trial lifts every limit).
  static ({int agents, int machines, int channels}) freeLimits(DateTime now) =>
      (agents: -1, machines: -1, channels: -1);
}
