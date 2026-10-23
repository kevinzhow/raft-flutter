// Shared by the RaftBench tests: the recorded-shape fixtures of the Web
// v1.21.23 contract (test/fixtures/raftbench) and a scripted session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:raft_client/raft_client.dart';

/// A fixture decoded fresh each time, so a test may edit it.
Object? raftbenchFixture(String name) =>
    jsonDecode(File('test/fixtures/raftbench/$name.json').readAsStringSync());

Map<String, Object?> raftbenchMap(String name) =>
    Map<String, Object?>.from(raftbenchFixture(name)! as Map);

/// Fixed clock of the recorded fixtures: the period windows end 2026-10-24.
final raftbenchNow = DateTime.utc(2026, 10, 24, 5);

class RaftbenchCall {
  RaftbenchCall(this.method, this.path, this.data, this.query);
  final String method, path;
  final Object? data;
  final Map<String, dynamic>? query;
  String get key => '$method $path';
}

/// A scripted API: `routes['GET /raftbench']` returns the JSON (or throws);
/// an unknown route is a 404 like the real server.
class RaftbenchApi {
  final routes = <String, FutureOr<Object?> Function(RaftbenchCall)>{};
  final calls = <RaftbenchCall>[];

  Iterable<RaftbenchCall> where(String key) => calls.where((c) => c.key == key);

  Future<dynamic> request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final call = RaftbenchCall(method, path, data, query);
    calls.add(call);
    final route = routes[call.key];
    if (route == null) throw RaftApiException('Not found', status: 404);
    return route(call);
  }
}
