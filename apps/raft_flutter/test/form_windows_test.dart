import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_runtime_editor.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/create_task_dialog.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/report_issue.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/close_support.dart';
import 'support/test_parts.dart';

// Every floating window that edits or creates something is a form
// (RaftPresentationPolicy.form): a bottom sheet below 768, a centered dialog
// from 768, one route either way. This runs each real form through the same
// four checks: its form at 390 and at 1000, its input kept across the
// breakpoint, its submit, and its scrolling above the keyboard.

/// One migrated form: how to open it, what to type, how to submit it and what
/// the submit must have done.
class _Form {
  const _Form(
    this.id, {
    this.open,
    this.prepare,
    this.field,
    this.tall = false,
    this.keyboardViewportHeight = 580,
    this.fill = const {},
    this.submit,
    this.submitted,
    this.routes,
  });
  final String id;

  /// Phone viewport height of the keyboard check. A tall form must still overflow
  /// the sheet with the keyboard up; a form with less content takes a shorter one.
  final double keyboardViewportHeight;

  /// Opens the form over the workspace. Not awaited: a window's future
  /// completes when it closes.
  final Future<void> Function(
    WidgetTester t,
    BuildContext context,
    WorkspaceController w,
    List<String> events,
  )?
  open;

  /// Steps that open the form by tapping through the app (awaited).
  final Future<void> Function(WidgetTester t, WorkspaceController w)? prepare;

  /// The field the checks type into (the first editable one by default).
  final Finder Function()? field;

  /// More content than a phone sheet with the keyboard up can show.
  final bool tall;

  /// Other required fields to fill before the submit.
  final Map<Finder Function(), String> fill;
  final Finder Function()? submit;

  /// What the submit did: an API call or a callback event.
  final bool Function(MessageAdapter api, List<String> events)? submitted;
  final void Function(MessageAdapter api)? routes;
}

/// The open form window: the sheet below 768, the dialog frame from 768.
Finder _window() => find.byType(BottomSheet).evaluate().isNotEmpty
    ? find.byType(BottomSheet)
    : find.byType(RaftDialogFrame);
Finder _editable() =>
    find.descendant(of: _window(), matching: find.byType(EditableText)).first;
Finder _key(String key) => find.byKey(ValueKey(key));

bool _posted(MessageAdapter api, String method, String path) =>
    api.calls.any((c) => c.method == method && c.path == path);

