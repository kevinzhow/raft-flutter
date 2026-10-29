/// The device-history limit covers one account across all its servers.
class HistoryAccount {
  const HistoryAccount(this.origin, this.principal);
  final String origin, principal;
  @override
  bool operator ==(Object other) =>
      other is HistoryAccount &&
      origin == other.origin &&
      principal == other.principal;
  @override
  int get hashCode => Object.hash(origin, principal);
}

const historyBudgetTiers = [512 << 20, 1 << 30, 2 << 30, 5 << 30, 0];

/// A zero limit means keep all, subject to available device space.
class HistoryDiskUsage {
  const HistoryDiskUsage({
    required this.budget,
    required this.accountBytes,
    required this.databaseBytes,
    required this.walBytes,
    required this.indexBytes,
    required this.freeBytes,
    required this.rows,
    required this.pendingCompaction,
    this.reclaimableAccountBytes = 0,
    this.reservedWalBytes = 0,
    this.protectedFull = false,
    this.hardFull = false,
  });
  final int budget,
      accountBytes,
      databaseBytes,
      walBytes,
      indexBytes,
      freeBytes,
      rows,
      reservedWalBytes;
  final int reclaimableAccountBytes;
  final bool pendingCompaction, protectedFull, hardFull;
  int get budgetCharge => accountBytes + reservedWalBytes;
  int get retainedCharge => budgetCharge - reclaimableAccountBytes;
  bool get overBudget => budget != 0 && budgetCharge > budget;

  HistoryDiskUsage withProtectedFull(bool value, {bool? hardFull}) =>
      HistoryDiskUsage(
        budget: budget,
        accountBytes: accountBytes,
        databaseBytes: databaseBytes,
        walBytes: walBytes,
        indexBytes: indexBytes,
        freeBytes: freeBytes,
        rows: rows,
        pendingCompaction: pendingCompaction,
        reservedWalBytes: reservedWalBytes,
        reclaimableAccountBytes: reclaimableAccountBytes,
        protectedFull: value,
        hardFull: hardFull ?? this.hardFull,
      );
}

/// Bodies currently needed by a reader or an unconfirmed local operation.
class HistoryProtectedRows {
  HistoryProtectedRows(
    this.account,
    this.server,
    this.channel,
    Iterable<String> ids, {
    this.wholeChannel = false,
  }) : ids = Set.unmodifiable(ids);
  final HistoryAccount account;
  final String server, channel;
  final Set<String> ids;
  final bool wholeChannel;
}

/// Existing readable data and drafts remain when no eligible body can be freed.
class HistoryCapacityExceeded implements Exception {
  const HistoryCapacityExceeded();
}

class HistoryCompactionPlan {
  const HistoryCompactionPlan({
    required this.fullVacuum,
    this.requiredBytes = 0,
    this.availableBytes,
  });
  final bool fullVacuum;
  final int requiredBytes;
  final int? availableBytes;
  bool get enoughSpace =>
      !fullVacuum || availableBytes != null && availableBytes! >= requiredBytes;
}

class HistoryCompactionNeedsConfirmation implements Exception {
  const HistoryCompactionNeedsConfirmation();
}

class HistoryCompactionSpaceRequired implements Exception {
  const HistoryCompactionSpaceRequired(this.plan);
  final HistoryCompactionPlan plan;
}

abstract interface class HistoryCapacity {
  Future<HistoryDiskUsage> usage(HistoryAccount account);
  Future<void> setBudget(HistoryAccount account, int bytes);
  Future<void> opened(HistoryAccount account, String server, String channel);
  Future<bool> isKept(HistoryAccount account, String server, String channel);
  Future<void> keep(
    HistoryAccount account,
    String server,
    String channel,
    bool value,
  );
  void protect(Object owner, Iterable<HistoryProtectedRows> Function() current);
  void release(Object owner);
  Future<HistoryCompactionPlan> compactionPlan(HistoryAccount account);
  Future<HistoryDiskUsage> maintain(
    HistoryAccount account, {
    bool compact = false,
    bool allowFullVacuum = false,
  });
}
