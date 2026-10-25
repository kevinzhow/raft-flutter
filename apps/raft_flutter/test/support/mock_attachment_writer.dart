import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_files.dart';

/// Transfer/staging tests only. Real Foundation and sandbox quarantine behavior
/// are covered by the native macOS tests and the NSSavePanel acceptance fixture.
void mockAttachmentWriter() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(AttachmentFiles.channel, (call) async {
    if (call.method != 'writeSaved') throw MissingPluginException();
    final args = Map<String, Object?>.from(call.arguments as Map);
    await File(args['uri']! as String)
        .writeAsBytes(await File(args['path']! as String).readAsBytes());
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(AttachmentFiles.channel, null);
  });
}
