import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_files.dart';
import 'native_sharing.dart';

/// Private local inputs prevent native decoders retaining signed URL handles.
class AttachmentPreviewFiles {
  AttachmentPreviewFiles({
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 45),
             ),
           ),
       temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final Dio dio;
  final Future<Directory> Function() temporaryDirectory;
  static const maxBytes = 50 * 1024 * 1024;
  Future<SharedFileLease?> load(
    String url,
    String filename, {
    required CancelToken cancel,
    required bool Function() authorized,
  }) async {
    if (!authorized() || cancel.isCancelled) return null;
    final root = await temporaryDirectory();
    if (!authorized() || cancel.isCancelled) return null;
    final previews = await Directory(p.join(root.path, 'raft-previews'))
        .create(recursive: true);
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
      await dio.download(
        AttachmentFiles.attachmentUri(url).toString(),
        file.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (!authorized() || received > maxBytes || total > maxBytes) {
            cancel.cancel();
          }
        },
      );
      if (!authorized() || cancel.isCancelled || await file.length() > maxBytes) {
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
