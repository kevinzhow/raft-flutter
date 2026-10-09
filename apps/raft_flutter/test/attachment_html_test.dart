import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

const csp =
    "default-src 'none'; sandbox allow-scripts; script-src 'unsafe-inline' https:; "
    "connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; worker-src 'none'";

class HtmlAdapter implements HttpClientAdapter {
  String policy = csp;
  Uint8List data = Uint8List.fromList('<h1>Native page</h1>'.codeUnits);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async => ResponseBody.fromBytes(
    data,
    200,
    headers: {
      'content-security-policy': [policy],
    },
  );
  @override
  void close({bool force = false}) {}
}

class PendingHtmlLoader extends AttachmentHtmlLoader {
  final pending = Completer<String?>();
  final loadStarted = Completer<void>();
  int verified = 0;
  @override
  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) {
    loadStarted.complete();
    return pending.future;
  }

  @override
  Future<bool> verify(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    verified++;
    return authorized();
  }
}

// Dio's interceptor queue spans the real async zone and the widget fake zone.
// Drain both until the observed callback completes; a fixed sleep only runs
// one zone and does not prove that the capability request reached the loader.
Future<void> waitForHtmlCompletion(
  WidgetTester tester,
  bool Function() completed,
) async {
  final deadline = Stopwatch()..start();
  while (!completed() && deadline.elapsed < const Duration(seconds: 5)) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(
    completed(),
    isTrue,
    reason: 'The actual HTML callback must complete.',
  );
}

void main() {
  test('only exact same-origin HTML capability and pinned sandbox authorize browser execution', () {
    final valid =
        'https://example.com/api/attachments/a/html-preview?previewToken=opaque&serverId=s';
    expect(
      attachmentHtmlPreviewUri(valid, 'https://example.com', 'a').path,
      '/api/attachments/a/html-preview',
    );
    for (final value in [
      valid.replaceFirst('example.com', 'other.com'),
      valid.replaceFirst('/html-preview?', '/download?'),
      valid.replaceFirst('previewToken', 'token'),
      'file:///private.html',
      '$valid&access_token=secret',
    ]) {
      expect(
        () => attachmentHtmlPreviewUri(value, 'https://example.com', 'a'),
        throwsFormatException,
      );
    }
    expect(attachmentHtmlSandboxed(csp), isTrue);
    expect(
      attachmentHtmlSandboxed(
        csp.replaceFirst('allow-scripts', 'allow-scripts allow-same-origin'),
      ),
      isFalse,
    );
    expect(
      attachmentHtmlSandboxed(csp.replaceFirst('sandbox allow-scripts;', '')),
      isFalse,
    );
    expect(
      attachmentHtmlSandboxed(
        csp.replaceFirst("connect-src 'none'", 'connect-src https:'),
      ),
      isFalse,
    );
  });
  test('HTML links use source parent policy and block credentials/application/private hosts', () {
    expect(
      attachmentHtmlExternalLink(
        'https://example.com/reference',
        'https://api.raft.build',
      ),
      isNotNull,
    );
    for (final value in [
      'http://example.com',
      'https://user@example.com',
      'https://example.com:8443',
      'https://127.0.0.1',
      'https://machine.local',
      'https://app.raft.build',
      'https://api.raft.build',
      'https://example.com?previewToken=x',
      'https://example.com#token=x',
      'javascript:alert(1)',
      '/relative',
    ]) {
      expect(
        attachmentHtmlExternalLink(value, 'https://api.raft.build'),
        isNull,
      );
    }
  });
  test(
    'loader refuses missing sandbox headers and purges transfer bytes',
    () async {
      final adapter = HtmlAdapter();
      List<int>? transferred;
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            transferred = response.data as List<int>?;
            handler.next(response);
          },
        ),
      );
      final loader = AttachmentHtmlLoader(dio: dio);
      addTearDown(loader.dispose);
      final text = await loader.load(
        Uri.parse('https://example.com/preview'),
        cancel: CancelToken(),
        authorized: () => true,
      );
      expect(text, contains('Native page'));
      expect(transferred, isNotEmpty);
      expect(transferred!.every((byte) => byte == 0), isTrue);
      adapter.policy = "default-src 'none'";
      await expectLater(
        loader.load(
          Uri.parse('https://example.com/preview'),
          cancel: CancelToken(),
          authorized: () => true,
        ),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'late HTML load after revocation neither renders nor opens a browser',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /attachments/a/html-preview-url'] = (_) => {
        'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
      };
      final loader = PendingHtmlLoader();
      var authorized = true, opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: HtmlAttachmentPreviewDialog(
              controller: w,
              metadata: const {'id': 'a', 'filename': 'document.html'},
              authorized: () => authorized,
              onClose: () {},
              onDownload: () async {},
              loader: loader,
              openExternal: (_) async {
                opened++;
                return true;
              },
            ),
          ),
        ),
      );
      await waitForHtmlCompletion(tester, () => loader.loadStarted.isCompleted);
      authorized = false;
      w.setError(null);
      loader.pending.complete('<h1>Private late document</h1>');
      await tester.pumpAndSettle();
      expect(find.text('Private late document'), findsNothing);
      expect(opened, 0);
      expect(loader.verified, 0);
    },
  );
  testWidgets(
    'interactive opening requires an explicit action and fresh scoped validation',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /attachments/a/html-preview-url'] = (_) => {
        'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
      };
      final loader = PendingHtmlLoader();
      Uri? opened;
      final externalOpened = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: HtmlAttachmentPreviewDialog(
              controller: w,
              metadata: const {'id': 'a', 'filename': 'document.html'},
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
              loader: loader,
              openExternal: (uri) async {
                opened = uri;
                externalOpened.complete();
                return true;
              },
            ),
          ),
        ),
      );
      await waitForHtmlCompletion(tester, () => loader.loadStarted.isCompleted);
      loader.pending.complete('<h1>Native document</h1>');
      await tester.pumpAndSettle();
      expect(opened, isNull);
      expect(loader.verified, 0);
      final button = tester.widget<RaftButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is RaftButton &&
              widget.label == 'Open interactive preview in browser',
        ),
      );
      expect(button.onPressed, isNotNull);
      await tester.tap(
        find.byWidgetPredicate((widget) => identical(widget, button)),
      );
      await waitForHtmlCompletion(tester, () => externalOpened.isCompleted);
      expect(loader.verified, 1);
      expect(opened?.path, '/api/attachments/a/html-preview');
      expect(
        api.calls.where(
          (call) => call.path == '/attachments/a/html-preview-url',
        ),
        hasLength(2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
