import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> bundle() => {
  'kind': 'forwarded-bundle',
  'version': 1,
  'forwardedItems': [
    for (var i = 0; i < 3; i++)
      {
        'index': i,
        'sourceIsThreadParent': i == 0,
        'provenanceState': i == 0 ? 'original_unavailable' : 'available',
        'sourceTargetSnapshot': {
          'type': 'thread',
          'label': 'private-secret-label',
          'labelVisibility': i == 0 ? 'restricted' : 'public',
        },
        'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'author$i'},
        'contentSnapshot': i == 0
            ? List.generate(
                12,
                (line) => 'Copied **message $i** line $line',
              ).join('\n')
            : 'Copied **message $i**',
        'sourceCreatedAt': '2026-10-07T09:0${2 - i}:00Z',
        'sourceMessageSeq': 3 - i,
        'attachmentPolicy': i == 0 ? 'excluded' : 'projected',
        'attachmentSnapshots': [
          {
            'id': 'projection-$i',
            'filename': 'report$i.txt',
            'mimeType': 'text/plain',
            'sizeBytes': 120,
            'url': 'https://secret.invalid/capability',
            'sourceProjectionId': 'private-id',
          },
        ],
      },
  ],
};
void main() {
  test('projection strips private pointers and excluded attachments; parent precedes chronologically sorted replies', () {
    final rows = raftForwardedItems(bundle());
    expect(rows.map((r) => r.index), [0, 2, 1]);
    expect(rows.first.sourceLabel, isNull);
    expect(rows.first.attachments, isEmpty);
    expect(rows[1].attachments.single.keys, [
      'id',
      'filename',
      'mimeType',
      'sizeBytes',
    ]);
    expect(
      rows[1].attachments.single.toString(),
      isNot(contains('secret.invalid')),
    );
    expect(raftForwardedItems({...bundle(), 'version': 2}), isEmpty);
    expect(
      raftForwardedItems({
        ...bundle(),
        'forwardedItems': [
          {'contentSnapshot': 'untrusted'},
        ],
      }),
      isEmpty,
    );
  });
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'recipient snapshot expands without exposing restricted source: $family/$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: RaftForwardedBundle(metadata: bundle()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('private-secret-label'), findsNothing);
        expect(find.text('report0.txt'), findsNothing);
        expect(find.text('report1.txt').hitTestable(), findsNothing);
        await tester.ensureVisible(find.text('View all 3 messages'));
        await tester.tap(find.text('View all 3 messages'));
        await tester.pump();
        await tester.ensureVisible(find.text('report1.txt'));
        expect(find.text('report1.txt').hitTestable(), findsOneWidget);
        expect(find.text('Collapse'), findsOneWidget);
        await tester.ensureVisible(find.text('Collapse'));
        await tester.tap(find.text('Collapse'));
        await tester.pump();
        expect(find.text('report1.txt').hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
