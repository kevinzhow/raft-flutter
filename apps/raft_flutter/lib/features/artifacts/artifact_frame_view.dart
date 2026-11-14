// Raft Web v1.24's Artifact frame (Porthole: door first, then the content on
// `w-<uuid>.<content domain>`) in the platform WebView, with the host's
// capabilities answered in Dart.
//
// Source: packages/web/src/apps/artifacts/ArtifactFrame.tsx at
// v1.24.0-source.1 (locating, the one automatic reload of an expired view,
// the error codes and fallbacks); Porthole 0.16.0's `createHost` runs in the
// wrapper page (tool/artifact-porthole-host). WP-ART0 (draft #593) proved the
// approach on Android, iOS and macOS.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'artifact_frame_bridge.dart';

/// Asks the frame route (`POST /api/artifacts/:id/frame`) for a new location:
/// every later mount and every Porthole run, since both tickets open once.
typedef ArtifactFrameLocator = Future<Object?> Function();

/// What the host asks of the app: Raft's own dialogs and actions, never the page's.
class ArtifactFrameHost {
  const ArtifactFrameHost({
    required this.openLink,
    required this.copyText,
    required this.comments,
    required this.confirm,
  });

  /// Opens a checked http(s) link outside the app (Web: a new tab, noopener).
  final Future<bool> Function(Uri uri) openLink;

  /// Copies the page's text and says so (Web: a toast).
  final Future<bool> Function(String text) copyText;

  /// The page's Comment button (Porthole's runtime `comments.open`). ART2
  /// opens the composer; until then the request is declined.
  final Future<bool> Function(Map<String, Object?> request) comments;

  /// A gated call's yes (`openLink`): Raft's own dialog.
  final Future<bool> Function(String capability, Object? args, String title)
  confirm;
}

/// How the frame stands, for the surface around it (Web ArtifactFrame
/// `ViewState`).
enum ArtifactFrameStatus { locating, starting, loaded, fallback, error }

/// Porthole's fallback for an outcome (`frameFallback(...).kind`).
enum ArtifactFrameFallback { needsTab, denied, expired, failed }

/// One find answer (Porthole `FindResult`).
class ArtifactFindAnswer {
  const ArtifactFindAnswer({
    required this.active,
    required this.total,
    this.capped = false,
  });

  static ArtifactFindAnswer? parse(Object? value) {
    if (value is! Map) return null;
    final total = value['total'], active = value['active'];
    if (total is! num || active is! num) return null;
    return ArtifactFindAnswer(
      active: active.toInt(),
      total: total.toInt(),
      capped: value['capped'] == true,
    );
  }

  final int active, total;
  final bool capped;
}

/// Drives a mounted frame from outside: find, theme, reload; and tells the
/// surface how the frame stands.
class ArtifactFrameController extends ChangeNotifier {
  WebViewController? _web;
  ArtifactFrameStatus status = ArtifactFrameStatus.locating;
  ArtifactFrameFallback? fallback;

  /// The route's error code (Web `artifactErrorCode`), when [status] is
  /// [ArtifactFrameStatus.error].
  String? errorCode;

  ArtifactBridgeGate? _gate;

  /// Messages the bridge refused (no nonce, a wrong one, malformed).
  int get refused => _gate?.refused ?? 0;

  /// The last find answer (null: none yet, or the query was cleared).
  ArtifactFindAnswer? findAnswer;

  /// Bumped when the page asks for the find bar (Cmd/Ctrl+F in the frame).
  int findRequests = 0;

  bool get ready => status == ArtifactFrameStatus.loaded;

  Future<void> _run(String source) async {
    try {
      await _web?.runJavaScript(source);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('[artifact-frame] call failed: $error');
    }
  }

  Future<void> find(String query, {String? direction}) =>
      _run(ArtifactHostCalls.find(query, direction: direction));
  Future<void> clearFind() {
    findAnswer = null;
    notifyListeners();
    return _run(ArtifactHostCalls.clearFind);
  }

  Future<void> setScheme({required bool dark, Map<String, String>? theme}) =>
      _run(ArtifactHostCalls.setScheme(dark: dark, theme: theme));

  void _found(ArtifactFindAnswer? answer) {
    findAnswer = answer;
    notifyListeners();
  }

  void _findRequested() {
    findRequests++;
    notifyListeners();
  }

  void _set(
    ArtifactFrameStatus next, {
    ArtifactFrameFallback? fallback,
    String? code,
  }) {
    status = next;
    this.fallback = fallback;
    errorCode = code;
    notifyListeners();
  }
}

