import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_composer.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';

void main() {
  test('adopting a draft describes interrupted checks and transfers', () {
    final owner = Object();
    final composer = WorkspaceComposer(
      owner: owner,
      read: (_, _) async => null,
      write: (_, _, _, {required requiredSuccess}) async {},
    );
    addTearDown(() => composer.disposeOwnedBy(owner));
    final checking = UploadDraft('checking.png', Uint8List(16), key: 1)
      ..checking = true;
    final uploading = UploadDraft('uploading.png', Uint8List(16), key: 2)
      ..progress = .4;
    composer.uploads.byScope['local-dm'] = [checking, uploading];

    composer.adoptScope('local-dm', 'actual-dm');

    expect(composer.uploads.byScope['actual-dm'], [checking, uploading]);
    expect(
      checking.error,
      'File checking was interrupted. Remove it and attach again.',
    );
    expect(checking.canRetry, isFalse);
    expect(uploading.error, 'File upload was interrupted. Tap to retry.');
    expect(uploading.progress, 0);
    expect(uploading.canRetry, isTrue);
  });
}
