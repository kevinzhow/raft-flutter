import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attachment URLs are capabilities. They live only in an active transfer,
/// never in preferences, logs, or the workspace database.
class AttachmentFiles {
  AttachmentFiles({
    Dio? dio,
    this.pickDestination,
    Future<Directory> Function()? temporaryDirectory,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Dio _dio;
  final Future<String?> Function(String, String)? pickDestination;
  final Future<Directory> Function() _temporaryDirectory;
  static const channel = MethodChannel('app.raft/attachment-files');

  static String safeFilename(String name) {
    final cleaned = p.posix
        .basename(p.windows.basename(name))
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '_');
    return cleaned.isEmpty || cleaned == '.' || cleaned == '..'
        ? 'attachment'
        : cleaned;
  }

  static Uri attachmentUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('The attachment address is invalid.');
    }
    return uri;
  }

  Future<Uint8List> image(String url, {required CancelToken cancel}) async {
    final result = await _dio.get<List<int>>(
      attachmentUri(url).toString(),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancel,
    );
    return Uint8List.fromList(result.data!);
  }

  /// Prompts before transferring. A cancelled picker makes no network request.
  /// Files remain private and temporary until the complete download succeeds.
  Future<String?> save({
    required String url,
    required String filename,
    required String mimeType,
    required CancelToken cancel,
    required bool Function() authorized,
    required void Function(int, int) onProgress,
  }) async {
    final name = safeFilename(filename);
    final String? destination;
    if (pickDestination != null) {
      destination = await pickDestination!(name, mimeType);
    } else if (Platform.isAndroid) {
      destination = await channel.invokeMethod<String>('chooseSave', {
        'filename': name,
        'mimeType': mimeType,
      });
    } else {
      destination = (await getSaveLocation(suggestedName: name))?.path;
    }
    if (destination == null || cancel.isCancelled || !authorized()) return null;
    final folder = await Directory(
      p.join(
        (await _temporaryDirectory()).path,
        'raft-attachment-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    final temporary = File(p.join(folder.path, name));
    try {
      if (Platform.isLinux) {
        final result = await Process.run('chmod', ['700', folder.path]);
        if (result.exitCode != 0) {
          throw const FileSystemException(
            'Private attachment storage is unavailable.',
          );
        }
      }
      await _dio.download(
        attachmentUri(url).toString(),
        temporary.path,
        cancelToken: cancel,
        onReceiveProgress: onProgress,
      );
      if (cancel.isCancelled || !authorized()) return null;
      if (Platform.isAndroid) {
        await channel.invokeMethod<void>('writeSaved', {
          'uri': destination,
          'path': temporary.path,
        });
      } else {
        await XFile(temporary.path).saveTo(destination);
      }
      return destination;
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }

  /// Saves a reviewed rendered export through the actual platform picker.
  Future<String?> saveBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required bool Function() authorized,
  }) async {
    if (!authorized()) return null;
    final name = safeFilename(filename);
    final String? destination;
    if (pickDestination != null) {
      destination = await pickDestination!(name, mimeType);
    } else if (Platform.isAndroid) {
      destination = await channel.invokeMethod<String>('chooseSave', {
        'filename': name,
        'mimeType': mimeType,
      });
    } else {
      destination = (await getSaveLocation(suggestedName: name))?.path;
    }
    if (destination == null || !authorized()) return null;
    final folder = await Directory(
      p.join(
        (await _temporaryDirectory()).path,
        'raft-export-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create();
    try {
      if (Platform.isLinux) {
        if ((await Process.run('chmod', ['700', folder.path])).exitCode != 0) {
          throw const FileSystemException(
            'Private export storage is unavailable.',
          );
        }
      }
      final temporary = File(p.join(folder.path, name));
      await temporary.writeAsBytes(bytes, flush: true);
      if (!authorized()) return null;
      if (Platform.isAndroid) {
        await channel.invokeMethod<void>('writeSaved', {
          'uri': destination,
          'path': temporary.path,
        });
      } else {
        await XFile(temporary.path).saveTo(destination);
      }
      return destination;
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }

  Future<void> open(String location, String mimeType) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('openSaved', {
        'uri': location,
        'mimeType': mimeType,
      });
    } else if (!await launchUrl(p.toUri(location))) {
      throw const FileSystemException('No application can open this file.');
    }
  }
}
