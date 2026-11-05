// Only the local HTTP contract. This is not a native region-comment acceptance
// test: runtime acceptance must use real GTK pointer and composer input.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/html_region_system_qa_document.dart';
import '../integration_test/html_region_system_qa_fixture.dart';

// Flutter's test binding normally returns a synthetic HTTP 400. This one owned
// client uses Dart's actual socket implementation for the loopback-only URLs
// below; the process-wide override and production transports are unchanged.
class _FixtureHttpFactory extends HttpOverrides {
  HttpClient open() =>
      super.createHttpClient(null)..findProxy = (_) => 'DIRECT';
}

void main() {
  late HtmlRegionSystemQaFixture fixture;
  late HttpClient http;
  setUp(() async {
    fixture = HtmlRegionSystemQaFixture();
    await fixture.start();
    http = _FixtureHttpFactory().open();
  });
  tearDown(() async {
    http.close(force: true);
    await fixture.close();
  });

  Future<({int status, String body, HttpHeaders headers})> request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final outgoing = await http.openUrl(
      method,
      Uri.parse('${fixture.origin}$path'),
    );
    if (body != null) {
      outgoing.headers.contentType = ContentType.json;
      outgoing.write(jsonEncode(body));
    }
    final response = await outgoing.close();
    return (
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
      headers: response.headers,
    );
  }

  Map<String, Object> anchor() => {
    'type': 'html-region',
    'data': {
      'x': 28,
      'y': 190,
      'w': 340,
      'h': 110,
      'viewportWidth': 790,
      'documentWidth': 790,
      'documentHeight': 1700,
      'quote': '区域评论验收：这里是可以重新排版的中文内容。',
    },
  };

  test('fresh comments reads are empty and cannot create an anchor', () async {
    for (final path in [
      '/qa/comments',
      '/qa/status',
      '/api/attachments/region-qa/comments',
    ]) {
      final result = await request('GET', path);
      expect(result.status, HttpStatus.ok);
    }
    expect(fixture.posts, isEmpty);
    expect(fixture.comments, isEmpty);
    expect(fixture.requests.length, 3);
    final status = jsonDecode((await request('GET', '/qa/status')).body) as Map;
    expect(status['ui'], isNull);
    expect(status['fixture']['postCount'], 0);
  });

  test('actual HTTP POST persists exact Unicode anchor and independent GET reads it', () async {
    final body = {'content': '这是独立 HTTP 协议测试的中文评论。', 'anchor': anchor()};
    final saved = await request(
      'POST',
      '/api/attachments/region-qa/comments',
      body,
    );
    expect(saved.status, HttpStatus.ok);
    final first = jsonDecode(saved.body) as Map;
    expect(first['anchor'], body['anchor']);
    expect(first['content'], body['content']);
    // A separate connection/HTTP GET reads the fixture's saved result; neither
    // the widget observer nor status readback can create this stored record.
    final read = jsonDecode((await request('GET', '/qa/comments')).body) as Map;
    expect(read['readOnly'], true);
    expect(read['posts'], [body]);
    expect((read['comments'] as List).single, first);
    final product = jsonDecode(
      (await request('GET', '/api/attachments/region-qa/comments')).body,
    ) as Map;
    expect(product['viewer'], {'canComment': true});
    expect(product['comments'], [first]);
  });

  test(
    'invalid or absent regions cannot become successful stored comments',
    () async {
      final invalid = [
        null,
        {
          'type': 'lines',
          'data': {'start': 1},
        },
        {
          'type': 'html-region',
          'data': {'x': -1},
        },
        {
          'type': 'html-region',
          'data': {...anchor()['data'] as Map, 'hostBridge': 'forbidden'},
        },
      ];
      for (final value in invalid) {
        final result = await request(
          'POST',
          '/api/attachments/region-qa/comments',
          {'content': '拒绝无效锚点', 'anchor': value},
        );
        expect(result.status, HttpStatus.badRequest);
      }
      expect(fixture.posts, isEmpty);
      expect(fixture.comments, isEmpty);
    },
  );

  test(
    'real preview URL serves the isolated reflow document and exact CSP',
    () async {
      final link = jsonDecode(
        (await request(
          'GET',
          '/api/attachments/region-qa/html-preview-url',
        )).body,
      ) as Map;
      expect(link['url'], fixture.preview.toString());
      final result = await request('GET', fixture.preview.path);
      expect(result.status, HttpStatus.ok);
      expect(result.headers.contentType?.mimeType, 'text/html');
      expect(
        result.headers.value('content-security-policy'),
        htmlRegionSystemQaCsp,
      );
      expect(result.headers.value('cache-control'), 'no-store');
      expect(result.body, htmlRegionSystemQaDocument);
    },
  );

  test(
    'product flag and post-send unread routes have real mounted contracts',
    () async {
      final flag = await request('POST', '/api/feature-flags/evaluate', {
        'keys': ['attachment_comments_v0'],
        'serverId': 'region-qa',
      });
      expect((jsonDecode(flag.body) as Map)['evaluations'], [
        {'key': 'attachment_comments_v0', 'enabled': true},
      ]);
      final unread = await request('GET', '/api/channels/unread?summary=1');
      expect(unread.status, HttpStatus.ok);
      expect(jsonDecode(unread.body), {'channels': <String, dynamic>{}});
    },
  );

  test(
    'QA routes are read only and no input-driving endpoint exists',
    () async {
      for (final path in [
        '/qa/status',
        '/qa/comments',
        '/qa/capture',
        '/qa/jump',
        '/qa/input',
      ]) {
        expect((await request('POST', path, {})).status, HttpStatus.notFound);
      }
      expect(fixture.posts, isEmpty);
      expect(fixture.comments, isEmpty);
    },
  );
}
