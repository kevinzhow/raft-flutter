import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/composer_editing.dart';

void main() {
  test('programmatic offsets clamp without splitting UTF16 pairs', () {
    expect(raftSafeEditingOffset('A😀B', 2), 1);
    expect(raftSafeEditingOffset('A😀B', 2, forward: true), 3);
    expect(raftSafeEditingOffset('😀', -1), 0);
    expect(raftSafeEditingOffset('😀', 9), 2);
    expect(raftSafeEditingOffset('A😀B', 3), 3);
  });
  test('only invalid surrogate units in app drafts are replaced', () {
    for (final text in ['中文', '😀', '👨‍👩‍👦', 'e\u0301', 'long ' * 5000]) {
      expect(raftProgrammaticEditingText(text), text);
    }
    expect(
      raftProgrammaticEditingText(
        String.fromCharCodes([0xd800, 65, 0xdc00, 0xd83d, 0xde00]),
      ),
      '�A�😀',
    );
    expect(
      raftProgrammaticEditingText(
        String.fromCharCodes([65, 0xd83d, 0xde00, 0xd800, 0xd83d, 0xde00]),
      ),
      'A😀�😀',
    );
  });
  test(
    'deferred append follows evolving native text without stale overwrite',
    () {
      final update = RaftDeferredComposerDraft('中文语音', '中文语音\nshared');
      expect(update.resolve('中文语音继续'), '中文语音继续\nshared');
      expect(update.resolve('中文更正😀'), '中文更正😀\nshared');
    },
  );
  test('failed prefix and combined prefix/suffix preserve ongoing input', () {
    expect(
      RaftDeferredComposerDraft('new', 'sent\nnew').resolve('new voice'),
      'sent\nnew voice',
    );
    expect(
      RaftDeferredComposerDraft('new', 'sent\nnew\nshared').resolve('new 中文😀'),
      'sent\nnew 中文😀\nshared',
    );
  });
  test('disjoint external replacement follows live editing offsets', () {
    expect(
      RaftDeferredComposerDraft('abc def', 'ABC def').resolve('abc definition'),
      'ABC definition',
    );
    expect(
      RaftDeferredComposerDraft('abc def', 'abc DEF').resolve('abcd def'),
      'abcd DEF',
    );
  });
  test(
    'conflicting replacements retain both values instead of losing live text',
    () {
      expect(
        RaftDeferredComposerDraft('abc', 'XYZ').resolve('abdc'),
        'abdc\nXYZ',
      );
    },
  );
  test(
    'caret moves with prepended recovery and stays before appended caption',
    () {
      const value = TextEditingValue(
        text: 'new😀',
        selection: TextSelection.collapsed(offset: 5),
      );
      expect(raftProgrammaticSelection(value, 'sent\nnew😀').baseOffset, 10);
      expect(raftProgrammaticSelection(value, 'new😀\nshared').baseOffset, 5);
      expect(
        raftProgrammaticSelection(
          const TextEditingValue(
            text: 'ab',
            selection: TextSelection.collapsed(offset: 1),
          ),
          '😀',
        ).baseOffset,
        2,
      );
      expect(
        raftProgrammaticSelection(
          const TextEditingValue(
            text: '😀',
            selection: TextSelection.collapsed(offset: 1),
          ),
          '😀',
        ).baseOffset,
        0,
      );
    },
  );
  test(
    'identical failed text keeps prepend intent through a later caption',
    () {
      final recovery = RaftDeferredComposerDraft(
        'same',
        'same\nsame',
        preferPrepend: true,
      );
      final caption = RaftDeferredComposerDraft(
        'same\nsame',
        'same\nsame\ncaption',
        following: recovery,
      );
      expect(caption.resolve('new voice'), 'same\nnew voice\ncaption');
      final value = caption.resolveValue(
        const TextEditingValue(
          text: 'new voice',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(value.text, 'same\nnew voice\ncaption');
      expect(value.selection.baseOffset, 9);
    },
  );
  test('combined prefix and suffix keep caret in the live text', () {
    expect(
      raftProgrammaticSelection(
        const TextEditingValue(
          text: 'new',
          selection: TextSelection.collapsed(offset: 2),
        ),
        'sent\nnew\ncaption',
      ).baseOffset,
      7,
    );
  });
}
