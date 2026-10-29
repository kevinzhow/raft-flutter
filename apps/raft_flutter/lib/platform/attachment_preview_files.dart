import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/attachment_disk_cache.dart';
import '../data/attachment_image_store.dart';
import 'attachment_files.dart';
import 'attachment_http.dart';
import 'cache_staging.dart';
import 'native_sharing.dart';

/// Private local inputs prevent native decoders retaining signed URL handles.
class AttachmentPreviewFiles {
  AttachmentPreviewFiles({
    Dio? dio,
    Future<Directory> Function()? stagingDirectory,
  }) : dio = dio ?? AttachmentHttp.shared,
       stagingDirectory = stagingDirectory ?? cacheStagingDirectory;
  final Dio dio;
  final Future<Directory> Function() stagingDirectory;
  static const maxBytes = 50 * 1024 * 1024;
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!authorized() || cancel.isCancelled) return null;
    final root = await stagingDirectory();
    if (!authorized() || cancel.isCancelled) return null;
    final previews = await Directory(
      p.join(root.path, 'raft-previews'),
    ).create(recursive: true);
    final folder = await previews.createTemp('preview-');
    final file = File(
      p.join(folder.path, AttachmentFiles.safeFilename(filename)),
    );
    var leased = false;
    try {
      if (Platform.isLinux) {
        final mode = await Process.run('chmod', ['700', folder.path]);
        if (mode.exitCode != 0) {
          throw const FileSystemException(
            'Private preview storage is unavailable.',
          );
        }
      }
      if (!authorized() || cancel.isCancelled) return null;
      await _download(url, file, cancel, authorized, onProgress);
      if (!authorized() ||
          cancel.isCancelled ||
          await file.length() > maxBytes) {
        return null;
      }
      leased = true;
      return SharedFileLease(file, lifetime: const Duration(hours: 1));
    } finally {
      // A successful lease owns cleanup; rejected or interrupted input does not.
      if (!leased) {
        if (await folder.exists()) await folder.delete(recursive: true);
      }
    }
  }

  Future<void> _download(
    String url,
    File file,
    CancelToken cancel,
    bool Function() authorized,
    void Function(int received, int total)? onProgress,
  ) => dio.download(
    AttachmentFiles.attachmentUri(url).toString(),
    file.path,
    cancelToken: cancel,
    options: Options(receiveTimeout: const Duration(seconds: 45)),
    onReceiveProgress: (received, total) {
      if (!authorized() || received > maxBytes || total > maxBytes) {
        cancel.cancel();
        return;
      }
      onProgress?.call(received, total);
    },
  );

  /// The preview input of one attachment, from the persistent cache when it
  /// holds the file (no request at all: [resolveUrl] is not even called),
  /// otherwise downloaded once into the cache (concurrent callers for the
  /// same entry share that download) and kept for the next open. Without a
  /// cache this is [load]. The lease never deletes a cached file; disposing
  /// it only releases the cache's hold.
  Future<SharedFileLease?> loadCached({
    required AttachmentDiskCache? cache,
    required AttachmentImageStoreKey key,
    required Future<String> Function() resolveUrl,
    Future<String> Function()? refreshUrl,
    required String filename,
    int? expectedBytes,
    required CancelToken cancel,
    required bool Function() authorized,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!authorized() || cancel.isCancelled) return null;
    // The storage host refused the signature (it lapsed early, clock skew):
    // [refreshUrl] signs once more and the transfer is tried once again.
    Future<void> download(
      String url,
      File destination,
      CancelToken token,
      bool Function() allowed,
      void Function(int, int)? progress,
    ) async {
      try {
        await _download(url, destination, token, allowed, progress);
      } on DioException catch (error) {
        final status = _httpStatus(error);
        if (refreshUrl == null ||
            token.isCancelled ||
            (status != 401 && status != 403)) {
          rethrow;
        }
        await _download(
          await refreshUrl(),
          destination,
          token,
          allowed,
          progress,
        );
      }
    }

    // Without a usable cache this is [load], signed again once on a refusal.
    Future<SharedFileLease?> uncached() async {
      Future<SharedFileLease?> attempt(String url) => load(
        url,
        filename,
        cancel: cancel,
        authorized: authorized,
        onProgress: onProgress,
      );
      try {
        return await attempt(await resolveUrl());
      } on DioException catch (error) {
        final status = _httpStatus(error);
        if (refreshUrl == null ||
            cancel.isCancelled ||
            (status != 401 && status != 403)) {
          rethrow;
        }
        return attempt(await refreshUrl());
      }
    }

    if (cache == null) return uncached();
    final AttachmentCachedFile? cached;
    try {
      cached = await cache.fetchFile(
        key,
        filename: filename,
        expectedBytes: expectedBytes,
        cancel: cancel,
        onProgress: onProgress,
        download: (destination, shared, progress) async {
          final url = await resolveUrl();
          if (shared.isCancelled) throw const FileSystemException('cancelled');
          // The download is shared: each caller's own cancel token detaches it,
          // so one caller's authority must not abort the others'.
          await download(
            url,
            destination,
            shared,
            () => !shared.isCancelled,
            progress,
          );
          if (await destination.length() > maxBytes) {
            throw const FileSystemException('The preview input is too large.');
          }
        },
      );
    } on AttachmentCacheUnavailable {
      return uncached();
    }
    if (cached == null) return null;
    if (!authorized() || cancel.isCancelled) {
      cached.release();
      return null;
    }
    return CachedFileLease(cached);
  }
}

