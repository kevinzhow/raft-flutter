import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists Settings > Network. Everything but the password is in
/// SharedPreferences; the password is in secure storage, with the same options
/// as the session store (Android `resetOnError: false`, so one Keystore error
/// can never wipe the stored credentials).
class ProxySettingsStore {
  ProxySettingsStore({
    SharedPreferences? preferences,
    FlutterSecureStorage? secure,
  }) : _loaded = preferences,
       _secure =
           secure ??
           FlutterSecureStorage(
             aOptions: const AndroidOptions(resetOnError: false),
             mOptions: MacOsOptions(
               usesDataProtectionKeychain: const bool.fromEnvironment(
                 'RAFT_MACOS_DATA_PROTECTION_KEYCHAIN',
               ),
             ),
             iOptions: const IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           );

  static const modeKey = 'raft.proxy.mode';
  static const hostKey = 'raft.proxy.host';
  static const portKey = 'raft.proxy.port';
  static const userKey = 'raft.proxy.user';
  static const bypassKey = 'raft.proxy.bypass';
  static const passwordKey = 'raft.proxy.password';

  SharedPreferences? _loaded;
  final FlutterSecureStorage _secure;

  Future<SharedPreferences> get _prefs async =>
      _loaded ??= await SharedPreferences.getInstance();

  Future<ProxySettings> load() async {
    final prefs = await _prefs;
    final mode = ProxyMode.values.firstWhere(
      (m) => m.name == prefs.getString(modeKey),
      orElse: () => ProxyMode.system,
    );
    final username = prefs.getString(userKey) ?? '';
    var password = '';
    if (username.isNotEmpty) {
      try {
        password = await _secure.read(key: passwordKey) ?? '';
      } catch (_) {
        // A Keystore that is momentarily unavailable: the stored value is kept
        // (resetOnError is false); this run has no credentials to send.
      }
    }
    return ProxySettings(
      mode: mode,
      host: prefs.getString(hostKey) ?? '',
      port: prefs.getInt(portKey) ?? 0,
      username: username,
      password: password,
      bypass: prefs.getStringList(bypassKey) ?? const [],
    );
  }

  /// True when a password is stored (without reading it into the UI).
  Future<bool> hasPassword() async {
    try {
      return (await _secure.read(key: passwordKey) ?? '').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Saves [settings]. With [keepPassword] the stored password is left as it
  /// is (the page never reads it back into a text field).
  Future<void> save(ProxySettings settings, {bool keepPassword = false}) async {
    final prefs = await _prefs;
    await prefs.setString(modeKey, settings.mode.name);
    await prefs.setString(hostKey, settings.host.trim());
    await prefs.setInt(portKey, settings.port);
    await prefs.setString(userKey, settings.username);
    await prefs.setStringList(bypassKey, settings.bypass);
    if (keepPassword && settings.username.isNotEmpty) return;
    if (settings.username.isEmpty || settings.password.isEmpty) {
      await _secure.delete(key: passwordKey);
    } else {
      await _secure.write(key: passwordKey, value: settings.password);
    }
  }

  @visibleForTesting
  static const keys = [modeKey, hostKey, portKey, userKey, bypassKey];
}
