// WP-ART0 spike: Raft Web v1.24's Artifact frame (Porthole, door first, then the content on
// `w-<uuid>.<content domain>`) in the platform WebView, with the host's capabilities in Dart.
//
// Source: packages/web/src/apps/artifacts/ArtifactFrame.tsx (v1.24.0).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'artifact_frame_bridge.dart';

/// Asks the frame route (`POST /api/artifacts/:id/frame`) for a new location: every mount and
/// every Porthole run, since both tickets open once.
typedef ArtifactFrameLocator = Future<Object?> Function();

/// What the host asks of the app: Raft's own dialogs and actions, never the page's.
class ArtifactFrameHost {
  const ArtifactFrameHost({
    required this.openLink,
    required this.copyText,
    required this.comments,
    required this.confirm,
  });

  /// Opens a checked http(s) link outside the app (Web: a new tab, noopener, noreferrer).
  final Future<bool> Function(Uri uri) openLink;

  /// Copies the page's text and says so (Web: a toast).
  final Future<bool> Function(String text) copyText;

  /// The page's Comment button (Porthole's runtime `comments.open`): its anchor and draft.
  final Future<bool> Function(Map<String, Object?> request) comments;

  /// A gated call's yes (`openLink`): Raft's own dialog.
  final Future<bool> Function(String capability, Object? args) confirm;
}

/// How the frame stands, for the surface around it.
enum ArtifactFrameStatus { locating, starting, loaded, blocked, failed }

/// Drives a mounted frame from outside: find, theme, annotations, reload.
class ArtifactFrameController extends ChangeNotifier {
  WebViewController? _web;
  ArtifactFrameStatus status = ArtifactFrameStatus.locating;
  String? blockedReason;

  /// Every message the page sent, by type (the spike's evidence).
  final received = <String, int>{};
  final log = <String>[];
  ArtifactBridgeGate? _gate;
  int get refused => _gate?.refused ?? 0;
  List<String> get refusedSamples => _gate?.refusedSamples ?? const [];
  Object? lastFind;
  Map<String, Object?>? compiled;

  Future<void> _run(String source) async => _web?.runJavaScript(source);

  Future<void> find(String query, {String? direction}) =>
      _run(ArtifactHostCalls.find(query, direction: direction));
  Future<void> clearFind() => _run(ArtifactHostCalls.clearFind);
  Future<void> reload() => _run(ArtifactHostCalls.reload);
  Future<void> setScheme({required bool dark, Map<String, String>? theme}) =>
      _run(ArtifactHostCalls.setScheme(dark: dark, theme: theme));
  Future<void> annotations(String action, [Object? arg]) =>
      _run(ArtifactHostCalls.annotations(action, arg));

  /// For the spike's own probes (a forged channel message from the content frame).
  Future<Object> evaluate(String source) async =>
      await _web?.runJavaScriptReturningResult(source) ?? '';

  void _changed() => notifyListeners();

  void _note(String entry) {
    if (kDebugMode) debugPrint('[artifact-frame] $entry');
    log.add(entry);
    if (log.length > 200) log.removeAt(0);
    notifyListeners();
  }
}

class ArtifactFrameView extends StatefulWidget {
  const ArtifactFrameView({
    super.key,
    required this.artifactId,
    required this.version,
    required this.title,
    required this.appOrigin,
    required this.contentDomain,
    required this.locate,
    required this.host,
    required this.hostScript,
    required this.controller,
    this.dark = false,
    this.theme = const {},
    this.allowLoopback = kDebugMode,
  });

  final String artifactId;
  final int version;
  final String title;

  /// The wrapper page's origin: one the content Worker lets frame pages and takes messages from
  /// (its APP_ORIGIN or an EXTRA_APP_ORIGINS entry).
  final Uri appOrigin;

  /// The build's content domain (`host[:port]`), never learned from the route's answer.
  final String contentDomain;
  final ArtifactFrameLocator locate;
  final ArtifactFrameHost host;
  final Future<String> Function() hostScript;
  final ArtifactFrameController controller;
  final bool dark;

  /// The page's Raft colours for [dark] (artifactPageTheme): only a Markdown page uses them.
  final Map<String, String> theme;
  final bool allowLoopback;

  @override
  State<ArtifactFrameView> createState() => _ArtifactFrameViewState();
}

class _ArtifactFrameViewState extends State<ArtifactFrameView> {
  late final WebViewController web;
  final gate = ArtifactBridgeGate();
  ArtifactFrameLocation? first;
  bool mounted_ = false, injected = false;

  ArtifactFrameController get frame => widget.controller;

  @override
  void initState() {
    super.initState();
    frame._gate = gate;
    web = WebViewController();
    frame._web = web;
    unawaited(_start());
  }

  @override
  void didUpdateWidget(ArtifactFrameView old) {
    super.didUpdateWidget(old);
    if (old.dark != widget.dark || !mapEquals(old.theme, widget.theme)) {
      unawaited(frame.setScheme(dark: widget.dark, theme: widget.theme));
    }
  }

  @override
  void dispose() {
    unawaited(web.runJavaScript(ArtifactHostCalls.destroy).catchError((_) {}));
    frame._web = null;
    super.dispose();
  }

  void _status(ArtifactFrameStatus status, [String? reason]) {
    if (!mounted) return;
    frame
      ..status = status
      ..blockedReason = reason;
    frame._note('status ${status.name}${reason == null ? '' : ' ($reason)'}');
  }

