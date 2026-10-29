import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.21.23 `ForwardedBundleCard`: the "from #channel" label opens the
/// source message when the source is public and still has a place to open.
Map<String, dynamic> bundle({
  String type = 'channel',
  String visibility = 'public',
  String provenance = 'available',
  bool ids = true,
}) => {
  'kind': 'forwarded-bundle',
  'version': 1,
  'forwardedItems': [
    {
      'index': 0,
      'provenanceState': provenance,
      'sourceTargetSnapshot': {
        'type': type,
        'label': 'general',
        'labelVisibility': visibility,
      },
      'sourceAuthorSnapshot': {'type': 'user', 'uniqueName': 'ann'},
      'contentSnapshot': 'hello',
      if (ids) ...{
        'sourceMessageId': 'm1',
        'sourceTargetId': 'c1',
        'sourceThreadId': 't1',
        'parentChannelId': 'p1',
        'sourceMessageSeq': 3,
      },
    },
  ],
};

void main() {
  Future<List<Map<String, dynamic>>> pump(
    WidgetTester tester,
    Map<String, dynamic> metadata,
  ) async {
    final opened = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftForwardedBundle(
            metadata: metadata,
            onOpenSource: opened.add,
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('a public channel source opens its message from the label', (
    tester,
  ) async {
    final opened = await pump(tester, bundle());
    final label = find.byKey(const Key('forwarded-bundle-source'));
    expect(label, findsOneWidget);
    expect(find.text('from general'), findsOneWidget);
    await tester.tap(label);
    expect(opened.single, {
      'sourceMessageId': 'm1',
      'sourceTargetId': 'c1',
      'sourceThreadId': 't1',
      'parentChannelId': 'p1',
      'sourceTargetSnapshot': {'type': 'channel'},
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a thread source needs its thread and parent channel ids', (
    tester,
  ) async {
    final item =
        (bundle(type: 'thread')['forwardedItems'] as List).single
            as Map<String, dynamic>;
    item.remove('parentChannelId');
    await pump(tester, bundle(type: 'thread')..['forwardedItems'] = [item]);
    expect(find.byKey(const Key('forwarded-bundle-source')), findsNothing);
    expect(find.textContaining('general'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (name, metadata) in [
    ('a restricted label', bundle(visibility: 'restricted')),
    ('an unavailable original', bundle(provenance: 'original_unavailable')),
    ('a DM source', bundle(type: 'dm')),
    ('no source ids', bundle(ids: false)),
  ]) {
    testWidgets('$name stays plain text', (tester) async {
      await pump(tester, metadata);
      expect(find.byKey(const Key('forwarded-bundle-source')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
