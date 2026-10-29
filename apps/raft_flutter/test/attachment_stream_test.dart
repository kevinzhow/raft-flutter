// The streamed source of an attachment: its signed URL, one admission of the
// first request when the Raft server itself serves the bytes (the user's
// 120/min attachment limit), and one re-sign for an expired signature.
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_flutter/platform/attachment_stream.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test('the key is the attachment and its content version', () {
    expect(attachmentMediaKey({'id': 'a', 'contentHash': 'h1'}), 'a|h1');
    expect(attachmentMediaKey({'id': 'a', 'updatedAt': 'u'}), 'a|u');
    expect(attachmentMediaKey({'id': 'a'}), 'a|');
  });

  test('a presigned storage URL is streamed as is, nothing sent with it', () async {
    final (w, api) = (await fixture('owner'));
    addTearDown(w.dispose);
    api.routes['GET /attachments/a1/url'] = (_) => {
      'url': 'https://bucket.storage.invalid/a1.mp4?X-Amz-Signature=s1',
    };
    final source = await attachmentStreamSource(w, 'a1', start: const Duration(seconds: 4));
    expect(source.isNetwork, isTrue);
    expect(source.url.toString(), 'https://bucket.storage.invalid/a1.mp4?X-Amz-Signature=s1');
    expect(source.headers, isEmpty, reason: 'the signature is the only credential');
    expect(source.start, const Duration(seconds: 4));
  });

  test('the source names the attachment and whose video cache it belongs to', () async {
    final (w, api) = (await fixture('owner'));
    addTearDown(w.dispose);
    api.routes['GET /attachments/a1/url'] = (_) => {
      'url': 'https://bucket.storage.invalid/a1.mp4?sig=1',
    };
    final source = await attachmentStreamSource(w, 'a1');
    expect(source.cacheKey, 'a1');
    expect(source.cacheAccount, isNotNull);
    expect(source.cacheAccount!.principal, w.client.user!.id);
    expect(source.cacheAccount!.origin, w.client.origin.replaceFirst(RegExp(r'/$'), ''));
    // Signing again keeps the place in the cache (it is keyed by the id, not the signature).
    final fresh = await source.refresh!();
    expect(source.resigned(fresh, start: Duration.zero).cacheKey, 'a1');
  });

  test('the refresh signs again (the cached URL is dropped), once per call', () async {
    final (w, api) = (await fixture('owner'));
    addTearDown(w.dispose);
    var n = 0;
    api.routes['GET /attachments/a1/url'] = (_) => {
      'url': 'https://bucket.storage.invalid/a1.mp4?sig=${++n}',
    };
    final source = await attachmentStreamSource(w, 'a1');
    expect(source.url.toString(), endsWith('sig=1'));
    final fresh = await source.refresh!();
    expect(fresh.toString(), endsWith('sig=2'));
  });

  test('a URL that is not http(s) is refused', () async {
    final (w, api) = (await fixture('owner'));
    addTearDown(w.dispose);
    api.routes['GET /attachments/a1/url'] = (_) => {'url': 'file:///etc/passwd'};
    await expectLater(attachmentStreamSource(w, 'a1'), throwsFormatException);
  });

  group('rate limit', () {
    const limits = [ServerRateLimits.attachments];

    // The governor is process-wide: every test starts and leaves it open, so
    // the order the tests run in (`--test-randomize-ordering-seed`) is moot.
    setUp(AttachmentHttp.governor.reset);
    tearDown(AttachmentHttp.governor.reset);

    test('a URL under /api/attachments is admitted through the governor', () async {
      final (w, api) = (await fixture('owner'));
      addTearDown(w.dispose);
      api.routes['GET /attachments/a1/url'] = (_) => {
        'url': 'https://raft.example/api/attachments/a1?token=t',
      };
      final before = AttachmentHttp.governor.paced + AttachmentHttp.governor.limited;
      // Open bucket: admitted at once.
      final source = await attachmentStreamSource(w, 'a1');
      expect(source.url!.path, '/api/attachments/a1');
      expect(AttachmentHttp.governor.paced + AttachmentHttp.governor.limited, before);
      // A bucket the server closed for longer than a foreground wait: the open
      // fails (the card says "Download to View") instead of sending a request
      // the server would refuse.
      AttachmentHttp.governor.limitedBy(limits, const Duration(minutes: 5));
      await expectLater(attachmentStreamSource(w, 'a1'), throwsA(isA<RateLimitedException>()));
    });

    test('a presigned URL on another host is not counted at all', () async {
      final (w, api) = (await fixture('owner'));
      addTearDown(w.dispose);
      api.routes['GET /attachments/a2/url'] = (_) => {
        'url': 'https://bucket.storage.invalid/a2.mp4?sig=1',
      };
      AttachmentHttp.governor.limitedBy(limits, const Duration(minutes: 5));
      final source = await attachmentStreamSource(w, 'a2');
      expect(source.isNetwork, isTrue);
    });
  });
}
