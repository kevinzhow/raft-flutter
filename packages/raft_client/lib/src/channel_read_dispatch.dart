part of 'client.dart';

/// `POST /channels/:id/read` only. `read-all` stays on Dio's chain.
final RegExp _channelReadPath = RegExp(r'^/channels/[^/]+/read$');

/// Dio queues every interceptor, and the send after them, as its own
/// event-loop turn (`Future(() => ...)`). A channel read is decided on the
/// live-message turn; a timer already waiting 10ms can run before those
/// turns and observe that the adapter was never asked. This path runs the
/// same interceptors, then hands the POST to the adapter before the caller
/// yields. An interceptor that actually waits (the proxy gate) still waits,
/// and the adapter is entered on the continuation of that wait, not on a
/// further timer.
bool _channelReadStaysOnThisTurn(
  Dio http,
  String method,
  String path, {
  required dynamic data,
  required void Function(int, int)? onSendProgress,
}) {
  if (method != 'POST' || onSendProgress != null) return false;
  if (data is FormData || data is Stream) return false;
  if (!_channelReadPath.hasMatch(path)) return false;
  return !http.interceptors.any(
    (interceptor) => interceptor is QueuedInterceptor,
  );
}

Future<Response<dynamic>> _dispatchChannelRead(
  Dio http, {
  required String method,
  required String path,
  required dynamic data,
  required Map<String, dynamic>? query,
  required Map<String, dynamic> headers,
  required Duration? receiveTimeout,
  required CancelToken? cancelToken,
}) {
  // Dio refuses a token that is already cancelled before any interceptor.
  final cancelled = cancelToken?.cancelError;
  if (cancelled != null) return Future<Response<dynamic>>.error(cancelled);
  final options =
      Options(
        method: method,
        receiveTimeout: receiveTimeout,
        headers: headers,
      ).compose(
        http.options,
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        sourceStackTrace: StackTrace.current,
      );
  return _ChannelReadChain(http, http.interceptors.toList()).open(options);
}

class _ChannelReadChain {
  _ChannelReadChain(this._http, this._interceptors);
  final Dio _http;
  final List<Interceptor> _interceptors;

  Future<Response<dynamic>> open(RequestOptions options) {
    final prepared = _prepare(options, 0);
    if (prepared is Future) {
      return (prepared as Future<Object?>).then(_afterPrepare);
    }
    return _afterPrepare(prepared);
  }

  Object? _prepare(RequestOptions options, int index) {
    for (var i = index; i < _interceptors.length; i++) {
      final step = _ReadStep();
      Object? result;
      try {
        final dynamic onRequest = _interceptors[i].onRequest;
        result = onRequest(options, step);
      } catch (error, stack) {
        if (!step.isCompleted) step.reject(_asDio(error, stack, options));
      }
      final settled = step.settled;
      if (!step.isCompleted) {
        _observe(result, options, (error) {
          if (!step.isCompleted) step.reject(error);
        });
        final next = i + 1;
        return settled.then((_) => _continue(step, next));
      }
      final branched = _branch(step);
      if (branched is! RequestOptions) return branched;
      options = branched;
    }
    return options;
  }

  Object? _continue(_ReadStep step, int index) {
    final branched = _branch(step);
    if (branched is! RequestOptions) return branched;
    return _prepare(branched, index);
  }

  Object? _branch(_ReadStep step) {
    final outcome = step.outcome;
    if (outcome is RequestOptions) return outcome;
    if (outcome is Response) {
      return _Stopped.response(outcome, follow: step.follow);
    }
    if (outcome is DioException) {
      return _Stopped.error(outcome, follow: step.follow);
    }
    throw StateError('A read interceptor finished without a request.');
  }

  Future<Response<dynamic>> _afterPrepare(Object? prepared) {
    if (prepared is _Stopped) return _finishStopped(prepared);
    if (prepared is! RequestOptions) {
      return Future<Response<dynamic>>.error(
        StateError('Read dispatch stopped without a request.'),
      );
    }
    // A cancel that lands while an interceptor is still waiting never starts
    // the exchange, including the retry after a 401 refresh.
    final cancelled = prepared.cancelToken?.cancelError;
    if (cancelled != null) return Future<Response<dynamic>>.error(cancelled);
    Future<ResponseBody> pending;
    try {
      pending = _http.httpClientAdapter.fetch(
        prepared,
        _body(prepared),
        prepared.cancelToken?.whenCancel,
      );
    } catch (error, stack) {
      pending = Future<ResponseBody>.error(_asDio(error, stack, prepared));
    }
    return _finish(prepared, pending);
  }

  Future<Response<dynamic>> _finishStopped(_Stopped stopped) {
    final response = stopped.response;
    if (response != null) {
      if (!stopped.follow) return Future<Response<dynamic>>.value(response);
      return _responses(response, 0);
    }
    final error = stopped.error!;
    if (!stopped.follow) return Future<Response<dynamic>>.error(error);
    return _errors(error, 0);
  }

  Future<Response<dynamic>> _finish(
    RequestOptions options,
    Future<ResponseBody> pending,
  ) async {
    final Response<dynamic> response;
    try {
      response = await _decode(options, pending);
    } catch (error, stack) {
      final dio = error is DioException ? error : _asDio(error, stack, options);
      return _errors(dio, 0);
    }
    return _responses(response, 0);
  }

