import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  RaftComposer composer, {
  RaftFamily family = RaftFamily.elegant,
}) => tester.pumpWidget(
  MaterialApp(
    theme: raftTheme(family),
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

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark drop overlay covers the composer without '
        'taking input or semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
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
      expect(
        tester.getRect(find.byKey(const ValueKey('composer-drop-overlay'))),
        tester.getRect(find.byType(RaftComposer)),
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
    });
  }

  testWidgets('drop overlay label is localized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
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
