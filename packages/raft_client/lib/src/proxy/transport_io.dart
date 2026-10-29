import 'dart:async';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:web_socket/io_web_socket.dart';
import 'package:web_socket/web_socket.dart' as ws;

import 'system_proxy.dart';

/// Waits (bounded) for a PAC answer before the first request to a host.
class ProxyReadyInterceptor extends Interceptor {
  ProxyReadyInterceptor([SystemProxy? proxy]) : _proxy = proxy;
  final SystemProxy? _proxy;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await (_proxy ?? SystemProxy.instance).ready(options.uri);
    handler.next(options);
  }
}

/// A [Dio] whose connections follow [SystemProxy]. Every app `Dio` is built
/// here (`proxy_hook_guard_test` fails on a bare `Dio()` in `lib/`).
Dio createProxiedDio(
  BaseOptions? options, {
  void Function(io.HttpClient client)? configure,
  SystemProxy? proxy,
}) {
  // ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: builds the Dio, its IOHttpClientAdapter and the socket.io WebSocket around SystemProxy.createHttpClient.
  final dio = Dio(options);
  // ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: builds the Dio, its IOHttpClientAdapter and the socket.io WebSocket around SystemProxy.createHttpClient.
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = (proxy ?? SystemProxy.instance).createHttpClient();
      configure?.call(client);
      return client;
    },
  );
  dio.interceptors.add(ProxyReadyInterceptor(proxy));
  return dio;
}

/// socket.io's WebSocket transport, connected through [SystemProxy]
/// (`dart:io` `WebSocket.connect(customClient:)`). `ws:`/`wss:` are matched
/// against `http:`/`https:` proxy rules, as dart:io does.
Future<ws.WebSocket> proxiedWebSocketConnector(
  Uri uri, {
  Iterable<String>? protocols,
  Map<String, String>? headers,
  SystemProxy? proxy,
}) async {
  final service = proxy ?? SystemProxy.instance;
  await service.ready(
    uri.replace(scheme: uri.scheme == 'wss' ? 'https' : 'http'),
  );
  final client = service.createHttpClient();
  try {
    // ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: builds the Dio, its IOHttpClientAdapter and the socket.io WebSocket around SystemProxy.createHttpClient.
    final socket = await io.WebSocket.connect(
      uri.toString(),
      protocols: protocols,
      headers: headers,
      customClient: client,
    );
    // The socket owns its connection; the client only existed to dial it.
    unawaited(
      socket.done
          .then((_) {}, onError: (Object _) {})
          .whenComplete(() => client.close(force: true)),
    );
    return IOWebSocket.fromWebSocket(socket);
  } on io.WebSocketException catch (error) {
    client.close(force: true);
    throw ws.WebSocketException(error.message);
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

/// Adds the proxy-aware connector to socket.io options.
sio.OptionBuilder applyProxyTransport(sio.OptionBuilder builder) =>
    builder.setWebSocketConnector(proxiedWebSocketConnector);
