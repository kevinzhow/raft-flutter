/// The Raft server's per-route rate limits, mirrored from
/// `packages/server/src/app.ts` at v1.24.0-source.1 (express-rate-limit; most
/// use the in-memory store, so each server replica counts on its own, the
/// message limiter is counted across replicas).
///
/// The client uses this table to (a) pace its own background requests below a
/// limit with headroom, (b) classify a 429 into the bucket it came from and
/// (c) let the request meter and the budget test compare traffic with the
/// limits. A response's `RateLimit-*` headers refine it at run time; the table
/// is only the starting point.
library;

/// One server limiter.
class ServerRateLimit {
  const ServerRateLimit(
    this.id, {
    required this.max,
    required this.window,
    required this.key,
    required this.note,
  });

  /// Stable bucket id (also the request meter's grouping key).
  final String id;

  /// Requests allowed per [window] per [key].
  final int max;
  final Duration window;

  /// What the server counts by: `user`, `ip` or `user-or-ip`.
  final String key;
  final String note;

  /// Requests per minute the limit allows.
  double get perMinute => max * 60000 / window.inMilliseconds;
}

abstract final class ServerRateLimits {
  /// `downloadLimiter`: every request under `/api/attachments` (the batch
  /// `POST /urls`, `GET /:id/url`, `/preview`, `/html-preview-url`, the
  /// streamed bytes of local storage, and also comment reads) is counted
  /// before the router picks a handler, per user.
  static const attachments = ServerRateLimit(
    'attachments',
    max: 120,
    window: Duration(minutes: 1),
    key: 'user',
    note: 'downloadLimiter, all /api/attachments requests',
  );

  /// `messageLimiter`: non-GET `/api/messages`, `/api/v2/messages`,
  /// `/api/tasks`, `POST /api/channels/:id/threads` and
  /// `POST /api/attachments/:id/comments`. 120 a minute since v1.24 (60
  /// before), counted across replicas.
  static const messages = ServerRateLimit(
    'messages',
    max: 120,
    window: Duration(minutes: 1),
    key: 'user-or-ip',
    note: 'messageLimiter, writes only (GET skipped), across replicas',
  );

  /// `uploadLimiter`: non-GET `/api/attachments` writes.
  static const uploads = ServerRateLimit(
    'uploads',
    max: 10,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'uploadLimiter',
  );

  /// `directUploadLimiter`: creating a direct upload session.
  static const uploadSessions = ServerRateLimit(
    'upload-sessions',
    max: 10,
    window: Duration(minutes: 1),
    key: 'user',
    note: 'directUploadLimiter',
  );

  /// `authLimiter`: `/api/auth/*` (login, refresh, me, logout, device,
  /// second-factor, ...; not invite-info / accept-invite), `/api/public`,
  /// `/api/app-installation`, `/api/release-notes`, `/api/mobile-download`,
  /// `/api/desktop-download`, `/api/computer`, `/api/oauth`, `/api/invites`,
  /// `/api/external-invites`, `/api/server-connect-requests`,
  /// `/api/me/account/deletion`, `/api/mcp/oauth`, `/api/connections`,
  /// `/api/appsumo`.
  static const auth = ServerRateLimit(
    'auth',
    max: 200,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'authLimiter, shared by every client behind one IP',
  );

  static const translation = ServerRateLimit(
    'translation',
    max: 120,
    window: Duration(minutes: 1),
    key: 'user',
    note: 'translationLimiter, POST /message-translations:batch',
  );

  static const productEvents = ServerRateLimit(
    'product-events',
    max: 60,
    window: Duration(minutes: 1),
    key: 'user',
    note: 'productEventsLimiter',
  );

  static const billing = ServerRateLimit(
    'billing',
    max: 5,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'billingLimiter, writes only, not the seat previews',
  );

  /// `billingPreviewLimiter`: `POST /api/billing/(seat-)pack-quantity/preview`
  /// (v1.24; the previews counted against [billing] before).
  static const billingPreview = ServerRateLimit(
    'billing-preview',
    max: 30,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'billingPreviewLimiter, seat-quantity previews',
  );

  /// `inviteFlowLimiter`: invite preview / accept and the invite routers.
  static const inviteFlow = ServerRateLimit(
    'invite-flow',
    max: 120,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'inviteFlowLimiter',
  );

