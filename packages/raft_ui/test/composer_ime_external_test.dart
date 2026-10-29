import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    Widget host({
      String draft = '',
      int revision = 0,
      List<String>? edits,
      RaftComposerHandle? handle,
      Future<bool> Function(String)? send,
      Key? composerKey,
    }) => MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RaftComposer(
            key: composerKey,
            initialDraft: draft,
            draftRevision: revision,
            clearOnSubmit: true,
            handle: handle,
            onDraftChanged: edits?.add,
            onSend: send ?? (_) async => true,
          ),
        ),
      ),
    );
    testWidgets(
      'failed send persists recovery without rewriting live IME ${dark ? 'dark' : 'light'}',
      (t) async {
        final reply = Completer<bool>(), edits = <String>[];
        await t.pumpWidget(
          host(draft: 'sent', edits: edits, send: (_) => reply.future),
        );
        final c = t.widget<TextField>(find.byType(TextField)).controller!;
        await t.tap(find.byKey(const ValueKey('composer-submit')));
        await t.pump();
        expect(c.text, isEmpty);
        const value = TextEditingValue(
          text: 'new 中文',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 4, end: 6),
        );
        c.value = value;
        reply.complete(false);
        await t.pump();
        expect(c.value, value);
        expect(edits.last, 'sent\nnew 中文');
        c.value = const TextEditingValue(
          text: 'new 中文继续😀',
          selection: TextSelection.collapsed(offset: 10),
          composing: TextRange(start: 4, end: 10),
        );
        await t.pump();
        expect(c.text, 'new 中文继续😀');
        expect(edits.last, 'sent\nnew 中文继续😀');
        c.value = c.value.copyWith(composing: TextRange.empty);
        await t.pump();
        await t.pump();
        expect(c.text, 'sent\nnew 中文继续😀');
        expect(c.selection.baseOffset, 15);
        expect(c.value.composing, TextRange.empty);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'successive external captions survive navigation during IME ${dark ? 'dark' : 'light'}',
      (t) async {
        final edits = <String>[];
        await t.pumpWidget(host(draft: 'native', edits: edits));
        final c = t.widget<TextField>(find.byType(TextField)).controller!;
        c.value = const TextEditingValue(
          text: 'native',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 0, end: 6),
        );
        await t.pumpWidget(
          host(draft: 'native\none', revision: 1, edits: edits),
        );
        c.value = const TextEditingValue(
          text: 'native中文',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 0, end: 8),
        );
        await t.pumpWidget(
          host(draft: 'native中文\none\ntwo', revision: 2, edits: edits),
        );
        expect(c.text, 'native中文');
        expect(edits.last, 'native中文\none\ntwo');
        await t.pumpWidget(
          host(
            draft: 'different channel',
            composerKey: const ValueKey('other'),
            edits: <String>[],
          ),
        );
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          'different channel',
        );
        expect(edits.last, 'native中文\none\ntwo');
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'programmatic mention preserves an emoji at synthetic midpoint ${dark ? 'dark' : 'light'}',
      (t) async {
        final handle = RaftComposerHandle();
        await t.pumpWidget(host(draft: '😀', handle: handle));
        final c = t.widget<TextField>(find.byType(TextField)).controller!;
        c.selection = const TextSelection.collapsed(offset: 1);
        expect(
          handle.insertMention(
            const RaftComposerSuggestion(
              type: 'user',
              id: 'fixture',
              name: 'Fixture',
            ),
          ),
          isTrue,
        );
        expect(c.text, '@Fixture 😀');
        expect(c.selection.baseOffset, 9);
        expect(c.text.runes.last, 0x1f600);
        await t.pump();
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      'long dictation and ordinary rebuild preserve native editing value ${dark ? 'dark' : 'light'}',
      (t) async {
        await t.pumpWidget(host());
        final c = t.widget<TextField>(find.byType(TextField)).controller!;
        final text = '中文😀 ${'long speech ' * 1000}';
        final value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange(start: 0, end: text.length),
        );
        c.value = value;
        await t.pump();
        await t.pumpWidget(host());
        expect(c.value, value);
        expect(
          t.widget<TextField>(find.byType(TextField)).inputFormatters,
          isNull,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
