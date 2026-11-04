import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory appRoot() {
  for (final path in ['apps/raft_flutter', '.']) {
    final dir = Directory(path);
    if (File('${dir.path}/macos/Runner/MainFlutterWindow.swift').existsSync()) {
      return dir;
    }
  }
  throw StateError('Run from repository or app directory.');
}

void main() {
  test('the child engine never registers the process-wide macOS notification delegate', () {
    final source = File(
      '${appRoot().path}/macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final callback = RegExp(
      r'setOnWindowCreatedCallback\s*\{\s*controller in([\s\S]*?)\n    \}',
    ).firstMatch(source)!.group(1)!;
    expect(
      callback,
      contains('RegisterRaftChildPlugins(registry: controller)'),
    );
    expect(callback, isNot(contains('RegisterGeneratedPlugins')));
    expect(
      source,
      contains('RegisterGeneratedPlugins(registry: flutterViewController)'),
    );
  });
  test('the child registry keeps every other generated plugin and remains in the Runner sources', () {
    final app = appRoot().path;
    final original = File('$app/macos/Flutter/GeneratedPluginRegistrant.swift')
        .readAsStringSync();
    final child = File('$app/macos/Runner/RaftChildPluginRegistrant.swift')
        .readAsStringSync();
    List<String> registrations(String value) => RegExp(
      r'([A-Za-z0-9_]+)\.register\(with: registry\.registrar\(forPlugin: "([A-Za-z0-9_]+)"\)\)',
    ).allMatches(value).map((m) => m.group(0)!).toList();
    final expected = registrations(original)
        .where((r) => !r.startsWith('FlutterLocalNotificationsPlugin.'))
        .toList();
    expect(registrations(child), expected);
    expect(child, isNot(contains('import flutter_local_notifications')));
    final project = File('$app/macos/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(project, contains('RaftChildPluginRegistrant.swift in Sources'));
  });
}
