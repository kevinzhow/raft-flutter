// Soft keyboard on the auth / onboarding pages (docs/auth-keyboard.md).
//
// Every text-entry page before the workspace is pumped through the real
// RaftApp on a phone with a simulated keyboard (viewInsets.bottom 336 dp, the
// Android gesture-nav IME). With each field focused, the field and the page's
// primary action must be fully visible: below the status bar, above the
// keyboard. The pages share one mechanism (RaftAuthShell's
// RaftKeyboardScrollView); a source guard keeps new pages on it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const _statusBar = 24.0;
const _keyboard = 336.0; // the Android gesture-nav IME is 320-336 dp

Map<String, dynamic> _me({bool verified = true, bool profile = true}) => {
  'id': 'alice',
  'name': profile ? 'alice' : 'pending_alice',
  'displayName': profile ? 'Alice' : null,
  'email': 'alice@example.invalid',
  'emailVerified': verified,
  if (!profile) 'profileSetupCompletedAt': null,
  if (!profile) 'profileSetupSuggestedHandle': 'alice',
};

void _signedOut(RootFixture f) => f.adapter.statuses['GET /auth/me'] = 401;

class _Page {
  const _Page(this.name, this.fields, this.action, {this.prepare, this.enter});
  final String name;
  final List<String> fields;
  final String action;
  final void Function(RootFixture f)? prepare;
  final Future<void> Function(WidgetTester t, RootFixture f)? enter;
}

Future<void> _tapText(WidgetTester t, RootFixture f, String text) async {
  await t.tap(find.text(text));
  await f.flush(t);
}

final _pages = <_Page>[
  _Page(
    'login',
    ['login-email', 'login-password'],
    'login-submit',
    prepare: _signedOut,
  ),
  _Page(
    'register',
    ['login-email', 'login-password'],
    'login-submit',
    prepare: _signedOut,
    enter: (t, f) => _tapText(t, f, 'Create one'),
  ),
  _Page(
    'forgot',
    ['login-email'],
    'login-submit',
    prepare: _signedOut,
    enter: (t, f) => _tapText(t, f, 'Forgot password?'),
  ),
  _Page(
    'verify',
    ['verification-token'],
    'verify-submit',
    prepare: (f) => f.overrides['GET /auth/me'] = (_) => _me(verified: false),
    enter: (t, f) async {
      await t.tap(find.byKey(const Key('verify-manual-toggle')));
      await f.flush(t);
    },
  ),
  _Page(
    'profile',
    ['onboarding-username', 'onboarding-display-name'],
    'onboarding-complete',
    prepare: (f) => f.overrides['GET /auth/me'] = (_) => _me(profile: false),
  ),
  _Page(
    'first-server',
    ['global-server-name', 'global-server-slug'],
    'global-server-create-submit',
    prepare: (f) => f.servers.clear(),
  ),
  _Page(
    'create-server',
    ['global-server-name', 'global-server-slug'],
    'global-server-create-submit',
    enter: (t, f) => _tapText(t, f, '+ Create New Server'),
  ),
];

Finder _byKey(String key) => find.byKey(ValueKey<String>(key));

/// The editable inside the field keyed [key] (the key sits on the input).
Finder _editable(String key) => find.descendant(
  of: _byKey(key),
  matching: find.byType(EditableText),
  matchRoot: true,
);

Rect _rect(WidgetTester t, Finder f) => t.getRect(f.first);

