import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/app_window.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final editor in [
    'field',
    'composer',
    'password',
    'multiline',
    'form',
    'cupertino',
    'read-only',
  ]) {
    testWidgets('native Paste reaches the focused $editor once', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final controller = TextEditingController();
      var clipboardReads = 0, attachmentChecks = 0;
      final states = <Map>[];
      const channel = MethodChannel('app.raft/window');
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'setWindowCommandsState') {
          states.add(call.arguments as Map);
        }
        return null;
      });
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            clipboardReads++;
            return {'text': 'synthetic dictated words'};
          }
          return null;
        },
      );
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: AppWindowCommands(
              navigatorKey: GlobalKey<NavigatorState>(),
              child: Scaffold(
                body: editor == 'composer'
                    ? RaftComposer(
                        onSend: (_) async => false,
                        onPasteAttachments: () async {
                          attachmentChecks++;
                          return false;
                        },
                      )
                    : editor == 'cupertino'
                    ? CupertinoTextField(controller: controller)
                    : editor == 'form'
                    ? TextFormField(controller: controller)
                    : TextField(
                        controller: controller,
                        readOnly: editor == 'read-only',
                        obscureText: editor == 'password',
                        maxLines: editor == 'multiline' ? 4 : 1,
                      ),
              ),
            ),
          ),
        );
        await t.tap(find.byType(EditableText));
        await t.pump();
        unawaited(
          t.binding.defaultBinaryMessenger.handlePlatformMessage(
            'app.raft/window',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('pasteRequested'),
            ),
            (_) {},
          ),
        );
        await t.pumpAndSettle();
        expect(
          t.widget<EditableText>(find.byType(EditableText)).controller.text,
          editor == 'read-only' ? '' : 'synthetic dictated words',
        );
        expect(clipboardReads, editor == 'read-only' ? 0 : 1);
        expect(attachmentChecks, editor == 'composer' ? 1 : 0);
        expect(states.last['paste'], editor != 'read-only');
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        controller.dispose();
        debugDefaultTargetPlatformOverride = null;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      }
    });
  }
  for (final composer in [false, true]) {
    testWidgets(
      'native window commands leave IME composition intact ($composer)',
      (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        const channel = MethodChannel('app.raft/window');
        var clipboardReads = 0;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
        );
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') clipboardReads++;
            return null;
          },
        );
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: AppWindowCommands(
                navigatorKey: GlobalKey<NavigatorState>(),
                child: Scaffold(
                  body: composer
                      ? RaftComposer(
                          onSend: (_) async => false,
                          onPasteAttachments: () async => false,
                        )
                      : const TextField(),
                ),
              ),
            ),
          );
          await t.tap(find.byType(EditableText));
          await t.pump();
          const marked = TextEditingValue(
            text: 'ni hao',
            selection: TextSelection.collapsed(offset: 6),
            composing: TextRange(start: 0, end: 6),
          );
          t.testTextInput.updateEditingValue(marked);
          await t.pump(const Duration(seconds: 2));
          final editor = t.widget<EditableText>(find.byType(EditableText));
          expect(editor.controller.value, marked);
          const committed = TextEditingValue(
            text: '你好',
            selection: TextSelection.collapsed(offset: 2),
          );
          t.testTextInput.updateEditingValue(committed);
          await t.pump();
          expect(editor.controller.value, committed);
          expect(clipboardReads, 0);
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump();
          debugDefaultTargetPlatformOverride = null;
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        }
      },
    );
  }
  testWidgets('native Paste targets a modal editor and ignores absent focus', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final behind = TextEditingController(text: 'keep background draft');
    final modal = TextEditingController();
    final navigator = GlobalKey<NavigatorState>();
    var reads = 0;
    const channel = MethodChannel('app.raft/window');
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => null,
    );
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          reads++;
          return {'text': 'modal dictated words'};
        }
        return null;
      },
    );
    void paste() => unawaited(
      t.binding.defaultBinaryMessenger.handlePlatformMessage(
        'app.raft/window',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('pasteRequested'),
        ),
        (_) {},
      ),
    );
    try {
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: AppWindowCommands(
            navigatorKey: navigator,
            child: Scaffold(body: TextField(controller: behind)),
          ),
        ),
      );
      await t.tap(find.byType(EditableText));
      await t.pump();
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => AlertDialog(content: TextField(controller: modal)),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(EditableText).last);
      await t.pump();
      paste();
      await t.pumpAndSettle();
      expect(modal.text, 'modal dictated words');
      expect(behind.text, 'keep background draft');
      expect(reads, 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      paste();
      await t.pumpAndSettle();
      expect(reads, 1);
      expect(behind.text, 'keep background draft');
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      behind.dispose();
      modal.dispose();
      debugDefaultTargetPlatformOverride = null;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    }
  });
}
