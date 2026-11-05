import 'dart:convert';
import 'dart:io';

import 'html_region_system_qa_document.dart';

/// Fresh loopback-only HTTP state. Reads never create comments or anchors.
class HtmlRegionSystemQaFixture {
  HttpServer? _server;
  final requests = <Map<String, Object?>>[];
  final posts = <Map<String, dynamic>>[];
  final comments = <Map<String, dynamic>>[];
  Future<Map<String, Object?>> Function()? readUi;
  String get origin => 'http://127.0.0.1:${_server!.port}';
  Uri get preview => Uri.parse(
    '$origin/api/attachments/region-qa/html-preview?previewToken=synthetic',
  );

  Future<void> start() async {
    if (_server != null) throw StateError('Fixture already started');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  static Map<String, dynamic> copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

  bool validAnchor(Object? value) {
    if (value is! Map ||
        value['type'] != 'html-region' ||
        value['data'] is! Map) {
      return false;
    }
    final data = value['data'] as Map;
    const allowed = {
      'x',
      'y',
      'w',
      'h',
      'viewportWidth',
      'documentWidth',
      'documentHeight',
      'quote',
    };
    if (data.keys.any((key) => !allowed.contains(key))) return false;
    for (final key in allowed.where((key) => key != 'quote')) {
      final number = data[key];
      if (number is! num ||
          !number.isFinite ||
          number < 0 ||
          number > 10000000 ||
          (key.endsWith('Width') || key.endsWith('Height')) && number <= 0) {
        return false;
      }
    }
    return data['quote'] == null ||
        data['quote'] is String && (data['quote'] as String).length <= 200;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final log = <String, Object?>{
      'method': request.method,
      'path': path,
      'cookiePresent': request.headers.value('cookie') != null,
      'authorizationPresent': request.headers.value('authorization') != null,
    };
    requests.add(log);
    if (requests.length > 128) requests.removeAt(0);
    Object? response;
    try {
      if (request.method == 'GET' &&
          path == '/api/attachments/region-qa/html-preview') {
        request.response.headers
          ..contentType = ContentType.html
          ..set('Content-Security-Policy', htmlRegionSystemQaCsp)
          ..set('Cache-Control', 'no-store');
        request.response.write(htmlRegionSystemQaDocument);
      } else {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, path)) {
          case ('GET', '/api/attachments/region-qa/html-preview-url'):
            response = {'url': preview.toString()};
          case ('POST', '/api/feature-flags/evaluate'):
            final body = await _body(request);
            log['body'] = body;
            response = {
              'evaluations': [
                {'key': 'attachment_comments_v0', 'enabled': true},
              ],
            };
          case ('GET', '/api/attachments/region-qa/comments'):
            response = {
              'comments': comments.map(copy).toList(),
              'viewer': {'canComment': true},
              'threadChannelId': 'qa-comments',
            };
          case ('POST', '/api/attachments/region-qa/comments'):
            final body = await _body(request);
            if (body is! Map<String, dynamic> ||
                body['content'] is! String ||
                (body['content'] as String).trim().isEmpty ||
                !validAnchor(body['anchor'])) {
              request.response.statusCode = HttpStatus.badRequest;
              response = {
                'error':
                    'A real HTML region anchor and comment text are required',
              };
            } else {
              final stored = copy(body);
              posts.add(stored);
              final comment = <String, dynamic>{
                'id': 'region-comment-${comments.length + 1}',
                'senderId': 'qa-human',
                'senderType': 'user',
                'senderName': '区域验收员',
                'content': body['content'],
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'anchor': stored['anchor'],
              };
              comments.add(comment);
              log['savedCommentId'] = comment['id'];
              response = copy(comment);
            }
          case ('GET', '/qa/comments'):
            response = {
              'comments': comments.map(copy).toList(),
              'posts': posts.map(copy).toList(),
              'readOnly': true,
            };
          case ('GET', '/qa/status'):
            response = {
              'fixture': {
                'origin': origin,
                'commentCount': comments.length,
                'postCount': posts.length,
                'requests': List.of(requests),
              },
              'ui': await readUi?.call(),
              'scope': 'isolated synthetic fixture; no AppRoot, persistent account or production service',
            };
          case ('GET', '/api/channels/unread'):
            response = {'channels': <String, dynamic>{}};
          default:
            request.response.statusCode = HttpStatus.notFound;
            response = {'error': 'Unknown isolated QA route', 'path': path};
        }
        request.response.write(jsonEncode(response));
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        jsonEncode({
          'error': 'Invalid local fixture request',
          'type': error.runtimeType.toString(),
        }),
      );
    } finally {
      await request.response.close();
    }
  }

  Future<Object?> _body(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > 16384) {
        throw const FormatException('Fixture body too large');
      }
    }
    return jsonDecode(utf8.decode(bytes));
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }
}