void _setView(WidgetTester t, Size size, double keyboard) {
  final v = t.view;
  v.devicePixelRatio = 1;
  v.physicalSize = size;
  v.padding = const FakeViewPadding(top: _statusBar);
  v.viewPadding = const FakeViewPadding(top: _statusBar);
  v.viewInsets = FakeViewPadding(bottom: keyboard);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void _expectVisible(
  WidgetTester t,
  String what,
  Finder f,
  Size size,
  double keyboard,
) {
  final r = _rect(t, f);
  expect(
    r.top,
    greaterThanOrEqualTo(_statusBar - .5),
    reason: '$what is under the status bar ($r)',
  );
  expect(
    r.bottom,
    lessThanOrEqualTo(size.height - keyboard + .5),
    reason:
        '$what is under the keyboard ($r, keyboard top '
        '${size.height - keyboard})',
  );
}

void main() {
  for (final size in const [Size(390, 844), Size(360, 640), Size(841, 701)]) {
    for (final page in _pages) {
      testWidgets(
        '${page.name}: focused field and action are above the keyboard '
        '(${size.width.toInt()}x${size.height.toInt()})',
        (t) async {
          final f = RootFixture();
          page.prepare?.call(f);
          await f.mount(t, 'light', size.width, settle: false);
          addTearDown(() {
            t.view.resetViewInsets();
            t.view.resetPadding();
            t.view.resetViewPadding();
          });
          _setView(t, size, 0);
          await f.flush(t);
          await page.enter?.call(t, f);
          await _settle(t);
          expect(_editable(page.fields.first), findsOneWidget);

          for (final field in [
            ...page.fields,
            // back to the first: a field that scrolled away comes back.
            page.fields.first,
          ]) {
            await t.showKeyboard(_editable(field));
            // the keyboard slides up after the focus (Android)
            _setView(t, size, _keyboard);
            await _settle(t);
            _expectVisible(t, field, _editable(field), size, _keyboard);
            // On a 360x640 window (280 dp above the keyboard) a form of three
            // rows cannot show the first field and the button together; the
            // field wins there and the button is required from the last field.
            final together = size.height >= 844 || field == page.fields.last;
            if (together || page.fields.length == 1) {
              _expectVisible(
                t,
                page.action,
                _byKey(page.action),
                size,
                _keyboard,
              );
            }
          }

          // Keyboard down: the page is back at rest and nothing is lifted.
          await t.testTextInput.receiveAction(TextInputAction.done);
          t.testTextInput.hide();
          _setView(t, size, 0);
          await _settle(t);
          await f.close(t);
        },
      );
    }
  }

  // A page below a layout that already spent the keyboard inset (the
  // workspace content region: setup survey, Cindy step) still reveals.
  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('inset spent by an ancestor: field and action are revealed '
        '(${size.width.toInt()}x${size.height.toInt()})', (t) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      // _setView replaces the view's root layer (size and pixel ratio); put the
      // defaults back so the layer this test made is not the one left alive
      // when it is the last test of the file.
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        t.view.resetViewInsets();
        t.view.resetPadding();
        t.view.resetViewPadding();
      });
      _setView(t, size, 0);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              return Padding(
                padding: EdgeInsets.only(
                  top: _statusBar,
                  bottom: media.viewInsets.bottom,
                ),
                child: MediaQuery(
                  data: media.copyWith(
                    viewInsets: media.viewInsets.copyWith(bottom: 0),
                  ),
                  child: Material(
                    child: RaftKeyboardScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 300),
                          TextField(key: const Key('f'), focusNode: focus),
                          const SizedBox(height: 40),
                          const RaftPrimaryAction(
                            child: SizedBox(
                              key: Key('go'),
                              height: 48,
                              child: Text('Go'),
                            ),
                          ),
                          const SizedBox(height: 600),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await t.showKeyboard(find.byKey(const Key('f')));
      _setView(t, size, _keyboard);
      await _settle(t);
      _expectVisible(t, 'field', find.byKey(const Key('f')), size, _keyboard);
      _expectVisible(t, 'action', find.byKey(const Key('go')), size, _keyboard);
    });
  }

  test('auth pages share the keyboard-aware scaffold', () {
    // Every page that owns the window and holds a form is a RaftAuthShell /
    // RaftOnboardingShell (RaftKeyboardScrollView + RaftPrimaryAction). A raw
    // scroll view or its own top bar in an auth page bypasses the mechanism.
    final auth = File('../../packages/raft_ui/lib/src/auth_page.dart')
        .readAsStringSync();
    expect(
      RegExp(r'\bSingleChildScrollView\(').allMatches(auth),
      isEmpty,
      reason: 'auth_page.dart scrolls through RaftKeyboardScrollView only',
    );
    expect(
      RegExp(r'RaftKeyboardScrollView\(').allMatches(auth).length,
      greaterThanOrEqualTo(2),
      reason: 'narrow shell and wide onboarding shell',
    );

    final offenders = <String>[];
    for (final dir in ['../../packages/raft_ui/lib', 'lib']) {
      for (final file
          in Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((e) => e.path.endsWith('.dart'))) {
        if (file.path.endsWith('auth_page.dart') ||
            file.path.endsWith('keyboard_reveal.dart')) {
          continue;
        }
        final source = file.readAsStringSync();
        // The brand bar is part of the shell; a page drawing it itself is a
        // second auth scaffold.
        if (source.contains('RaftAuthTopBar(')) offenders.add(file.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'new auth / onboarding pages use RaftAuthShell, '
          'RaftOnboardingShell or RaftAuthPage, not their own frame',
    );

    // Every app page with a text input, rendered through the auth shell,
    // reaches RaftKeyboardScrollView.
    final feature = File('lib/features/global_server_selector.dart')
        .readAsStringSync();
    expect(feature, contains('RaftOnboardingShell('));
    expect(feature, contains('RaftAuthShell('));
  });

  testWidgets('RaftKeyboardScrollView ancestors every auth form field', (
    t,
  ) async {
    final f = RootFixture();
    _signedOut(f);
    await f.mount(t, 'light', 390, settle: false);
    await f.flush(t);
    expect(
      find.ancestor(
        of: _editable('login-password'),
        matching: find.byType(RaftKeyboardScrollView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _byKey('login-submit'),
        matching: find.byType(RaftPrimaryAction),
      ),
      findsOneWidget,
    );
    await f.close(t);
  });
}
