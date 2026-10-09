import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/features/workspace_grid_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'parity/parity_harness.dart' show loadParityFonts;

Future<void> drain(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets(
    '[N22c] actual mode switch keeps retained editors at the Source1023/1024 boundary',
    (t) async {
      final proofDir = Platform.environment['WORKSPACE_PROOF_DIR'];
      if (proofDir != null) await t.runAsync(loadParityFonts);
      final proofRoot = GlobalKey();
      Future<void> capture(String name) async {
        if (proofDir == null) return;
        await t.pump();
        final boundary =
            proofRoot.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await Directory(proofDir).create(recursive: true);
          await File('$proofDir/$name.png')
              .writeAsBytes(data.buffer.asUint8List());
          image.dispose();
        });
      }

      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final (w, a) = (await t.runAsync(() => fixture('owner')))!;
      final c2 = RaftChannel({
        'id': 'c2',
        'name': 'second',
        'joined': true,
        'type': 'channel',
      });
      w.channels.add(c2);
      w.ledger.switchServer('s1');
      w.drafts['c1'] = '保留原窗口';
      for (final id in ['c1', 'c2']) {
        a.routes['GET /messages/channel/$id'] = (_) => {
          'messages': [
            {
              'id': 'm-$id',
              'channelId': id,
              'seq': '1',
              'senderId': 'alice',
              'content': 'row $id',
            },
          ],
          'hasMore': false,
        };
        a.routes['POST /channels/$id/read'] = (_) => {};
        a.routes['GET /tasks/channel/$id'] = (_) => [];
      }
      a.routes['GET /agents'] = (_) => [];
      a.routes['GET /servers/s1/members'] = (_) => [];
      a.routes['GET /servers/s1/settings'] = (_) => {
        'projection': {'blocksChat': false},
      };
      w.setSection('settings');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: RepaintBoundary(
            key: proofRoot,
            child: WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await drain(t);
      expect(find.byType(RaftWorkspaceModeCard), findsOneWidget);
      await capture('classic-account-mode-card');
      await t.tap(
        find.descendant(
          of: find.byType(RaftWorkspaceModeCard),
          matching: find.byType(RaftCheckbox),
        ),
      );
      await drain(t);
      expect(find.byType(WorkspaceGridView), findsOneWidget);
      expect(
        t
            .getTopLeft(find.byKey(const ValueKey('editor-tab-route:settings')))
            .dy,
        0,
      );
      expect(
        find.byKey(const ValueKey('editor-tab-route:settings')),
        findsOneWidget,
      );
      final second = find.byKey(const ValueKey('sidebar-channel-c2'));
      await t.ensureVisible(second);
      await t.tap(second);
      await drain(t);
      expect(find.byKey(const ValueKey('editor-tab-c2')), findsOneWidget);
      expect(w.channel?.id, 'c1');
      final host = t.state<WorkspaceGridViewState>(
        find.byType(WorkspaceGridView),
      );
      expect(host.sessions.controllers['c2']?.messages.single.id, 'm-c2');
      host.split('c2');
      await drain(t);
      expect(host.groups.length, 2);
      await capture('two-independent-editor-groups');
      final edit = find.descendant(
        of: find.byKey(const ValueKey('editor-group-workspace-group-1')),
        matching: find.descendant(
          of: find.byType(RaftComposer),
          matching: find.byType(TextField),
        ),
      );
      await t.enterText(edit, '新独立草稿');
      await t.pump();
      host.flushDrafts();
      expect(w.drafts['c2'], '新独立草稿');
      final editorState = t.state(edit);
      final editorController = t.widget<TextField>(edit).controller!;
      editorController.selection = const TextSelection.collapsed(offset: 3);
      t.view.physicalSize = const Size(1023, 900);
      await drain(t);
      expect(find.byType(WorkspaceGridView), findsNothing);
      expect(host.sessions.controllers['c2']!.foreground, false);
      expect(find.byType(RaftComposer), findsOneWidget);
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(1024, 900);
      await drain(t);
      expect(find.byType(WorkspaceGridView), findsOneWidget);
      expect(t.state(edit), same(editorState));
      expect(editorController.text, '新独立草稿');
      expect(editorController.selection.baseOffset, 3);
      expect(host.sessions.controllers['c2']!.foreground, true);
      expect(t.takeException(), isNull);
      // Source lg breakpoint suspends grid ownership without destroying
      // retained desktop editors or laying out two groups at phone width.
      t.view.physicalSize = const Size(390, 900);
      await drain(t);
      expect(find.byType(WorkspaceGridView), findsNothing);
      expect(host.sessions.controllers['c2']!.foreground, false);
      await capture('classic-narrow-retained-editors');
      final classicEdit = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(TextField),
      );
      await t.enterText(classicEdit, '窄屏更新原草稿');
      await t.pump();
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(1400, 900);
      await drain(t);
      expect(t.state(edit), same(editorState));
      expect(editorController.text, '新独立草稿');
      expect(editorController.selection.baseOffset, 3);
      expect(host.sessions.controllers['c2']!.foreground, true);
      expect(host.sessions.controllers['c1']!.drafts['c1'], '窄屏更新原草稿');
      expect(find.text('窄屏更新原草稿'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('editor-tab-route:settings')));
      await drain(t);
      expect(w.section, 'settings');
      final card = find.byType(RaftWorkspaceModeCard);
      expect(t.widget<RaftWorkspaceModeCard>(card).enabled, true);
      await t.tap(
        find.descendant(of: card, matching: find.byType(RaftCheckbox)),
      );
      await drain(t);
      expect(find.byType(WorkspaceGridView), findsNothing);
      expect(w.channel?.id, 'c1');
      expect(w.drafts['c1'], '窄屏更新原草稿');
      expect(w.client.user?.id, 'alice');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 400));
      w.dispose();
    },
  );
}
