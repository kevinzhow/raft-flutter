import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test(
    'references are memoised per message and recomputed when a projection changes',
    () async {
      final (w, _) = await fixture('owner');
      addTearDown(w.dispose);
      w.channels = [
        RaftChannel({'id': 'c1', 'name': 'design', 'joined': true}),
        RaftChannel({'id': 'c2', 'name': 'ops', 'joined': true}),
      ];
      const directory = [
        RaftTextReference(text: '@alice', href: 'raft-ref://mention/user/u1'),
      ];
      MessagePresentation presentation(String content, {String id = 'm1'}) =>
          MessagePresentation(
            controller: w,
            message: RaftMessage({
              'id': id,
              'channelId': 'c1',
              'content': content,
            }),
            onExternalLink: (_) {},
            directoryReferences: directory,
          );

      final first = presentation('see #design and #ops, ask @alice').references;
      expect(
        first.map((r) => r.text),
        unorderedEquals(['@alice', '#design', '#ops']),
      );
      // A rebuilt row (new widget, same inputs) reuses the same result.
      expect(
        presentation('see #design and #ops, ask @alice').references,
        same(first),
      );
      // Edited text is a different input.
      final edited = presentation('see #design').references;
      expect(edited.map((r) => r.text), ['#design']);
      // A replaced channel projection drops a removed channel...
      w.channels = [w.channels.first];
      expect(
        presentation(
          'see #design and #ops, ask @alice',
        ).references.map((r) => r.text),
        unorderedEquals(['@alice', '#design']),
      );
      // ...and so does an in-place removal.
      w.channels = [
        ...w.channels,
        RaftChannel({'id': 'c2', 'name': 'ops', 'joined': true}),
      ];
      expect(presentation('#ops').references.map((r) => r.text), ['#ops']);
      w.channels.removeWhere((c) => c.id == 'c2');
      expect(presentation('#ops').references, isEmpty);
    },
  );
}
