import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'mounted_message_navigation_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('mounted empty channel follows Source content/$id/$dark', (
        tester,
      ) async {
        final (w, api) = await pageFixture(tester);
        api.routes['GET /announcements/active'] = (_) => null;
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id), dark: dark),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(themeId: id),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Mounted ChatPanel.tsx:1620 and en.ts:2359-2360, shared product copy.
        final empty = find.byType(RaftEmptyState);
        expect(empty, findsOneWidget);
        expect(
          find.descendant(of: empty, matching: find.text('No messages yet')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: empty,
            matching: find.text('Start the conversation.'),
          ),
          findsOneWidget,
        );
        expect(find.text('Send a message to this channel.'), findsNothing);
        if (id == raftThemePackId) {
          final glyph = tester.widget<RaftIcon>(
            find.descendant(of: empty, matching: find.byType(RaftIcon)),
          );
          expect(glyph.glyph, RaftGlyph.messageSquare);
          expect(glyph.size, 36);
          final title = tester.widget<Text>(find.text('No messages yet'));
          expect(title.style!.fontSize, 17);
          expect(title.style!.height, 22 / 17);
        }
        expect(w.channel!.id, 'c1');
        expect(find.byType(RaftComposer), findsOneWidget);
        final editor = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(EditableText),
          ),
        );
        // ChatPanel composerAutoFocus defaults true; MessageInput restricts
        // it to hover-capable input. The real desktop channel owns this focus.
        expect(editor.focusNode.hasFocus, isTrue);
        final finder = find.byKey(
          const Key('sidebar-conversation-finder-input'),
        );
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(editor.focusNode.hasFocus, isFalse);
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(editor.focusNode.hasFocus, isFalse);

        expect(
          api.calls.where((r) => r.method == 'POST' && r.path == '/messages'),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  }
  for (final width in [390.0, 856.0]) {
    for (final dark in [false, true]) {
      testWidgets('touch channel never requests initial focus/$width/$dark', (
        tester,
      ) async {
        final (w, api) = await pageFixture(tester);
        api.routes['GET /announcements/active'] = (_) => null;
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: const RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(RaftComposer),
            matching: find.byType(EditableText),
          ),
        );
        expect(editor.focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }
}
