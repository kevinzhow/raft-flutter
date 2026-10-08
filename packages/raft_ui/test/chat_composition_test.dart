import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    Future<void> mount(
      WidgetTester tester,
      Widget child, {
      RaftDensity density = RaftDensity.desktop,
      double width = 800,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: RaftDensityScope(
              density: density,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 320, child: child),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('$family/$dark empty groups follow actual mounted predicates', (
      tester,
    ) async {
      final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
      for (final kind in RaftChatSidebarGroupKind.values) {
        final recipe = RaftChatSidebarGroupRecipe(tokens, kind);
        expect(
          recipe.hidden(count: 0, loading: false, hideEmpty: true),
          kind != RaftChatSidebarGroupKind.channels,
        );
        expect(recipe.hidden(count: 0, loading: true, hideEmpty: true), false);
        expect(recipe.hidden(count: 1, loading: false, hideEmpty: true), false);
        expect(
          recipe.hidden(count: 0, loading: false, hideEmpty: false),
          false,
        );
        expect(
          recipe.hidden(
            count: 0,
            loading: false,
            hideEmpty: true,
            dragActive: true,
            dragSource: true,
          ),
          false,
        );
        expect(
          recipe.hidden(
            count: 0,
            loading: false,
            hideEmpty: true,
            dragActive: true,
          ),
          kind == RaftChatSidebarGroupKind.directMessages,
        );
      }
      await mount(
        tester,
        Column(
          children: [
            for (final kind in RaftChatSidebarGroupKind.values)
              RaftChatSidebarGroup(
                kind: kind,
                label: kind.name,
                count: 0,
                expanded: true,
                hideEmpty: false,
                emptyLabel: 'hint-${kind.name}',
                onExpandedChanged: (_) {},
                children: const [],
              ),
          ],
        ),
      );
      expect(find.text('hint-pinned'), findsOneWidget);
      expect(find.text('hint-joint'), findsOneWidget);
      expect(find.text('hint-channels'), findsOneWidget);
      expect(find.text('hint-directMessages'), findsNothing);
    });

    testWidgets(
      '$family/$dark loading substitutes exact rows and reduced motion is finite',
      (tester) async {
        await mount(
          tester,
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Column(
              children: [
                for (final kind in RaftChatSidebarGroupKind.values)
                  RaftChatSidebarGroup(
                    kind: kind,
                    label: kind.name,
                    count: 0,
                    expanded: true,
                    hideEmpty: true,
                    loading: true,
                    emptyLabel: 'hint-${kind.name}',
                    onExpandedChanged: (_) {},
                    children: const [],
                  ),
              ],
            ),
          ),
        );
        expect(find.text('hint-pinned'), findsOneWidget);
        expect(find.text('hint-joint'), findsNothing);
        final skeletons = tester
            .widgetList<RaftChatSidebarLoadingRows>(
              find.byType(RaftChatSidebarLoadingRows),
            )
            .toList();
        expect(skeletons.map((s) => s.rows), [2, 4, 3]);
        expect(
          tester.getSize(find.byType(RaftChatSidebarLoadingRows).last).height,
          3 * 34,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.hasScheduledFrame, false);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '$family/$dark collapse and actions are controlled independently',
      (tester) async {
        var expanded = true, sorted = 0;
        await mount(
          tester,
          StatefulBuilder(
            builder: (context, update) => RaftChatSidebarGroup(
              kind: RaftChatSidebarGroupKind.channels,
              label: 'Channels',
              count: 1,
              expanded: expanded,
              hideEmpty: true,
              disclosureKey: const ValueKey('controlled-disclosure'),
              onExpandedChanged: (value) => update(() => expanded = value),
              actions: [
                RaftSidebarSectionAction(
                  key: const ValueKey('sort'),
                  glyph: RaftGlyph.arrowDownUp,
                  label: 'Sort channels',
                  onPressed: () => sorted++,
                ),
              ],
              children: const [Text('permitted channel')],
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('sort')));
        await tester.pump();
        expect(sorted, 1);
        expect(expanded, true);
        await tester.tap(find.byKey(const ValueKey('controlled-disclosure')));
        await tester.pump();
        expect(expanded, false);
        expect(find.text('permitted channel'), findsNothing);
        expect(find.byKey(const ValueKey('sort')), findsOneWidget);
      },
    );

    testWidgets(
      '$family/$dark tabs select via pointer and arrows skip disabled',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var selected = RaftConversationTabId.chat;
          final receipts = <RaftConversationTabId>[];
          await mount(
            tester,
            StatefulBuilder(
              builder: (context, update) => RaftConversationTabs(
                tabs: const [
                  RaftConversationTab(
                    id: RaftConversationTabId.chat,
                    label: 'Chat',
                  ),
                  RaftConversationTab(
                    id: RaftConversationTabId.tasks,
                    label: 'Tasks',
                  ),
                  RaftConversationTab(
                    id: RaftConversationTabId.files,
                    label: 'Files',
                    enabled: false,
                  ),
                ],
                value: selected,
                onChanged: (value) {
                  receipts.add(value);
                  update(() => selected = value);
                },
              ),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('panel-tab-chat')));
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(selected, RaftConversationTabId.tasks);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
          expect(selected, RaftConversationTabId.chat);
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pump();
          expect(selected, RaftConversationTabId.tasks);
          await tester.tap(find.byKey(const ValueKey('panel-tab-files')));
          await tester.pump();
          expect(selected, RaftConversationTabId.tasks);
          expect(
            receipts.where((value) => value == RaftConversationTabId.files),
            isEmpty,
          );
          final nodes = tester.widgetList<Semantics>(find.byType(Semantics));
          expect(
            nodes.where((node) => node.properties.role == SemanticsRole.tabBar),
            hasLength(1),
          );
          final tasks = nodes.singleWhere(
            (node) =>
                node.properties.role == SemanticsRole.tab &&
                node.properties.label == 'Tasks',
          );
          expect(tasks.properties.selected, true);
          expect(tasks.properties.focused, true);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('$family/$dark tabs paint/list/hit contracts remain separate', (
      tester,
    ) async {
      for (final mobile in [false, true]) {
        for (final density in RaftDensity.values) {
          await mount(
            tester,
            RaftConversationTabs(
              tabs: const [
                RaftConversationTab(
                  id: RaftConversationTabId.chat,
                  label: 'Chat',
                ),
                RaftConversationTab(
                  id: RaftConversationTabId.tasks,
                  label: 'Tasks',
                ),
              ],
              value: RaftConversationTabId.chat,
              onChanged: (_) {},
            ),
            density: density,
            width: mobile ? 390 : 1000,
          );
          final tokens = raftTheme(family, dark: dark).extension<RaftTokens>()!;
          final recipe = RaftConversationTabsRecipe(
            tokens,
            mobile: mobile,
            density: density,
          );
          expect(
            tester.getSize(find.byType(RaftConversationTabs)).height,
            recipe.effectiveListHeight + recipe.outerBottomBorder,
          );
          final control = find.byKey(const ValueKey('panel-tab-chat'));
          final face = find.descendant(
            of: control,
            matching: find.byType(AnimatedContainer),
          );
          expect(tester.getSize(face).height, recipe.sourceTabHeight);
          expect(tester.getSize(control).height, recipe.targetHeight);
          expect(
            recipe.effectiveListHeight,
            greaterThanOrEqualTo(recipe.targetHeight),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
      '$family/$dark task pointer preserves editor focus, keyboard toggles once',
      (tester) async {
        final editorFocus = FocusNode();
        try {
          var checked = false, calls = 0;
          await mount(
            tester,
            StatefulBuilder(
              builder: (context, update) => Column(
                children: [
                  TextField(focusNode: editorFocus),
                  RaftComposerTaskToggle(
                    checked: checked,
                    label: 'As task',
                    onChanged: (value) {
                      calls++;
                      update(() => checked = value);
                    },
                  ),
                ],
              ),
            ),
          );
          editorFocus.requestFocus();
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('composer-as-task-toggle')),
          );
          await tester.pump();
          expect(editorFocus.hasFocus, true);
          expect(checked, true);
          expect(calls, 1);
          tester
              .widget<RaftControl>(
                find.byKey(const ValueKey('composer-as-task-toggle')),
              )
              .focusNode!
              .requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          expect(checked, false);
          expect(calls, 2);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          editorFocus.dispose();
        }
      },
    );

    testWidgets(
      '$family/$dark header actions real callbacks, narrow day label bounded',
      (tester) async {
        var searches = 0, settings = 0;
        await mount(
          tester,
          Column(
            children: [
              RaftConversationHeaderActions(
                onSearch: () => searches++,
                onSettings: () => settings++,
                searchLabel: 'Search conversation',
                settingsLabel: 'Conversation settings',
              ),
              const SizedBox(
                width: 180,
                child: RaftConversationDateHeader(
                  label: '星期四 · Thursday 日本語 2026年10月08日',
                ),
              ),
            ],
          ),
          width: 390,
        );
        await tester.tap(find.byKey(const ValueKey('channel-topbar-search')));
        await tester.tap(
          find.byKey(const ValueKey('channel-overflow-trigger')),
        );
        await tester.pump();
        expect((searches, settings), (1, 1));
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(RaftConversationDateHeader)).width,
          180,
        );
      },
    );
  }
}
