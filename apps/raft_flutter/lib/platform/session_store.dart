import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:raft_client/raft_client.dart';

class SecureSessionStore implements SessionStore {
  final storage = const FlutterSecureStorage();
  String key(String origin) =>
      'raft.session.${base64Url.encode(utf8.encode(origin))}';
  @override
  Future<Session?> read(String origin) async {
    final value = await storage.read(key: key(origin));
    return value == null
        ? null
        : Session.fromJson(Map<String, dynamic>.from(jsonDecode(value)));
  }

  @override
  Future<void> write(String origin, Session? session) async {
    if (session == null) {
      await storage.delete(key: key(origin));
    } else {
      await storage.write(
        key: key(origin),
        value: jsonEncode(session.toJson()),
      );
    }
  }
}
