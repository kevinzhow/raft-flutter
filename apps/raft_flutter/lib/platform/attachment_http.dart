import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart'
    show RateLimitGovernor, RateLimitInterceptor, RequestMeter;
import 'package:raft_client/system_proxy.dart';

/// The app-wide HTTP client for attachment storage hosts.
///
/// Every attachment transfer used to build its own `Dio`, hence its own
/// `HttpClient` and connection pool, so each open paid DNS + TCP + TLS again.
/// One long-lived client keeps those connections alive between opens (and
/// between the list preview and the lightbox of the same host).
///
/// It is deliberately separate from the Raft API client: no auth interceptors, no
/// default headers, no cookies. A signed storage URL is the only credential it
/// ever carries, so API tokens can never reach a storage host through it.
class AttachmentHttp {
  AttachmentHttp._();

  /// Idle connections stay pooled this long (the platform default is 15 s,
  /// shorter than the gap between two typical previews).
  static const idleTimeout = Duration(seconds: 60);
  static const maxConnectionsPerHost = 8;

  /// The process-wide admission control for the user's rate-limited routes.
  /// The API client of the signed-in session and the attachment transfers
  /// share it, because the server counts both against one limiter.
  static final RateLimitGovernor governor = RateLimitGovernor();

  static Dio? _shared;

  /// The shared client, created on first use.
  static Dio get shared => _shared ??= create();

  /// A new client with the storage configuration. Tests and the latency probe
  /// call this directly (with [configure] for a test certificate); production
  /// code uses [shared].
  static Dio create({void Function(HttpClient)? configure}) {
    // Built through the proxy hook: a signed storage URL follows the system
    // (or manual) proxy like every other request, and carries no API token.
    final dio = createProxiedDio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
      configure: (client) {
        client
          ..idleTimeout = idleTimeout
          ..maxConnectionsPerHost = maxConnectionsPerHost;
        configure?.call(client);
      },
    );
    // Opt-in request counter (only when a tool or test enabled it first; each
    // interceptor costs a request an event-loop turn).
    if (RequestMeter.instance.enabled) {
      dio.interceptors.add(RequestMeter.instance.interceptor());
    }
    // When the Raft server streams the bytes itself, these requests share the
    // user's attachment limiter with the API client: pace and retry 429s.
    dio.interceptors.add(RateLimitInterceptor(governor, dio));
    return dio;
  }

  /// Closes the pool (app teardown, tests). The next [shared] builds a new one.
  static void close() {
    _shared?.close(force: false);
    _shared = null;
  }

  /// Test hook: replaces the shared client.
  static void debugReplace(Dio? dio) {
    _shared = dio;
  }
}
