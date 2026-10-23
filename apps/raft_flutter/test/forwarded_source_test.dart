import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/forwarded_source.dart';

/// Web v1.21.23: a forwarded bundle's source label opens the source message,
/// and the forwarding note shows above the card.
void main() {
  final channels = [
    RaftChannel({'id': 'c1', 'name': 'general', 'type': 'channel'}),
    RaftChannel({'id': 'd1', 'name': 'peer', 'type': 'dm'}),
  ];

  test('a channel source jumps to its message', () {
    expect(
      forwardedSourceHref(channels, {
        'sourceMessageId': 'm1',
        'sourceTargetId': 'c1',
        'sourceTargetSnapshot': {'type': 'channel'},
      }),
      'raft-ref://message/c1/m1',
    );
  });

  test('a thread source resolves its thread through the parent channel', () {
    expect(
      forwardedSourceHref(channels, {
        'sourceMessageId': 'm1',
        'sourceThreadId': 't1',
        'parentChannelId': 'c1',
        'sourceTargetSnapshot': {'type': 'thread'},
      }),
      'raft-ref://thread/c1/m1',
    );
  });

  test('a DM or a channel this server does not list opens nothing', () {
    for (final id in ['d1', 'gone']) {
      expect(
        forwardedSourceHref(channels, {
          'sourceMessageId': 'm1',
          'sourceTargetId': id,
          'sourceTargetSnapshot': {'type': 'channel'},
        }),
        isNull,
      );
    }
  });

  test('the note is what a person typed, never the generated count', () {
    final one = {
      'forwardedItems': [{}],
    };
    final two = {
      'forwardedItems': [{}, {}],
    };
    expect(forwardedNote(one, 'Forwarded 1 message'), '');
    expect(forwardedNote(two, 'Forwarded 2 messages'), '');
    expect(forwardedNote(two, ' Forwarded 2 messages '), '');
    expect(forwardedNote(one, ''), '');
    expect(forwardedNote(one, 'Please read this'), 'Please read this');
    expect(forwardedNote(two, 'Forwarded 1 message'), 'Forwarded 1 message');
  });
}
