import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

const _desktopPastePlatforms = TargetPlatformVariant({
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
});

Future<void> _pump(WidgetTester tester, RaftComposer composer) =>
    tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: composer),
        ),
      ),
    );

void _clipboardText(WidgetTester tester, String text) => tester
    .binding
    .defaultBinaryMessenger
    .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': text};
      if (call.method == 'Clipboard.hasStrings') return {'value': true};
      return null;
    });

Future<void> _ctrlV(WidgetTester tester) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets(
    'Ctrl/Cmd+V hands clipboard files to the host and skips the text paste',
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
    (tester) async {
      _clipboardText(tester, '/home/me/report.pdf');
      var asked = 0;
      await _pump(
        tester,
        RaftComposer(
          onSend: (_) async => true,
          onPasteAttachments: () async {
            asked++;
            return true;
          },
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await _ctrlV(tester);
      expect(asked, 1);
      expect(_text(tester), isEmpty);
    },
  );

  testWidgets('text paste is unaffected when the clipboard has no files', (
    tester,
  ) async {
    _clipboardText(tester, 'plain words');
    var asked = 0;
    await _pump(
      tester,
      RaftComposer(
        onSend: (_) async => true,
        onPasteAttachments: () async {
          asked++;
          return false;
        },
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _ctrlV(tester);
    expect(asked, 1);
    expect(_text(tester), 'plain words');
  });

  testWidgets(
    'paste keeps the dictated text while attachment inspection is pending',
    variant: _desktopPastePlatforms,
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      var clipboard = 'dictated synthetic words';
      final inspecting = Completer<bool>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        },
      );
      await _pump(
        tester,
        RaftComposer(
          onSend: (_) async => true,
          onPasteAttachments: () => inspecting.future,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await _ctrlV(tester);
      clipboard = 'previous clipboard';
      inspecting.complete(false);
      await tester.pumpAndSettle();
      expect(_text(tester), 'dictated synthetic words');
    },
  );

  testWidgets(
    'a delayed toolbar paste retains its original clipboard text',
    variant: _desktopPastePlatforms,
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      var clipboard = 'toolbar dictated words';
      final inspecting = Completer<bool>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        },
      );
      await _pump(
        tester,
        RaftComposer(
          onSend: (_) async => false,
          onPasteAttachments: () => inspecting.future,
        ),
      );
      await tester.longPress(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pump();
      clipboard = 'restored clipboard';
      inspecting.complete(false);
      await tester.pumpAndSettle();
      expect(_text(tester), 'toolbar dictated words');
    },
  );

  testWidgets(
    'pending clipboard text cannot follow focus into another editor',
    variant: _desktopPastePlatforms,
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      _clipboardText(tester, 'dictated words');
      final inspecting = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
          home: Scaffold(
            body: Column(
              children: [
                RaftComposer(
                  onSend: (_) async => false,
                  onPasteAttachments: () => inspecting.future,
                ),
                const TextField(key: ValueKey('other-editor')),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await _ctrlV(tester);
      await tester.tap(find.byKey(const ValueKey('other-editor')));
      await tester.pump();
      inspecting.complete(false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((f) => f.controller?.text ?? ''),
        ['', ''],
      );
    },
  );

  testWidgets(
    'captured paste replaces the selection and keeps editor undo',
    variant: _desktopPastePlatforms,
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
      _clipboardText(tester, 'voice');
      await _pump(
        tester,
        RaftComposer(
          initialDraft: 'prefix suffix',
          onSend: (_) async => false,
          onPasteAttachments: () async => false,
        ),
      );
      await tester.tap(find.byType(TextField));
      final field = tester.widget<TextField>(find.byType(TextField));
      field.controller!.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 13,
      );
      await tester.pump();
      // Advance the fake clock past UndoHistory's initial throttled snapshot.
      await tester.pump(const Duration(milliseconds: 600));
      await _ctrlV(tester);
      expect(_text(tester), 'prefix voice');
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 12),
      );
      final history = field.undoController!;
      for (var frame = 0; frame < 40 && !history.value.canUndo; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(history.value.canUndo, isTrue);
      history.undo();
      await tester.pumpAndSettle();
      expect(_text(tester), 'prefix suffix');
    },
  );

  for (final taken in [true, false]) {
    testWidgets('toolbar Paste asks the host first (taken: $taken)', (
      tester,
    ) async {
      _clipboardText(tester, 'menu words');
      var asked = 0;
      await _pump(
        tester,
        RaftComposer(
          onSend: (_) async => true,
          onPasteAttachments: () async {
            asked++;
            return taken;
          },
        ),
      );
      await tester.longPress(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(asked, 1);
      expect(_text(tester), taken ? isEmpty : 'menu words');
    });
  }

  testWidgets('a failing clipboard read still pastes the text', (tester) async {
    _clipboardText(tester, 'fallback');
    await _pump(
      tester,
      RaftComposer(
        onSend: (_) async => true,
        onPasteAttachments: () => Future.error(StateError('no clipboard')),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _ctrlV(tester);
    expect(_text(tester), 'fallback');
  });

  testWidgets('without a host handler the composer pastes text as before', (
    tester,
  ) async {
    _clipboardText(tester, 'untouched');
    await _pump(tester, RaftComposer(onSend: (_) async => true));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _ctrlV(tester);
    expect(_text(tester), 'untouched');
  });

  testWidgets('keyboard-inserted images reach the host only when enabled', (
    tester,
  ) async {
    final inserted = <KeyboardInsertedContent>[];
    Future<void> commit(bool enabled) async {
      await _pump(
        tester,
        RaftComposer(
          onSend: (_) async => true,
          enabled: enabled,
          onContentInserted: inserted.add,
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.contentInsertionConfiguration, isNotNull);
      field.contentInsertionConfiguration!.onContentInserted(
        KeyboardInsertedContent(
          mimeType: 'image/gif',
          uri: 'content://keyboard/sticker',
          data: Uint8List.fromList([1, 2, 3]),
        ),
      );
    }

    await commit(false);
    expect(inserted, isEmpty);
    await commit(true);
    expect(inserted.single.mimeType, 'image/gif');
    await _pump(tester, RaftComposer(onSend: (_) async => true));
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .contentInsertionConfiguration,
      isNull,
    );
  });

  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} drop overlay covers the composer without '
      'taking input or semantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(elegantThemePackId),
              dark: dark,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  children: [
                    RaftComposer(onSend: (_) async => true),
                    const Positioned.fill(child: RaftComposerDropOverlay()),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.text('Drop files to attach'), findsOneWidget);
        // `absolute inset-0` of the composer root: its padding box, below the
        // root's `border-t` (1px).
        final composer = tester.getRect(find.byType(RaftComposer));
        expect(
          tester.getRect(find.byKey(const ValueKey('composer-drop-overlay'))),
          Rect.fromLTRB(
            composer.left,
            composer.top + 1,
            composer.right,
            composer.bottom,
          ),
        );
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Drop files to attach'), findsNothing);
        semantics.dispose();
        expect(
          find.ancestor(
            of: find.text('Drop files to attach'),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('drop overlay label is localized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(pack: packForThemeId(elegantThemePackId)),
        home: Scaffold(
          body: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('zh'),
              child: const RaftComposerDropOverlay(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('拖放文件以添加附件'), findsOneWidget);
  });
}
