import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'attachment_http.dart';
import 'cache_staging.dart';

/// Attachment URLs are capabilities. They live only in an active transfer,
/// never in preferences, logs, or the workspace database.
class AttachmentFiles {
  AttachmentFiles({
    Dio? dio,
    this.pickDestination,
    Future<Directory> Function()? stagingDirectory,
    bool? gallerySupported,
    this.writeToGallery,
    this.discardIncompleteDestination = false,
    this.discardDestination,
    bool? androidSave,
  }) : gallerySupported =
           gallerySupported ?? (Platform.isAndroid || Platform.isIOS),
       _androidSave = androidSave ?? Platform.isAndroid,
       _dio = dio ?? AttachmentHttp.shared,
       _stagingDirectory = stagingDirectory ?? cacheStagingDirectory;
  final Dio _dio;
  // Test hosts can exercise the Android MethodChannel save protocol.
  final bool _androidSave;
  final Future<String?> Function(String, String)? pickDestination;

  /// Artifact downloads create a new Android document before transferring.
  /// Remove that empty/partial document when the transfer does not complete.
  /// Ordinary attachment destinations retain their existing default behavior.
  final bool discardIncompleteDestination;
  final Future<void> Function(String destination)? discardDestination;

  /// Whether this device has a photo library to save an image into (the
  /// Android gallery through MediaStore, iOS Photos). Phone layouts offer it
  /// from the image viewer's long-press menu.
  final bool gallerySupported;

  /// Test hook: receives `(path, filename, mimeType)` instead of the host.
  final Future<String?> Function(String, String, String)? writeToGallery;

  /// Label of the long-press item that saves into [gallerySupported]'s library.
  static String get galleryLabel =>
      Platform.isIOS ? 'Save to Photos' : 'Save to Gallery';
  final Future<Directory> Function() _stagingDirectory;
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

  /// [onProgress] receives dio's `(received, total)`; `total` is -1 when the
  /// server sends no length. The caller throttles; this is called per chunk.
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    final result = await _dio.get<List<int>>(
      attachmentUri(url).toString(),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancel,
      onReceiveProgress: onProgress,
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
    String? saveToken;
    if (pickDestination != null) {
      destination = await pickDestination!(name, mimeType);
    } else if (_androidSave) {
      final selected = await channel.invokeMethod<Object?>('chooseSave', {
        'filename': name,
        'mimeType': mimeType,
        'trackIncomplete': discardIncompleteDestination,
      });
      if (selected == null) {
        destination = null;
      } else if (discardIncompleteDestination) {
        if (selected is! Map ||
            selected['uri'] is! String ||
            selected['saveToken'] is! String) {
          throw const FileSystemException(
            'A secure save destination is unavailable.',
          );
        }
        destination = selected['uri'] as String;
        saveToken = selected['saveToken'] as String;
      } else {
        destination = selected as String;
      }
    } else {
      destination = (await getSaveLocation(suggestedName: name))?.path;
    }
    if (destination == null) return null;
    final trackedToken = saveToken;
    if (trackedToken != null) {
      unawaited(
        cancel.whenCancel.then((_) async {
          try {
            await channel.invokeMethod<String>('cancelSave', {
              'uri': destination,
              'saveToken': trackedToken,
            });
          } on PlatformException {
            // A committed/acknowledged operation no longer admits cancellation.
          } on MissingPluginException {
            // Engine teardown cancels the viewer too.
          }
        }),
      );
    }
    Directory? folder;
    var completed = false;
    var discarded = false;
    try {
      if (cancel.isCancelled || !authorized()) return null;
      folder = await Directory(
        p.join(
          (await _stagingDirectory()).path,
          'raft-attachment-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final temporary = File(p.join(folder.path, name));
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
      final result = await _writeSaved(
        temporary,
        destination,
        saveToken: saveToken,
      );
      discarded = result.discarded;
      if (!result.committed) return null;
      // A native commit won the cancellation race: preserve the complete file
      // and return success even if Cancel arrived while its reply was in flight.
      completed = true;
      return destination;
    } finally {
      if (folder != null && await folder.exists()) {
        await folder.delete(recursive: true);
      }
      if (!completed && !discarded && discardIncompleteDestination) {
        if (discardDestination != null) {
          await discardDestination!(destination);
        } else if (_androidSave) {
          await channel.invokeMethod<void>('discardSave', {
            'uri': destination,
            'saveToken': saveToken,
          });
        }
      }
    }
  }

  /// Saves a local file (a copy the attachment cache holds) through the same
  /// picker as [save], without any download. The source is only read.
  Future<String?> saveFile({
    required File source,
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
    await _writeSaved(source, destination);
    return destination;
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
        (await _stagingDirectory()).path,
        'raft-export-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
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
      await _writeSaved(temporary, destination);
      return destination;
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }

  /// Saves an image into the device photo library (Android: MediaStore
  /// `Pictures/Raft`, no picker; iOS: Photos, add-only). The file keeps its
  /// name and type. Returns the library location, or null when the user
  /// declined (iOS permission) or the scope ended. The bytes are staged in
  /// private temporary storage first.
  Future<String?> saveToGallery({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required bool Function() authorized,
  }) async {
    if (!authorized()) return null;
    final name = safeFilename(filename);
    final folder = await Directory(
      p.join(
        (await _stagingDirectory()).path,
        'raft-gallery-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    try {
      if (Platform.isLinux) {
        if ((await Process.run('chmod', ['700', folder.path])).exitCode != 0) {
          throw const FileSystemException(
            'Private image storage is unavailable.',
          );
        }
      }
      final temporary = File(p.join(folder.path, name));
      await temporary.writeAsBytes(bytes, flush: true);
      if (!authorized()) return null;
      if (writeToGallery != null) {
        return await writeToGallery!(temporary.path, name, mimeType);
      }
      return await channel.invokeMethod<String>('saveToGallery', {
        'path': temporary.path,
        'filename': name,
        'mimeType': mimeType,
      });
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }

  Future<({bool committed, bool discarded})> _writeSaved(
    File source,
    String destination, {
    String? saveToken,
  }) async {
    if (_androidSave || Platform.isMacOS) {
      // macOS publishes bytes atomically into the user-selected destination.
      // File.copy would carry private cache quarantine metadata into it.
      final result = await channel.invokeMethod<Object?>('writeSaved', {
        'uri': destination,
        'path': source.path,
        'saveToken': ?saveToken,
      });
      if (saveToken != null) {
        if (result is! Map ||
            result['committed'] is! bool ||
            result['discarded'] is! bool ||
            (result['committed'] == true && result['discarded'] == true)) {
          throw const FileSystemException(
            'The save result could not be verified.',
          );
        }
        if (result['committed'] == true) {
          try {
            await channel.invokeMethod<void>('acknowledgeSave', {
              'uri': destination,
              'saveToken': saveToken,
            });
          } on PlatformException {
            // Commit is authoritative; acknowledgement only releases its receipt.
          }
        }
        return (
          committed: result['committed'] as bool,
          discarded: result['discarded'] as bool,
        );
      }
    } else {
      await XFile(source.path).saveTo(destination);
    }
    return (committed: true, discarded: false);
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
