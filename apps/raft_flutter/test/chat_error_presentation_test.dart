import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/forward_composer_page.dart';
import 'package:raft_flutter/features/pending_mention_actions.dart';

// Chat failures read like Web: the server's own text or the surface's Web
// fallback, never exception text.
void main() {
  group('upload errors (Web attachmentUploadErrorPresentation)', () {
    test('the storage timeout is mapped to its catalog sentence', () {
      expect(
        WorkspaceController.uploadErrorText(
          const RaftApiException('Attachment storage timed out'),
        ),
        'The file reached Raft, but saving it timed out.',
      );
    });

    test('UPLOAD_* codes map to catalog copy', () {
      final error = RaftApiException.response(
        'raw server text',
        status: 400,
        body: {'error': 'raw server text', 'code': 'UPLOAD_TOO_LARGE'},
      );
      expect(
        WorkspaceController.uploadErrorText(error),
        'The attachment exceeds the plan limit.',
      );
    });

    test('a structured server error keeps its own words', () {
      final error = RaftApiException.response(
        'Monthly file upload quota exceeded',
        status: 402,
        body: {'error': 'Monthly file upload quota exceeded'},
      );
      expect(
        WorkspaceController.uploadErrorText(error),
        'Monthly file upload quota exceeded',
      );
    });

    test('transport and unknown failures show the Web retry hint only', () {
      for (final failure in <Object>[
        DioException(
          requestOptions: RequestOptions(path: '/x?token=abc'),
          message: 'connection reset https://x.test/u?token=abc',
        ),
        StateError('boom'),
        const FormatException('bad json'),
      ]) {
        expect(
          WorkspaceController.uploadErrorText(failure),
          'File no longer available or upload failed. Tap to retry.',
        );
      }
    });
  });

  group('forward failure (Web forwardRequestFailureMessage)', () {
    String message(Object error) => forwardRequestFailureMessage(error);

    test('maps each server code to its sentence', () {
      RaftApiException coded(String code) => RaftApiException.response(
        'x',
        status: 400,
        body: {'error': 'x', 'code': code},
      );
      expect(
        message(coded('cross_source_bundle')),
        'Select messages from one conversation or thread.',
      );
      expect(
        message(coded('cross_server_source')),
        "Messages from another server can't be forwarded here.",
      );
      expect(
        message(coded('unsupported_source')),
        message(coded('unsupported_source_message')),
      );
    });

    test('anything else is the uncertain-outcome sentence', () {
      const uncertain =
          "We couldn't confirm whether the forward finished. It's safe to try again.";
      expect(message(StateError('socket closed')), uncertain);
      expect(
        message(const RaftApiException('Server said no', status: 500)),
        uncertain,
      );
    });
  });

  testWidgets(
    'mention action notices follow Web formatMentionActionStatusNotice',
    (t) async {
      late BuildContext context;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      String notice(Map? result) => mentionActionStatusNotice(context, result);
      expect(notice(null), 'This mention action is no longer available.');
      expect(
        notice({
          'status': 'no_permission',
          'reason': 'target_lacks_read_access',
        }),
        'That person cannot read this conversation, so they were not notified.',
      );
      expect(
        notice({'status': 'stale', 'reason': 'target_already_member'}),
        'That target is already in the channel, so no action is needed.',
      );
      expect(notice({'status': 'expired'}), 'This mention action has expired.');
      expect(
        notice({'status': 'weird'}),
        'This mention action could not be applied.',
      );
    },
  );
}
