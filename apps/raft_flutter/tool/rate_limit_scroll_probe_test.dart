// Prints the per-route request counts of scripted scroll sessions on a fake
// server (presigned and server-streamed storage). Run by hand:
//   ../../tool/flutter test tool/rate_limit_scroll_probe_test.dart --no-pub -r expanded
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import '../test/support/scroll_session.dart';

String report(ScrollSession s, String title) {
  final b = StringBuffer('== $title\n');
  final counts = s.meter.countsByRoute().entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in counts) {
    b.writeln('${e.value.toString().padLeft(5)}  ${e.key}');
  }
  for (final id in ['attachments']) {
    final l = ServerRateLimits.byId(id)!;
    b.writeln(
      'limit ${l.id}: total=${s.meter.countFor(id)} peak/min=${s.meter.peakInWindow(id)} of ${l.max}',
    );
  }
  b.writeln('media downloads=${s.media.loads}');
  b.writeln(
    '429s=${s.meter.rateLimited} served429=${s.server.rateLimited} '
    'dup(60s)=${s.meter.duplicates(within: const Duration(seconds: 60)).values.fold<int>(0, (a, b) => a + b)}',
  );
  return b.toString();
}

void main() {
  for (final local in [false, true]) {
    testWidgets('probe: 60 s back-and-forth scroll local=$local', (tester) async {
      await withScrollSession(tester, local: local, (s) async {
        for (var i = 0; i < 6; i++) {
          await s.back(8000, 5);
          await s.forth(8000, 5);
        }
        // ignore: avoid_print
        print(report(s, 'narrow 8000px local=$local'));
      });
    }, timeout: const Timeout(Duration(minutes: 10)));
    testWidgets('probe: whole-history sweep local=$local', (tester) async {
      await withScrollSession(tester, local: local, (s) async {
        for (var i = 0; i < 6; i++) {
          await s.back(24000, 5);
          await s.forth(24000, 5);
        }
        // ignore: avoid_print
        print(report(s, 'whole history local=$local'));
      });
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
