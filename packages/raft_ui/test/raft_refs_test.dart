import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_ref_target.dart';

void main() {
  test('raftRefs parses both qualified forms as task targets', () {
    for (final target in ['#design:#7', 'dm:@Twin~agent:#7']) {
      final parsed = raftParseRefTarget(target);
      expect(parsed?.kind, RaftRefKind.task, reason: target);
      expect(parsed?.taskNumber, 7);
      expect(parsed?.text, target);
    }
    for (final target in ['#design:#7a', '#design:#7:#8', 'dm:@Twin:#0']) {
      expect(raftParseRefTarget(target), isNull, reason: target);
    }
  });
}