  /// `searchLimiter` (`/api/search`), `objectSummariesLimiter`
  /// (`/api/objects`) and `mentionAudienceLimiter` (`/api/mentions`), v1.24.
  static const search = ServerRateLimit(
    'search',
    max: 300,
    window: Duration(minutes: 1),
    key: 'user-or-ip',
    note: 'searchLimiter, /api/search',
  );
  static const objectSummaries = ServerRateLimit(
    'object-summaries',
    max: 300,
    window: Duration(minutes: 1),
    key: 'user-or-ip',
    note: 'objectSummariesLimiter, /api/objects',
  );
  static const mentionAudience = ServerRateLimit(
    'mention-audience',
    max: 300,
    window: Duration(minutes: 1),
    key: 'user-or-ip',
    note: 'mentionAudienceLimiter, /api/mentions',
  );

  static const feedback = ServerRateLimit(
    'feedback',
    max: 10,
    window: Duration(hours: 1),
    key: 'user',
    note: 'productFeedbackLimiter, writes only',
  );

  static const forgotPassword = ServerRateLimit(
    'forgot-password',
    max: 5,
    window: Duration(hours: 1),
    key: 'ip',
    note: 'forgotPasswordLimiter',
  );

  static const all = <ServerRateLimit>[
    attachments,
    messages,
    uploads,
    uploadSessions,
    auth,
    translation,
    productEvents,
    billing,
    billingPreview,
    inviteFlow,
    search,
    objectSummaries,
    mentionAudience,
    feedback,
    forgotPassword,
  ];

  static ServerRateLimit? byId(String id) {
    for (final limit in all) {
      if (limit.id == id) return limit;
    }
    return null;
  }

  /// The limiters a request counts against. [path] is relative to `/api`
  /// (`/attachments/urls`), without a query. Most reads count against none.
  static List<ServerRateLimit> forRequest(String method, String path) {
    final m = method.toUpperCase();
    final write = m != 'GET' && m != 'HEAD' && m != 'OPTIONS';
    final bare = path.split('?').first;
    final p = bare.startsWith('/') ? bare : '/$bare';
    bool under(String prefix) => p == prefix || p.startsWith('$prefix/');
    if (under('/attachments')) {
      final comment = RegExp(r'^/attachments/[^/]+/comments$').hasMatch(p);
      return [
        attachments,
        if (write && comment) messages,
        if (write &&
            !comment &&
            p != '/attachments/urls' &&
            !p.startsWith('/attachments/upload-sessions'))
          uploads,
        if (write && m == 'POST' && p == '/attachments/upload-sessions')
          uploadSessions,
      ];
    }
    if (under('/messages') || under('/v2/messages') || under('/tasks')) {
      return [if (write) messages];
    }
    if (m == 'POST' && RegExp(r'^/channels/[^/]+/threads/?$').hasMatch(p)) {
      return [messages];
    }
    if (p.startsWith('/message-translations')) return [translation];
    if (under('/product-events')) return [productEvents];
    if (under('/billing')) {
      final preview = RegExp(r'^/billing/(?:seat-)?pack-quantity/preview/?$')
          .hasMatch(p);
      return [if (write) preview ? billingPreview : billing];
    }
    if (under('/search')) return [search];
    if (under('/objects')) return [objectSummaries];
    if (under('/mentions')) return [mentionAudience];
    if (p == '/auth/invite-info' || p == '/auth/accept-invite') {
      return [inviteFlow];
    }
    if (under('/invites') ||
        under('/external-invites') ||
        under('/server-connect-requests')) {
      return [inviteFlow, auth];
    }
    if (under('/product-feedback')) return [if (write) feedback];
    // v1.24: the retired share-artifacts create route (410) has no limiter.
    if (p == '/auth/forgot-password') return [forgotPassword, auth];
    if (under('/auth') ||
        under('/public') ||
        under('/app-installation') ||
        under('/release-notes') ||
        under('/mobile-download') ||
        under('/desktop-download') ||
        under('/oauth') ||
        under('/computer') ||
        under('/me/account/deletion') ||
        under('/mcp/oauth') ||
        under('/connections') ||
        under('/appsumo')) {
      return [auth];
    }
    return const [];
  }
}

/// A request path reduced to its route template: ids and long tokens become
/// `:id`, so `/channels/6f1c.../messages` counts as `/channels/:id/messages`.
String routeTemplate(String path) {
  final withoutApi = path.startsWith('/api/') ? path.substring(4) : path;
  final segments = withoutApi.split('/');
  return segments
      .map(
        (s) =>
            RegExp(
              r'^(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[0-9a-fA-F]{16,}|\d+|[A-Za-z0-9_-]{22,})$',
            ).hasMatch(s)
            ? ':id'
            : s,
      )
      .join('/');
}
