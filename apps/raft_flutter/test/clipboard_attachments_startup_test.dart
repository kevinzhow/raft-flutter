import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// The iOS paste hook takes a system Paste of attachments only after Dart's
// watcher asked `available` (RaftSharingBridge.swift `dartReady`). The watcher
// starts at app start, so every field, including sign-in before any chat,
// gets an answer at once rather than a paste that waits in the channel.
void main() {
  test('the clipboard watcher starts in main, before the app root', () {
    final source = File('lib/main.dart').readAsStringSync();
    final watch = source.indexOf('ClipboardAttachments.watch();');
    expect(watch, isNonNegative, reason: 'main.dart starts the watcher');
    expect(watch, lessThan(source.indexOf('runRaftAppRoot(')));
  });

  test('no screen starts the clipboard watcher late', () {
    final late = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !p.equals(file.path, p.join('lib', 'main.dart')) &&
            p.basename(file.path) != 'clipboard_attachments.dart' &&
            file.readAsStringSync().contains('ClipboardAttachments.watch('))
          file.path,
    ];
    expect(late, isEmpty);
  });
}
