import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/artifacts/artifact_attachment_saves.dart';
import 'package:raft_flutter/features/artifacts/artifact_session.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_ui/raft_ui.dart';

import '../support/artifact_fake_client.dart';

/// Save as Artifact on a document attachment and the line under it (WP-ART1,
/// Web ArtifactAttachment.tsx): the menu, the saving and saved lines,
/// failures with Retry, and `artifact:attachment-saved`.
void main() {
  const meta = {
    'id': 'att1',
    'filename': 'notes.txt',
    'mimeType': 'text/plain',
    'sizeBytes': 4096,
  };
  late ArtifactFakeClient client;
  late WorkspaceController w;

  setUp(() {
    client = ArtifactFakeClient();
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Dev'});
  });
  tearDown(() => w.dispose());

  Map<String, Object?> saved() => {
    'artifact': artifactViewerJson(card: artifactCardJson(title: 'notes')),
    'created': true,
  };

  void savesAre(Object? savedAs) =>
      client.answers['GET /artifacts/attachment-saves?attachmentIds=att1'] =
          (_) => {
            'saves': [
              if (savedAs != null) {'attachmentId': 'att1', 'savedAs': savedAs},
            ],
          };

  Future<void> show(
    WidgetTester tester, {
    Map<String, dynamic> metadata = meta,
    String? messageId = 'm1',
    bool enabled = true,
  }) async {
    client.enabled = enabled;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftToastHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: AttachmentView(
                controller: w,
                files: AttachmentFiles(),
                metadata: metadata,
                messageId: messageId,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('artifact-attachment-menu-trigger')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Save as Artifact'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a savable document has the menu; saving shows the saved line '
      'and a toast', (tester) async {
    savesAre(null);
    client.answers['POST /artifacts/save-attachment'] = (_) => saved();
    await show(tester);
    expect(
      find.byKey(const ValueKey('artifact-attachment-menu-trigger')),
      findsOneWidget,
    );
    expect(
      client.requests,
      contains('GET /artifacts/attachment-saves?attachmentIds=att1'),
    );
    savesAre({'status': 'ok', 'card': artifactCardJson(title: 'notes')});
    await save(tester);
    expect(client.bodies['POST /artifacts/save-attachment'], {
      'attachmentId': 'att1',
    });
    expect(
      find.byKey(const ValueKey('artifact-attachment-saved')),
      findsOneWidget,
    );
    expect(find.text('notes'), findsWidgets);
    expect(find.text('v1'), findsOneWidget);
    expect(find.text('Saved as Artifact “notes”'), findsOneWidget);
    // Saved: the menu is gone (the line takes over).
    expect(
      find.byKey(const ValueKey('artifact-attachment-menu-trigger')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('already saved when it is shown: the line, no menu', (
    tester,
  ) async {
    savesAre({'status': 'ok', 'card': artifactCardJson(title: 'notes')});
    await show(tester);
    expect(
      find.byKey(const ValueKey('artifact-attachment-saved')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artifact-attachment-menu-trigger')),
      findsNothing,
    );
  });

  testWidgets('nothing with the flag off, in an export, on an image, over '
      'the size limit or while uploading', (tester) async {
    await show(tester, enabled: false);
    expect(
      find.byKey(const ValueKey('artifact-attachment-menu-trigger')),
      findsNothing,
    );
    expect(
      client.requests.where((r) => r.contains('attachment-saves')),
      isEmpty,
    );
    expect(
      canSaveAsArtifact(
        id: 'a',
        filename: 'big.bin',
        sizeBytes: 15 * 1024 * 1024 + 1,
      ),
      isFalse,
    );
    expect(
      canSaveAsArtifact(
        id: 'a',
        filename: 'big.csv',
        sizeBytes: 16 * 1024 * 1024,
      ),
      isTrue,
    );
    expect(
      canSaveAsArtifact(
        id: 'optimistic-att-1',
        filename: 'a.txt',
        sizeBytes: 1,
      ),
      isFalse,
    );
  });

  testWidgets('a failed save says why and Retry tries again; too large has '
      'no Retry', (tester) async {
    savesAre(null);
    var attempts = 0;
    client.answers['POST /artifacts/save-attachment'] = (_) {
      attempts++;
      if (attempts == 1) {
        return RaftApiException.response(
          'x',
          status: 500,
          body: {'error': 'x', 'code': 'INTERNAL'},
        );
      }
      return saved();
    };
    await show(tester);
    await save(tester);
    expect(find.text('Couldn\'t save it as an Artifact.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('artifact-attachment-save-retry')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(attempts, 2);
    expect(
      find.byKey(const ValueKey('artifact-attachment-saved')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));

    final attempt = const ArtifactSaveAttempt.failed(
      ArtifactSaveFailure.tooLarge,
    );
    expect(attempt.retryable, isFalse);
  });

  testWidgets('artifact:attachment-saved asks again for a shown attachment, '
      'and never for one that is not', (tester) async {
    savesAre(null);
    await show(tester);
    int asks() =>
        client.requests.where((r) => r.contains('attachment-saves')).length;
    expect(asks(), 1);
    savesAre({'status': 'ok', 'card': artifactCardJson(title: 'notes')});
    client.ingress.add(
      const RaftEvent('artifact:attachment-saved', {
        'channelId': 'c1',
        'messageId': 'm1',
        'attachmentId': 'other',
      }),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(asks(), 1);
    client.ingress.add(
      const RaftEvent('artifact:attachment-saved', {
        'channelId': 'c1',
        'messageId': 'm1',
        'attachmentId': 'att1',
      }),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(asks(), 2);
    expect(
      find.byKey(const ValueKey('artifact-attachment-saved')),
      findsOneWidget,
    );
    expect(ArtifactSession.peek(w), isNotNull);
  });
}
