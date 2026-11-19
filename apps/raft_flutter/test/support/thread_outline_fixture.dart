import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

class ThreadOutlineTestWorkspace extends WorkspaceController {
  ThreadOutlineTestWorkspace(super.client);

  final requests = <String>[];
  final jumps = <String>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    requests.add(path);
    if (path == '/channels/threads/followed') {
      return {
        'threads': [
          {'parentMessageId': 'parent', 'threadChannelId': 'replies'},
        ],
      };
    }
    if (path == '/messages/channel/replies/human-outline') {
      expect(query, {'limit': 200});
      return {
        'hasMore': false,
        'items': [
          for (var i = 4; i >= 1; i--)
            {
              'id': i == 1 ? 'old-reply' : 'reply-$i',
              'seq': i + 1,
              'senderId': 'u',
              'senderName': 'Casey',
              'createdAt': '2026-11-19T01:00:00Z',
              'preview': i == 1 ? 'An older outline reply' : 'Outline reply $i',
              'attachmentCount': 0,
            },
        ],
      };
    }
    throw StateError('Unexpected request: $path');
  }

  @override
  Future<void> openThreadIdentity({
    required String parentChannelId,
    required String parentMessageId,
    String? focusedMessageId,
    String? initialThreadChannelId,
    bool navigate = true,
  }) async {
    expect(parentChannelId, 'channel');
    expect(parentMessageId, 'parent');
    expect(initialThreadChannelId, 'replies');
    expect(navigate, isFalse);
    jumps.add(focusedMessageId!);
  }
}
