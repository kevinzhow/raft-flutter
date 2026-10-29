import 'dart:convert';

import 'device_preferences.dart';

/// What the Create Agent dialog remembers per server: the computer, runtime and
/// model of the last agent created there (Web `createAgentLastConfig.ts`, same
/// storage key and JSON, kept in the device preferences instead of
/// localStorage). Best effort: a failed read or write never blocks creating an
/// agent.
class CreateAgentLastConfig {
  const CreateAgentLastConfig({
    required this.machineId,
    required this.runtime,
    required this.model,
    required this.customModelMode,
  });
  final String machineId, runtime, model;
  final bool customModelMode;

  static const keyPrefix = 'raft:create-agent:last-config:v1:';
  static const _maxValueLength = 512;

  static String storageKey(String serverId) =>
      '$keyPrefix${Uri.encodeComponent(serverId)}';

  static bool _valid(Object? value, {bool allowEmpty = false}) =>
      value is String &&
      value.length <= _maxValueLength &&
      (allowEmpty || value.isNotEmpty);

  /// Web `parseCreateAgentLastConfig`: any malformed record is "nothing
  /// remembered".
  static CreateAgentLastConfig? parse(Object? value) {
    if (value is! Map) return null;
    final machineId = value['machineId'],
        runtime = value['runtime'],
        model = value['model'],
        custom = value['customModelMode'];
    if (!_valid(machineId) ||
        !_valid(runtime) ||
        !_valid(model, allowEmpty: true) ||
        custom is! bool) {
      return null;
    }
    return CreateAgentLastConfig(
      machineId: machineId as String,
      runtime: runtime as String,
      model: model as String,
      customModelMode: custom,
    );
  }

  Map<String, Object> toJson() => {
    'machineId': machineId,
    'runtime': runtime,
    'model': model,
    'customModelMode': customModelMode,
  };

  /// The remembered configuration for [serverId], or null.
  static CreateAgentLastConfig? read(String? serverId) {
    if (serverId == null || serverId.isEmpty) return null;
    try {
      final raw = DevicePreferences.current?.getString(storageKey(serverId));
      return raw == null ? null : parse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Remembers this configuration for [serverId]; ignored when it is invalid
  /// or storage is unavailable.
  void write(String? serverId) {
    if (serverId == null || serverId.isEmpty) return;
    if (parse(toJson()) == null) return;
    try {
      DevicePreferences.current?.setString(
        storageKey(serverId),
        jsonEncode(toJson()),
      );
    } catch (_) {
      // Preferences are best effort and must never make agent creation fail.
    }
  }
}
