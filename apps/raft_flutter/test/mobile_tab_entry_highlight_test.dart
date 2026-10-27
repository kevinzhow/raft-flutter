@Tags(['slow'])
library;

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

enum _EntryInput { touch, mouse, keyboard }

const _barKey = Key('workspace-mobile-navigation');
const _notificationsKey = ValueKey('workspace-settings-nav-notifications');

final _preferences = {
  MobileTabbarStore.preferenceKey: jsonEncode({
    'order': ['chat', 'activity', 'members', 'computers', 'tasks'],
    'enabled': ['chat', 'activity', 'members', 'computers'],
  }),
};

void _assertSettingsBar(WidgetTester t, {required bool pointer}) {
  // The covered root still paints during the platform transition, then stays
  // offstage for Back. Inspect its actual widgets in both phases.
  final bar = find.byKey(_barKey, skipOffstage: false);
  expect(bar, findsOneWidget);
  expect(t.widget<RaftMobileNav>(bar).selectedId, 'settings');
  final home = find.byKey(const Key('mobile-tab-home'), skipOffstage: false);
  final settings = find.byKey(
    const Key('mobile-tab-settings'),
    skipOffstage: false,
  );
  bool? selected(Finder target) {
    final control = t.widget(target);
    if (control is RaftInteractive) return control.selected;
    if (control is RaftControl) return control.recipe!.selected;
    throw StateError('Unexpected mobile navigation control: $control');
  }

  expect(selected(home), isFalse);
  expect(selected(settings), isTrue);
  final homeFocus = t.widget<FocusableActionDetector>(
    find
        .descendant(
          of: home,
          matching: find.byType(FocusableActionDetector, skipOffstage: false),
          skipOffstage: false,
        )
        .first,
  );
  expect(
    homeFocus.focusNode!.hasFocus,
    isFalse,
    reason: 'The first tab must not acquire focus on route entry or Back.',
  );
  if (pointer) {
    final outlines = t.widgetList<CustomPaint>(
      find.descendant(
        of: bar,
        matching: find.byType(CustomPaint, skipOffstage: false),
        skipOffstage: false,
      ),
    );
    expect(
      outlines
          .map((w) => w.foregroundPainter)
          .whereType<RaftCssFocusOutline>()
          .any((painter) => painter.enabled),
      isFalse,
      reason: 'Pointer navigation must not acquire a keyboard focus outline.',
    );
  }
}

Future<void> _activate(WidgetTester t, Finder target, _EntryInput input) async {
  await t.ensureVisible(target);
  if (input == _EntryInput.keyboard) {
    final detector = t.widget<FocusableActionDetector>(
      find
          .descendant(
            of: target,
            matching: find.byType(FocusableActionDetector),
          )
          .first,
    );
    final focus = detector.focusNode!;
    for (var step = 0; step < 40 && !focus.hasFocus; step++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    expect(focus.hasFocus, isTrue, reason: 'Tab must reach Notifications.');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
  } else {
    final gesture = await t.startGesture(
      t.getCenter(target),
      kind: input == _EntryInput.mouse
          ? PointerDeviceKind.mouse
          : PointerDeviceKind.touch,
    );
    await gesture.up();
  }
}

Future<void> _transitionFrames(
  WidgetTester t,
  RootFixture fixture,
  void Function() observe,
) async {
  final size = t.view.physicalSize;
  for (var frame = 0; frame < 12; frame++) {
    // A real viewport update forces layout of the retained root while another
    // route owns the current location. It must retain its own tab selection.
    if (frame == 1) t.view.physicalSize = Size(size.width + 1, size.height);
    if (frame == 3) t.view.physicalSize = size;
    await t.pump(const Duration(milliseconds: 16));
    observe();
  }
  await fixture.flush(t);
}

void main() {
  for (final (platform, input, theme) in [
    (TargetPlatform.iOS, _EntryInput.touch, 'dark'),
    (TargetPlatform.iOS, _EntryInput.touch, 'light'),
    (TargetPlatform.android, _EntryInput.touch, 'light'),
    (TargetPlatform.linux, _EntryInput.mouse, 'light'),
    (TargetPlatform.linux, _EntryInput.keyboard, 'light'),
  ]) {
    testWidgets(
      '$platform/$input/$theme entering and returning from Notifications '
      'never selects Home on the retained Settings root',
      (t) async {
        final f = RootFixture();
        await f.mount(
          t,
          theme,
          390,
          uri: Uri.parse('/s/alpha/settings'),
          preferences: _preferences,
        );
        t.view.physicalSize = const Size(390, 844);
        await f.flush(t);
        var observed = 0;
        void observe() {
          _assertSettingsBar(t, pointer: input != _EntryInput.keyboard);
          observed++;
        }

        observe();
        f.onFrame = observe;
        try {
          if (input == _EntryInput.keyboard) {
            final settings = find.byKey(const Key('mobile-tab-settings'));
            await _activate(t, settings, input);
            await f.flush(t);
            final outlines = t.widgetList<CustomPaint>(
              find.descendant(of: settings, matching: find.byType(CustomPaint)),
            );
            expect(
              outlines
                  .map((w) => w.foregroundPainter)
                  .whereType<RaftCssFocusOutline>()
                  .any((painter) => painter.enabled),
              isTrue,
              reason: 'Real keyboard activation keeps its visible focus ring.',
            );
          }
          // Settings rows currently support pointer activation; keyboard
          // coverage uses the real tab above and Escape on the pushed route.
          await _activate(
            t,
            find.byKey(_notificationsKey),
            input == _EntryInput.keyboard ? _EntryInput.mouse : input,
          );
          await _transitionFrames(t, f, observe);
          expect(f.workspace(t).location.settingsPath, ['notifications']);
          expect(find.byKey(const Key('mobile-settings-back')), findsOneWidget);
          if (input == _EntryInput.keyboard) {
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
          } else {
            await _activate(
              t,
              find.byKey(const Key('mobile-settings-back')),
              input,
            );
          }
          await _transitionFrames(t, f, observe);
          expect(f.workspace(t).location.settingsPath, isEmpty);
          expect(observed, greaterThan(24));
          expect(t.takeException(), isNull);
        } finally {
          f.onFrame = null;
          await f.close(t);
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'unfolded Android uses Settings rail while touch opens Notifications',
    (t) async {
      final f = RootFixture();
      await f.mount(
        t,
        'light',
        856,
        uri: Uri.parse('/s/alpha/settings'),
        preferences: _preferences,
      );
      t.view.physicalSize = const Size(856, 944);
      await f.flush(t);
      void observe() {
        expect(find.byKey(_barKey), findsNothing);
        expect(
          t.widget<RaftWorkspaceRail>(find.byType(RaftWorkspaceRail)).selected,
          isNot('chat'),
        );
        expect(
          t
              .widget<RaftWorkspaceRailAction>(
                find.byKey(const Key('rail-settings')),
              )
              .selected,
          isTrue,
        );
      }

      observe();
      f.onFrame = observe;
      try {
        await _activate(t, find.byKey(_notificationsKey), _EntryInput.touch);
        await f.flush(t);
        expect(f.workspace(t).location.settingsPath, ['notifications']);
        observe();
        expect(t.takeException(), isNull);
      } finally {
        f.onFrame = null;
        await f.close(t);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
