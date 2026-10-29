// Scrolling a channel full of attachments back and forth must not spend the
// server's attachment limit (120 a minute per user, shared by every client the
// user has open): same fake server and fake clock as the session test, with the
// server really answering 429 past its limit.
@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/scroll_session.dart';
import 'flutter_test_config.dart' show leakDebt;

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['Image']);
  const limit = 120;
  for (final local in [false, true]) {
    final storage = local ? 'server-streamed storage' : 'presigned storage';
    testWidgets(
      '30 s of fast back-and-forth scrolling over images, clips and files ($storage)',
      (tester) async {
        await withScrollSession(tester, local: local, (s) async {
          for (var i = 0; i < 3; i++) {
            await s.back(24000, 5);
            await s.forth(24000, 5);
          }
          final peak = s.meter.peakInWindow('attachments');
          final clips = s.media.loads;
          // ignore: avoid_print
          print(
            '[$storage] attachments requests: ${s.meter.countFor('attachments')}, '
            'peak/min $peak of $limit, clip downloads $clips, 429s '
            '${s.meter.rateLimited}, '
            'by route ${s.meter.countsByRoute().entries.where((e) => e.key.contains('attachments')).map((e) => '${e.value} ${e.key}').join('; ')}',
          );
          expect(s.meter.rateLimited, 0, reason: 'the server never says 429');
          expect(s.server.rateLimited, isEmpty);
          // Presigned storage: only the URL requests reach the server, and they
          // must leave most of the limit to the user's other clients. Streamed
          // storage also sends every image and clip through the limiter, where
          // the client's own pacing keeps it under three quarters.
          expect(
            peak,
            lessThanOrEqualTo(local ? (limit * 0.9).floor() : limit ~/ 2),
          );
          // Each of the 17 clips is fetched about once for the session, not once
          // per pass (before: 12 times each).
          expect(
            clips,
            lessThanOrEqualTo(2 * 17),
            reason: 'clip downloads: $clips',
          );
          // No speculative signing: only images without a thumbnail (`raw-*`,
          // visible tiles) are signed while scrolling, in batches; never the
          // thumbnailed ones (`img-*`).
          final signs = s.meter
              .countsByRoute()
              .entries
              .where((e) => e.key.contains('/attachments/urls'))
              .fold<int>(0, (a, b) => a + b.value);
          final singles = s.meter
              .countsByRoute()
              .entries
              .where((e) => RegExp(r'/attachments/[^/]+/url$').hasMatch(e.key))
              .fold<int>(0, (a, b) => a + b.value);
          expect(singles, 0, reason: 'single signing requests while scrolling');
          expect(
            signs,
            lessThanOrEqualTo(30),
            reason: 'batched signing of visible no-thumbnail tiles only',
          );
          // The same URL question is not asked twice inside its validity.
          final repeated = s.meter
              .duplicates(within: const Duration(seconds: 60))
              .entries
              .where(
                (e) =>
                    e.key.contains('/attachments/') && e.key.contains('/url'),
              )
              .fold<int>(0, (a, b) => a + b.value);
          expect(repeated, 0, reason: 'single url requests repeated');
        });
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  }
}