/// The platform WebView for [controller]. Tests replace it.
typedef ArtifactFrameWebViewBuilder = Widget Function(
  BuildContext context,
  WebViewController controller,
);

Widget _platformWebView(BuildContext context, WebViewController controller) =>
    WebViewWidget(controller: controller);

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
    this.firstLocation,
    this.dark = false,
    this.theme = const {},
    this.allowLoopback = kDebugMode,
    this.webViewBuilder,
  });

  final String artifactId;
  final int version;
  final String title;

  /// The wrapper page's origin: the Web app origin the content Worker lets
  /// frame pages (APP_ORIGIN). Loaded as the base URL, never fetched.
  final Uri appOrigin;

  /// The build's content domain (`host[:port]`), never learned from the route.
  final String contentDomain;
  final ArtifactFrameLocator locate;

  /// The viewer route's own `frame` for the first mount (Web
  /// `takeViewerFrame`): its tickets open once, so only this mount uses it.
  final Object? firstLocation;
  final ArtifactFrameHost host;
  final Future<String> Function() hostScript;
  final ArtifactFrameController controller;
  final bool dark;

  /// The page's Raft colours for [dark]: only a Markdown page gets them
  /// (Web `useArtifactPageTheme(kind === "markdown")`).
  final Map<String, String> theme;
  final bool allowLoopback;
  final ArtifactFrameWebViewBuilder? webViewBuilder;

  @override
  State<ArtifactFrameView> createState() => _ArtifactFrameViewState();
}

class _ArtifactFrameViewState extends State<ArtifactFrameView> {
  WebViewController? web;
  final gate = ArtifactBridgeGate();
  ArtifactFrameLocation? first;
  bool mounted_ = false, injected = false, initialDocumentAllowed = false;

  /// One automatic reload of an expired view per load (Web
  /// `reloadedSinceLoad`); a second expiry shows "This view has expired".
  bool reloadedSinceLoad = false;

  /// The last locate the route refused: its code is the state shown (Web
  /// `locatorFailed`), not Porthole's `blocked: locate`.
  bool locatorFailed = false;

  ArtifactFrameController get frame => widget.controller;

  @override
  void initState() {
    super.initState();
    frame._gate = gate;
    unawaited(_start());
  }

