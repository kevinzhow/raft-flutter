// ignore_for_file: implementation_imports, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:raft_ui/test_themes.dart' show raftFullMatrix;
import 'package:stack_trace/stack_trace.dart' show Trace;
import 'package:test_api/src/backend/group.dart' show Group;
import 'package:test_api/src/backend/invoker.dart' show Invoker;

/// A declaration site that expands to more cases than this is a matrix.
const matrixLeakLimit = 8;

/// Leak tracking costs 10 to 20% of a widget test's run time, and a matrix of
/// dozens of variants of one declaration (page x size x theme) repeats the same
/// object lifecycle in each. On the gate this tracks the FIRST case of every
/// declaration site that expands to more than [limit] cases in the file and
/// turns tracking off for the rest; `RAFT_TEST_TIER=full` (the nightly) and
/// `RAFT_TEST_ALL_THEMES=1` track every case. Sites of [limit] cases or fewer
/// are always tracked.
///
/// The site of a case is the first stack frame outside the test packages, taken
/// from the trace the runner records when a JSON reporter is attached (the gate
/// and the nightly use one). Without traces (a plain local run) nothing is
/// skipped and every case is tracked. Call it once from `testExecutable`, after
/// `LeakTesting.enable()`.
void trackMatrixLeaksOnce({int limit = matrixLeakLimit}) {
  if (!LeakTesting.enabled || raftFullMatrix) return;
  final tracked = <String>{};
  Map<String, int>? sizes;
  LeakTesting? tracking;
  setUp(() {
    final live = Invoker.current?.liveTest;
    if (live == null) return;
    sizes ??= _siteSizes(live.suite.group);
    final site = _siteOf(live.test.trace);
    if (site == null || (sizes![site] ?? 0) <= limit) return;
    if (tracked.add(site)) return; // the first case of the site stays tracked
    tracking = LeakTesting.settings;
    LeakTesting.settings = tracking!.withIgnoredAll();
  });
  tearDown(() {
    final settings = tracking;
    if (settings == null) return;
    tracking = null;
    LeakTesting.settings = settings;
  });
}

Map<String, int> _siteSizes(Group group) {
  final sizes = <String, int>{};
  void visit(Group g) {
    for (final entry in g.entries) {
      if (entry is Group) {
        visit(entry);
      } else {
        final site = _siteOf(entry.trace);
        if (site != null) sizes[site] = (sizes[site] ?? 0) + 1;
      }
    }
  }

  visit(group);
  return sizes;
}

/// `file:line:column` of the first frame that is not the test framework's.
String? _siteOf(Trace? trace) {
  if (trace == null) return null;
  for (final frame in trace.frames) {
    final uri = frame.uri.toString();
    if (uri.startsWith('dart:') ||
        uri.startsWith('package:test_api/') ||
        uri.startsWith('package:test_core/') ||
        uri.startsWith('package:test/') ||
        uri.startsWith('package:flutter_test/')) {
      continue;
    }
    return '$uri:${frame.line}:${frame.column}';
  }
  return null;
}
