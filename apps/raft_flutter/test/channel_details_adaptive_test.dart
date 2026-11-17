import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show mountWorkspace, frames;

void main() {
  for (final scenario in [
    (size: const Size(856, 944), platform: TargetPlatform.android),
    (size: const Size(944, 856), platform: TargetPlatform.android),
    (size: const Size(390, 844), platform: TargetPlatform.linux),
  ]) {
    testWidgets(
      'details follows width at ${scenario.size} / ${scenario.platform}',
      (t) async {
        await mountWorkspace(t, scenario.size);
        final app = t.widget<MaterialApp>(find.byType(MaterialApp));
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: scenario.platform),
            home: app.home,
          ),
        );
        await frames(t);
        expect(find.byType(WorkspaceView), findsOneWidget);
        await t.tap(find.byKey(const Key('channel-overflow-trigger')));
        await frames(t, 25);
        expect(find.text('Details'), findsOneWidget);
        final phone = scenario.size.width < 768;
        final close = find.byKey(
          Key(phone ? 'channel-overflow-back' : 'channel-details-close'),
        );
        expect(close, findsOneWidget);
        expect(find.byKey(const Key('channel-overflow-scrim')), findsNothing);
        await t.tap(close);
        await frames(t, 25);
        expect(find.byKey(const Key('channel-details')), findsNothing);
        await t.tap(find.byKey(const Key('channel-overflow-trigger')));
        await frames(t, 25);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(t, 25);
        expect(find.byKey(const Key('channel-details')), findsNothing);
        await t.pumpWidget(const SizedBox.shrink());
        await frames(t);
      },
    );
  }
}
