import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:raft_ui/raft_ui.dart' show raftStaticHtmlMaxChars;

import 'attachment_http.dart';

/// Preview capabilities belong to one attachment and one server. Normal
/// presigned download URLs never authorize execution of HTML in a browser.
Uri attachmentHtmlPreviewUri(String value, String origin, String id) {
  final uri = Uri.tryParse(value), base = Uri.tryParse(origin);
  if (uri == null ||
      base == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !['https', 'http'].contains(base.scheme) ||
      uri.origin != base.origin ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.path != '/api/attachments/$id/html-preview' ||
      uri.queryParameters['previewToken']?.isNotEmpty != true ||
      uri.queryParameters.keys.any(
        (key) => !{'previewToken', 'serverId'}.contains(key),
      )) {
    throw const FormatException('The HTML preview URL is unavailable.');
  }
  return uri;
}

bool attachmentHtmlSandboxed(String? value) {
  if (value == null) return false;
  final directives = <String, List<String>>{};
  for (final part in value.toLowerCase().split(';')) {
    final words = part.trim().split(RegExp(r'\s+'));
    if (words.first.isEmpty) continue;
    // Duplicate directives are browser-policy dependent; accept only the
    // pinned, unambiguous server contract before external execution.
    if (directives.containsKey(words.first)) return false;
    directives[words.first] = words.skip(1).toList();
  }
  final sandbox = directives['sandbox'];
  if (sandbox == null ||
      sandbox.length != 1 ||
      sandbox.single != 'allow-scripts') {
    return false;
  }
  return [
    'default-src',
    'connect-src',
    'object-src',
    'base-uri',
    'form-action',
    'worker-src',
  ].every((key) => directives[key]?.join(' ') == "'none'");
}

/// The static (no WebView) preview refused a document for its size. Carries
/// the real size so the message can say why instead of "could not be loaded".
class AttachmentHtmlTooLarge extends FormatException {
  const AttachmentHtmlTooLarge(this.limit, [this.size])
    : super('The HTML is too large for a native preview.');
  final int limit;
  final int? size;
}

/// The server's response did not carry the pinned sandbox policy, so the
/// document must not execute in any browser surface.
class AttachmentHtmlNotIsolated extends FormatException {
  const AttachmentHtmlNotIsolated()
    : super('The server did not provide an isolated HTML preview.');
}

/// What the preview WebView does with a main-frame navigation request. The
/// uploaded document is hostile input: it may only ever show itself.
enum AttachmentHtmlNavigationAction { allow, external, block }

/// Parent-owned navigation policy for the WebView preview (web equivalent:
/// the sandboxed iframe lacks allow-top-navigation/allow-popups, and links are
/// opened by the parent through the same external-link policy). The preview
/// URL itself (and in-page `#fragment` jumps) stays; a policy-approved https
/// link opens in the system browser; everything else (relative links, other
/// Raft paths, file:/data:/javascript:/intent: schemes) is inert.
({AttachmentHtmlNavigationAction action, Uri? link}) attachmentHtmlNavigation(
  String url,
  Uri preview,
  String origin,
) {
  final target = Uri.tryParse(url);
  if (target != null &&
      target.scheme == preview.scheme &&
      target.host == preview.host &&
      target.port == preview.port &&
      target.path == preview.path &&
      target.query == preview.query &&
      target.userInfo.isEmpty) {
    return (action: AttachmentHtmlNavigationAction.allow, link: null);
  }
  final link = attachmentHtmlExternalLink(url, origin);
  return link == null
      ? (action: AttachmentHtmlNavigationAction.block, link: null)
      : (action: AttachmentHtmlNavigationAction.external, link: link);
}

class AttachmentHtmlLoader {
  AttachmentHtmlLoader({Dio? dio})
    : dio = dio ?? AttachmentHttp.shared,
      _shared = dio == null;
  final Dio dio;
  // The default client is the app-wide attachment pool: closing it with the
  // preview broke every later HTML preview (and other attachment fetches).
  final bool _shared;

  /// Static-preview (desktop without a WebView) download cap. The sanitizer
  /// parses the whole document; see [raftStaticHtmlMaxChars].
  static const maxBytes = raftStaticHtmlMaxChars;

  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int? total)? onProgress,
  }) async {
    if (!authorized() || cancel.isCancelled) return null;
    int? oversize;
    final Response<List<int>> response;
    try {
      response = await dio.get<List<int>>(
        uri.toString(),
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
        onReceiveProgress: (received, total) {
          if (received > maxBytes || total > maxBytes) {
            oversize = total > maxBytes ? total : received;
            cancel.cancel();
          } else if (!authorized()) {
            cancel.cancel();
          } else {
            onProgress?.call(received, total > 0 ? total : null);
          }
        },
      );
    } on DioException {
      if (oversize != null) throw AttachmentHtmlTooLarge(maxBytes, oversize);
      rethrow;
    }
    final bytes = response.data;
    if (bytes == null) {
      throw const FormatException('The HTML preview could not be loaded.');
    }
    try {
      if (!authorized() || cancel.isCancelled) return null;
      if (bytes.length > maxBytes) {
        throw AttachmentHtmlTooLarge(maxBytes, bytes.length);
      }
      if (!attachmentHtmlSandboxed(
        response.headers.value('content-security-policy'),
      )) {
        throw const AttachmentHtmlNotIsolated();
      }
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// Revalidates a freshly issued capability and the actual response policy
  /// immediately before the user's explicit external-browser action.
  Future<bool> verify(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    if (!authorized() || cancel.isCancelled) return false;
    final response = await dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
      ),
    );
    await response.data?.stream.listen((_) {}).cancel();
    return authorized() &&
        !cancel.isCancelled &&
        attachmentHtmlSandboxed(
          response.headers.value('content-security-policy'),
        );
  }

  void dispose() {
    if (!_shared) dio.close(force: true);
  }
}

/// Source-equivalent parent-owned link policy. Uploaded relative links,
/// application links, private-network targets and credential URLs stay inert.
Uri? attachmentHtmlExternalLink(String raw, String origin) {
  if (raw.length > 4096) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.host.isEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (!host.contains('.') ||
      host == 'localhost' ||
      host.contains(':') ||
      RegExp(r'^\d+(\.\d+){3}$').hasMatch(host) ||
      [
        '.home',
        '.internal',
        '.invalid',
        '.lan',
        '.local',
        '.localhost',
        '.test',
      ].any(host.endsWith) ||
      host == Uri.tryParse(origin)?.host.toLowerCase() ||
      {
        'api.raft.build',
        'api.slock.ai',
        'app.raft.build',
        'app.slock.ai',
        'staging.slock.ai',
        'botiverse.dev',
      }.contains(host) ||
      host.endsWith('.botiverse.dev')) {
    return null;
  }
  const sensitive = {
    'access_token',
    'accesstoken',
    'auth_token',
    'preview_token',
    'previewtoken',
    'refresh_token',
    'refreshtoken',
    'token',
  };
  if (uri.queryParameters.keys.any(
    (k) => sensitive.contains(k.toLowerCase()),
  )) {
    return null;
  }
  final fragment = Uri(query: uri.fragment);
  if (fragment.queryParameters.keys.any(
    (k) => sensitive.contains(k.toLowerCase()),
  )) {
    return null;
  }
  return uri;
}
