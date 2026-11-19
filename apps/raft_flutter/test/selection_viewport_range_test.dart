import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_selection.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test(
    'Select to here moves the anchor to the far visible selectable row',
    () async {
      final (w, _) = await fixture('owner');
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.ledger.ingest([
        for (var i = 1; i <= 6; i++)
          {
            'id': 'm$i',
            'channelId': 'c1',
            'seq': i,
            'content': 'Body $i',
            if (i == 3) 'actionMetadata': {'kind': 'action-card'},
          },
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {for (var i = 1; i <= 6; i++) 'm$i'};
      final selection = MessageSelection(w, thread: false)..enter('m1');
      addTearDown(selection.dispose);
      expect(selection.rangeToVisible(['m1', 'm2']), isNull);
      expect(selection.rangeToVisible(['m4', 'm5'])?.anchorAbove, isTrue);
      selection.selectToVisible(['m4', 'm5']);
      expect(selection.ids, {'m1', 'm2', 'm4', 'm5'});
      expect(selection.anchorId, 'm5');
      expect(selection.rangeToVisible(['m1', 'm2'])?.anchorAbove, isFalse);
      selection.toggle('m5');
      expect(selection.anchorId, isNull);
    },
  );
}