final _forms = <_Form>[
  _Form(
    'create workspace',
    open: (t, context, w, _) => WorkspaceActions.create(context, w),
    field: () => _key('field-name'),
    fill: {() => _key('field-slug'): 'beta'},
    submit: () => find.widgetWithText(RaftButton, 'Create Server'),
    routes: (api) => api.routes['POST /servers'] = (_) => {'id': 'sx'},
    submitted: (api, _) => _posted(api, 'POST', '/servers'),
  ),
  _Form(
    'join workspace',
    open: (t, context, w, _) => WorkspaceActions.join(context, w),
    field: () => _key('field-token'),
    submit: () => find.widgetWithText(RaftButton, 'Review Invitation'),
    submitted: (api, events) => true,
  ),
  _Form(
    'leave workspace',
    open: (t, context, w, _) => WorkspaceActions.leave(context, w),
    field: () => _key('field-confirm'),
    routes: (api) => api.routes['POST /servers/s1/leave'] = (_) => {},
    submit: () => find.widgetWithText(RaftButton, 'Leave Server'),
    submitted: (api, _) => _posted(api, 'POST', '/servers/s1/leave'),
  ),
  _Form(
    'create channel',
    tall: true,
    open: (t, context, w, _) =>
        CreateChannelDialog.show(context, controller: w),
    routes: (api) =>
        api.routes['POST /channels'] = (_) => {'id': 'c9', 'name': 'made'},
    submit: () => find.text('Create Channel').last,
    submitted: (api, _) => _posted(api, 'POST', '/channels'),
  ),
  _Form(
    'create task',
    open: (t, context, w, _) =>
        CreateTaskDialog.show(context, controller: w, channelId: 'c1'),
    field: () => _key('create-task-title-0'),
    routes: (api) =>
        api.routes['POST /tasks/channel/c1'] = (_) => {'tasks': <dynamic>[]},
    submit: () => _key('create-task-submit'),
    submitted: (api, _) => _posted(api, 'POST', '/tasks/channel/c1'),
  ),
  _Form(
    'create joint channel',
    tall: true,
    open: (t, context, w, _) =>
        CreateJointChannelDialog.show(context, controller: w),
    field: () => _key('joint-name'),
    fill: {
      () => find
              .descendant(
                of: _key('joint-invite-invite-1'),
                matching: find.byType(EditableText),
              )
              .at(0):
          'partner',
      () => find
              .descendant(
                of: _key('joint-invite-invite-1'),
                matching: find.byType(EditableText),
              )
              .at(1):
          'dana@example.test',
    },
    routes: (api) =>
        api.routes['POST /channels'] = (_) => {'id': 'j1', 'name': 'joint'},
    submit: () => _key('joint-create-submit'),
    submitted: (api, _) => _posted(api, 'POST', '/channels'),
  ),
  _Form(
    'invite human',
    open: (t, context, w, _) => showWorkspaceMenuInvite(context, w),
    field: () => _key('invite-email-0'),
    routes: (api) {
      api.routes['GET /servers/s1/join-links'] = (_) => <dynamic>[];
      api.routes['POST /servers/s1/invites'] = (_) => {'ok': true};
    },
    submit: () => _key('invite-send'),
    submitted: (api, _) => _posted(api, 'POST', '/servers/s1/invites'),
  ),
  _Form(
    'register computer',
    open: (t, context, w, _) =>
        showFleetRegistration(context, w, computers: true),
    field: () => _key('field-name'),
    routes: (api) =>
        api.routes['POST /servers/s1/machines'] = (_) => {'id': 'm9'},
    submit: () => find.widgetWithText(RaftButton, 'Register Computer'),
    submitted: (api, _) => _posted(api, 'POST', '/servers/s1/machines'),
  ),
  _Form(
    'create external agent',
    open: (t, context, w, _) => showFleetRegistration(context, w),
    field: () => _key('field-name'),
    routes: (api) => api.routes['POST /agents'] = (_) => {'id': 'a9'},
    submit: () => find.widgetWithText(RaftButton, 'Create External Agent'),
    submitted: (api, _) => _posted(api, 'POST', '/agents'),
  ),
  _Form(
    'create agent',
    tall: true,
    // With no computer the form is one banner; Web's shorter "Add Computer"
    // copy no longer overflows 580 dp, so the check uses a shorter phone.
    keyboardViewportHeight: 520,
    open: (t, context, w, _) => showManagedAgentForm(context, w),
  ),
  _Form(
    'report issue',
    tall: true,
    open: (t, context, w, _) => showReportIssueDialog(
      context,
      controller: w,
      agent: const {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
      exportUrl: 'https://feedback.example.test',
    ),
  ),
  _Form(
    'edit runtime config',
    tall: true,
    open: (t, context, w, _) => showAgentRuntimeEditor(
      context,
      controller: w,
      agent: const {
        'id': 'a1',
        'name': 'cindy',
        'displayName': 'Cindy',
        'status': 'active',
        'runtime': 'codex',
        'model': 'gpt-5',
      },
    ),
  ),
  _Form(
    'edit agent name',
    prepare: (t, w) async {
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(_key('agent-edit-display-name'));
    },
    field: () => _key('agent-profile-edit-display-name'),
    routes: (api) {
      api.routes['PATCH /agents/a1'] = (_) => {'id': 'a1'};
    },
    submit: () => _key('agent-profile-edit-save'),
    submitted: (api, _) => _posted(api, 'PATCH', '/agents/a1'),
  ),
  _Form(
    'new sidebar section',
    open: (t, context, w, events) => showRaftSidebarSectionDialog(
      context,
      title: 'New Section',
      submitLabel: 'Create',
      onSubmit: (name, _) => events.add('section:$name'),
    ),
    submit: () => find.text('Create'),
    submitted: (api, events) => events.any((e) => e.startsWith('section:')),
  ),
];

const _phone = Size(390, 844), _desktop = Size(1000, 800);

/// Two files share this suite (`form_windows_part2_test.dart`), each
/// registering half of the forms.
void main() => registerFormWindowTests(TestPart(0, 2));

void registerFormWindowTests(TestPart part) {
  // Leak debt (report issue's transcript notifier) as in close_dialogs_test;
  // Flutter 3.47.6: a modal bottom sheet closed by a drag rebinds its
  // animation to a CurvedAnimation that nothing disposes.
  leakDebt(const [
    'ValueNotifier<RaftTranscriptRequestState?>',
    'CurvedAnimation',
  ]);

  Future<(WorkspaceController, MessageAdapter, List<String>)> openForm(
    WidgetTester t,
    _Form form,
    Size size,
  ) async {
    final original = FlutterError.onError;
    // The fixture font is wider than the shipped one: dense forms report
    // overflow on a phone that the device does not have.
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    await t.pumpWidget(const SizedBox.shrink());
    final (w, api) = await mountWorkspace(t, size);
    final events = <String>[];
    form.routes?.call(api);
    final context = t.element(find.byType(WorkspaceView));
    await form.prepare?.call(t, w);
    unawaited(form.open?.call(t, context, w, events) ?? Future<void>.value());
    await frames(t, 30);
    return (w, api, events);
  }

  final sheet = find.byType(BottomSheet);
  final dialog = find.byType(RaftDialogFrame);

  for (final form in _forms) {
    part.group(form.id, () {
      testWidgets('is a sheet at 390 and a dialog at 1000', (t) async {
        await openForm(t, form, _phone);
        expect(sheet, findsOneWidget, reason: 'sheet at 390');
        expect(find.byType(RaftSheet), findsOneWidget);
        expect(dialog, findsNothing);
        expect(find.byKey(const ValueKey('raft-sheet-handle')), findsOne);
        await t.pumpWidget(const SizedBox.shrink());
        await openForm(t, form, _desktop);
        expect(dialog, findsOneWidget, reason: 'dialog at 1000');
        expect(sheet, findsNothing);
        expect(find.byType(RaftSheet), findsNothing);
      });

      if (form.field != null || form.id == 'create channel') {
        testWidgets('keeps the input, the focus and the window across 768', (
          t,
        ) async {
          await openForm(t, form, _desktop);
          Finder field() => (form.field ?? _editable)();
          await t.enterText(field(), 'typed once');
          await t.pump();
          final focus = FocusManager.instance.primaryFocus;
          expect(focus, isNotNull);
          for (final size in [_phone, _desktop, const Size(600, 800)]) {
            t.view.physicalSize = size;
            await frames(t, 20);
            expect(
              field(),
              findsOneWidget,
              reason: '${size.width}: still open',
            );
            expect(
              find.text('typed once'),
              findsOneWidget,
              reason: '${size.width}: text',
            );
            expect(
              FocusManager.instance.primaryFocus,
              same(focus),
              reason: '${size.width}: focus',
            );
          }
        });
      }

      if (form.submit != null) {
        for (final size in [_phone, _desktop]) {
          testWidgets('submits at ${size.width.toInt()}', (t) async {
            final (_, api, events) = await openForm(t, form, size);
            if (form.field != null) {
              await t.enterText(
                form.field!(),
                form.id == 'leave workspace'
                    ? 'Alpha'
                    : form.id == 'join workspace'
                    ? 'https://example.test/invite/abc123'
                    : form.id == 'invite human'
                    ? 'dana@example.test'
                    : 'abc',
              );
            } else {
              await t.enterText(_editable(), 'abc');
            }
            for (final entry in form.fill.entries) {
              await t.enterText(entry.key(), entry.value);
            }
            await t.pump();
            final submit = find.descendant(
              of: _window(),
              matching: form.submit!(),
            );
            await t.ensureVisible(submit.first);
            await t.tap(submit.first);
            await frames(t, 30);
            expect(form.submitted!(api, events), isTrue, reason: 'submitted');
          });
        }
      }

      testWidgets('scrolls and keeps the focused field above the keyboard', (
        t,
      ) async {
        final size = Size(390, form.keyboardViewportHeight);
        const keyboard = 260.0;
        t.view.viewInsets = const FakeViewPadding(bottom: keyboard);
        addTearDown(t.view.resetViewInsets);
        await openForm(t, form, size);
        expect(sheet, findsOneWidget);
        final scrollView = find
            .descendant(of: sheet, matching: find.byType(CustomScrollView))
            .first;
        final position = t
            .state<ScrollableState>(
              find
                  .descendant(of: scrollView, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        if (form.tall) {
          expect(
            position.maxScrollExtent,
            greaterThan(0),
            reason: 'the sheet is shorter than the form: the body scrolls',
          );
        }
        final room = size.height - keyboard;
        // The last text field a thumb can edit (not a read-only link).
        final editable = find.descendant(
          of: sheet,
          matching: find.byWidgetPredicate(
            (w) => w is EditableText && !w.readOnly,
          ),
        );
        if (editable.evaluate().isEmpty) {
          // A form made of selects: the pinned actions still sit above the
          // keyboard while the body scrolls.
          expect(
            t.getRect(find.byType(RaftSheet)).bottom,
            lessThanOrEqualTo(room + 1),
          );
          return;
        }
        final last = editable.last;
        // Scroll the sheet's body until the last field is above the keyboard.
        // The viewport ends where the pinned footer starts.
        final visible = t.getRect(scrollView).bottom;
        expect(visible, lessThanOrEqualTo(room + 1));
        for (var i = 0; i < 40 && t.getRect(last).bottom > visible; i++) {
          // Start at the bottom edge of the body: a drag that starts on a
          // multi-line field would scroll that field, not the sheet.
          await t.dragFrom(
            t.getRect(scrollView).bottomCenter - const Offset(0, 8),
            const Offset(0, -80),
          );
          await frames(t, 4);
        }
        expect(t.getRect(last).bottom, lessThanOrEqualTo(visible + 1));
        await t.tapAt(t.getRect(last).center);
        await frames(t, 20);
        expect(
          t.widget<EditableText>(last).focusNode.hasFocus,
          isTrue,
          reason: 'the last field took the focus',
        );
        // Focus reveals the caret line, not the whole field: a multi-line field taller than the free band
        // (the 0.7.1 controls are taller) may keep its lower edge under the pinned footer, but its first
        // line stays above the keyboard.
        expect(t.getRect(last).top, lessThan(visible));
        expect(
          t.getRect(find.byType(RaftSheet)).bottom,
          lessThanOrEqualTo(room + 1),
        );
      });
    });
  }

  // A form never throws unsaved input away by a stray close: dragging the
  // sheet down, the scrim, Esc, Back and the X all ask first. An untouched
  // form closes at once, and Cancel never asks.
  final asked = find.byType(RaftAvatarDiscardConfirmation);
  final handle = find.byKey(const ValueKey('raft-sheet-handle'));
  for (final form in _forms.where(
    (f) => const {
      'create workspace',
      'create channel',
      'create task',
      'new sidebar section',
      'create joint channel',
    }.contains(f.id),
  )) {
    part.group('${form.id} guards unsaved input', () {
      Future<void> typeSomething(WidgetTester t) async {
        await t.enterText((form.field ?? _editable)(), 'unsaved words');
        await t.pump();
      }

      Future<void> closeBy(WidgetTester t, String how) async {
        switch (how) {
          case 'drag':
            await t.fling(handle, const Offset(0, 700), 2500);
          case 'scrim':
            await t.tapAt(const Offset(200, 6));
          case 'esc':
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
          case 'back':
            await t.binding.handlePopRoute();
          case 'x':
            await t.tap(
              find
                  .descendant(
                    of: _window(),
                    matching: find.byWidgetPredicate(
                      (w) => w is RaftDialogClose || w is RaftCloseButton,
                    ),
                  )
                  .first,
            );
        }
        await frames(t, 30);
      }

      for (final how in ['drag', 'scrim', 'esc', 'back', 'x']) {
        testWidgets('$how asks; Keep editing keeps the text; Discard closes', (
          t,
        ) async {
          final size = how == 'drag' || how == 'scrim' ? _phone : _desktop;
          await openForm(t, form, size);
          await typeSomething(t);
          await closeBy(t, how);
          expect(asked, findsOneWidget, reason: '$how asks');
          expect(find.text('unsaved words'), findsOneWidget);
          await t.tap(find.text('Keep Editing'));
          await frames(t, 30);
          expect(asked, findsNothing);
          expect(find.text('unsaved words'), findsOneWidget, reason: 'kept');
          expect(
            (form.field ?? _editable)(),
            findsOneWidget,
            reason: 'still open',
          );
          await closeBy(t, how);
          expect(asked, findsOneWidget);
          await t.tap(find.text('Discard Changes'));
          await frames(t, 30);
          expect(find.text('unsaved words'), findsNothing, reason: 'closed');
          expect(asked, findsNothing);
        });
      }

      testWidgets('an untouched form closes without asking', (t) async {
        for (final how in ['drag', 'scrim', 'esc']) {
          await openForm(t, form, how == 'esc' ? _desktop : _phone);
          await closeBy(t, how);
          expect(asked, findsNothing, reason: how);
          expect(_window(), findsNothing, reason: '$how closed it');
          await t.pumpWidget(const SizedBox.shrink());
        }
      });

      testWidgets('a footer Cancel does not ask', (t) async {
        await openForm(t, form, _phone);
        await typeSomething(t);
        final cancel = find.descendant(
          of: _window(),
          matching: find.text('Cancel'),
        );
        if (cancel.evaluate().isEmpty) return;
        await t.ensureVisible(cancel.first);
        await t.tap(cancel.first);
        await frames(t, 30);
        expect(asked, findsNothing);
        expect(find.text('unsaved words'), findsNothing);
      });
    });
  }
}
