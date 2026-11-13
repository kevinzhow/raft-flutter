// WP-ART0 spike: the Dart side of Raft Web v1.24's Artifact frame (Porthole) in an app WebView.
//
// Source: packages/web/src/apps/artifacts/ArtifactFrame.tsx (v1.24.0) for the frame location
// check, `openLink` and the sandbox; Porthole 0.16.0's `createHost` for the host. The host script
// (tool/artifact-porthole-host) runs in a wrapper page whose origin the content Worker lets frame
// pages; this file builds that page and checks every message the page sends.
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Color;

/// The content frame's sandbox tokens (shared `ARTIFACT_FRAME_SANDBOX`, v1.24.0). The host script
/// frames nothing when Porthole's compiled sandbox differs.
const artifactFrameSandbox = 'allow-scripts allow-same-origin';

/// Where a framed version loads: the frame route's answer (`ArtifactWebFrame`).
class ArtifactFrameLocation {
  const ArtifactFrameLocation({
    required this.url,
    required this.origin,
    this.reports = false,
    this.door,
    this.instanceVersion,
  });

  /// Null for anything that isn't an `ArtifactWebFrame` with a door: Porthole 0.14.10+ frames
  /// nothing without one, so the content isn't available (Web: CONTENT_UNAVAILABLE).
  static ArtifactFrameLocation? parse(Object? json) {
    if (json is! Map) return null;
    final url = json['url'], origin = json['origin'], door = json['door'];
    if (url is! String || origin is! String) return null;
    final doorUrl = door is Map ? door['url'] : null;
    if (doorUrl is! String) return null;
    final version = json['instanceVersion'];
    return ArtifactFrameLocation(
      url: url,
      origin: origin,
      reports: json['reports'] == true,
      door: doorUrl,
      instanceVersion: version is String && _instanceVersion.hasMatch(version)
          ? version
          : null,
    );
  }

  final String url, origin;
  final bool reports;
  final String? door;
  final String? instanceVersion;

  static final _instanceVersion = RegExp(
    r'^v_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Porthole's `FrameLocation`, for the host script. Load it once: both tickets open once.
  Map<String, Object?> toJson() => {
    'url': url,
    'origin': origin,
    'reports': reports,
    'door': {'url': door},
    'instanceVersion': ?instanceVersion,
  };
}

/// The content source (`<scheme>://*.<content domain>`) a located frame is on, or null when it
/// isn't exactly this Artifact's own label (`w-<uuid>.<domain>`) on the build's content domain
/// (Web `frameContentSource`). Plain http only on a `*.localhost` domain in a debug build.
String? artifactFrameContentSource({
  required String artifactId,
  required String? contentDomain,
  required ArtifactFrameLocation location,
  required bool allowLoopback,
}) {
  final domain = contentDomain?.trim().toLowerCase() ?? '';
  if (domain.isEmpty) return null;
  final uuid = RegExp(
    r'^pt_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$',
  ).firstMatch(artifactId)?.group(1);
  if (uuid == null) return null;
  final origin = Uri.tryParse(location.origin);
  final url = Uri.tryParse(location.url);
  final door = Uri.tryParse(location.door ?? '');
  if (origin == null || url == null || door == null) return null;
  String originOf(Uri uri) => uri.hasAuthority ? uri.origin : '';
  if (origin.path.isNotEmpty && origin.path != '/') return null;
  if (originOf(origin) != location.origin) return null;
  if (originOf(url) != location.origin || originOf(door) != location.origin) {
    return null;
  }
  final domainHost = domain.replaceFirst(RegExp(r':\d+$'), '');
  final loopback =
      allowLoopback &&
      origin.scheme == 'http' &&
      domainHost.endsWith('.localhost');
  if (origin.scheme != 'https' && !loopback) return null;
  final host = origin.hasPort ? '${origin.host}:${origin.port}' : origin.host;
  if (host != 'w-$uuid.$domain') return null;
  return '${origin.scheme}://*.$domain';
}

/// A link the page asked to open (`openLink`): the content's word. Only an absolute http or
/// https address opens (Web `openFrameLink`); anything else is dropped.
Uri? artifactFrameLink(Object? raw) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  return uri;
}

/// The messages the host script sends. Anything else is dropped.
enum ArtifactBridgeMessageType {
  ready,
  compiled,
  initialized,
  outcome,
  fallback,
  resize,
  contentError,
  hostError,
  navigated,
  navigationBlocked,
  refused,
  muted,
  storage,
  annotation,
  annotationsAck,
  findRequested,
  findUpdated,
  findResult,
  locate,
  openLink,
  copyText,
  comments,
  confirm,
}

/// One message from the wrapper page, checked.
class ArtifactBridgeMessage {
  const ArtifactBridgeMessage(this.type, this.detail);
  final ArtifactBridgeMessageType type;
  final Map<String, Object?> detail;

  /// The id of a call the page awaits (`locate`, `openLink`, `copyText`, `comments`, `confirm`).
  int? get callId => switch (detail['id']) {
    final int id when id > 0 => id,
    _ => null,
  };
}

/// The bridge's wall: a WebView's JavaScript channel is visible in every frame of the page, the
/// content's too (Android `addJavascriptInterface`, WebKit script message handlers), and neither
/// platform tells Dart which frame sent a message. So the wrapper page carries a nonce only Dart
/// and that page know; a message without it is the content's, and is dropped.
class ArtifactBridgeGate {
  ArtifactBridgeGate({String? nonce, this.maxMessageBytes = 256 * 1024})
    : nonce = nonce ?? _randomToken();

  final String nonce;
  final int maxMessageBytes;

