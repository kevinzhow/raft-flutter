import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final raw = await driver.requestData(null, timeout: const Duration(minutes: 20));
  final out = Platform.environment['RAFT_PERF_OUT']!;
  await File('$out/driver-result.json').writeAsString(raw);
  final response = Response.fromJson(raw);
  await driver.close();
  if (response.allTestsPassed) {
    stdout.writeln('All tests passed.');
    exit(0);
  }
  stdout.writeln('Failure Details:\n${response.formattedFailureDetails}');
  exit(1);
}
