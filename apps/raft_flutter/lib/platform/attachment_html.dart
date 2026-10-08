import 'dart:convert';

import 'package:dio/dio.dart';

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

class AttachmentHtmlLoader {
  AttachmentHtmlLoader({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          );
  final Dio dio;
  static const maxBytes = 2 * 1024 * 1024;

  Future<String?> load(
    Uri uri, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    if (!authorized() || cancel.isCancelled) return null;
    final response = await dio.get<List<int>>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
      ),
      onReceiveProgress: (received, total) {
        if (!authorized() || received > maxBytes || total > maxBytes) {
          cancel.cancel();
        }
      },
    );
    final bytes = response.data;
    if (bytes == null) {
      throw const FormatException('The HTML preview could not be loaded.');
    }
    try {
      if (!authorized() || cancel.isCancelled) return null;
      if (bytes.length > maxBytes) {
        throw const FormatException(
          'The HTML is too large for a native preview.',
        );
      }
      if (!attachmentHtmlSandboxed(
        response.headers.value('content-security-policy'),
      )) {
        throw const FormatException(
          'The server did not provide an isolated HTML preview.',
        );
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

  void dispose() => dio.close(force: true);
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
