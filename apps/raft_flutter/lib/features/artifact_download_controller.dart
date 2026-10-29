import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/artifact_download_bridge.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_http.dart';

enum ArtifactDownloadStatus {
  idle,
  saving,
  cancelling,
  saved,
  cancelled,
  failed,
}

/// One viewer owns one transfer and picker. HTTP clients are private to a
/// transfer: no Raft API headers, cookie jar, or credential persistence.
class ArtifactDownloadController extends ChangeNotifier {
  ArtifactDownloadController({required this.origin, this.files});
  final Uri origin;
  final AttachmentFiles Function(Dio)? files;
  bool _alive = true;
  CancelToken? _cancel;
  ArtifactDownloadRequest? _request;
  ArtifactDownloadStatus status = ArtifactDownloadStatus.idle;
  RaftTransferProgress progress = RaftTransferProgress.connecting;
  String filename = '';
  bool unsupportedOrigin = false;
  bool get busy => _cancel != null;
  bool get retryable => !busy && _request != null;

  bool sameOrigin(Uri uri) =>
      const {'http', 'https'}.contains(uri.scheme) &&
      uri.userInfo.isEmpty &&
      uri.scheme == origin.scheme &&
      uri.host.toLowerCase() == origin.host.toLowerCase() &&
      uri.port == origin.port;

  void receive(ArtifactDownloadRequest request) {
    if (!_alive || busy) return;
    final uri = Uri.tryParse(request.url);
    if (request.rejected || uri == null || !sameOrigin(uri)) {
      _request = null;
      filename = '';
      unsupportedOrigin = true;
      status = ArtifactDownloadStatus.failed;
      notifyListeners();
      return;
    }
    _request = request;
    unawaited(_save(request));
  }

  Future<void> retry() async {
    final request = _request;
    if (_alive && !busy && request != null) await _save(request);
  }

  void cancel() {
    if (!_alive) return;
    _cancel?.cancel();
    status = busy
        ? ArtifactDownloadStatus.cancelling
        : ArtifactDownloadStatus.cancelled;
    notifyListeners();
  }

  void dismiss() {
    if (!_alive || busy) return;
    _request = null;
    status = ArtifactDownloadStatus.idle;
    notifyListeners();
  }

  Future<void> _save(ArtifactDownloadRequest request) async {
    final cancel = CancelToken();
    _cancel = cancel;
    bool current() => _alive && !cancel.isCancelled;
    filename = AttachmentFiles.safeFilename(request.filename);
    status = ArtifactDownloadStatus.saving;
    unsupportedOrigin = false;
    progress = RaftTransferProgress.connecting;
    notifyListeners();
    final dio = AttachmentHttp.create();
    // Follow redirects ourselves: the platform HTTP adapter must never take a
    // cookie to a Location on another origin (including another port).
    dio.options.followRedirects = false;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!current() || !sameOrigin(options.uri)) {
            handler.reject(DioException(requestOptions: options));
            return;
          }
          if (request.cookie.isNotEmpty) {
            options.headers['Cookie'] = request.cookie;
          }
          if (request.userAgent.isNotEmpty) {
            options.headers['User-Agent'] = request.userAgent;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // ignore: raft_lints/avoid_caught_exception_text -- Only typed response status and Location control same-origin redirects; no exception text is shown or logged.
          final response = error.response;
          final location = response?.headers.value('location');
          final hops =
              error.requestOptions.extra['artifactRedirects'] as int? ?? 0;
          if (current() &&
              const {301, 302, 303, 307, 308}.contains(response?.statusCode) &&
              location != null &&
              hops < 4) {
            final relative = Uri.tryParse(location);
            final target = relative == null
                ? null
                : error.requestOptions.uri.resolveUri(relative);
            if (target != null && sameOrigin(target)) {
              final next = error.requestOptions.copyWith(
                path: target.toString(),
                extra: {
                  ...error.requestOptions.extra,
                  'artifactRedirects': hops + 1,
                },
              );
              try {
                handler.resolve(await dio.fetch<dynamic>(next));
                return;
              } on DioException catch (failure) {
                handler.next(failure);
                return;
              }
            }
            unsupportedOrigin = true;
          }
          handler.next(error);
        },
      ),
    );
    try {
      final saver =
          files?.call(dio) ??
          AttachmentFiles(dio: dio, discardIncompleteDestination: true);
      final saved = await saver.save(
        url: request.url,
        filename: filename,
        mimeType: request.mimeType,
        cancel: cancel,
        authorized: current,
        onProgress: (received, total) {
          if (!current()) return;
          progress = RaftTransferProgress(received: received, total: total);
          notifyListeners();
        },
      );
      if (!_alive) return;
      status = saved == null
          ? ArtifactDownloadStatus.cancelled
          : ArtifactDownloadStatus.saved;
      if (saved != null) _request = null;
    } catch (error) {
      if (_alive) {
        status = error is DioException && CancelToken.isCancel(error)
            ? ArtifactDownloadStatus.cancelled
            : ArtifactDownloadStatus.failed;
      }
    } finally {
      dio.close(force: true);
      _cancel = null;
      if (_alive) notifyListeners();
    }
  }

  @override
  void dispose() {
    retire();
    super.dispose();
  }

  void retire() {
    _alive = false;
    _request = null;
    _cancel?.cancel();
  }
}
