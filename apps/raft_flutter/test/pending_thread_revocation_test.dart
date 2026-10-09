import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final revokeParent in [true, false]) {
    test('[N24a] pending parent storage revocation=$revokeParent', () async {
      SharedPreferences.setMockInitialValues({});
      final (base, api) = await fixture('member');
      final main = RaftChannel({'id': 'c0', 'name': 'main', 'joined': true}),
          parentChannel = base.channel!,
          other = RaftChannel({'id': 'c2', 'name': 'other', 'joined': true});
      final (w, db) = await (() async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory());
        return (
          WorkspaceController(base.client, cache: cache, ownsClient: false)
            ..server = base.server
            ..channel = main
            ..channels = [main, parentChannel, other],
          cache,
        );
      })();
      addTearDown(() async {
        w.dispose();
        base.dispose();
        await db.close();
      });
      final parent = Completer<Map<String, dynamic>>.sync(),
          parentStarted = Completer<void>.sync(),
          uploadStarted = Completer<void>.sync(),
          mainUploadStarted = Completer<void>.sync(),
          threadUpload = Completer<Map<String, dynamic>>.sync(),
          mainUpload = Completer<Map<String, dynamic>>.sync(),
          lateRead = Completer<Map<String, dynamic>>.sync(),
          lateReadStarted = Completer<void>.sync();
      api.routes['GET /messages/channel/c0'] = (_) => {
        'messages': [row('main', 'c0', 2)],
      };
      api.routes['POST /channels/c0/read'] = (_) => {
        'maxReadSeq': 2,
        'readStateVersion': 3,
      };
      api.routes['GET /messages/context/parent'] = (_) {
        parentStarted.complete();
        return parent.future;
      };
      api.routes['GET /messages/channel/thread-1'] = (_) => {
        'messages': [row('private-reply', 'thread-1', 7)],
      };
      var reads = 0;
      api.routes['POST /channels/thread-1/read'] = (_) {
        if (++reads == 1) {
          return {'maxReadSeq': 7, 'readStateVersion': 4};
        }
        lateReadStarted.complete();
        return lateRead.future;
      };
      api.routes['POST /attachments/upload'] = (request) {
        final form = request.data as FormData;
        final channel = form.fields
            .singleWhere((f) => f.key == 'channelId')
            .value;
        if (channel == 'c0') {
          mainUploadStarted.complete();
          return mainUpload.future;
        }
        expect(channel, 'thread-1');
        uploadStarted.complete();
        return threadUpload.future;
      };
      late Future<void> mainTransfer, threadTransfer, reading;
      late UploadDraft mainAttachment, threadAttachment;
      await (() async {
        w.ledger.switchServer('s1');
        await w.selectChannel(main);
        w.saveDraft('Keep unrelated main draft');
        mainTransfer = w.attachUpload('main.txt', Uint8List.fromList([1]));
        await Future.any([
          mainUploadStarted.future,
          mainTransfer.then((_) {
            expect(
              mainUploadStarted.isCompleted,
              true,
              reason:
                  'Upload did not reach transport: ${w.uploads().single.error}; calls ${api.calls.map((c) => c.path).toList()}',
            );
          }),
        ]);
        mainAttachment = w.uploads().single;
        w.setSection('activity');
        w.navigation.navigate(
          w.location.withQuery({
            'open': 'thread:thread-1',
            'thread': 'c1:parent',
          }),
        );
        await w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'parent',
          initialThreadChannelId: 'thread-1',
          navigate: false,
        );
        await parentStarted.future;
        w.saveDraft('Private parent draft', thread: true);
        threadTransfer = w.attachUpload(
          'private.txt',
          Uint8List.fromList([2]),
          thread: true,
        );
        await Future.any([
          uploadStarted.future,
          threadTransfer.then((_) {
            expect(
              uploadStarted.isCompleted,
              true,
              reason:
                  'Upload did not reach transport: ${w.uploads(thread: true).single.error}',
            );
          }),
        ]);
        threadAttachment = w.uploads(thread: true).single;
        await w.flushCache();
        expect(w.presentedThreadParent, isNull);
        expect(w.threadParentLoading, true);
        expect(w.ledger.messages('c1'), isEmpty);
        expect(w.replies.single.id, 'private-reply');
        expect(w.readState.state('s1', 'alice', 'thread-1')?['maxReadSeq'], 7);
        expect(
          await db.read(w.client.origin, 'alice', 's1', 'window', 'thread-1'),
          isNotNull,
        );
        expect(
          await db.read(
            w.client.origin,
            'alice',
            's1',
            'draft',
            'thread:parent',
          ),
          isNotNull,
        );
        // A same-named record under another principal is outside this purge.
        await db.write(
          w.client.origin,
          'other-user',
          's1',
          'draft',
          'thread:parent',
          {'text': 'Other account'},
        );
        reading = w.markRead('thread-1');
        await lateReadStarted.future;
      })();
      final removed = revokeParent ? 'c1' : 'c2';
      api.routes['GET /channels'] = (_) => [
        main.json,
        if (!revokeParent) parentChannel.json,
        if (revokeParent) other.json,
      ];
      api.routes['GET /channels/dm'] = (_) => [];
      await (() async {
        await w.refreshChannels();
        await w.flushCache();
        expect(w.channels.any((c) => c.id == removed), false);
        expect(w.channel?.id, 'c0');
        expect(w.messages.single.id, 'main');
        expect(w.drafts['c0'], 'Keep unrelated main draft');
        expect(mainAttachment.cancel.cancelled, false);
        expect(w.readState.state('s1', 'alice', 'c0')?['maxReadSeq'], 2);
        expect(
          await db.read(w.client.origin, 'alice', 's1', 'window', 'c0'),
          isNotNull,
        );
        expect(
          await db.read(
            w.client.origin,
            'other-user',
            's1',
            'draft',
            'thread:parent',
          ),
          {'text': 'Other account'},
        );
        if (revokeParent) {
          expect(w.threadIdentity, isNull);
          expect(w.replies, isEmpty);
          expect(w.ledger.messages('thread-1'), isEmpty);
          expect(w.visibleIds.containsKey('thread-1'), false);
          expect(w.drafts.containsKey('thread:parent'), false);
          expect(w.readState.state('s1', 'alice', 'thread-1'), isNull);
          expect(threadAttachment.cancel.cancelled, true);
          expect(
            await db.read(w.client.origin, 'alice', 's1', 'window', 'thread-1'),
            isNull,
          );
          expect(
            await db.read(
              w.client.origin,
              'alice',
              's1',
              'draft',
              'thread:parent',
            ),
            isNull,
          );
          final frontiers = await db.read(
            w.client.origin,
            'alice',
            's1',
            'read-frontiers',
            '',
          ) as List;
          expect(frontiers.any((f) => f['scopeId'] == 'thread-1'), false);
        } else {
          expect(w.threadIdentity?.parentMessageId, 'parent');
          expect(w.replies.single.id, 'private-reply');
          expect(w.drafts['thread:parent'], 'Private parent draft');
          expect(threadAttachment.cancel.cancelled, false);
          expect(
            await db.read(w.client.origin, 'alice', 's1', 'window', 'thread-1'),
            isNotNull,
          );
          expect(
            await db.read(
              w.client.origin,
              'alice',
              's1',
              'draft',
              'thread:parent',
            ),
            isNotNull,
          );
        }
        parent.complete({
          'messages': [row('parent', 'c1', 1)],
        });
        lateRead.complete({'maxReadSeq': 8, 'readStateVersion': 5});
        threadUpload.complete({
          'attachments': [
            {'id': 'private-upload'},
          ],
        });
        mainUpload.complete({
          'attachments': [
            {'id': 'main-upload'},
          ],
        });
        await Future.wait([reading, threadTransfer, mainTransfer]);
        await Future<void>.delayed(Duration.zero);
        await w.flushCache();
        expect(mainAttachment.id, 'main-upload');
        if (revokeParent) {
          expect(w.presentedThreadParent, isNull);
          expect(threadAttachment.id, isNull);
          expect(w.readState.state('s1', 'alice', 'thread-1'), isNull);
          expect(
            await db.read(
              w.client.origin,
              'alice',
              's1',
              'draft',
              'thread:parent',
            ),
            isNull,
          );
        } else {
          expect(w.presentedThreadParent?.id, 'parent');
          expect(threadAttachment.id, 'private-upload');
          expect(
            w.readState.state('s1', 'alice', 'thread-1')?['maxReadSeq'],
            8,
          );
        }
      })();
    });
  }

  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final revokeParent in [true, false]) {
      testWidgets(
        '[N24a] $family/$dark held-parent private rows retire only on parent revocation=$revokeParent',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, api) = (await tester.runAsync(() => fixture('member')))!;
          addTearDown(w.dispose);
          final parentChannel = w.channel!,
              main = RaftChannel({'id': 'c0', 'name': 'main', 'joined': true}),
              other = RaftChannel({
                'id': 'c2',
                'name': 'other',
                'joined': true,
              });
          w.channels.addAll([main, other]);
          w.channel = main;
          w.ledger.switchServer('s1');
          w.ledger.ingest([
            row('main', 'c0', 2),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c0'] = {'main'};
          w.setSection('activity');
          w.navigation.navigate(
            w.location.withQuery({
              'open': 'thread:thread-1',
              'thread': 'c1:parent',
              'msg': 'private-reply',
            }),
          );
          final parent = Completer<Map<String, dynamic>>.sync(),
              started = Completer<void>.sync();
          api.routes['GET /messages/context/parent'] = (_) {
            started.complete();
            return parent.future;
          };
          api.routes['GET /messages/context/private-reply'] = (_) => {
            'messages': [row('private-reply', 'thread-1', 7)],
          };
          api.routes['POST /channels/thread-1/read'] = (_) => {
            'maxReadSeq': 7,
            'readStateVersion': 4,
          };
          await tester.runAsync(() async {
            await w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
              initialThreadChannelId: 'thread-1',
              focusedMessageId: 'private-reply',
              navigate: false,
            );
            expect(started.isCompleted, true);
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(body: RaftChatView(controller: w, thread: true)),
            ),
          );
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(paintedMessage(tester, 'private-reply'), isNotNull);
          expect(w.presentedThreadParent, isNull);
          api.routes['GET /channels'] = (_) => [
            main.json,
            if (!revokeParent) parentChannel.json,
            if (revokeParent) other.json,
          ];
          api.routes['GET /channels/dm'] = (_) => [];
          await tester.runAsync(w.refreshChannels);
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(w.messages.single.id, 'main');
            expect(find.text('Message parent'), findsNothing);
            if (revokeParent) {
              expect(w.threadIdentity, isNull);
              expect(w.ledger.messages('thread-1'), isEmpty);
              expect(paintedMessage(tester, 'private-reply'), isNull);
            } else {
              expect(w.threadIdentity?.parentMessageId, 'parent');
              expect(paintedMessage(tester, 'private-reply'), isNotNull);
            }
          }
          await tester.runAsync(() async {
            parent.complete({
              'messages': [row('parent', 'c1', 1)],
            });
            for (var i = 0; i < 40 && w.threadParentLoading; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          for (var frame = 0; frame < 6; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            if (revokeParent) {
              expect(w.presentedThreadParent, isNull);
              expect(paintedMessage(tester, 'private-reply'), isNull);
              expect(find.text('Message parent'), findsNothing);
            } else {
              expect(w.presentedThreadParent?.id, 'parent');
              expect(paintedMessage(tester, 'private-reply'), isNotNull);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
