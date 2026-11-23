import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_timeline_presentation.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('a live tick reuses the style revision for mounted rows', (
    tester,
  ) async {
    final presentation = ChatTimelinePresentation();
    final revisions = <Object>[];
    final theme = raftTheme();
    Widget view(int tick, TextScaler scaler) => MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: Builder(
            builder: (context) {
              revisions.add(
                presentation.rowStyle(
                  context,
                  authority: 'thread',
                  user: 'reader',
                  interactive: true,
                  day: '2026-11-23',
                ),
              );
              return Text('Live revision $tick');
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(view(1, TextScaler.noScaling));
    final first = revisions.last;
    await tester.pumpWidget(view(2, TextScaler.noScaling));
    expect(find.text('Live revision 2'), findsOneWidget);
    expect(revisions.last, same(first));

    await tester.pumpWidget(view(3, TextScaler.linear(1.5)));
    expect(revisions.last, isNot(same(first)));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
