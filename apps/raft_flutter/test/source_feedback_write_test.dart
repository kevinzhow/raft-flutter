// Feedback writes (hands-feedback-react NewFeedbackForm / FeedbackTicket /
// FeedbackInbox close): confirmed, never optimistic; every POST is followed
// by the authoritative detail GET; failures keep the user's input.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';

import 'source_feedback_store_test.dart' as fx;

class _Post {
  _Post(this.path, this.json, this.form, this.abort);
  final String path;
  final Map<String, dynamic>? json;
  final SourceFeedbackForm? form;
  final SourceFeedbackAbort? abort;
}

/// A fake transport: list/detail GETs from [details], POSTs recorded and
/// answered by [answer] (a value, a thrown failure or a pending future).
class _Fake {
  _Fake({List<Map<String, dynamic>>? tickets})
    : tickets = tickets ?? [fx.ticket(fx.first), fx.ticket(fx.second)];
  final List<Map<String, dynamic>> tickets;
  final details = <String, Map<String, dynamic>>{};
  final gets = <String>[];
  final posts = <_Post>[];
  Object? Function(_Post post) answer = (_) => {'id': fx.second};
  String? scope = 'account';
  var ids = 0;

  late final store = SourceFeedbackStore(
    authority: () => scope,
    newId: () => 'id-${++ids}',
    get: (path, {query}) async {
      gets.add(path);
      if (path == '/product-feedback/tickets') return fx.page(tickets);
      final id = path.split('/').last;
      return details[id] ?? fx.detail(id);
    },
    post: (path, {json, form, onProgress, abort}) async {
      final post = _Post(path, json, form, abort);
      posts.add(post);
      onProgress?.call(.5);
      final value = answer(post);
      if (value is Future) return await value;
      if (value is Exception) throw value;
      return value;
    },
  );
}

SourceFeedbackFile _png(String name, {int size = 4, String? type}) =>
    SourceFeedbackFile(
      name: name,
      contentType: type ?? 'image/png',
      bytes: Uint8List(size),
    );

