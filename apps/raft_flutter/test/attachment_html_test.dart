import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_flutter/platform/attachment_http.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
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
  int verified = 0, loaded = 0;
  bool isolated = true;
  void Function(int received, int? total)? reportProgress;
  @override
  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int? total)? onProgress,
  }) {
    reportProgress = onProgress;
    loaded++;
    if (!loadStarted.isCompleted) loadStarted.complete();
    return pending.future;
  }

  @override
  Future<bool> verify(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    verified++;
    return authorized() && isolated;
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
          theme: raftTheme(),
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
          theme: raftTheme(),
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
              widget.label == 'Open Interactive Preview in Browser',
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

  test('large inline-image documents load, only the real cap refuses', () async {
    // A real 3.2 MB report (inline base64 images + script) failed at 2 MiB.
    final adapter = HtmlAdapter()
      ..data = Uint8List.fromList(
        '<h1>Report</h1><img src="data:image/jpeg;base64,${'A' * 3300000}">'
            .codeUnits,
      );
    final loader = AttachmentHtmlLoader(dio: Dio()..httpClientAdapter = adapter);
    addTearDown(loader.dispose);
    final uri = Uri.parse('https://example.com/preview');
    final text = await loader.load(
      uri,
      cancel: CancelToken(),
      authorized: () => true,
    );
    expect(text, contains('Report'));
    expect(text!.length, greaterThan(3 * 1024 * 1024));
    adapter.data = Uint8List(AttachmentHtmlLoader.maxBytes + 1);
    await expectLater(
      loader.load(uri, cancel: CancelToken(), authorized: () => true),
      throwsA(isA<AttachmentHtmlTooLarge>()),
    );
    adapter.data = Uint8List.fromList('x'.codeUnits);
    adapter.policy = "default-src 'none'";
    await expectLater(
      loader.load(uri, cancel: CancelToken(), authorized: () => true),
      throwsA(isA<AttachmentHtmlNotIsolated>()),
    );
  });
  test('closing one preview does not close the shared attachment client', () async {
    final adapter = HtmlAdapter();
    final shared = Dio()..httpClientAdapter = adapter;
    AttachmentHttp.debugReplace(shared);
    addTearDown(() => AttachmentHttp.debugReplace(null));
    final uri = Uri.parse('https://example.com/preview');
    for (var i = 0; i < 2; i++) {
      // The loader zeroes its transfer buffer, so serve fresh bytes each time.
      adapter.data = Uint8List.fromList('<h1>Native page</h1>'.codeUnits);
      final loader = AttachmentHtmlLoader();
      expect(
        await loader.load(uri, cancel: CancelToken(), authorized: () => true),
        contains('Native page'),
      );
      expect(
        await loader.verify(uri, cancel: CancelToken(), authorized: () => true),
        isTrue,
      );
      loader.dispose(); // the dialog disposes its loader on close
    }
  });
  test('verify checks the pinned sandbox without reading a size', () async {
    final adapter = HtmlAdapter()
      ..data = Uint8List(AttachmentHtmlLoader.maxBytes * 2);
    final loader = AttachmentHtmlLoader(dio: Dio()..httpClientAdapter = adapter);
    addTearDown(loader.dispose);
    final uri = Uri.parse('https://example.com/preview');
    expect(
      await loader.verify(uri, cancel: CancelToken(), authorized: () => true),
      isTrue,
    );
    for (final bad in [
      "default-src 'none'",
      csp.replaceFirst('allow-scripts', 'allow-scripts allow-same-origin'),
      csp.replaceFirst('sandbox allow-scripts;', ''),
      csp.replaceFirst("worker-src 'none'", 'worker-src https:'),
    ]) {
      adapter.policy = bad;
      expect(
        await loader.verify(uri, cancel: CancelToken(), authorized: () => true),
        isFalse,
        reason: bad,
      );
    }
  });
  test('WebView navigation keeps the document inert but itself', () {
    final preview = Uri.parse(
      'https://api.raft.build/api/attachments/a/html-preview?previewToken=t&serverId=s',
    );
    ({AttachmentHtmlNavigationAction action, Uri? link}) nav(String url) =>
        attachmentHtmlNavigation(url, preview, 'https://api.raft.build');
    expect(nav(preview.toString()).action, AttachmentHtmlNavigationAction.allow);
    final external = nav('https://example.com/reference');
    expect(external.action, AttachmentHtmlNavigationAction.external);
    expect(external.link, Uri.parse('https://example.com/reference'));
    for (final url in [
      'https://api.raft.build/api/attachments/b/download',
      'https://api.raft.build/api/attachments/a/html-preview?previewToken=other',
      'https://app.raft.build/',
      'http://example.com',
      'file:///etc/passwd',
      'content://media/external/file/1',
      'intent://scan/#Intent;scheme=zxing;end',
      'javascript:alert(1)',
      'data:text/html,<script>1</script>',
      '/relative',
      'https://example.com/x?previewToken=leak',
      'https://user:pass@example.com/',
    ]) {
      expect(nav(url).action, AttachmentHtmlNavigationAction.block, reason: url);
    }
  });
  Future<(PendingHtmlLoader, List<AttachmentHtmlWebViewEvents>, List<Uri>)>
  pumpWebViewDialog(
    WidgetTester tester, {
    bool isolated = true,
    Future<bool> Function(Uri)? openExternal,
    bool useWebView = true,
  }) async {
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /attachments/a/html-preview-url'] = (_) => {
      'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
    };
    final loader = PendingHtmlLoader()..isolated = isolated;
    final events = <AttachmentHtmlWebViewEvents>[];
    final shown = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: HtmlAttachmentPreviewDialog(
            controller: w,
            metadata: const {'id': 'a', 'filename': 'npc.html'},
            authorized: () => true,
            onClose: () {},
            onDownload: () async {},
            loader: loader,
            useWebView: useWebView,
            openExternal: openExternal ?? (_) async => true,
            webViewBuilder: (context, uri, e) {
              shown.add(uri);
              events.add(e);
              return const SizedBox(key: ValueKey('fake-webview'));
            },
          ),
        ),
      ),
    );
    await waitForHtmlCompletion(
      tester,
      () => loader.verified > 0 || loader.loaded > 0,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    return (loader, events, shown);
  }

  testWidgets(
    'WebView preview shows the isolated URL after verification, no byte cap, no static parse',
    (tester) async {
      Uri? external;
      final (loader, events, shown) = await pumpWebViewDialog(
        tester,
        openExternal: (uri) async {
          external = uri;
          return true;
        },
      );
      expect(loader.verified, 1);
      expect(loader.loaded, 0, reason: 'the document is not downloaded into Dart');
      expect(shown.last.path, '/api/attachments/a/html-preview');
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
      // Transfer stage until the page finished.
      expect(find.byType(RaftPreviewTransferStage), findsOneWidget);
      events.last.onLoaded();
      await tester.pumpAndSettle();
      expect(find.byType(RaftPreviewTransferStage), findsNothing);
      expect(events.last.onNavigation(shown.last.toString()), isTrue);
      expect(events.last.onNavigation('file:///etc/passwd'), isFalse);
      await tester.pump();
      expect(find.text('This link is unavailable in the HTML preview.'), findsOneWidget);
      expect(
        events.last.onNavigation('https://example.com/ref'),
        isFalse,
        reason: 'approved links leave the preview through the system browser',
      );
      await waitForHtmlCompletion(tester, () => external != null);
      expect(external, Uri.parse('https://example.com/ref'));
    },
  );
  testWidgets(
    'a link failure ends with the next successful link open or allowed navigation',
    (tester) async {
      var accept = false;
      final (_, events, shown) = await pumpWebViewDialog(
        tester,
        openExternal: (uri) async => accept,
      );
      events.last.onLoaded();
      await tester.pumpAndSettle();
      const refused = 'The link could not be opened.';
      // The system refuses to open the link: the failure shows.
      expect(events.last.onNavigation('https://example.com/ref'), isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text(refused), findsOneWidget);
      // A later link that does open replaces it.
      accept = true;
      expect(events.last.onNavigation('https://example.com/ok'), isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.text(refused), findsNothing);
      // A blocked link shows its own failure, and navigating inside the
      // preview afterwards ends that one too.
      expect(events.last.onNavigation('file:///etc/passwd'), isFalse);
      await tester.pump();
      const blocked = 'This link is unavailable in the HTML preview.';
      expect(find.text(blocked), findsOneWidget);
      expect(events.last.onNavigation(shown.last.toString()), isTrue);
      await tester.pump();
      expect(find.text(blocked), findsNothing);
    },
  );
  testWidgets(
    'WebView preview shows the page-load percent in the transfer panel, then removes it',
    (tester) async {
      final (_, events, _) = await pumpWebViewDialog(tester);
      // Waiting for the first progress: the same "Connecting…" label.
      expect(find.byType(RaftFileTransferPanel), findsOneWidget);
      expect(find.byType(RaftTransferBar), findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('npc.html'), findsWidgets);
      final bar = find.byType(RaftTransferBar);
      double? value() => tester.widget<RaftTransferBar>(bar).value;
      expect(value(), isNull);
      events.last.onProgress!(0);
      await tester.pump();
      expect(find.text('Connecting…'), findsOneWidget);
      events.last.onProgress!(40);
      await tester.pump();
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Connecting…'), findsNothing);
      expect(value(), closeTo(.4, 1e-9));
      events.last.onProgress!(100);
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      expect(value(), 1);
      events.last.onLoaded();
      await tester.pumpAndSettle();
      expect(find.byType(RaftTransferBar), findsNothing);
      expect(find.byType(RaftFileTransferPanel), findsNothing);
      // A late progress event after load must not bring the panel back.
      events.last.onProgress!(60);
      await tester.pump();
      expect(find.byType(RaftTransferBar), findsNothing);
      expect(find.byKey(const ValueKey('fake-webview')), findsOneWidget);
    },
  );
  testWidgets(
    'static preview shows download progress (bytes and percent), then the document',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /attachments/a/html-preview-url'] = (_) => {
        'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
      };
      final loader = PendingHtmlLoader();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: HtmlAttachmentPreviewDialog(
              controller: w,
              metadata: const {'id': 'a', 'filename': 'document.html'},
              authorized: () => true,
              onClose: () {},
              onDownload: () async {},
              loader: loader,
              useWebView: false,
            ),
          ),
        ),
      );
      await waitForHtmlCompletion(tester, () => loader.loadStarted.isCompleted);
      await tester.pump();
      expect(find.text('Connecting…'), findsOneWidget);
      final bar = find.byType(RaftTransferBar);
      loader.reportProgress!(512 * 1024, 2 * 1024 * 1024);
      await tester.pump();
      expect(find.text('0.5 / 2.0 MB · 25%'), findsOneWidget);
      expect(tester.widget<RaftTransferBar>(bar).value, .25);
      // Unknown length: bytes only, indeterminate bar.
      loader.reportProgress!(900 * 1024, null);
      await tester.pump();
      expect(find.text('900 KB'), findsOneWidget);
      expect(tester.widget<RaftTransferBar>(bar).value, isNull);
      loader.pending.complete('<h1>Native document</h1>');
      await tester.pumpAndSettle();
      expect(find.byType(RaftTransferBar), findsNothing);
      expect(find.byType(RaftHtmlPreview), findsOneWidget);
    },
  );
  testWidgets(
    'WebView preview refuses a server response without the pinned sandbox and says why',
    (tester) async {
      final (loader, _, shown) = await pumpWebViewDialog(tester, isolated: false);
      expect(loader.verified, 1);
      expect(shown, isEmpty);
      expect(find.byKey(const ValueKey('fake-webview')), findsNothing);
      expect(
        find.textContaining('did not provide an isolated HTML preview'),
        findsOneWidget,
      );
      expect(find.text('Download File'), findsOneWidget);
      expect(find.text('Open Interactive Preview in Browser'), findsNothing);
      expect(find.text('Retry Preview'), findsNothing);
    },
  );
  testWidgets(
    'WebView failure replaces the page with a reason, Open in browser and Download',
    (tester) async {
      final (_, events, _) = await pumpWebViewDialog(tester);
      events.last.onFailed('net::ERR_FAILED');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('fake-webview')), findsNothing);
      expect(
        find.textContaining('could not display the HTML preview'),
        findsOneWidget,
      );
      expect(find.text('Open Interactive Preview in Browser'), findsOneWidget);
      expect(find.text('Download File'), findsOneWidget);
      expect(find.text('Retry Preview'), findsOneWidget);
    },
  );
  testWidgets(
    'static fallback names an oversize document and offers browser and download',
    (tester) async {
      final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /attachments/a/html-preview-url'] = (_) => {
        'url': 'https://example.invalid/api/attachments/a/html-preview?previewToken=opaque',
      };
      final loader = _TooLargeLoader();
      var downloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: HtmlAttachmentPreviewDialog(
              controller: w,
              metadata: const {'id': 'a', 'filename': 'npc.html'},
              authorized: () => true,
              onClose: () {},
              onDownload: () async => downloads++,
              loader: loader,
              useWebView: false,
            ),
          ),
        ),
      );
      await waitForHtmlCompletion(tester, () => loader.attempted);
      await tester.pumpAndSettle();
      expect(find.textContaining('too large for the in-app preview'), findsOneWidget);
      expect(find.text('Retry Preview'), findsNothing);
      expect(find.text('Open Interactive Preview in Browser'), findsOneWidget);
      await tester.tap(find.text('Download File'));
      expect(downloads, 1);
    },
  );
}

class _TooLargeLoader extends AttachmentHtmlLoader {
  bool attempted = false;
  @override
  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int? total)? onProgress,
  }) async {
    attempted = true;
    throw const AttachmentHtmlTooLarge(AttachmentHtmlLoader.maxBytes, 20000000);
  }
}
