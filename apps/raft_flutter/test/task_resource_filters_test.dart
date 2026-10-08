import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_filters.dart';

void main() {
  test(
    'task multi-select is OR within typed identities and AND across fields',
    () {
      final f = TaskResourceFilters()
        ..channels.addAll(['c', 'd'])
        ..creators.addAll(['user:same', 'agent:writer'])
        ..assignees.addAll(['unassigned', 'agent:same']);
      Map<String, dynamic> row(
        String creatorType,
        String? assigneeType,
        String? assigneeId,
      ) => {
        'channelId': 'c',
        'createdByType': creatorType,
        'createdById': 'same',
        'claimedByType': assigneeType,
        'claimedById': assigneeId,
      };
      expect(f.matches(row('user', null, null)), true);
      expect(f.matches(row('user', 'agent', 'same')), true);
      expect(f.matches(row('user', 'user', 'same')), false);
      expect(f.matches(row('agent', null, null)), false);
      expect(
        f.matches({...row('user', null, null), 'channelId': 'other'}),
        false,
      );
      expect(
        f.matches({
          ...row('user', null, null),
          'createdByType': 'agent',
          'createdById': 'writer',
        }),
        true,
      );
      f.clear();
      expect(f.isEmpty, true);
      expect(f.matches(row('agent', 'user', 'same')), true);
    },
  );
}
