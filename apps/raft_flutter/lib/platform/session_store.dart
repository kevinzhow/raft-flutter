import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:raft_client/raft_client.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({
    bool useDataProtectionKeychain = const bool.fromEnvironment(
      'RAFT_MACOS_DATA_PROTECTION_KEYCHAIN',
    ),
  }) : _migrateLegacy =
           useDataProtectionKeychain &&
           !kIsWeb &&
           defaultTargetPlatform == TargetPlatform.macOS,
       storage = FlutterSecureStorage(
         // flutter_secure_storage defaults resetOnError to true: any exception
         // while reading or writing (a Keystore that is momentarily
         // unavailable, a background engine racing the foreground, a key that
         // cannot unwrap) makes the plugin delete EVERY stored value and
         // answer "Data has been reset". For credentials that turns one
         // transient error into a permanent sign-out. Errors must surface to
         // the caller, which keeps the record and retries.
         aOptions: const AndroidOptions(resetOnError: false),
         mOptions: MacOsOptions(
           usesDataProtectionKeychain: useDataProtectionKeychain,
         ),
         iOptions: const IOSOptions(
           accessibility: KeychainAccessibility.first_unlock_this_device,
         ),
       );

  // Enable only in macOS builds with an authorized provisioning profile.
  // Credentials remain private to this app; unprovisioned builds keep the
  // legacy backend. Serialize migration with logout to avoid restoring it.
  final FlutterSecureStorage storage;
  final bool _migrateLegacy;
  static const _legacyOptions = MacOsOptions(usesDataProtectionKeychain: false);
  Future<void> _operations = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  String key(String origin) =>
      '$_prefix${base64Url.encode(utf8.encode(origin))}';
  @override
  Future<Session?> read(String origin) => _serialized(() async {
    final item = key(origin);
    var value = await storage.read(key: item);
    if (value == null && _migrateLegacy) {
      value = await storage.read(key: item, mOptions: _legacyOptions);
      if (value != null) {
        // Validate before copying; never discard the old item until the new
        // keychain has confirmed the exact value was stored.
        final session = _decode(value);
        await storage.write(key: item, value: value);
        if (await storage.read(key: item) != value) {
          throw StateError('Keychain session migration could not be verified.');
        }
        await storage.delete(key: item, mOptions: _legacyOptions);
        return session;
      }
    }
    return value == null ? null : _decode(value);
  });

  /// Every saved session by origin (the keys carry the origin, so the list
  /// needs no other index). Throws when the store cannot be read or a record
  /// is damaged: callers that delete data on the strength of this list must
  /// then delete nothing.
  Future<Map<String, Session>> readAll() => _serialized(() async {
    final result = <String, Session>{};
    Future<void> collect(Map<String, String> items) async {
      for (final MapEntry(:key, :value) in items.entries) {
        if (!key.startsWith(_prefix)) continue;
        final origin = utf8.decode(
          base64Url.decode(base64Url.normalize(key.substring(_prefix.length))),
        );
        result.putIfAbsent(origin, () => _decode(value));
      }
    }

    await collect(await storage.readAll());
    if (_migrateLegacy) {
      await collect(await storage.readAll(mOptions: _legacyOptions));
    }
    return result;
  });

  static const _prefix = 'raft.session.';

  Session _decode(String value) =>
      Session.fromJson(Map<String, dynamic>.from(jsonDecode(value)));

  @override
  Future<void> write(String origin, Session? session) => _serialized(() async {
    if (session == null) {
      // Clear the fallback first so a later read cannot resurrect a logout.
      if (_migrateLegacy) {
        await storage.delete(key: key(origin), mOptions: _legacyOptions);
      }
      await storage.delete(key: key(origin));
    } else {
      await storage.write(
        key: key(origin),
        value: jsonEncode(session.toJson()),
      );
    }
  });
}
