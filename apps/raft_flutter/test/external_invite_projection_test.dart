import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_footer_states.dart';
import 'package:raft_flutter/features/external_mentions.dart';

import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  test(
    'explicitly non-mentionable external people stay out of suggestions',
    () {
      final member = {
        'provider': 'slack',
        'id': 'projection',
        'displayName': 'External',
        'handles': ['external'],
      };
      expect(
        externalMentionSuggestion('https://example.invalid', member),
        isNotNull,
      );
      expect(
        externalMentionSuggestion('https://example.invalid', {
          ...member,
          'mentionable': false,
        }),
        isNull,
      );
    },
  );

  test(
    'a bound guest can post while an older public guest stays read-only',
    () async {
      final (workspace, _) = await fixture('guest');
      addTearDown(workspace.dispose);
      final now = DateTime(2026, 11, 18);
      workspace.channel = RaftChannel({
        'id': 'guest',
        'type': 'private',
        'joined': true,
      });
      expect(channelFooterKind(workspace, now), ChannelFooterKind.composer);
      workspace.channel = RaftChannel({
        'id': 'guest',
        'type': 'channel',
        'joined': true,
      });
      expect(
        channelFooterKind(workspace, now),
        ChannelFooterKind.guestReadOnly,
      );
    },
  );

  test('external freeze can lock a private channel at its deadline', () {
    final row = {'type': 'private', 'externalFreezeAt': '2026-11-18T00:00:00Z'};
    expect(jointChannelReadOnly(row, DateTime.utc(2026, 11, 17)), isFalse);
    expect(jointChannelReadOnly(row, DateTime.utc(2026, 11, 18)), isTrue);
  });
}