  /// Messages refused (no nonce, a wrong one, malformed): what the spike reports.
  int refused = 0;
  final refusedSamples = <String>[];

  ArtifactBridgeMessage? accept(String raw) {
    ArtifactBridgeMessage? refuse(String why) {
      refused++;
      if (refusedSamples.length < 5) refusedSamples.add(why);
      return null;
    }

    if (raw.length > maxMessageBytes) return refuse('too long');
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return refuse('not json');
    }
    if (json is! Map) return refuse('not an object');
    final map = json;
    final given = map['nonce'];
    if (given is! String || !_constantTimeEquals(given, nonce)) {
      return refuse('bad nonce');
    }
    final type = ArtifactBridgeMessageType.values
        .where((each) => each.name == map['type'])
        .firstOrNull;
    if (type == null) return refuse('unknown type');
    final detail = map['detail'];
    return ArtifactBridgeMessage(
      type,
      detail is Map ? detail.cast<String, Object?>() : const {},
    );
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

String _randomToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// The wrapper page: a box for the frame and a policy that lets the page frame only the content
/// source and run no script of its own. Loaded with the app origin as its base URL, so the content
/// Worker's `frame-ancestors` and the shell's message origin accept it. The host script is run in
/// it by the app (`runJavaScript`), not inlined: the bundle holds `<!--` and `<script`, which
/// would break an inline script element.
String artifactWrapperHtml({
  required String contentSource,
  required ArtifactBridgeGate gate,
  required bool dark,
}) {
  final background = dark ? '#121212' : '#ffffff';
  final csp = [
    "default-src 'none'",
    "script-src 'none'",
    "style-src 'unsafe-inline'",
    'frame-src $contentSource',
    "base-uri 'none'",
    "form-action 'none'",
  ].join('; ');
  return '<!doctype html><html data-bridge-nonce="${gate.nonce}"><head>'
      '<meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<meta http-equiv="Content-Security-Policy" content="$csp">'
      '<meta name="referrer" content="no-referrer">'
      '<style>html,body{margin:0;height:100%;background:$background}'
      '#frame{position:fixed;inset:0}#frame iframe{border:0}</style>'
      '</head><body><div id="frame"></div></body></html>';
}

/// Calls into the wrapper page (`window.RaftArtifactHost`), as JavaScript source for
/// `runJavaScript`. Every value is JSON, never pasted text.
abstract final class ArtifactHostCalls {
  static String mount({
    required ArtifactFrameLocation location,
    required String artifactId,
    required int version,
    required String title,
    required String contentDomain,
    required bool dark,
    Map<String, String> theme = const {},
  }) =>
      'RaftArtifactHost.mount(${jsonEncode({'location': location.toJson(), 'id': artifactId, 'version': version, 'title': title, 'contentDomain': contentDomain, 'scheme': dark ? 'dark' : 'light', 'theme': theme})})';

  static String answer(int id, {required bool ok, Object? value}) =>
      'RaftArtifactHost.answer($id, $ok, ${jsonEncode(value)})';

  static String setScheme({required bool dark, Map<String, String>? theme}) =>
      'RaftArtifactHost.setScheme(${jsonEncode(dark ? 'dark' : 'light')}, '
      '${jsonEncode(theme)})';

  static String find(String query, {String? direction}) =>
      'RaftArtifactHost.find(${jsonEncode(query)}, ${jsonEncode(direction)})';

  static const clearFind = 'RaftArtifactHost.clearFind()';
  static const reload = 'RaftArtifactHost.reload()';
  static const destroy = 'RaftArtifactHost.destroy()';

  static String annotations(String action, [Object? arg]) =>
      'RaftArtifactHost.annotations(${jsonEncode(action)}, ${jsonEncode(arg)})';
}

/// Where an Artifact can be framed in the app: Android, iOS and macOS have a platform WebView;
/// Linux and Windows don't (this app ships none there), so they open it in the browser.
enum ArtifactFrameSupport { webView, browser }

ArtifactFrameSupport artifactFrameSupportFor(String operatingSystem) =>
    switch (operatingSystem) {
      'android' || 'ios' || 'macos' => ArtifactFrameSupport.webView,
      _ => ArtifactFrameSupport.browser,
    };

/// The Raft tokens a Markdown Artifact's page draws with (shared `ARTIFACT_PAGE_COLORS`, v1.24.0),
/// each sent as `--raft-<token>`. Web reads them from its own CSS (useArtifactPageTheme); the app
/// reads them from its theme.
const artifactPageTokens = [
  'layer-canvas',
  'layer-sidebar',
  'layer-card',
  'layer-code',
  'layer-backdrop',
  'foreground',
  'foreground-muted',
  'foreground-hint',
  'foreground-link',
  'line-hairline',
  'line-seam',
  'fill-muted',
  'fill-medium',
  'brand-400',
  'sticker-ink',
  'warning-soft',
];

/// Porthole theme values for the page: the tokens the app's theme has, as CSS colours. A token
/// it lacks is left out, so the page keeps its own light default for it.
Map<String, String> artifactPageTheme(Map<String, Color> colors) => {
  for (final token in artifactPageTokens)
    if (colors[token] case final Color color) '--raft-$token': cssColor(color),
};

String cssColor(Color color) {
  int channel(double value) => (value * 255).round().clamp(0, 255);
  final alpha = color.a;
  final rgb = '${channel(color.r)}, ${channel(color.g)}, ${channel(color.b)}';
  return alpha >= 1 ? 'rgb($rgb)' : 'rgba($rgb, ${alpha.toStringAsFixed(3)})';
}
