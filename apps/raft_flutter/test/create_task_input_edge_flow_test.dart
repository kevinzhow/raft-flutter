import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });

  for (final (name, size, platform) in [
    ('narrow desktop', const Size(390, 844), TargetPlatform.linux),
    ('foldable portrait', const Size(856, 944), TargetPlatform.android),
    ('foldable landscape', const Size(944, 856), TargetPlatform.android),
    ('iOS phone', const Size(390, 844), TargetPlatform.iOS),
    ('Android phone', const Size(390, 844), TargetPlatform.android),
  ]) {
    testWidgets('$name input edge keeps both drafts and submits them', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (workspace, api) = await pageFixture(t);
      api.routes['POST /tasks/channel/c1'] = (_) => {'tasks': <dynamic>[]};
      var created = 0;
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            builder: (context, child) => RaftTextScaling(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open-create-task'),
                  onPressed: () => unawaited(
                    CreateTaskDialog.show(
                      context,
                      controller: workspace,
                      channelId: 'c1',
                      onCreated: () async {
                        created++;
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const ValueKey('open-create-task')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('create-task-title-0')),
          'draft alpha',
        );
        await t.tap(find.byKey(const ValueKey('create-task-add-row')));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('create-task-title-1')),
          'draft beta',
        );
        await t.pumpAndSettle();
        final first = find.byWidgetPredicate(
          (w) => w is RaftDialogTextInput && w.controller.text == 'draft alpha',
        );
        expect(first, findsOneWidget);
        final rect = t.getRect(first);
        await t.tapAt(Offset(rect.right - 2, rect.center.dy));
        await t.pumpAndSettle();
        expect(
          t
              .widgetList<RaftDialogTextInput>(find.byType(RaftDialogTextInput))
              .map((w) => w.controller.text)
              .toList(),
          ['draft alpha', 'draft beta'],
        );
        final editable = find.descendant(
          of: first,
          matching: find.byType(EditableText),
        );
        expect(t.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
        await t.enterText(
          find.byKey(const ValueKey('create-task-title-0')),
          'draft alpha edited',
        );
        await t.tap(find.byKey(const ValueKey('create-task-submit')));
        await t.pumpAndSettle();
        final requests = api.calls
            .where((r) => r.method == 'POST' && r.path == '/tasks/channel/c1')
            .toList();
        expect(requests, hasLength(1));
        expect(requests.single.data, {
          'tasks': [
            {'title': 'draft alpha edited'},
            {'title': 'draft beta'},
          ],
        });
        expect(created, 1);
        expect(find.byType(CreateTaskDialog), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    });
  }
}
