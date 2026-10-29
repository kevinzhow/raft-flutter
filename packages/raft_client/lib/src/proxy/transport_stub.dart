import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

/// Platforms without dart:io (web) use the browser's networking and proxy.
// ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: web stub, the browser owns the transport.
Dio createProxiedDio(BaseOptions? options) => Dio(options);

sio.OptionBuilder applyProxyTransport(sio.OptionBuilder builder) => builder;
