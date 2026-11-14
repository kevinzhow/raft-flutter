// Task v2 widgets (Web v1.24): the Backlog status (raft-ui 0.95.3: no hue, a
// hollow pixel, a hairline edge), the task list under a message
// (TaskChipList), the head field editor (TaskHeadEditor) and the reason step.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _mount(WidgetTester t, Widget child, {double width = 640}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
  await t.pump();
}

void main() {
  test('Backlog is a status of its own, labelled and never a hue', () {
    expect(raftTaskStatusVocabulary.first, 'backlog');
    expect(raftTaskStatuses, isNot(contains('backlog')));
    expect(raftTaskCreateStatuses, ['backlog', 'todo', 'in_progress']);
    expect(raftTaskStatusLabel('backlog'), 'Backlog');
    expect(raftTaskStatusOf('backlog'), RaftMessageTaskStatus.backlog);
    final tokens = raftTheme().extension<RaftTokens>()!;
    final recipe = RaftMessageTaskChipRecipe(
      tokens,
      RaftMessageTaskStatus.backlog,
    );
    expect(recipe.background.a, 0);
    expect(recipe.foreground, tokens.ui.foreground);
    expect(recipe.side().color, tokens.colors['line-hairline']);
  });

  testWidgets('the task list under a message: one row per task, its count '
      'and unread pixel, the assignee and the status', (t) async {
    final opened = <String>[];
    await _mount(
      t,
      RaftTaskChipList(
        tasks: const [
          RaftTaskChipRow(
            id: 'a',
            number: 11,
            title: 'Write the notes',
            status: 'todo',
            replyCount: 3,
            unread: true,
            assigneeName: 'Bob',
          ),
          RaftTaskChipRow(
            id: 'b',
            number: 12,
            title: 'Park the rest',
            status: 'backlog',
            assigneeName: 'Alice',
            assigneeIsViewer: true,
          ),
        ],
        onOpen: (row) => opened.add(row.id),
      ),
    );
    expect(find.text('#11'), findsOneWidget);
    expect(find.text('Write the notes'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-task-chip-unread')),
      findsOneWidget,
    );
    expect(find.text('Bob'), findsOneWidget);
    // The reader is "You".
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Backlog'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Open task #11: Write the notes, 3 messages in this task, new ones you follow',
      ),
      findsOneWidget,
    );
    // At least 320px, at most the column.
    final box = t.getSize(find.byKey(const ValueKey('message-task-chip-list')));
    expect(box.width, greaterThanOrEqualTo(320));
    expect(box.width, lessThanOrEqualTo(640));
    await t.tap(find.text('Park the rest'));
    expect(opened, ['b']);
  });

  testWidgets('the head editor: Enter saves, Esc cancels, a blank title is '
      "refused, someone else's edit warns before it is replaced", (t) async {
    final saves = <String>[];
    var value = 'Ship it';
    var closed = 0;
    late StateSetter rebuild;
    RaftTaskAmendOutcome next = const RaftTaskAmendSaved();
    await _mount(
      t,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return RaftTaskHeadFieldEditor(
            field: RaftTaskHeadField.title,
            value: value,
            onSave: (text) async {
              saves.add(text);
              return next;
            },
            onClose: () => closed++,
          );
        },
      ),
    );
    await t.pump();
    final input = find.descendant(
      of: find.byKey(const ValueKey('task-head-title-input')),
      matching: find.byType(EditableText),
    );
    await t.enterText(input, '   ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.text('A task needs a title.'), findsOneWidget);
    expect(saves, isEmpty);
    // Someone else changed the title meanwhile: say so, send nothing.
    rebuild(() => value = 'Ship it today');
    await t.pump();
    await t.showKeyboard(input);
    await t.enterText(input, 'Ship it now');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(saves, isEmpty);
    expect(find.byKey(const ValueKey('task-head-edit-notice')), findsOneWidget);
    // Saving again replaces their text.
    await t.showKeyboard(input);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(saves, ['Ship it now']);
    expect(closed, 1);

    // Esc cancels without saving.
    await _mount(
      t,
      RaftTaskHeadFieldEditor(
        field: RaftTaskHeadField.description,
        value: 'Notes',
        onSave: (text) async {
          saves.add(text);
          return const RaftTaskAmendSaved();
        },
        onClose: () => closed++,
      ),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(closed, 2);
    expect(saves, ['Ship it now']);
  });

  testWidgets('the reason step: optional, trimmed, and it stays with the '
      'failure', (t) async {
    final reasons = <String>[];
    var cancelled = false;
    var ok = false;
    await _mount(
      t,
      RaftTaskReasonPanel(
        kind: RaftTaskReasonKind.handoff,
        name: 'Carol',
        onSubmit: (reason) async {
          reasons.add(reason);
          return ok;
        },
        onCancel: () => cancelled = true,
      ),
    );
    expect(find.text('Hand to Carol'), findsWidgets);
    expect(
      find.text('What are you waiting on Carol for? (optional)'),
      findsWidgets,
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-handoff-reason-input')),
        matching: find.byType(EditableText),
      ),
      '  the copy  ',
    );
    await t.tap(find.byKey(const ValueKey('task-handoff-reason-confirm')));
    await t.pump();
    expect(reasons, ['the copy']);
    expect(find.text("Couldn't assign the task. Try again."), findsOneWidget);
    ok = true;
    await t.tap(find.byKey(const ValueKey('task-handoff-reason-cancel')));
    expect(cancelled, isTrue);
  });
}
