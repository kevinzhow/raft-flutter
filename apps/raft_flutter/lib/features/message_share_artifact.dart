// Web utils/selectMarkdown.ts `createSelectedMessagesShareArtifact` and
// `buildShareArtifactXIntentUrl`: the reviewed PNG is uploaded as a public
// share artifact (`POST /share-artifacts/message-selection`, multipart
// `channelId` + `image`) and its page URL goes into an X (Twitter) intent.
import 'package:dio/dio.dart' show DioMediaType, FormData, MultipartFile;
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';

/// The server's `{ id, url, imageUrl }`.
class MessageShareArtifact {
  const MessageShareArtifact({
    required this.id,
    required this.url,
    required this.imageUrl,
  });
  final String id, url, imageUrl;
}

Future<MessageShareArtifact> createMessageSelectionShareArtifact(
  WorkspaceController w, {
  required Uint8List png,
  required String channelId,
  String filename = 'raft-thread.png',
}) async {
  final response = await w.command(
    'POST',
    '/share-artifacts/message-selection',
    data: FormData.fromMap({
      'channelId': channelId,
      'image': MultipartFile.fromBytes(
        png,
        filename: filename,
        contentType: DioMediaType('image', 'png'),
      ),
    }),
  );
  if (response is! Map ||
      response['id'] is! String ||
      response['url'] is! String) {
    throw const RaftApiException('Share failed');
  }
  return MessageShareArtifact(
    id: response['id'] as String,
    url: response['url'] as String,
    imageUrl: '${response['imageUrl'] ?? ''}',
  );
}

/// Web `buildShareArtifactXIntentUrl`.
Uri shareArtifactXIntentUrl(String shareUrl, String viaRaft) => Uri.parse(
  'https://twitter.com/intent/tweet?url=${Uri.encodeComponent(shareUrl)}'
  '&text=${Uri.encodeComponent(viaRaft)}',
);
