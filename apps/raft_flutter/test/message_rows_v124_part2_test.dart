import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/system_message_grouping.dart';

/// Web v1.24 message-row details, part 2 (app side): the gutter clock
/// (formatGutterClock), the date divider's day rules (formatDayLabel), the
/// confirmed link schemes (externalLinkSchemes.ts), inline HEIC images
/// (urlImageFallback.ts) and the system rows that are never folded
/// (systemMessageGrouping.ts).
void main() {
  SourceTimeFormatter formatter(SourceTimeFormat format) => SourceTimeFormatter(
    locale: 'en',
    preferredTimezone: 'UTC',
    preferredTimeFormat: format,
    todayLabel: 'Today',
    yesterdayLabel: 'Yesterday',
  );

  test('the gutter clock has no day period', () {
    final at = DateTime.utc(2026, 11, 1, 18, 35);
    expect(formatter(SourceTimeFormat.twelveHour).gutterClock(at), '6:35');
    expect(formatter(SourceTimeFormat.twentyFourHour).gutterClock(at), '18:35');
    expect(
      formatter(SourceTimeFormat.twelveHour)
          .gutterClock(DateTime.utc(2026, 11, 1, 0, 5)),
      '12:05',
    );
    expect(
      formatter(SourceTimeFormat.twentyFourHour)
          .gutterClock(DateTime.utc(2026, 11, 1, 7, 5)),
      '07:05',
    );
  });

  test('day labels: yesterday is the calendar day before, year by zone', () {
    final f = formatter(SourceTimeFormat.twentyFourHour);
    final now = DateTime.utc(2026, 3, 1, 10);
    expect(f.dayLabel(DateTime.utc(2026, 3, 1, 1), now: now), 'Today');
    expect(f.dayLabel(DateTime.utc(2026, 2, 28, 23), now: now), 'Yesterday');
    expect(
      f.dayLabel(DateTime.utc(2026, 2, 27, 12), now: now),
      'Friday, February 27',
    );
    expect(
      f.dayLabel(DateTime.utc(2025, 12, 31, 12), now: now),
      'Wednesday, December 31, 2025',
    );
  });

  test('irc, ircs, xmpp and obsidian links open behind the confirmation', () {
    for (final link in [
      'irc://irc.libera.chat/raft',
      'ircs://irc.libera.chat/raft',
      'xmpp:team@example.com',
      'obsidian://open?vault=a',
    ]) {
      expect(isAllowedCustomProtocol(Uri.parse(link)), isTrue, reason: link);
    }
    expect(isAllowedCustomProtocol(Uri.parse('javascript:alert(1)')), isFalse);
    expect(isAllowedCustomProtocol(Uri.parse('file:///etc/passwd')), isFalse);
  });

  test('a HEIC image is inline only with a raster preview', () {
    expect(attachmentIsInlineImage({'mimeType': 'image/heic'}), isFalse);
    expect(
      attachmentIsInlineImage({
        'mimeType': 'image/HEIF; foo=bar',
        'thumbnailUrl': 'https://cdn.example/t.webp',
      }),
      isTrue,
    );
    expect(attachmentIsInlineImage({'mimeType': 'image/png'}), isTrue);
  });

  test(
    'receipts, the WeChat notice and a hand-off with a reason stay rows',
    () {
      RaftMessage system(
        String id,
        String content, [
        Map<String, dynamic>? extra,
      ]) => RaftMessage({
        'id': id,
        'messageType': 'system',
        'content': content,
        'createdAt': '2026-11-01T09:00:00Z',
        ...?extra,
      });
      final messages = [
        system('a', 'Alice joined'),
        system('b', 'Sent for you', {
          'actionMetadata': {'kind': 'delegated-receipt'},
        }),
        system('c', 'Bob joined'),
        system('d', 'WeChat connected', {'randomId': 'wechat-connected:abc'}),
        system('e', 'Carol joined'),
        system('f', 'Kirby handed #7 to Niko', {
          'actionMetadata': {
            'kind': 'task-assignment',
            'taskNumber': 7,
            'actor': {'type': 'agent', 'id': 'kirby'},
            'assignee': {'type': 'agent', 'id': 'niko'},
            'reason': 'Needs the Android device',
          },
        }),
        system('g', 'Dana joined'),
      ];
      final states = buildSystemGroupStates(messages, (key, values) => key);
      // Each own card breaks the run around it: no row is folded at all here.
      expect(states, everyElement(isNull));
    },
  );
}
