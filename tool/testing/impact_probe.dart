// ignore_for_file: implementation_imports, depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:test_api/scaffolding.dart' show tearDownAll;
import 'package:test_api/src/backend/invoker.dart' show Invoker;

/// Environment variable that turns the probe on: the directory it writes to.
const impactDirVariable = 'RAFT_TEST_IMPACT_DIR';

/// Comma-separated library URI prefixes to record (default `package:raft_`).
const impactFiltersVariable = 'RAFT_TEST_IMPACT_FILTERS';

/// Records which library lines this test file executed, for test impact
/// selection (`tool/test-impact`, docs/development.md).
///
/// Off unless [impactDirVariable] is set (the nightly and `tool/test-impact
/// build` set it). `flutter test` runs each test file in its own process, so
/// the VM's line coverage of that process at the end of the file is exactly
/// what this file ran. The run must have the VM service on: `--coverage` or
/// `--enable-vmservice`, and `--no-dds` (the probe connects to the VM service
/// directly). Call it once from `testExecutable`, before any test is declared:
/// its `tearDownAll` is the first one registered, so it runs after every other.
///
/// It also records the paths the file opens through `dart:io` (`File`,
/// `Directory`, type and stat checks): guard tests that read sources as text,
/// golden images and test assets depend on files that coverage cannot see.
///
/// Never fails a test: any error is written next to the result instead.
void recordTestImpact() {
  final dir = Platform.environment[impactDirVariable];
  if (dir == null || dir.isEmpty) return;
  final paths = _PathRecorder(Directory.current.path, IOOverrides.current);
  IOOverrides.global = paths;
  tearDownAll(() async {
    final path = Invoker.current?.liveTest.suite.path ?? 'unknown';
    final name = path.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final out = File('$dir/$name.${pid}.json');
    try {
      final filters = (Platform.environment[impactFiltersVariable] ?? '')
          .split(',')
          .where((p) => p.isNotEmpty)
          .toList();
      final report = await _collect(
        filters.isEmpty ? const ['package:raft_'] : filters,
      ).timeout(const Duration(seconds: 120));
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(
        jsonEncode({
          'test': path,
          ...report,
          'paths': (paths.seen.toList()..sort()),
        }),
      );
    } catch (error) {
      try {
        out.parent.createSync(recursive: true);
        out.writeAsStringSync(jsonEncode({'test': path, 'error': '$error'}));
      } catch (_) {}
    }
  });
}

/// `{'hits': {script uri: [line, ...]}, 'misses': {...}}` over every isolate
/// of this process. A missed line is one in a compiled function that never
/// ran; together with the hits it is the file's executable lines.
Future<Map<String, Map<String, List<int>>>> _collect(
  List<String> filters,
) async {
  final info = await developer.Service.getInfo();
  final uri = info.serverWebSocketUri;
  if (uri == null) {
    throw StateError('no VM service (run with --enable-vmservice --no-dds)');
  }
  // The test binding installs a mock HttpClient that answers 400 to
  // everything; the probe needs a real one for the service websocket.
  return HttpOverrides.runWithHttpOverrides(() async {
    final socket = await WebSocket.connect(uri.toString());
    final replies = <int, Completer<Map<String, dynamic>>>{};
    var next = 0;
    socket.listen((message) {
      final reply = jsonDecode(message as String) as Map<String, dynamic>;
      final id = int.tryParse('${reply['id']}');
      replies.remove(id)?.complete(reply);
    });
    Future<Map<String, dynamic>> call(
      String method,
      Map<String, Object?> params,
    ) {
      final id = next++;
      final done = replies[id] = Completer<Map<String, dynamic>>();
      socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': '$id',
          'method': method,
          'params': params,
        }),
      );
      return done.future.then((reply) {
        if (reply['error'] != null) {
          throw StateError('$method: ${reply['error']}');
        }
        return reply['result'] as Map<String, dynamic>;
      });
    }

    final hits = <String, Set<int>>{};
    final misses = <String, Set<int>>{};
    try {
      final vm = await call('getVM', {});
      for (final isolate in (vm['isolates'] as List).cast<Map>()) {
        final Map<String, dynamic> report;
        try {
          report = await call('getSourceReport', {
            'isolateId': isolate['id'],
            'reports': ['Coverage'],
            'forceCompile': false,
            'reportLines': true,
            'libraryFilters': filters,
          });
        } on StateError {
          continue; // an isolate that exited meanwhile
        }
        final scripts = (report['scripts'] as List).cast<Map>();
        for (final range in (report['ranges'] as List).cast<Map>()) {
          final coverage = range['coverage'] as Map?;
          if (coverage == null) continue;
          final script = scripts[range['scriptIndex'] as int]['uri'] as String;
          if (!filters.any(script.startsWith)) continue; // inlined code
          for (final (key, into) in [('hits', hits), ('misses', misses)]) {
            final lines = (coverage[key] as List?)?.cast<int>() ?? const [];
            if (lines.isNotEmpty) {
              into.putIfAbsent(script, () => <int>{}).addAll(lines);
            }
          }
        }
      }
    } finally {
      await socket.close();
    }
    Map<String, List<int>> sorted(Map<String, Set<int>> lines) => {
      for (final entry in lines.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    return {'hits': sorted(hits), 'misses': sorted(misses)};
  }, _RealHttp());
}

class _RealHttp extends HttpOverrides {}

/// Remembers every path a `File`, `Directory` or type/stat check names.
final class _PathRecorder extends IOOverrides {
  _PathRecorder(this._cwd, this._inner);

  final String _cwd;
  final IOOverrides? _inner;
  final seen = <String>{};

  void _note(String path) =>
      seen.add(path.startsWith('/') ? path : '$_cwd/$path');

  @override
  File createFile(String path) {
    _note(path);
    return _inner?.createFile(path) ?? super.createFile(path);
  }

  @override
  Directory createDirectory(String path) {
    _note(path);
    return _inner?.createDirectory(path) ?? super.createDirectory(path);
  }

  @override
  Future<FileSystemEntityType> fseGetType(String path, bool followLinks) {
    _note(path);
    return super.fseGetType(path, followLinks);
  }

  @override
  FileSystemEntityType fseGetTypeSync(String path, bool followLinks) {
    _note(path);
    return super.fseGetTypeSync(path, followLinks);
  }

  @override
  Future<FileStat> stat(String path) {
    _note(path);
    return super.stat(path);
  }

  @override
  FileStat statSync(String path) {
    _note(path);
    return super.statSync(path);
  }
}