  /// A located frame, checked as Web checks it; null when it isn't this Artifact's.
  Future<ArtifactFrameLocation?> _located() async {
    final location = ArtifactFrameLocation.parse(await widget.locate());
    if (location == null) return null;
    final source = artifactFrameContentSource(
      artifactId: widget.artifactId,
      contentDomain: widget.contentDomain,
      location: location,
      allowLoopback: widget.allowLoopback,
    );
    return source == null ? null : location;
  }

  Future<void> _start() async {
    final ArtifactFrameLocation? location;
    try {
      location = await _located();
    } catch (_) {
      // ART1: the route's code (artifactErrorCode), as Web shows it.
      _status(ArtifactFrameStatus.failed, 'locate failed');
      return;
    }
    if (location == null) {
      _status(ArtifactFrameStatus.failed, 'CONTENT_UNAVAILABLE');
      return;
    }
    first = location;
    final source = artifactFrameContentSource(
      artifactId: widget.artifactId,
      contentDomain: widget.contentDomain,
      location: location,
      allowLoopback: widget.allowLoopback,
    )!;
    final script = await widget.hostScript();
    await web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await web.addJavaScriptChannel(
      'RaftArtifactBridge',
      onMessageReceived: (message) => unawaited(_onMessage(message.message)),
    );
    await web.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) {
          // The wrapper page loaded: run the host script in it, once.
          if (injected) return;
          injected = true;
          unawaited(web.runJavaScript(script));
        },
        onNavigationRequest: (request) {
          // The wrapper page never leaves: the content can't navigate the top (its sandbox has no
          // allow-top-navigation), and anything else that tries is dropped.
          if (!request.isMainFrame) return NavigationDecision.navigate;
          frame._note('main-frame navigation refused: ${request.url}');
          return NavigationDecision.prevent;
        },
      ),
    );
    _status(ArtifactFrameStatus.starting);
    await web.loadHtmlString(
      artifactWrapperHtml(contentSource: source, gate: gate, dark: widget.dark),
      baseUrl: widget.appOrigin.toString(),
    );
  }

  Future<void> _answer(int id, {required bool ok, Object? value}) =>
      web.runJavaScript(ArtifactHostCalls.answer(id, ok: ok, value: value));

  Future<void> _onMessage(String raw) async {
    final message = gate.accept(raw);
    if (message == null) {
      frame._note('refused a channel message (${gate.refusedSamples.last})');
      return;
    }
    final type = message.type;
    frame.received.update(type.name, (n) => n + 1, ifAbsent: () => 1);
    final detail = message.detail;
    final id = message.callId;
    frame._note('<- ${type.name} ${_brief(detail)}');
    switch (type) {
      case ArtifactBridgeMessageType.ready:
        final location = first;
        if (location == null || mounted_) return;
        mounted_ = true;
        await web.runJavaScript(
          ArtifactHostCalls.mount(
            location: location,
            artifactId: widget.artifactId,
            version: widget.version,
            title: widget.title,
            contentDomain: widget.contentDomain,
            dark: widget.dark,
            theme: widget.theme,
          ),
        );
      case ArtifactBridgeMessageType.compiled:
        frame.compiled = detail;
      case ArtifactBridgeMessageType.outcome:
        final state = detail['state'];
        if (state == 'loaded') {
          _status(ArtifactFrameStatus.loaded);
        } else if (state == 'blocked') {
          _status(ArtifactFrameStatus.blocked, '${detail['reason']}');
        } else {
          _status(ArtifactFrameStatus.failed, '$state');
        }
      case ArtifactBridgeMessageType.locate when id != null:
        try {
          final location = await _located();
          await _answer(
            id,
            ok: location != null,
            value: location?.toJson() ?? {'code': 'CONTENT_UNAVAILABLE'},
          );
        } catch (_) {
          await _answer(id, ok: false, value: {'code': 'CONTENT_UNAVAILABLE'});
        }
      case ArtifactBridgeMessageType.openLink when id != null:
        final uri = artifactFrameLink(detail['url']);
        await _answer(
          id,
          ok: true,
          value: uri != null && await widget.host.openLink(uri),
        );
      case ArtifactBridgeMessageType.copyText when id != null:
        final text = detail['text'];
        await _answer(
          id,
          ok: true,
          value: text is String && await widget.host.copyText(text),
        );
      case ArtifactBridgeMessageType.comments when id != null:
        final request = detail['request'];
        await _answer(
          id,
          ok: true,
          value:
              request is Map &&
              await widget.host.comments(request.cast<String, Object?>()),
        );
      case ArtifactBridgeMessageType.confirm when id != null:
        final capability = detail['capability'];
        final yes =
            capability is String &&
            await widget.host.confirm(capability, detail['args']);
        await _answer(id, ok: true, value: yes);
      case ArtifactBridgeMessageType.findResult:
        frame.lastFind = detail['result'];
      default:
        break;
    }
    if (mounted) frame._changed();
  }

  static String _brief(Map<String, Object?> detail) {
    final text = jsonEncode(detail);
    // Never log a ticket.
    final clean = text.replaceAll(RegExp(r'ticket=[^"&]+'), 'ticket=…');
    return clean.length > 160 ? '${clean.substring(0, 160)}…' : clean;
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: web);
}

/// Copies to the system clipboard (Web: copyTextToClipboard).
Future<bool> copyArtifactFrameText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}
