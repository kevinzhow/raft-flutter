/// Device cache of accepted workspace facts, keyed by origin, principal and
/// server (the account/workspace isolation boundary).
///
/// Validity rule: cached data has no age limit. It is painted immediately
/// (cold start included) and always revalidated in the background; fresher
/// facts replace it in place. It is never an authorization grant: a window
/// is adopted only under the same role and channel authority it was saved
/// with, and is dropped (screen and disk) as soon as fresher facts revoke
/// the channel, the server membership, or change the role. Message and
/// thread windows are bounded (500 rows each, least recently written
/// evicted past a per-server count). The server-scoped entity directory
/// (kind `entities`, one record per agents/members/computers) follows the
/// same rule: painted at server selection before any read, adopted only
/// under the role it was saved with and for kinds the role may view, and
/// deleted on a role/permission change, a 401/403, server revocation or
/// account clear. Message translations (Web translationStore entries, one per
/// message id, valid only for the target language and original content they
/// were requested for) are kept per server, least recently used evicted past
/// a per-server count, and deleted with their channel, server or account.
/// Logout, a rejected session and an account switch clear the account's rows.
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

  /// The saved translation entries of one account and server, most recently
  /// used first.
  Future<List<Map<String, dynamic>>> readTranslations(
    String origin,
    String principal,
    String server,
  );

  /// Saves [entries] (each with `messageId` and `channelId`) as the most
  /// recently used, replacing earlier entries of the same message.
  Future<void> writeTranslations(
    String origin,
    String principal,
    String server,
    List<Map<String, dynamic>> entries,
  );
  Future<void> revokeServer(String origin, String principal, String server);
  Future<void> close();
}
