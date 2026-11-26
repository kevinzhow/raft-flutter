import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _harness({
  required bool dark,
  required Size size,
  required double textScale,
  required Widget child,
}) {
  return MaterialApp(
    theme: raftTheme(dark: dark),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: RaftTextScaling(
        child: Scaffold(body: SizedBox.expand(child: child)),
      ),
    ),
  );
}

void main() {
  const sizes = <Size>[Size(390, 844), Size(841, 701), Size(1180, 820)];
  const scales = <double>[1.0, 2.0, 3.1];

  group('Wave 4B E5/E6 layout + Dynamic Type reflow matrix', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      for (final size in sizes) {
        for (final scale in scales) {
          testWidgets(
            'surfaces fit without overflow at ${size.width.toInt()}x${size.height.toInt()} $mode ${scale}x',
            (tester) async {
              addTearDown(() => tester.binding.setSurfaceSize(null));
              await tester.binding.setSurfaceSize(size);

              var selectedIcon = RaftAppIconPalette.yellow;
              var selectedTab = 'a';

              await tester.pumpWidget(
                _harness(
                  dark: dark,
                  size: size,
                  textScale: scale,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return ListView(
                        padding: const EdgeInsets.all(RaftSpace.x4),
                        children: [
                          RaftMermaidBlock(
                            source: 'graph TD\n  A-->B',
                            onCopy: (_) async {},
                            onExport: (_, __) async {},
                          ),
                          const SizedBox(height: RaftSpace.x4),
                          RaftDropdownMenu(
                            kind: RaftMenuKind.dropdownMenu,
                            label: 'Channel filter',
                            entries: [
                              RaftMenuEntry(
                                label: 'All Channels',
                                onPressed: () {},
                              ),
                              RaftMenuEntry(
                                label: 'Engineering',
                                onPressed: () {},
                              ),
                            ],
                            triggerBuilder: (context, focusNode, onPressed) =>
                                RaftPickerTriggerButton(
                                  key: const ValueKey('wave4b-picker-trigger'),
                                  label: 'All Channels',
                                  focusNode: focusNode,
                                  onPressed: onPressed,
                                ),
                          ),
                          const SizedBox(height: RaftSpace.x4),
                          RaftAppIconChoices(
                            selected: selectedIcon,
                            onChanged: (next) =>
                                setState(() => selectedIcon = next),
                          ),
                          const SizedBox(height: RaftSpace.x4),
                          SizedBox(
                            height: 240,
                            child: RaftEditorGroups(
                              groups: [
                                RaftEditorGroup(
                                  id: 'g1',
                                  selected: selectedTab,
                                  tabs: const [
                                    RaftEditorTab(
                                      id: 'a',
                                      label: 'General Channel',
                                      child: SizedBox.shrink(),
                                    ),
                                    RaftEditorTab(
                                      id: 'b',
                                      label: 'Design System',
                                      child: SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ],
                              onSelect: (_, tab) =>
                                  setState(() => selectedTab = tab),
                              onClose: (_) {},
                              onMove: (_, __) {},
                            ),
                          ),
                          const SizedBox(height: RaftSpace.x4),
                          const RaftField(
                            label: 'Display Name',
                            error: 'Must not be empty',
                            child: RaftTextInput(
                              initialValue: '',
                              invalid: true,
                              hintText: 'Enter name',
                            ),
                          ),
                          const SizedBox(height: RaftSpace.x4),
                          const RaftSeparator(),
                          const RaftListRow(
                            variant: RaftListRowVariant.plain,
                            interactive: false,
                            children: [
                              RaftListRowBody(
                                children: [
                                  RaftListRowTitle('Channel settings row'),
                                  RaftListRowDescription(
                                    'Migrated from ListTile',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 200));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      for (final size in sizes) {
        for (final scale in scales) {
          testWidgets(
            'RaftFormDialog + open RaftSelectField fit at ${size.width.toInt()}x${size.height.toInt()} $mode ${scale}x',
            (tester) async {
              addTearDown(() => tester.binding.setSurfaceSize(null));
              await tester.binding.setSurfaceSize(size);

              await tester.pumpWidget(
                _harness(
                  dark: dark,
                  size: size,
                  textScale: scale,
                  child: Center(
                    child: RaftFormDialog(
                      title: 'Channel Visibility',
                      description: 'Choose who can discover this channel.',
                      fields: const [
                        RaftFormField('name', 'Name', initial: 'engineering'),
                        RaftFormField(
                          'visibility',
                          'Visibility',
                          initial: 'workspace',
                          choices: {
                            'workspace': 'Workspace',
                            'private': 'Private',
                          },
                          localizeChoices: false,
                        ),
                      ],
                      onSubmit: (_) async {},
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 200));
              expect(tester.takeException(), isNull);

              final selectFinder = find.byKey(
                const ValueKey('field-visibility'),
              );
              await tester.ensureVisible(selectFinder);
              await tester.tap(selectFinder);
              await tester.pump(const Duration(milliseconds: 200));
              expect(find.text('Private'), findsWidgets);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets(
      'RaftMermaidBlock download menu opens cleanly across sizes and scales',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final size in sizes) {
          for (final scale in scales) {
            await tester.binding.setSurfaceSize(size);
            await tester.pumpWidget(
              _harness(
                dark: scale == 2.0,
                size: size,
                textScale: scale,
                child: Padding(
                  padding: const EdgeInsets.all(RaftSpace.x4),
                  child: RaftMermaidBlock(
                    source: 'graph TD\n  A-->B',
                    onCopy: (_) async {},
                    onExport: (_, __) async {},
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 200));
            final trigger = find.byKey(
              const ValueKey('mermaid-download-trigger'),
            );
            await tester.tap(trigger);
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Download Source'), findsOneWidget);
            expect(tester.takeException(), isNull);

            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.text('Download Source'), findsNothing);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  });

  group('Keyboard Escape focus restore', () {
    testWidgets(
      'RaftFormDialog choice RaftSelectField restores focus on Escape',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            dark: false,
            size: const Size(1180, 820),
            textScale: 1.0,
            child: RaftFormDialog(
              title: 'Select Role',
              fields: const [
                RaftFormField(
                  'role',
                  'Role',
                  initial: 'member',
                  choices: {'member': 'Member', 'admin': 'Admin'},
                  localizeChoices: false,
                ),
              ],
              onSubmit: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final selectFinder = find.byKey(const ValueKey('field-role'));
        final focusBefore = FocusManager.instance.primaryFocus;
        await tester.tap(selectFinder);
        await tester.pumpAndSettle();
        expect(find.text('Admin'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Admin'), findsNothing);
        final focusAfter = FocusManager.instance.primaryFocus;
        expect(focusAfter, isNotNull);
        expect(focusAfter, isNot(equals(focusBefore)));
        expect(focusAfter?.context, isNotNull);
        expect(
          find.ancestor(
            of: find.byElementPredicate(
              (e) => identical(e, focusAfter!.context),
            ),
            matching: selectFinder,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RaftMermaidBlock download RaftDropdownMenu restores trigger focus on Escape',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            dark: false,
            size: const Size(1180, 820),
            textScale: 1.0,
            child: RaftMermaidBlock(
              source: 'graph TD\n  A-->B',
              onCopy: (_) async {},
              onExport: (_, __) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trigger = find.byKey(const ValueKey('mermaid-download-trigger'));
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.text('Download Source'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Download Source'), findsNothing);
        final triggerWidget = tester.widget<RaftButton>(trigger);
        expect(triggerWidget.focusNode?.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'Custom RaftButton RaftDropdownMenu trigger restores focus on Escape',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            dark: false,
            size: const Size(1180, 820),
            textScale: 1.0,
            child: Align(
              alignment: Alignment.topRight,
              child: RaftDropdownMenu(
                kind: RaftMenuKind.dropdownMenu,
                align: RaftDropdownAlign.end,
                label: 'Member Actions',
                entries: [
                  RaftMenuEntry(label: 'Make Admin', onPressed: () {}),
                  RaftMenuEntry(label: 'Remove member', onPressed: () {}),
                ],
                triggerBuilder: (context, focusNode, onPressed) => RaftButton(
                  key: const ValueKey('custom-btn-trigger'),
                  focusNode: focusNode,
                  uiVariant: RaftButtonVariant.ghost,
                  uiSize: RaftButtonSize.iconMd,
                  glyph: RaftGlyph.ellipsisVertical,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trigger = find.byKey(const ValueKey('custom-btn-trigger'));
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.text('Remove member'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Remove member'), findsNothing);
        final triggerWidget = tester.widget<RaftButton>(trigger);
        expect(triggerWidget.focusNode?.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets(
      'RaftPickerTriggerButton RaftDropdownMenu trigger restores focus on Escape',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            dark: false,
            size: const Size(1180, 820),
            textScale: 1.0,
            child: Align(
              alignment: Alignment.topLeft,
              child: RaftDropdownMenu(
                kind: RaftMenuKind.dropdownMenu,
                label: 'Filter by channel',
                entries: [
                  RaftMenuEntry(label: 'All Channels', onPressed: () {}),
                  RaftMenuEntry(label: '#engineering', onPressed: () {}),
                ],
                triggerBuilder: (context, focusNode, onPressed) =>
                    RaftPickerTriggerButton(
                      key: const ValueKey('picker-btn-trigger'),
                      label: 'All Channels',
                      focusNode: focusNode,
                      onPressed: onPressed,
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trigger = find.byKey(const ValueKey('picker-btn-trigger'));
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(find.text('#engineering'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('#engineering'), findsNothing);
        final triggerWidget = tester.widget<RaftPickerTriggerButton>(trigger);
        expect(triggerWidget.focusNode?.hasPrimaryFocus, isTrue);
      },
    );
  });
}
