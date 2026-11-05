// Actual product preview + comments + system renderer, with a fresh loopback
// service and memory-only synthetic identity. No AppRoot or real account store.
// Use real pointer/keyboard input. The HTTP QA endpoints never drive the UI.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html.dart';
import 'package:raft_flutter/platform/attachment_html_desktop.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'html_region_system_qa_fixture.dart';
import 'html_region_system_qa_observer.dart';
import 'html_region_system_qa_readback.dart';

Dio _transport(String origin) {
  final allowed = Uri.parse(origin);
  if (allowed.scheme != 'http' ||
      allowed.host != '127.0.0.1' ||
      allowed.userInfo.isNotEmpty ||
      allowed.port <= 0) {
    throw ArgumentError('The region QA fixture must have a loopback origin');
  }
  // ignore: raft_lints/avoid_unproxied_network_client -- QA-only transport: interceptor restricts every request to the fresh exact loopback origin, redirects are disabled, and no account/proxy store is read.
  final dio = Dio(BaseOptions(followRedirects: false));
  // ignore: raft_lints/avoid_unproxied_network_client -- This isolated local fixture must not send its synthetic requests through a user/system proxy; the exact-origin guard below remains mandatory.
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      // ignore: raft_lints/avoid_unproxied_network_client -- Private QA client only; no global HttpOverrides, account or production request can use it.
      return HttpClient()..findProxy = (_) => 'DIRECT';
    },
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.uri.origin != origin) {
          handler.reject(
            DioException(
              requestOptions: options,
              error:
                  'The isolated QA transport only accepts its loopback fixture',
            ),
          );
        } else {
          handler.next(options);
        }
      },
    ),
  );
  return dio;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isLinux || !attachmentHtmlDesktopSupported) {
    throw StateError(
      'This entry requires the registered Linux system renderer',
    );
  }
  final fixture = HtmlRegionSystemQaFixture();
  await fixture.start();
  final client = RaftClient(
    origin: fixture.origin,
    sessionStore: MemorySessionStore(),
    transport: _transport(fixture.origin),
  )..user = RaftRecord({'id': 'qa-human', 'name': '区域验收员'});
  client.selectServer('region-qa');
  final workspace = WorkspaceController(client)
    ..server = RaftRecord({
      'id': 'region-qa',
      'name': 'Local QA',
      'role': 'owner',
    })
    ..channel = RaftChannel({
      'id': 'region-channel',
      'name': 'QA',
      'joined': true,
    });
  workspace.channels = [workspace.channel!];
  debugPrint('[raft-region-qa] status=${fixture.origin}/qa/status');
  debugPrint('[raft-region-qa] saved=${fixture.origin}/qa/comments');
  runApp(
    MaterialApp(
      theme: raftTheme(),
      home: _RegionQaPage(fixture: fixture, workspace: workspace),
    ),
  );
}

class _RegionQaPage extends StatefulWidget {
  const _RegionQaPage({required this.fixture, required this.workspace});
  final HtmlRegionSystemQaFixture fixture;
  final WorkspaceController workspace;
  @override
  State<_RegionQaPage> createState() => _RegionQaPageState();
}

class _RegionQaPageState extends State<_RegionQaPage> {
  final previewKey = GlobalKey();
  SystemWebViewController? system;
  HtmlRegionSystemQaObserver? observer;
  bool open = true, loaded = false, disposed = false;
  int opens = 1;
  final rendererFailures = <String>[];

  @override
  void initState() {
    super.initState();
    widget.fixture.readUi = snapshot;
  }

  Future<Map<String, Object?>> snapshot() async {
    final current = system;
    final opening = opens, wasOpen = open;
    Object? document, native;
    if (current != null) {
      try {
        native = await current.inspect().timeout(const Duration(seconds: 2));
        if (loaded && !current.closed) {
          final result = await current
              .evaluate(htmlRegionSystemQaDocumentReadback)
              .timeout(const Duration(seconds: 2));
          document = result is String ? jsonDecode(result) : result;
        }
      } catch (error) {
        document = {'readbackError': error.runtimeType.toString()};
      }
    }
    if (current != system || opening != opens || wasOpen != open || !mounted) {
      return {'stale': true, 'reason': 'The preview changed during readback'};
    }
    return {
      'stale': false,
      'open': open,
      'opens': opens,
      'loaded': loaded,
      'disposed': disposed,
      'failure': rendererFailures.lastOrNull,
      'tree': htmlRegionSystemQaTree(previewKey),
      'document': document,
      'native': native,
      'region': observer?.snapshot(),
      'inputContract':
          'Actual GTK drag and Flutter composer input only; '
          'observer delegates unchanged SDK calls and never synthesizes input',
    };
  }

  void closePreview() => setState(() {
    loaded = false;
    open = false;
  });

  Widget renderer(
    BuildContext context,
    Uri uri,
    AttachmentHtmlWebViewEvents events,
  ) {
    final opening = opens;
    return DesktopAttachmentHtmlWebView(
      uri: uri,
      onSystemControllerCreated: (value) {
        if (mounted && opening == opens) {
          system = value;
          disposed = false;
        }
      },
      onSystemDisposed: () {
        if (mounted && opening == opens) disposed = true;
      },
      events: AttachmentHtmlWebViewEvents(
        onNavigation: events.onNavigation,
        onProgress: events.onProgress,
        onGeometryReady: (value) {
          if (!mounted || !open || opening != opens) return;
          if (value is! RaftHtmlNativeRegionController) {
            rendererFailures.add(
              'The Linux region input/paint capability is missing',
            );
            return;
          }
          final observed = observer?.delegate == value
              ? observer!
              : HtmlRegionSystemQaObserver(value);
          observer = observed;
          events.onGeometryReady?.call(observed);
        },
        onLoaded: () {
          if (mounted && open && opening == opens) {
            loaded = true;
            events.onLoaded();
            debugPrint('[raft-region-qa] loaded');
          }
        },
        onFailed: (reason) {
          if (mounted && open && opening == opens) {
            loaded = false;
            rendererFailures.add(reason);
            events.onFailed(reason);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.fixture.readUi = null;
    widget.workspace.dispose();
    unawaited(widget.fixture.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: open
        ? HtmlAttachmentPreviewDialog(
            key: previewKey,
            controller: widget.workspace,
            metadata: const {
              'id': 'region-qa',
              'filename': 'system-region-report.html',
            },
            authorized: () => open,
            onClose: closePreview,
            onDownload: () async {},
            openExternal: (_) async => false,
            loader: AttachmentHtmlLoader(
              dio: _transport(widget.fixture.origin),
            ),
            page: true,
            webViewBuilder: renderer,
          )
        : Center(
            child: RaftButton(
              label: 'Reopen preview',
              onPressed: () => setState(() {
                opens++;
                system = null;
                observer = null;
                rendererFailures.clear();
                loaded = false;
                disposed = false;
                open = true;
              }),
            ),
          ),
  );
}
