import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_reaction_projection.dart';

void main() {
  const legacy = [
    {
      'emoji': '👍',
      'reactorIds': ['alice', 'bob'],
      'reactorNames': ['Alice', 'Bob'],
    },
    {
      'emoji': '🔥',
      'reactorIds': ['bob'],
      'reactorNames': ['Bob'],
    },
  ];
  test(
    'only current principal from a legitimate legacy roster is own-reacted',
    () {
      expect(
        projectedOwnReactions(
          principal: 'alice',
          reactions: legacy,
          completeViewer: null,
        ),
        {'👍'},
      );
      expect(
        projectedOwnReactions(
          principal: 'bob',
          reactions: legacy,
          completeViewer: null,
        ),
        {'👍', '🔥'},
      );
      expect(
        projectedOwnReactions(
          principal: null,
          reactions: legacy,
          completeViewer: null,
        ),
        isEmpty,
      );
    },
  );
  test('complete empty/private state supersedes older legacy membership', () {
    expect(
      projectedOwnReactions(
        principal: 'alice',
        reactions: legacy,
        completeViewer: {},
      ),
      isEmpty,
    );
    expect(
      projectedOwnReactions(
        principal: 'alice',
        reactions: legacy,
        completeViewer: {'🔥'},
      ),
      {'🔥'},
    );
  });
  test('canonical previews and incomplete legacy rows do not infer private choices', () {
    expect(
      projectedOwnReactions(
        principal: 'alice',
        completeViewer: null,
        reactions: [
          {
            'emoji': '👍',
            'previewK': [
              {'id': 'alice', 'displayName': 'Alice'},
            ],
          },
          {
            'emoji': '🔥',
            'reactorIds': ['alice'],
          },
          {
            'emoji': '✅',
            'reactorIds': ['bob'],
            'reactorNames': ['Alice'],
          },
        ],
      ),
      isEmpty,
    );
  });
}
