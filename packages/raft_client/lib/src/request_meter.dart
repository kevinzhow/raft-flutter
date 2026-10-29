import 'dart:collection';

import 'package:dio/dio.dart';

import 'server_rate_limits.dart';

/// One request the meter saw.
class MeteredRequest {
  MeteredRequest({
    required this.at,
    required this.method,
    required this.route,
    required this.key,
    required this.limits,
    required this.host,
  });

  /// When the request left (the injected clock).
  final DateTime at;
  final String method;

  /// Route template, e.g. `/channels/:id/messages`.
  final String route;

  /// Method + path + sorted query: two requests with the same key asked the
  /// same question.
  final String key;
  final List<String> limits;
  final String host;
  int? status;
  bool completed = false;

  /// Seconds the server asked to wait (`Retry-After`), on a 429.
  int? retryAfter;
  String get label => '$method $route';
}

/// Opt-in request counter for the Dio clients (the Raft API client and the
/// attachment storage client). It is a measurement tool: off by default, no
/// cost beyond one boolean check per request, and it never records bodies,
/// headers or query values (only the sorted query *keys* + values hash-free
/// shape needed to recognise a duplicate, held in memory only).
class RequestMeter {
  RequestMeter({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static final RequestMeter instance = RequestMeter();

  DateTime Function() _clock;
  bool enabled = false;
  final List<MeteredRequest> _requests = [];

  set clock(DateTime Function() value) => _clock = value;
  DateTime now() => _clock();

  List<MeteredRequest> get requests => UnmodifiableListView(_requests);

  void enable({DateTime Function()? clock}) {
    enabled = true;
    if (clock != null) _clock = clock;
  }

  void disable() => enabled = false;

  void reset() => _requests.clear();

  /// A Dio interceptor feeding this meter. Safe to add to any client.
  Interceptor interceptor() => _MeterInterceptor(this);

  MeteredRequest? begin(RequestOptions options) {
    if (!enabled) return null;
    final uri = options.uri;
    final path = uri.path;
    final query = uri.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final apiPath = path.startsWith('/api/') ? path.substring(4) : path;
    final request = MeteredRequest(
      at: _clock(),
      method: options.method.toUpperCase(),
      route: routeTemplate(path),
      key:
          '${options.method.toUpperCase()} $path?'
          '${query.map((e) => '${e.key}=${e.value}').join('&')}'
          '${_bodyShape(options.data)}',
      limits: [
        for (final limit in ServerRateLimits.forRequest(
          options.method,
          apiPath,
        ))
          limit.id,
      ],
      host: uri.host,
    );
    _requests.add(request);
    return request;
  }

  /// A JSON body reduced to a stable fingerprint: two POSTs asking for the same
  /// ids are the same question, two asking for different ids are not.
  static String _bodyShape(Object? data) {
    if (data == null || data is! Map && data is! List) return '';
    String norm(Object? v) => v is Map
        ? '{${(v.entries.map((e) => '${e.key}:${norm(e.value)}').toList()..sort()).join(',')}}'
        : v is List
        ? '[${v.map(norm).join(',')}]'
        : '$v';
    return '#${norm(data).hashCode}';
  }

  /// Requests per route label, for the whole recording.
  Map<String, int> countsByRoute() {
    final counts = <String, int>{};
    for (final r in _requests) {
      counts.update(r.label, (n) => n + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Highest number of requests that counted against limiter [limitId] inside
  /// any sliding window of [window] (default: the limiter's own window).
  int peakInWindow(String limitId, {Duration? window}) {
    final limit = ServerRateLimits.byId(limitId);
    final span = window ?? limit?.window ?? const Duration(minutes: 1);
    final times = [
      for (final r in _requests)
        if (r.limits.contains(limitId)) r.at,
    ];
    var peak = 0, start = 0;
    for (var end = 0; end < times.length; end++) {
      while (times[end].difference(times[start]) >= span) {
        start++;
      }
      if (end - start + 1 > peak) peak = end - start + 1;
    }
    return peak;
  }

  /// Total requests that counted against [limitId].
  int countFor(String limitId) =>
      _requests.where((r) => r.limits.contains(limitId)).length;

  /// Requests that asked the same question as an earlier one less than
  /// [within] before it. Returned as `key -> extra requests`.
  Map<String, int> duplicates({Duration within = const Duration(seconds: 5)}) {
    final last = <String, DateTime>{};
    final extra = <String, int>{};
    for (final r in _requests) {
      final before = last[r.key];
      if (before != null && r.at.difference(before) < within) {
        extra.update(r.key, (n) => n + 1, ifAbsent: () => 1);
      }
      last[r.key] = r.at;
    }
    return extra;
  }

  int get rateLimited => _requests.where((r) => r.status == 429).length;
}

class _MeterInterceptor extends Interceptor {
  _MeterInterceptor(this.meter);
  final RequestMeter meter;
  static const _slot = 'raft.meter';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final record = meter.begin(options);
    if (record != null) options.extra[_slot] = record;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final record = response.requestOptions.extra[_slot];
    if (record is MeteredRequest) {
      record.status = response.statusCode;
      record.completed = true;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final record = err.requestOptions.extra[_slot];
    if (record is MeteredRequest) {
      record.status = err.response?.statusCode ?? 0;
      record.completed = true;
      final after = err.response?.headers.value('retry-after');
      record.retryAfter = int.tryParse(after ?? '');
    }
    handler.next(err);
  }
}
