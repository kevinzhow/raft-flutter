/// The Raft server's per-route rate limits, mirrored from
/// `packages/server/src/app.ts` (express-rate-limit, in-memory store, so each
/// server replica counts on its own).
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

  /// `messageLimiter`: non-GET `/api/messages`, `/api/v2/messages` and
  /// `POST /api/attachments/:id/comments`.
  static const messages = ServerRateLimit(
    'messages',
    max: 60,
    window: Duration(minutes: 1),
    key: 'user',
    note: 'messageLimiter, writes only (GET skipped)',
  );

  /// `uploadLimiter`: non-GET `/api/attachments` writes and share artifacts.
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

  /// `authLimiter`: `/api/auth/*` (login, refresh, me, logout, device, ...),
  /// `/api/public`, `/api/app-installation`, `/api/release-notes`,
  /// `/api/mobile-download`, `/api/computer`, `/api/oauth`.
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
    note: 'billingLimiter, writes only',
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

  static const notificationEnrollment = ServerRateLimit(
    'notification-enrollment',
    max: 60,
    window: Duration(minutes: 1),
    key: 'ip',
    note: 'enrollmentGrantLimiter / enrollmentExchangeLimiter',
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
    feedback,
    forgotPassword,
    notificationEnrollment,
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
    if (under('/messages') || under('/v2/messages')) {
      return [if (write) messages];
    }
    if (p.startsWith('/message-translations')) return [translation];
    if (under('/product-events')) return [productEvents];
    if (under('/billing')) return [if (write) billing];
    if (under('/product-feedback')) return [if (write) feedback];
    if (under('/share-artifacts')) return [uploads];
    if (p == '/auth/forgot-password') return [forgotPassword];
    if (under('/notifications')) return [notificationEnrollment];
    if (under('/auth') ||
        under('/public') ||
        under('/app-installation') ||
        under('/release-notes') ||
        under('/mobile-download') ||
        under('/oauth') ||
        under('/computer')) {
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
        (s) => RegExp(
              r'^(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[0-9a-fA-F]{16,}|\d+|[A-Za-z0-9_-]{22,})$',
            ).hasMatch(s)
            ? ':id'
            : s,
      )
      .join('/');
}