  @override
  void didUpdateWidget(ArtifactFrameView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._web = null;
      widget.controller
        .._gate = gate
        .._web = web;
    }
    if (old.dark != widget.dark || !mapEquals(old.theme, widget.theme)) {
      unawaited(frame.setScheme(dark: widget.dark, theme: widget.theme));
    }
  }

  @override
  void dispose() {
    final web = this.web;
    if (web != null) {
      unawaited(
        web.runJavaScript(ArtifactHostCalls.destroy).catchError((_) {}),
      );
    }
    if (frame._web == web) frame._web = null;
    super.dispose();
  }

  /// A located frame, checked as Web checks it (`frameContentSource`); null
  /// when it isn't this Artifact's own label on the build's content domain,
  /// or has no door.
  ArtifactFrameLocation? _checked(Object? answer) {
    final location = ArtifactFrameLocation.parse(answer);
    if (location == null) return null;
    final source = artifactFrameContentSource(
      artifactId: widget.artifactId,
      contentDomain: widget.contentDomain,
      location: location,
      allowLoopback: widget.allowLoopback,
    );
    return source == null ? null : location;
  }

  String? _codeOf(Object error) =>
      error is RaftApiException ? error.code : null;

  Future<void> _start() async {
    ArtifactFrameLocation? location;
    try {
      location = _checked(widget.firstLocation ?? await widget.locate());
    } catch (error) {
      if (!mounted) return;
      frame._set(ArtifactFrameStatus.error, code: _codeOf(error));
      return;
    }
    if (!mounted) return;
    if (location == null) {
      frame._set(ArtifactFrameStatus.error, code: 'CONTENT_UNAVAILABLE');
      return;
    }
    first = location;
    final source = artifactFrameContentSource(
      artifactId: widget.artifactId,
      contentDomain: widget.contentDomain,
      location: location,
      allowLoopback: widget.allowLoopback,
    )!;
    final String script;
    try {
      script = await widget.hostScript();
    } catch (_) {
      if (mounted) frame._set(ArtifactFrameStatus.error);
      return;
    }
    if (!mounted) return;
    final web = WebViewController();
    this.web = web;
    frame._web = web;
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
          // The content can't navigate the top (its sandbox has no
          // allow-top-navigation); the wrapper's own first document passes
          // (WebKit asks for loadHtmlString's base URL), anything after it
          // is dropped.
          if (!request.isMainFrame) return NavigationDecision.navigate;
          if (artifactInitialWrapperNavigation(
            request.url,
            appOrigin: widget.appOrigin,
            alreadyAllowed: initialDocumentAllowed,
            injected: injected,
          )) {
            initialDocumentAllowed = true;
            return NavigationDecision.navigate;
          }
          if (kDebugMode) debugPrint('[artifact-frame] navigation refused');
          return NavigationDecision.prevent;
        },
      ),
    );
    if (!mounted) return;
    frame._set(ArtifactFrameStatus.starting);
    setState(() {});
    await web.loadHtmlString(
      artifactWrapperHtml(contentSource: source, gate: gate, dark: widget.dark),
      baseUrl: widget.appOrigin.toString(),
    );
  }

  Future<void> _answer(int id, {required bool ok, Object? value}) async {
    await web?.runJavaScript(
      ArtifactHostCalls.answer(id, ok: ok, value: value),
    );
  }

  Future<void> _onMessage(String raw) async {
    final message = gate.accept(raw);
    if (message == null || !mounted) return;
    final detail = message.detail;
    final id = message.callId;
    switch (message.type) {
      case ArtifactBridgeMessageType.ready:
        final location = first;
        if (location == null || mounted_) return;
        mounted_ = true;
        await web?.runJavaScript(
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
      case ArtifactBridgeMessageType.fallback:
        _onFallback(detail['fallback']);
      case ArtifactBridgeMessageType.outcome:
        final state = detail['state'];
        if (state == 'loaded') {
          reloadedSinceLoad = false;
          frame._set(ArtifactFrameStatus.loaded);
        } else if (state == 'blocked' && detail['reason'] == 'locate') {
          // The locator's own refusal already set the state (its code).
          if (!locatorFailed) {
            frame._set(ArtifactFrameStatus.error, code: 'CONTENT_UNAVAILABLE');
          }
        } else if (state == 'blocked' && detail['reason'] == 'config') {
          frame._set(ArtifactFrameStatus.error);
        }
      case ArtifactBridgeMessageType.locate when id != null:
        try {
          final location = _checked(await widget.locate());
          locatorFailed = false;
          await _answer(
            id,
            ok: location != null,
            value: location?.toJson() ?? {'code': 'CONTENT_UNAVAILABLE'},
          );
        } catch (error) {
          locatorFailed = true;
          if (mounted) {
            frame._set(ArtifactFrameStatus.error, code: _codeOf(error));
          }
          await _answer(id, ok: false, value: {'code': _codeOf(error)});
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
            await widget.host.confirm(capability, detail['args'], widget.title);
        await _answer(id, ok: true, value: yes);
      case ArtifactBridgeMessageType.findResult:
        final result = detail['result'];
        frame._found(ArtifactFindAnswer.parse(result));
      case ArtifactBridgeMessageType.findUpdated:
        frame._found(ArtifactFindAnswer.parse(detail));
      case ArtifactBridgeMessageType.findRequested:
        frame._findRequested();
      default:
        break;
    }
  }

  /// Porthole's fallback for the outcome (Web `onOutcome`): an expired view
  /// is reloaded once with new tickets; a timeout reads as failed.
  void _onFallback(Object? fallback) {
    if (fallback is! Map) return;
    final kind = fallback['kind'];
    if (kind == 'expired' && !reloadedSinceLoad) {
      reloadedSinceLoad = true;
      locatorFailed = false;
      unawaited(web?.runJavaScript(ArtifactHostCalls.reload));
      return;
    }
    frame._set(
      ArtifactFrameStatus.fallback,
      fallback: switch (kind) {
        'needs-tab' => ArtifactFrameFallback.needsTab,
        'denied' => ArtifactFrameFallback.denied,
        'expired' => ArtifactFrameFallback.expired,
        _ => ArtifactFrameFallback.failed,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final web = this.web;
    if (web == null) return const SizedBox.expand();
    return (widget.webViewBuilder ?? _platformWebView)(context, web);
  }
}

/// Copies to the system clipboard (Web: copyTextToClipboard).
Future<bool> copyArtifactFrameText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}

/// The host script (tool/artifact-porthole-host's bundle), read once.
Future<String> artifactHostScript() =>
    _hostScript ??= rootBundle.loadString('assets/artifacts/porthole_host.js');
Future<String>? _hostScript;
