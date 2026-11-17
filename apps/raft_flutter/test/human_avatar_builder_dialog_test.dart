import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_avatar_builder_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX;
import 'parity/parity_harness.dart' show loadParityFonts;

/// Web `HumanAvatarBuilderDialog` (C18): preview, Shuffle, five tabs, radio
/// tiles, the replaces-photo note, Save off while unchanged, a blocked close
/// while saving, a failed save that keeps every choice, and
/// `PUT /auth/me/avatar-recipe` then the signed-in user replaced.
class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final calls = <String>[];
  final bodies = <Object?>[];
  final replaced = <Map<String, dynamic>>[];
  Completer<dynamic>? pending;
  Object? failure;
  int reads = 0;

  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add('$method $path');
    bodies.add(data);
    if (path == '/auth/me') reads++;
    final wait = pending;
    if (wait != null) await wait.future;
    if (failure != null) throw failure!;
    return {
      'id': 'me',
      'avatarUrl': (data as Map)['recipe'] == null ? null : 'saved',
    };
  }

  @override
  Future<void> replaceUser(Map<String, dynamic> json) async =>
      replaced.add(json);
}

const _stored = 'pixel-human:v1:sky.3.curly.brown.grin.headphones.glasses';

void main() {
  setUpAll(loadParityFonts);
  late _Client client;
  var saved = 0;
  setUp(() {
    client = _Client()..user = RaftRecord({'id': 'me'});
    saved = 0;
  });
  tearDown(() => client.dispose());

  Future<void> open(
    WidgetTester t, {
    String? avatarUrl = _stored,
    Size size = const Size(1000, 1200),
    bool dark = false,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showHumanAvatarBuilder(
                context,
                client: client,
                avatarUrl: avatarUrl,
                onSaved: () => saved++,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  Finder preview(String value) =>
      find.byKey(ValueKey('human-avatar-builder-preview:$value'));
  Finder option(String field, String id) =>
      find.byKey(ValueKey('human-avatar-option-$field-$id'));
  Finder save = find.byKey(const ValueKey('human-avatar-builder-save'));
  bool saveEnabled(WidgetTester t) =>
      t.widget<RaftButton>(save).onPressed != null;
  Future<void> tab(WidgetTester t, String name) async {
    await t.tap(find.byKey(ValueKey('human-avatar-builder-tab-$name')));
    await t.pumpAndSettle();
  }

  testWidgets('opens on the stored look with Save off and no note', (t) async {
    await open(t);
    expect(preview(_stored), findsOneWidget);
    expect(find.text('Build an avatar'), findsOneWidget);
    expect(saveEnabled(t), isFalse);
    expect(
      find.byKey(const ValueKey('human-avatar-builder-replaces-photo')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('human-avatar-builder-error')),
      findsNothing,
    );
    for (final name in [
      'Background',
      'Skin',
      'Hair',
      'Expression',
      'Accessories',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // The background tab: six tiles, the stored one chosen.
    for (final id in ['yellow', 'pink', 'sky', 'mint', 'lilac', 'cream']) {
      expect(option('background', id), findsOneWidget, reason: id);
    }
    expect(
      t.getSemantics(option('background', 'sky')),
      matchesSemantics(
        label: 'Sky',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('over a photo it opens on the default and says it replaces it', (
    t,
  ) async {
    await open(t, avatarUrl: '/api/avatars/users/a1.webp');
    expect(
      preview('pixel-human:v1:yellow.2.short.ink.wink.cap.none'),
      findsOneWidget,
    );
    expect(
      find.text('This replaces your current photo when you save.'),
      findsOneWidget,
    );
    // Save always does something over a photo.
    expect(saveEnabled(t), isTrue);
  });

  testWidgets('no avatar at all: default look, no note, Save on', (t) async {
    await open(t, avatarUrl: null);
    expect(
      preview('pixel-human:v1:yellow.2.short.ink.wink.cap.none'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('human-avatar-builder-replaces-photo')),
      findsNothing,
    );
    expect(saveEnabled(t), isTrue);
  });

  testWidgets('choosing changes the preview; back to stored turns Save off', (
    t,
  ) async {
    await open(t);
    await t.tap(option('background', 'mint'));
    await t.pumpAndSettle();
    expect(
      preview('pixel-human:v1:mint.3.curly.brown.grin.headphones.glasses'),
      findsOneWidget,
    );
    expect(saveEnabled(t), isTrue);
    await t.tap(option('background', 'sky'));
    await t.pumpAndSettle();
    expect(preview(_stored), findsOneWidget);
    expect(saveEnabled(t), isFalse);
  });

  testWidgets('each tab offers its options; hair tiles are bare-headed', (
    t,
  ) async {
    await open(t);
    await tab(t, 'skin');
    for (final id in ['1', '2', '3', '4', '5']) {
      expect(option('skin', id), findsOneWidget, reason: id);
    }
    expect(t.getSemantics(option('skin', '4')).label, 'Tone 4');
    await tab(t, 'hair');
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    for (final id in ['short', 'side', 'long', 'bun', 'curly', 'buzz']) {
      expect(option('hair', id), findsOneWidget, reason: id);
    }
    for (final id in ['ink', 'brown', 'blonde', 'ginger', 'grey']) {
      expect(option('hairColor', id), findsOneWidget, reason: id);
    }
    // The stored look wears headphones; the hair tiles must not.
    final slot = t.widget<RaftAvatarSlot>(
      find.descendant(
        of: option('hair', 'long'),
        matching: find.byType(RaftAvatarSlot),
      ),
    );
    expect(slot.avatarUrl, 'pixel-human:v1:sky.3.long.brown.grin.none.glasses');
    await tab(t, 'expression');
    for (final id in [
      'wink',
      'grin',
      'oh',
      'smirk',
      'happy',
      'calm',
      'blush',
    ]) {
      expect(option('expression', id), findsOneWidget, reason: id);
    }
    await tab(t, 'accessories');
    expect(find.text('On the head'), findsOneWidget);
    expect(find.text('On the face'), findsOneWidget);
    for (final id in ['none', 'cap', 'beanie', 'headphones']) {
      expect(option('head', id), findsOneWidget, reason: id);
    }
    for (final id in ['none', 'glasses']) {
      expect(option('face', id), findsOneWidget, reason: id);
    }
  });

  testWidgets('arrow keys move the choice inside a group and wrap', (t) async {
    await open(t);
    await t.tap(option('background', 'sky'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(
      preview('pixel-human:v1:mint.3.curly.brown.grin.headphones.glasses'),
      findsOneWidget,
    );
    for (var i = 0; i < 3; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
    }
    expect(
      preview('pixel-human:v1:yellow.3.curly.brown.grin.headphones.glasses'),
      findsOneWidget,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(
      preview('pixel-human:v1:cream.3.curly.brown.grin.headphones.glasses'),
      findsOneWidget,
    );
  });

  testWidgets('Shuffle picks a known look', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('human-avatar-builder-shuffle')));
    await t.pumpAndSettle();
    final shown = t
        .widgetList<RaftAvatarSlot>(find.byType(RaftAvatarSlot))
        .map((s) => s.avatarUrl)
        .where((v) => v != null)
        .toList();
    expect(shown, isNotEmpty);
    expect(RaftHumanAvatarRecipe.parse(shown.first!), isNotNull);
  });

  testWidgets('Save sends the recipe once, replaces the user, closes', (
    t,
  ) async {
    await open(t);
    await t.tap(option('background', 'pink'));
    await t.pump();
    await t.tap(save);
    await t.pumpAndSettle();
    expect(client.calls, ['PUT /auth/me/avatar-recipe']);
    expect(client.bodies.single, {
      'recipe': {
        'background': 'pink',
        'skin': '3',
        'hair': 'curly',
        'hairColor': 'brown',
        'expression': 'grin',
        'head': 'headphones',
        'face': 'glasses',
      },
    });
    expect(client.reads, 0, reason: 'Web sets the user from the PUT answer');
    expect(client.replaced.single['id'], 'me');
    expect(saved, 1);
    expect(
      find.byKey(const ValueKey('human-avatar-builder-save')),
      findsNothing,
    );
  });

  testWidgets('a failed save keeps the dialog and every choice, then retries', (
    t,
  ) async {
    client.failure = const RaftApiException('boom', status: 500);
    await open(t);
    await t.tap(option('background', 'lilac'));
    await t.pump();
    await t.tap(save);
    await t.pumpAndSettle();
    expect(
      find.text(
        "Couldn't save your avatar. Your old one is still there. Try saving again.",
      ),
      findsOneWidget,
    );
    expect(
      preview('pixel-human:v1:lilac.3.curly.brown.grin.headphones.glasses'),
      findsOneWidget,
    );
    expect(saveEnabled(t), isTrue);
    expect(client.replaced, isEmpty);
    expect(saved, 0);
    // A new choice clears the banner.
    await t.tap(option('background', 'cream'));
    await t.pump();
    expect(
      find.byKey(const ValueKey('human-avatar-builder-error')),
      findsNothing,
    );
    client.failure = null;
    await t.tap(save);
    await t.pumpAndSettle();
    expect(client.calls.length, 2);
    expect(saved, 1);
  });

  testWidgets('X, Esc, Back, the scrim and Cancel are blocked while saving', (
    t,
  ) async {
    client.pending = Completer<dynamic>();
    await open(t);
    await t.tap(option('background', 'mint'));
    await t.pump();
    await t.tap(save);
    await t.pump();
    expect(client.calls, ['PUT /auth/me/avatar-recipe']);
    final cancel = t.widget<RaftButton>(
      find.byKey(const ValueKey('human-avatar-builder-cancel')),
    );
    expect(cancel.onPressed, isNull);
    await t.tap(anyX.first, warnIfMissed: false);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    await t.tapAt(const Offset(6, 6));
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(HumanAvatarBuilderDialog), findsOneWidget);
    expect(
      t.widget<RaftButton>(save).busy,
      isTrue,
      reason: 'Save shows its busy state',
    );
    client.pending!.complete(null);
    await t.pumpAndSettle();
    expect(find.byType(HumanAvatarBuilderDialog), findsNothing);
    expect(saved, 1);
  });

  testWidgets('Cancel, Esc and Back close it without a request', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('human-avatar-builder-cancel')));
    await t.pumpAndSettle();
    expect(find.byType(HumanAvatarBuilderDialog), findsNothing);
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(HumanAvatarBuilderDialog), findsNothing);
    expect(client.calls, isEmpty);
  });

  testWidgets('on a phone it is a sheet with Save in its head', (t) async {
    await open(t, size: const Size(390, 844));
    expect(find.byType(RaftFormSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RaftFormSheet),
        matching: find.byKey(const ValueKey('human-avatar-builder-save')),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('human-avatar-builder-cancel')),
      findsNothing,
      reason: 'the X is Cancel on the sheet',
    );
  });
}
