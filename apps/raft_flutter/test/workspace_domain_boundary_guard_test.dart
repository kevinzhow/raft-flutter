import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _repository() {
  var directory = Directory.current;
  while (!File.fromUri(directory.uri.resolve('tool/workspace_domain_guard.py'))
      .existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) throw StateError('Repository not found');
    directory = parent;
  }
  return directory;
}

ProcessResult _python(Directory repository, List<String> arguments) {
  try {
    // preflight-allow: Python is required by tool/preflight and tool/check-project.
    return Process.runSync(
      'python3',
      arguments,
      workingDirectory: repository.path,
    );
  } on ProcessException {
    // preflight-allow: Windows can expose the required Python interpreter as python.
    return Process.runSync(
      'python',
      arguments,
      workingDirectory: repository.path,
    );
  }
}

void main() {
  test(
    'workspace domains have no new root dependency or untyped root escape',
    () {
      final result = _python(_repository(), ['tool/workspace_domain_guard.py']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final report = jsonDecode(result.stdout as String) as Map;
      expect(report['passed'], isTrue);
    },
  );
  test(
    'domain boundary policy rejects import, cast, dynamic and identity escapes',
    () {
      final result = _python(_repository(), [
        '-m',
        'unittest',
        'discover',
        '-s',
        'tool/tests',
        '-p',
        'test_workspace_domain_guard.py',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
  );
}
