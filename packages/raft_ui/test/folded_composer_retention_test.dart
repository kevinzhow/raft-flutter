import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'fold/split retains real editor and excludes hidden actions $family/$dark',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(957, 720);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        var thread = false, sends = 0;
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return RaftAdaptiveWorkspace(
                    rail: const SizedBox(),
                    sidebar: const SizedBox(),
                    content: Align(
                      alignment: Alignment.bottomCenter,
                      child: RaftComposer(
                        key: const Key('main-editor'),
                        onSend: (_) async {
                          sends++;
                          return true;
                        },
                      ),
                    ),
                    thread: thread
                        ? const Center(child: Text('Visible thread'))
                        : null,
                  );
                },
              ),
            ),
          ),
        );
        final finder = find.byKey(
          const Key('main-editor'),
          skipOffstage: false,
        );
        final dynamic state = t.state(finder);
        final controller = t
            .widget<TextField>(
              find.descendant(of: finder, matching: find.byType(TextField)),
            )
            .controller!;
        await t.enterText(find.byType(TextField), '中文 草稿 日本語');
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 5,
        );
        await t.pump();
        final value = controller.value;
        update(() => thread = true);
        await t.pump();
        expect(t.state(finder), same(state));
        expect(find.byType(TextField), findsNothing);
        expect(controller.value, value);
        expect((state.focus as FocusNode).hasFocus, isFalse);
        await state.send();
        expect(sends, 0, reason: 'Hidden retained editor cannot initiate send');
        t.view.physicalSize = const Size(1280, 720);
        await t.pump();
        expect(t.state(finder), same(state));
        expect(find.byType(TextField), findsOneWidget);
        expect(controller.value, value);
        t.view.physicalSize = const Size(390, 720);
        await t.pump();
        expect(t.state(finder), same(state));
        expect(find.byType(TextField), findsNothing);
        update(() => thread = false);
        await t.pump();
        expect(t.state(finder), same(state));
        expect(controller.value, value);
        expect(find.byType(TextField), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
  testWidgets(
    'hidden editor closes suggestions and keeps structured mentions',
    (t) async {
      var visible = true, requests = 0;
      late StateSetter update;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return Column(
                  children: [
                    const Spacer(),
                    Visibility(
                      visible: visible,
                      maintainState: true,
                      child: RaftComposer(
                        suggestions: const [
                          RaftComposerSuggestion(
                            type: 'agent',
                            id: 'cindy',
                            name: 'Cindy',
                            title: 'Cindy agent',
                          ),
                        ],
                        onSuggestionsRequested: (_) => requests++,
                        onSend: (_) async => true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), '@Cin');
      await t.pump();
      await t.pump();
      expect(
        find.byKey(const ValueKey('composer-suggestion-agent-cindy')),
        findsOneWidget,
      );
      final dynamic state = t.state(find.byType(RaftComposer));
      update(() => visible = false);
      await t.pump();
      await t.pump();
      expect(
        find.byKey(const ValueKey('composer-suggestion-agent-cindy')),
        findsNothing,
      );
      final before = requests;
      (state.controller as TextEditingController).value =
          const TextEditingValue(
            text: '@Cindy',
            selection: TextSelection.collapsed(offset: 6),
          );
      await t.pump();
      expect(
        requests,
        before,
        reason: 'Hidden draft updates cannot request private directory work',
      );
      update(() => visible = true);
      await t.pump();
      await t.pump();
      await t.tap(
        find.byKey(const ValueKey('composer-suggestion-agent-cindy')),
      );
      await t.pump();
      expect(state.mentions, contains('Cindy'));
      final value = (state.controller as TextEditingController).value;
      update(() => visible = false);
      await t.pump();
      update(() => visible = true);
      await t.pump();
      expect(t.state(find.byType(RaftComposer)), same(state));
      expect(state.mentions, contains('Cindy'));
      expect((state.controller as TextEditingController).value, value);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('accepted same-editor send clears original draft while folded', (
    t,
  ) async {
    final ack = Completer<bool>();
    var hidden = false;
    late StateSetter update;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Visibility(
                visible: !hidden,
                maintainState: true,
                child: RaftComposer(onSend: (_) => ack.future),
              );
            },
          ),
        ),
      ),
    );
    await t.enterText(find.byType(TextField), 'Already sent 中文');
    final dynamic state = t.state(find.byType(RaftComposer));
    final pending = state.send() as Future<void>;
    await t.pump();
    update(() => hidden = true);
    await t.pump();
    ack.complete(true);
    await pending;
    await t.pump();
    expect((state.controller as TextEditingController).text, isEmpty);
    update(() => hidden = false);
    await t.pump();
    expect(t.state(find.byType(RaftComposer)), same(state));
    expect(t.takeException(), isNull);
  });
}