/// A [SharedFileLease] on a file the attachment cache owns: disposing it ends
/// the hold (the cache may evict the file again), it never deletes anything.
class CachedFileLease extends SharedFileLease {
  CachedFileLease(this._cached) : super(_cached.file, staged: false) {
    cancelExpiry();
  }
  final AttachmentCachedFile _cached;
  @override
  Future<void> dispose() async => _cached.release();
}

class NativePdfPage {
  const NativePdfPage(this.bytes, this.pageCount);
  final Uint8List bytes;
  final int pageCount;
}

/// PdfRenderer on Android; distro Poppler utilities on Linux. No document JS.
class NativePdfRenderer {
  static const channel = MethodChannel('app.raft/pdf-preview');
  Future<NativePdfPage> render(
    File file,
    int page, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    if (!authorized() || cancel.isCancelled) {
      throw StateError('The preview closed.');
    }
    if (Platform.isAndroid) {
      final value = await channel.invokeMapMethod<String, dynamic>('page', {
        'path': file.path,
        'page': page,
        'maxDimension': 1600,
      });
      if (!authorized() ||
          cancel.isCancelled ||
          value?['bytes'] is! Uint8List ||
          value?['pageCount'] is! int) {
        throw StateError('The preview closed.');
      }
      return NativePdfPage(
        value!['bytes'] as Uint8List,
        value['pageCount'] as int,
      );
    }
    if (!Platform.isLinux) {
      throw UnsupportedError('PDF preview is unavailable.');
    }
    final info = await _run('pdfinfo', [file.path], cancel);
    final count = int.tryParse(
      RegExp(r'^Pages:\s+(\d+)', multiLine: true).firstMatch(info)?.group(1) ??
          '',
    );
    if (count == null ||
        page < 0 ||
        page >= count ||
        !authorized() ||
        cancel.isCancelled) {
      throw const FormatException('The PDF could not be opened.');
    }
    final prefix = p.join(
      file.parent.path,
      'page-${DateTime.now().microsecondsSinceEpoch}',
    );
    final output = File('$prefix.png');
    try {
      await _run('pdftoppm', [
        '-f',
        '${page + 1}',
        '-l',
        '${page + 1}',
        '-singlefile',
        '-scale-to',
        '1600',
        '-png',
        file.path,
        prefix,
      ], cancel);
      if (!authorized() ||
          cancel.isCancelled ||
          await output.length() > 16 * 1024 * 1024) {
        throw StateError('The preview closed.');
      }
      return NativePdfPage(await output.readAsBytes(), count);
    } finally {
      if (await output.exists()) await output.delete();
    }
  }

  Future<String> _run(
    String executable,
    List<String> arguments,
    CancelToken cancel,
  ) async {
    if (cancel.isCancelled) throw StateError('The preview closed.');
    final process = await Process.start(
      executable,
      arguments,
      includeParentEnvironment: false,
      environment: const {'PATH': '/usr/bin:/bin'},
    );
    var running = true;
    unawaited(
      cancel.whenCancel.then((_) {
        if (running) process.kill(ProcessSignal.sigkill);
      }),
    );
    final out = process.stdout.transform(utf8.decoder).join();
    final err = process.stderr.drain<void>();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 20));
      await err;
      final text = await out;
      if (code != 0 || cancel.isCancelled) {
        throw const FormatException('The PDF could not be opened.');
      }
      return text;
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw const FormatException('The PDF preview timed out.');
    } finally {
      running = false;
    }
  }
}

int? _httpStatus(DioException failure) => failure.response?.statusCode;
