import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// Source contracts are the pinned Web SelectionPopover and MenuItem, not the
// existing Flutter Container geometry. Selection's ring occupies no layout;
// disabled rows do not carry checked bold, and the italic label slot owns ink.
const _choice = ValueKey('source-choice');
const _disabledChoice = ValueKey('disabled-source-choice');

Widget _host(Widget child, {bool dark = false, double scale = 1}) =>
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w400,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.renderObject<RenderParagraph>(find.text(label)).text.style!;

Future<void> _retire(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'Selection ring reserves no row or surface layout; dark=$dark',
      (tester) async {
        try {
          await tester.pumpWidget(
            _host(
              RaftSelectionPopover(
                title: 'Channels',
                width: 310,
                showHeader: false,
                options: [
                  RaftSelectionOption(
                    rowKey: _choice,
                    label: 'Design',
                    checked: false,
                    onTap: () {},
                  ),
                ],
              ),
              dark: dark,
            ),
          );
          await tester.pump();
          final surface = tester.getRect(find.byType(RaftSelectionPopover));
          final row = tester.getRect(find.byKey(_choice));
          expect(surface.size, const Size(310, 48));
          expect(row.topLeft - surface.topLeft, const Offset(6, 6));
          expect(row.size, const Size(298, 36));
          expect(tester.takeException(), isNull);
        } finally {
          await _retire(tester);
        }
      },
    );

    testWidgets(
      'Selection disabled checked and italic slots stay distinct; dark=$dark',
      (tester) async {
        try {
          await tester.pumpWidget(
            _host(
              RaftSelectionPopover(
                title: 'Assignee',
                width: 310,
                showHeader: false,
                options: [
                  RaftSelectionOption(
                    label: 'Unavailable selected',
                    checked: true,
                    disabled: true,
                    onTap: () => fail('disabled choice activated'),
                  ),
                  RaftSelectionOption(
                    label: 'No assignee',
                    checked: false,
                    disabled: true,
                    italic: true,
                    onTap: () => fail('disabled italic choice activated'),
                  ),
                ],
              ),
              dark: dark,
            ),
          );
          final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
          expect(
            _labelStyle(tester, 'Unavailable selected').fontWeight,
            FontWeight.w400,
          );
          expect(
            _labelStyle(tester, 'Unavailable selected').color,
            tokens.ui.foregroundDisabled,
          );
          expect(
            _labelStyle(tester, 'No assignee').color,
            tokens.ui.foregroundMuted,
          );
          await tester.tap(find.text('Unavailable selected'));
          await tester.tap(find.text('No assignee'));
          expect(tester.takeException(), isNull);
        } finally {
          await _retire(tester);
        }
      },
    );

    testWidgets(
      'Selection preserves search editing and keyed choice updates; dark=$dark',
      (tester) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        final searches = <String>[];
        var clears = 0;
        var picks = 0;
        var checked = false;
        var reverse = false;
        late StateSetter update;
        try {
          await tester.pumpWidget(
            _host(
              StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final choices = [
                    RaftSelectionOption(
                      rowKey: _choice,
                      label: 'Design',
                      checked: checked,
                      reserveLeadingSlot: true,
                      leading: const SizedBox.square(
                        key: ValueKey('caller-leading'),
                        dimension: 12,
                      ),
                      onTap: () => setState(() {
                        picks++;
                        checked = !checked;
                      }),
                    ),
                    RaftSelectionOption(
                      rowKey: _disabledChoice,
                      label: 'Archived',
                      checked: false,
                      disabled: true,
                      onTap: () => fail('disabled choice activated'),
                    ),
                  ];
                  return RaftSelectionPopover(
                    title: 'Channels',
                    width: 310,
                    searchController: controller,
                    searchFocusNode: focus,
                    onSearchChanged: searches.add,
                    onClear: () {
                      clears++;
                      controller.clear();
                    },
                    options: reverse ? choices.reversed.toList() : choices,
                  );
                },
              ),
              dark: dark,
            ),
          );
          await tester.pump();
          await tester.showKeyboard(find.byType(EditableText));
          final editor = tester.state(find.byType(EditableText));
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'des',
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange(start: 0, end: 3),
            ),
          );
          await tester.pump();
          update(() => reverse = true);
          await tester.pump();
          expect(tester.state(find.byType(EditableText)), same(editor));
          expect(focus.hasFocus, isTrue);
          expect(controller.value.composing, const TextRange(start: 0, end: 3));
          expect(
            controller.selection,
            const TextSelection.collapsed(offset: 3),
          );
          expect(searches, ['des']);
          expect(find.byKey(const ValueKey('caller-leading')), findsOneWidget);
          await tester.tap(find.byKey(_disabledChoice));
          await tester.tap(find.byKey(_choice));
          await tester.pump();
          expect(picks, 1);
          expect(_labelStyle(tester, 'Design').fontWeight, FontWeight.w700);
          await tester.tap(find.text('Clear'));
          await tester.pump();
          expect(clears, 1);
          expect(controller.text, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await _retire(tester);
          controller.dispose();
          focus.dispose();
        }
      },
    );

    for (final height in [844.0, 600.0]) {
      testWidgets(
        'InlineBadge retains action weight, disabled ink and viewport row size; dark=$dark height=$height',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(900, height);
          addTearDown(tester.view.reset);
          final calls = <String>[];
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              _host(
                RaftInlineBadgeMenu(
                  minWidth: 180,
                  selectedId: 'todo',
                  options: const [
                    RaftInlineBadgeOption(id: 'todo', label: 'To do'),
                    RaftInlineBadgeOption(
                      id: 'blocked',
                      label: 'Unavailable',
                      disabled: true,
                    ),
                    RaftInlineBadgeOption(id: 'done', label: 'Done'),
                  ],
                  onSelect: calls.add,
                ),
                dark: dark,
              ),
            );
            final tokens = raftTheme(dark: dark).extension<RaftTokens>()!;
            final first = find.bySemanticsLabel('To do');
            expect(tester.getRect(first).height, height <= 600 ? 32 : 36);
            expect(_labelStyle(tester, 'To do').fontWeight, FontWeight.w500);
            expect(
              _labelStyle(tester, 'Unavailable').color,
              tokens.ui.foregroundDisabled,
            );
            await tester.tap(find.text('Unavailable'));
            await tester.tap(find.text('Done'));
            await tester.pump();
            expect(calls, ['done']);
            expect(tester.takeException(), isNull);
          } finally {
            await _retire(tester);
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'Selection large text grows its choice instead of clipping the line',
    (tester) async {
      try {
        await tester.pumpWidget(
          _host(
            RaftSelectionPopover(
              title: 'Channels',
              width: 310,
              showHeader: false,
              options: [
                RaftSelectionOption(
                  rowKey: _choice,
                  label: 'Design',
                  checked: false,
                  onTap: () {},
                ),
              ],
            ),
            scale: 2,
          ),
        );
        expect(
          tester.getRect(find.byKey(_choice)).height,
          greaterThanOrEqualTo(40),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await _retire(tester);
      }
    },
  );
}
