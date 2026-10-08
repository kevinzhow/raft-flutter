abstract interface class WorkspaceCache {
  Future<dynamic> read(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
  );
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  );
  Future<void> revokeChannel(
    String origin,
    String principal,
    String server,
    String channel,
  );
  Future<void> clearAccount(String origin, String principal);
  Future<void> revokeServer(String origin, String principal, String server);
  Future<void> close();
}
