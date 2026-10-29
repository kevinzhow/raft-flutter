import 'package:raft_ui/raft_ui.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import 'forward_composer_page.dart';

/// The retry keeps the exact server idempotency payload, including destinations.
/// Successful destinations are reported separately from failed destinations.
class ForwardAttempt {
  ForwardAttempt({
    required String requestId,
    required List<String> sources,
    required List<String> destinations,
    required String note,
  }) : payload = Map.unmodifiable({
         'requestId': requestId,
         'sourceMessageIds': List<String>.unmodifiable(sources),
         'destinationChannelIds': List<String>.unmodifiable(destinations),
         'note': note.trim(),
       });
  final Map<String, dynamic> payload;
  List<String> get destinations => payload['destinationChannelIds'];
  final Map<String, String> outcomes = {};
  final Map<String, String> errors = {};
  void apply(dynamic response) {
    if (response is! Map || response['results'] is! List) {
      throw const RaftApiException(
        'The forward response was incomplete. Retry this request.',
      );
    }
    final rows = (response['results'] as List).whereType<Map>().toList();
    for (final id in destinations) {
      final matching = rows
          .where((r) => r['destinationChannelId'] == id)
          .toList();
      // Missing/duplicate/unrecognized receipts never become success.
      if (matching.length != 1 ||
          !['success', 'failed'].contains(matching.single['status'])) {
        if (outcomes[id] != 'success') {
          outcomes[id] = 'unknown';
          errors[id] = 'No conclusive receipt. Retry the same request.';
        }
        continue;
      }
      final row = matching.single;
      if (row['status'] == 'success' &&
          row['message'] is Map &&
          row['message']['id'] is String &&
          (row['message']['id'] as String).isNotEmpty) {
        outcomes[id] = 'success';
        errors.remove(id);
      } else if (row['status'] == 'success' && outcomes[id] != 'success') {
        outcomes[id] = 'unknown';
        errors[id] = 'No conclusive receipt. Retry the same request.';
      } else if (outcomes[id] != 'success') {
        outcomes[id] = 'failed';
        errors[id] = row['error'] is String
            ? row['error']
            : 'Could not forward to this target.';
      }
    }
  }

  bool get completed => destinations.every((id) => outcomes[id] == 'success');
}

/// Web getForwardableMessages (forwardSelectionUtils.ts): only a `system`
/// message or one whose `actionMetadata.kind` is set (action card, forwarded
/// bundle) is blocked; any other messageType value is forwardable.
bool messageForwardable(RaftMessage message) {
  if (message.string('messageType') == 'system') return false;
  final meta = message.json['actionMetadata'];
  final kind = meta is Map ? meta['kind'] : null;
  return kind == null || kind == '';
}

Future<bool> forwardMessages(
  BuildContext context,
  WorkspaceController controller,
  List<RaftMessage> messages,
) async {
  if (messages.isEmpty || messages.length > 20) {
    throw const RaftApiException('Forward between 1 and 20 messages.');
  }
  if (!messages.every(messageForwardable)) {
    throw const RaftApiException(
      'Only original, ordinary chat messages can be forwarded.',
    );
  }
  // Web ForwardComposerDialog: ForwardComposerMobile below `md` (768px).
  if (MediaQuery.sizeOf(context).width < 768) {
    return showForwardComposerPage(context, controller, messages);
  }
  return await showRaftDialog<bool>(
        legacyMaterial: true,
        context: context,
        builder: (_) => ForwardComposerPage(
          controller: controller,
          messages: messages,
          desktop: true,
        ),
      ) ??
      false;
}
