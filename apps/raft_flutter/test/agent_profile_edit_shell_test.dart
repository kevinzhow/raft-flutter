import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/profile_side_panel.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/close_support.dart';

// The agent profile is a phone page below the desktop breakpoint and a side
// panel above it. Those are different widget trees, so a resize across 768
// rebuilds the panel and drops the edit window it opened. The window has to
// move with the layout: same dialog, same typed text, same focus.

const _typed = 'typed once';
const _phone = Size(390, 844);
const _desktop = Size(1200, 800);
const _up = [Size(600, 800), Size(900, 800), _desktop];
const _down = [Size(900, 800), Size(600, 800), _phone];

final _pencil = find.byKey(const ValueKey('agent-edit-display-name'));
final _field = find.byKey(const ValueKey('agent-profile-edit-display-name'));
final _dialog = find.byType(RaftAgentProfileEditDialog);

EditableTextState _editor(WidgetTester t) => t.state<EditableTextState>(
  find.descendant(of: _field, matching: find.byType(EditableText)),
);

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  for (final (name, from, steps) in [
    ('phone to desktop', _phone, _up),
    ('desktop to phone', _desktop, _down),
  ]) {
    testWidgets('$name: the agent name editor stays, with text and focus', (
      t,
    ) async {
      final original = FlutterError.onError;
      // The fixture font is wider than the shipped one: the profile reports
      // overflow on a phone that the device does not have.
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed by')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      final (w, _) = await mountWorkspace(t, from);
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(_pencil);
      await frames(t, 25);
      expect(_dialog, findsOneWidget);
      await t.enterText(_field, _typed);
      await t.pump();
      final editor = _editor(t);
      final before = editor.widget.controller.value;
      final focus = FocusManager.instance.primaryFocus;
      expect(before.text, _typed);
      expect(focus, isNotNull);
      expect(editor.widget.focusNode.hasFocus, isTrue);

      for (final size in steps) {
        t.view.physicalSize = size;
        await frames(t, 20);
        expect(_dialog, findsOneWidget, reason: '${size.width}: still open');
        expect(
          find.text(_typed),
          findsOneWidget,
          reason: '${size.width}: text',
        );
        final live = _editor(t);
        expect(
          identical(live.widget.controller, editor.widget.controller),
          isTrue,
          reason: '${size.width}: same controller',
        );
        expect(live.widget.controller.value, before);
        expect(
          FocusManager.instance.primaryFocus,
          same(focus),
          reason: '${size.width}: focus',
        );
        expect(live.widget.focusNode.hasFocus, isTrue);
      }
    });
  }

  testWidgets(
    'a phone page above the profile keeps one panel and the open editor',
    (t) async {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed by')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      final (w, _) = await mountWorkspace(t, _phone);
      addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 30);
      await t.tap(_pencil);
      await frames(t, 25);
      await t.enterText(_field, _typed);
      await t.pump();
      final editor = _editor(t);
      final before = editor.widget.controller.value;
      final focus = FocusManager.instance.primaryFocus;
      expect(
        find.byType(ProfileSidePanel, skipOffstage: false),
        findsOneWidget,
      );

      // Channel settings is a page above the profile. The profile page stays
      // mounted under it. A second copy of the same panel would duplicate the
      // shared key.
      w.navigation.navigate(
        w.location.withQuery({'channelPage': 'settings:c1'}),
      );
      w.notifyListeners();
      await frames(t, 30);

      expect(t.takeException(), isNull);
      expect(
        find.byType(ProfileSidePanel, skipOffstage: false),
        findsOneWidget,
        reason: 'the page under settings does not build another panel',
      );
      expect(_dialog, findsOneWidget, reason: 'the editor stays open');
      expect(
        identical(_editor(t).widget.controller, editor.widget.controller),
        isTrue,
      );
      expect(editor.widget.controller.value, before);
      expect(FocusManager.instance.primaryFocus, same(focus));
    },
  );
}