void main() {
  test('Web transport error mapping uses the closed code set', () {
    expect(
      sourceFeedbackErrorFor('feedback_submission_conflict', 409),
      SourceFeedbackError.conflict,
    );
    expect(
      sourceFeedbackErrorFor('feedback_comment_conflict', 409),
      SourceFeedbackError.conflict,
    );
    expect(
      sourceFeedbackErrorFor('feedback_attachment_too_large', 413),
      SourceFeedbackError.invalid,
    );
    expect(
      sourceFeedbackErrorFor('feedback_rate_limited', 429),
      SourceFeedbackError.rateLimited,
    );
    expect(
      sourceFeedbackErrorFor('feedback_not_found', 404),
      SourceFeedbackError.notFound,
    );
    expect(sourceFeedbackErrorFor(null, 403), SourceFeedbackError.unauthorized);
    expect(
      sourceFeedbackErrorFor('feedback_service_unavailable', 503),
      SourceFeedbackError.unavailable,
    );
  });

  test('New feedback posts the Web multipart form, then opens the read '
      'ticket at the top of the inbox', () async {
    final fake = _Fake(tickets: [fx.ticket(fx.first)]);
    final store = fake.store;
    await store.loadList();
    store.startNew();
    expect(store.route, SourceFeedbackRoute.create);
    expect(store.canSubmitNew, isFalse);
    store.setNewMessage('   ');
    expect(store.canSubmitNew, isFalse);
    await store.submitNew();
    expect(fake.posts, isEmpty);
    store
      ..setNewKind('bug')
      ..setNewMessage('  Crash on paste \n')
      ..addNewAttachments([_png('a.png')]);
    fake.details[fx.second] = fx.detail(
      fx.second,
      comments: [fx.reply('c1', 3000)],
      unread: 4,
    );
    await store.submitNew();
    final post = fake.posts.single;
    expect(post.path, '/product-feedback');
    expect(post.form!.fields, {
      'type': 'problem',
      'message': 'Crash on paste',
      'submission_id': 'id-2',
      'may_contact': 'false',
    });
    expect(post.form!.attachments.single.name, 'a.png');
    expect(fake.gets.where((p) => p.endsWith(fx.second)).length, 2);
    expect(store.route, SourceFeedbackRoute.ticket);
    expect(store.selectedId, fx.second);
    expect(store.tickets.first.id, fx.second);
    expect(store.comments.single.id, 'c1');
    expect(store.unreadTotal, 4);
    expect(store.announcement, SourceFeedbackAnnouncement.created);
    expect(store.newMessage, isEmpty);
    store.dispose();
  });

  test('a failed create keeps the form, marks uploads failed and retries '
      'with the same submission id until the content changes', () async {
    final fake = _Fake()
      ..answer = (_) =>
          const SourceFeedbackFailure(SourceFeedbackError.invalid);
    final store = fake.store;
    store
      ..startNew()
      ..setNewMessage('Idea')
      ..addNewAttachments([_png('a.png')]);
    await store.submitNew();
    expect(store.route, SourceFeedbackRoute.create);
    expect(store.newSending, isFalse);
    expect(store.newError!.error, SourceFeedbackError.invalid);
    expect(store.newAttachments.single.state, SourceFeedbackUploadState.failed);
    expect(store.newMessage, 'Idea');
    await store.submitNew();
    expect(
      fake.posts.map((p) => p.form!.fields['submission_id']).toSet().length,
      1,
    );
    store.setNewMessage('Idea 2');
    await store.submitNew();
    expect(
      fake.posts.last.form!.fields['submission_id'],
      isNot(fake.posts.first.form!.fields['submission_id']),
    );
    store.dispose();
  });

  test('Cancel while submitting aborts and ignores the late answer', () async {
    final fake = _Fake();
    final pending = Completer<Object?>();
    fake.answer = (_) => pending.future;
    final store = fake.store;
    store
      ..startNew()
      ..setNewMessage('Hello')
      ..addNewAttachments([_png('a.png')]);
    final submitting = store.submitNew();
    expect(store.newSending, isTrue);
    expect(store.canSubmitNew, isFalse);
    expect(
      store.newAttachments.single.state,
      SourceFeedbackUploadState.uploading,
    );
    store.cancelNew();
    expect(fake.posts.single.abort!.aborted, isTrue);
    expect(store.route, SourceFeedbackRoute.create);
    expect(store.newSending, isFalse);
    expect(store.newAttachments.single.state, SourceFeedbackUploadState.ready);
    expect(store.announcement, SourceFeedbackAnnouncement.uploadCanceled);
    pending.complete({'id': fx.second});
    await submitting;
    expect(store.route, SourceFeedbackRoute.create);
    expect(fake.gets.where((p) => p.endsWith(fx.second)), isEmpty);
    store.cancelNew();
    expect(store.route, SourceFeedbackRoute.inbox);
    store.dispose();
  });

  test('attachment checks: count, type and size, nothing added on error', () {
    final store = _Fake().store..startNew();
    store.addNewAttachments([_png('a.png'), _png('b.png')]);
    store.addNewAttachments([_png('c.png'), _png('d.png')]);
    expect(store.newAttachments, hasLength(2));
    expect(store.newError!.attachment, SourceFeedbackAttachmentIssue.tooMany);
    store.addNewAttachments([_png('e.svg', type: 'image/svg+xml')]);
    expect(
      store.newError!.attachment,
      SourceFeedbackAttachmentIssue.unsupported,
    );
    expect(store.newError!.name, 'e.svg');
    store.addNewAttachments([
      SourceFeedbackFile(
        name: 'big.png',
        contentType: 'image/png',
        bytes: Uint8List(0),
        declaredSize: sourceFeedbackMaxAttachmentBytes + 1,
      ),
    ]);
    expect(store.newError!.attachment, SourceFeedbackAttachmentIssue.tooLarge);
    store.addNewAttachments([_png('ok.webp', type: 'image/webp')]);
    expect(store.newError, isNull);
    expect(store.newAttachments, hasLength(3));
    store.removeNewAttachment(store.newAttachments.first.id);
    expect(store.newAttachments, hasLength(2));
    store.dispose();
  });

  test('reply posts the trimmed body, then the detail GET replaces the '
      'conversation and clears only that ticket draft', () async {
    final fake = _Fake()..answer = (_) => {'id': 'comment'};
    final store = fake.store;
    await store.loadList();
    await store.openTicket(fx.first);
    expect(store.canSendReply, isFalse);
    store.setReply('  Thanks!  ');
    expect(store.canSendReply, isTrue);
    await store.openTicket(fx.second);
    store.setReply('second draft');
    await store.openTicket(fx.first);
    expect(store.reply, '  Thanks!  ');
    fake.details[fx.first] = fx.detail(
      fx.first,
      comments: [fx.reply('mine', 5000, body: 'Thanks!')],
      unread: 1,
    );
    expect(await store.sendReply(), isTrue);
    final post = fake.posts.single;
    expect(post.path, '/product-feedback/tickets/${fx.first}/comments');
    expect(post.form!.fields, {'body': 'Thanks!', 'submission_id': 'id-1'});
    expect(store.comments.single.id, 'mine');
    expect(store.reply, isEmpty);
    expect(store.unreadTotal, 1);
    expect(store.announcement, SourceFeedbackAnnouncement.replySent);
    await store.openTicket(fx.second);
    expect(store.reply, 'second draft');
    store.dispose();
  });

  test(
    'a failed reply keeps the draft and shows the error in the composer',
    () async {
      final fake = _Fake()
        ..answer = (_) =>
            const SourceFeedbackFailure(SourceFeedbackError.rateLimited);
      final store = fake.store;
      await store.loadList();
      await store.openTicket(fx.first);
      store
        ..setReply('Hello')
        ..addReplyAttachments([_png('a.png')]);
      expect(await store.sendReply(), isFalse);
      expect(store.reply, 'Hello');
      expect(store.replySending, isFalse);
      expect(store.actionError!.error, SourceFeedbackError.rateLimited);
      expect(
        store.replyAttachments.single.state,
        SourceFeedbackUploadState.failed,
      );
      store.dispose();
    },
  );

  test('close from the conversation: confirm, busy dialog cannot be '
      'dismissed, then the closed ticket moves to the inbox top', () async {
    final fake = _Fake();
    final pending = Completer<Object?>();
    fake.answer = (_) => pending.future;
    final store = fake.store;
    await store.loadList();
    await store.openTicket(fx.second);
    store.requestClose(fx.second, SourceFeedbackCloseReason.noLongerNeeded);
    expect(store.closeRequest!.detail, isTrue);
    final closing = store.confirmClose();
    expect(store.closing, isTrue);
    store.dismissClose();
    expect(store.closeRequest, isNotNull);
    fake.details[fx.second] = {
      ...fx.detail(fx.second),
      'ticket': {
        ...fx.ticket(fx.second, status: 'closed', unread: false),
        'closure_reason': 'no_longer_needed',
      },
    };
    pending.complete({'ok': true});
    await closing;
    final post = fake.posts.single;
    expect(post.path, '/product-feedback/tickets/${fx.second}/close');
    expect(post.json, {'reason': 'no_longer_needed'});
    expect(store.closeRequest, isNull);
    expect(store.closing, isFalse);
    expect(store.detail!.status, 'closed');
    expect(store.canSendReply, isFalse);
    expect(store.tickets.first.id, fx.second);
    expect(store.tickets.first.closureReason, 'no_longer_needed');
    expect(store.announcement, SourceFeedbackAnnouncement.closed);
    store.dispose();
  });

  test('close from an inbox row replaces the row in place; a failure stays '
      'in the dialog', () async {
    final fake =
        _Fake(
            tickets: [
              fx.ticket(fx.first),
              fx.ticket(fx.second, status: 'resolved'),
            ],
          )
          ..answer = (_) =>
              const SourceFeedbackFailure(SourceFeedbackError.unavailable);
    final store = fake.store;
    await store.loadList();
    expect(
      SourceFeedbackCloseReason.defaultFor('resolved'),
      SourceFeedbackCloseReason.completed,
    );
    store.requestClose(fx.second, SourceFeedbackCloseReason.completed);
    await store.confirmClose();
    expect(store.closeRequest, isNotNull);
    expect(store.closeError, SourceFeedbackError.unavailable);
    fake.answer = (_) => {'ok': true};
    fake.details[fx.second] = {
      ...fx.detail(fx.second),
      'ticket': {
        ...fx.ticket(fx.second, status: 'closed', unread: false),
        'closure_reason': 'completed',
      },
    };
    await store.confirmClose();
    expect(fake.posts.last.json, {'reason': 'completed'});
    expect(store.closeRequest, isNull);
    expect(store.tickets.map((t) => t.id), [fx.first, fx.second]);
    expect(store.tickets.last.status, 'closed');
    store.dismissClose();
    store.dispose();
  });

  test('an authority change during a write drops its answer', () async {
    final fake = _Fake();
    final pending = Completer<Object?>();
    fake.answer = (_) => pending.future;
    final store = fake.store;
    await store.loadList();
    await store.openTicket(fx.first);
    store.setReply('private');
    final sending = store.sendReply();
    fake.scope = 'other-account';
    store.syncAuthority();
    pending.complete({'id': 'c'});
    expect(await sending, isFalse);
    expect(store.tickets, isEmpty);
    expect(store.reply, isEmpty);
    expect(fake.gets.where((p) => p.endsWith(fx.first)).length, 1);
    store.dispose();
  });
}
