import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

void main() {
  test('artifact:attachment-saved reads three strings, nothing else', () {
    final event = LiveEvent.read(ArtifactAttachmentSavedEvent.name, {
      'channelId': 'c1',
      'messageId': 'm1',
      'attachmentId': 'a1',
      'extra': 1,
    });
    expect(event, isA<ArtifactAttachmentSavedEvent>());
    final saved = event! as ArtifactAttachmentSavedEvent;
    expect(
      [saved.channelId, saved.messageId, saved.attachmentId],
      ['c1', 'm1', 'a1'],
    );
    expect(LiveEvent.names, contains('artifact:attachment-saved'));
  });

  test('a frame missing or mistyping a field is dropped', () {
    for (final payload in <Object?>[
      null,
      'x',
      {'channelId': 'c1', 'messageId': 'm1'},
      {'channelId': 'c1', 'messageId': 'm1', 'attachmentId': 3},
    ]) {
      expect(
        LiveEvent.read(ArtifactAttachmentSavedEvent.name, payload),
        isNull,
      );
    }
  });
}
