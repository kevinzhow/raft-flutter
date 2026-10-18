import 'package:flutter_timezone/flutter_timezone.dart';

/// The OS IANA identifier at dispatch time, independent of display preferences.
/// Missing plugins, unsupported hosts and slow native calls must not block sends.
Future<String?> readDeviceTimezone() async {
  try {
    final zone = await FlutterTimezone.getLocalTimezone().timeout(
      const Duration(milliseconds: 500),
    );
    final name = zone.identifier.trim();
    return name.isEmpty || name == 'Etc/Unknown' ? null : name;
  } catch (_) {
    return null;
  }
}