  Future<Response<dynamic>> _decode(
    RequestOptions options,
    Future<ResponseBody> pending,
  ) async {
    final body = await pending;
    final headers = Headers.fromMap(
      body.headers,
      preserveHeaderCase: options.preserveHeaderCase,
    );
    body.headers = headers.map;
    final response = Response<dynamic>(
      headers: headers,
      requestOptions: options,
      redirects: body.redirects ?? const <RedirectRecord>[],
      isRedirect: body.isRedirect,
      statusCode: body.statusCode,
      statusMessage: body.statusMessage,
      extra: body.extra,
    );
    final ok = options.validateStatus(body.statusCode);
    if (ok || options.receiveDataWhenStatusError) {
      var data = await _http.transformer.transformResponse(options, body);
      if (data is String &&
          data.isEmpty &&
          options.responseType == ResponseType.json) {
        data = null;
      }
      response.data = data;
    } else {
      await body.stream.drain<void>();
    }
    if (!ok) {
      throw DioException.badResponse(
        statusCode: body.statusCode,
        requestOptions: options,
        response: response,
      );
    }
    return response;
  }

  Future<Response<dynamic>> _responses(
    Response<dynamic> response,
    int index,
  ) async {
    for (var i = index; i < _interceptors.length; i++) {
      final step = _ResponseStep();
      Object? result;
      try {
        final dynamic onResponse = _interceptors[i].onResponse;
        result = onResponse(response, step);
      } catch (error, stack) {
        if (!step.isCompleted) {
          step.reject(_asDio(error, stack, response.requestOptions));
        }
      }
      final settled = step.settled;
      if (!step.isCompleted) {
        _observe(result, response.requestOptions, (error) {
          if (!step.isCompleted) step.reject(error);
        });
        await settled;
      }
      final outcome = step.outcome;
      if (outcome is Response) {
        if (step.stop) return outcome;
        response = outcome;
        continue;
      }
      final error = outcome is DioException
          ? outcome
          : _asDio(
              outcome ?? 'missing response',
              StackTrace.current,
              response.requestOptions,
            );
      if (step.stop) throw error;
      return _errors(error, 0);
    }
    return response;
  }

  Future<Response<dynamic>> _errors(DioException error, int index) async {
    for (var i = index; i < _interceptors.length; i++) {
      final step = _ErrorStep();
      Object? result;
      try {
        final dynamic onError = _interceptors[i].onError;
        result = onError(error, step);
      } catch (thrown, stack) {
        if (!step.isCompleted) {
          step.next(_asDio(thrown, stack, error.requestOptions));
        }
      }
      final settled = step.settled;
      if (!step.isCompleted) {
        _observe(result, error.requestOptions, (failure) {
          if (!step.isCompleted) step.next(failure);
        });
        await settled;
      }
      final outcome = step.outcome;
      if (outcome is Response) return outcome;
      if (outcome is DioException) {
        if (step.stop) throw outcome;
        error = outcome;
        continue;
      }
      throw error;
    }
    throw error;
  }
}

class _Stopped {
  _Stopped.response(this.response, {required this.follow}) : error = null;
  _Stopped.error(this.error, {required this.follow}) : response = null;
  final Response<dynamic>? response;
  final DioException? error;
  final bool follow;
}

class _ReadStep extends RequestInterceptorHandler {
  Object? outcome;
  bool follow = false;
  Future<void> get settled =>
      future.then((_) {}, onError: (Object _, StackTrace _) {});

  @override
  void next(RequestOptions requestOptions) {
    outcome = requestOptions;
    super.next(requestOptions);
  }

  @override
  void resolve(Response<dynamic> response, [bool callFollowing = false]) {
    outcome = response;
    follow = callFollowing;
    super.resolve(response, callFollowing);
  }

  @override
  void reject(DioException error, [bool callFollowing = false]) {
    outcome = error;
    follow = callFollowing;
    super.reject(error, callFollowing);
  }
}

class _ResponseStep extends ResponseInterceptorHandler {
  Object? outcome;
  bool stop = false;
  Future<void> get settled =>
      future.then((_) {}, onError: (Object _, StackTrace _) {});

  @override
  void next(Response<dynamic> response) {
    outcome = response;
    super.next(response);
  }

  @override
  void resolve(Response<dynamic> response) {
    outcome = response;
    stop = true;
    super.resolve(response);
  }

  @override
  void reject(DioException error, [bool callFollowing = false]) {
    outcome = error;
    stop = !callFollowing;
    super.reject(error, callFollowing);
  }
}

class _ErrorStep extends ErrorInterceptorHandler {
  Object? outcome;
  bool stop = false;
  Future<void> get settled =>
      future.then((_) {}, onError: (Object _, StackTrace _) {});

  @override
  void next(DioException error) {
    outcome = error;
    super.next(error);
  }

  @override
  void resolve(Response<dynamic> response) {
    outcome = response;
    super.resolve(response);
  }

  @override
  void reject(DioException error, [bool callFollowing = false]) {
    outcome = error;
    stop = !callFollowing;
    super.reject(error, callFollowing);
  }
}

Stream<Uint8List>? _body(RequestOptions options) {
  if (options.data == null) return null;
  final encoded = Transformer.defaultTransformRequest(options, jsonEncode);
  if (encoded is! String) {
    throw StateError('A channel read body has to encode before the next turn.');
  }
  final bytes = Uint8List.fromList(utf8.encode(encoded));
  options.headers[Headers.contentLengthHeader] = '${bytes.length}';
  return Stream<Uint8List>.value(bytes);
}

void _observe(
  Object? result,
  RequestOptions options,
  void Function(DioException error) fail,
) {
  if (result is! Future) return;
  unawaited(
    result.then(
      (_) {},
      onError: (Object error, StackTrace stack) {
        fail(_asDio(error, stack, options));
      },
    ),
  );
}

DioException _asDio(Object error, StackTrace stack, RequestOptions options) {
  if (error is DioException) return error;
  return DioException(requestOptions: options, error: error, stackTrace: stack);
}
