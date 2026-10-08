import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_files.dart';

class IncomingSharedFile {
  const IncomingSharedFile(
    this.uri,
    this.filename,
    this.mimeType,
    this.sizeBytes,
  );
  final String uri, filename, mimeType;
  final int? sizeBytes;
}

class IncomingShare {
  const IncomingShare({this.text, this.files = const []});
  final String? text;
  final List<IncomingSharedFile> files;
  static IncomingShare? parse(dynamic value) {
    if (value is! Map) return null;
    final files = <IncomingSharedFile>[];
    for (final entry
        in (value['files'] is List ? value['files'] as List : const [])) {
      if (entry is! Map ||
          entry['uri'] is! String ||
          entry['filename'] is! String) {
        return null;
      }
      final uri = Uri.tryParse(entry['uri']);
      if (uri == null || uri.scheme != 'content' || uri.host.isEmpty) {
        return null;
      }
      files.add(
        IncomingSharedFile(
          entry['uri'],
          AttachmentFiles.safeFilename(entry['filename']),
          entry['mimeType'] is String
              ? entry['mimeType']
              : 'application/octet-stream',
          entry['sizeBytes'] is num
              ? (entry['sizeBytes'] as num).toInt()
              : null,
        ),
      );
    }
    if (files.length > 10) return null;
    final text = value['text'] is String ? value['text'] as String : null;
    if (text != null && text.length > 65536 ||
        files.isEmpty && (text == null || text.isEmpty)) {
      return null;
    }
    return IncomingShare(text: text, files: files);
  }
}

/// A user-authorized export lives only in private temporary storage. It never
/// contains a signed URL. Recipients get a read grant to this one file.
class SharedFileLease {
  SharedFileLease(
    this.file, {
    Duration lifetime = const Duration(minutes: 15),
  }) {
    _timer = Timer(lifetime, () => unawaited(dispose()));
  }
  final File file;
  Timer? _timer;
  Future<void>? _disposal;
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _timer?.cancel();
    _timer = null;
    if (await file.parent.exists()) await file.parent.delete(recursive: true);
  }
}

class NativeSharing {
  NativeSharing({
    MethodChannel? channel,
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
    bool? supported,
  }) : channel = channel ?? const MethodChannel('app.raft/sharing'),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       supported = supported ?? Platform.isAndroid;
  final MethodChannel channel;
  final Dio _dio;
  final Future<Directory> Function() _temporaryDirectory;
  final bool supported;
  void Function(IncomingShare)? _receiver;
  IncomingShare? _pending;
  set onIncoming(void Function(IncomingShare)? receiver) {
    _receiver = receiver;
    final pending = _pending;
    if (receiver != null && pending != null && !_closed) {
      _pending = null;
      receiver(pending);
    }
  }

  void receive(IncomingShare incoming) {
    if (_closed) return;
    if (_receiver == null) {
      _pending = incoming;
    } else {
      _receiver!(incoming);
    }
  }

  void Function() registerReceiver(void Function(IncomingShare) receiver) {
    onIncoming = receiver;
    return () {
      if (identical(_receiver, receiver)) _receiver = null;
    };
  }

  bool _closed = false;

  Future<void> init() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingShare' && !_closed) {
        final share = IncomingShare.parse(call.arguments);
        if (share != null) receive(share);
      }
    });
    try {
      final incoming = IncomingShare.parse(
        await channel.invokeMethod<dynamic>('takeIncoming'),
      );
      if (incoming != null && !_closed) receive(incoming);
    } catch (_) {
      /* A platform without a receiver can still copy content links. */
    }
  }

  Future<void> shareText(String text, {String? title}) async {
    if (!supported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'System sharing is unavailable on this platform.',
      );
    }
    await channel.invokeMethod<void>('share', {
      'text': text,
      'title': title,
      'mimeType': 'text/plain',
    });
  }

  Future<void> shareFile(SharedFileLease lease, String mimeType) async {
    if (!supported) {
      throw PlatformException(
        code: 'unsupported',
        message: 'System sharing is unavailable on this platform.',
      );
    }
    await channel.invokeMethod<void>('share', {
      'path': lease.file.path,
      'mimeType': mimeType,
    });
  }

  Future<Uint8List> readIncoming(
    IncomingSharedFile file, {
    required bool Function() authorized,
  }) async {
    if (!supported || !authorized()) {
      throw PlatformException(
        code: 'stale',
        message: 'The conversation changed.',
      );
    }
    final bytes = await channel.invokeMethod<Uint8List>('readIncoming', {
      'uri': file.uri,
    });
    if (!authorized() || bytes == null) {
      throw PlatformException(
        code: 'stale',
        message: 'The conversation changed.',
      );
    }
    return bytes;
  }

  Future<SharedFileLease?> prepareBytes(
    Uint8List bytes, {
    required String filename,
    required bool Function() authorized,
  }) async {
    if (!supported || !authorized()) return null;
    final root = await _temporaryDirectory();
    final folder = await Directory(
      p.join(
        root.path,
        'raft-share',
        'share-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final file = File(
      p.join(folder.path, AttachmentFiles.safeFilename(filename)),
    );
    try {
      await file.writeAsBytes(bytes, flush: true);
      if (!authorized()) {
        await folder.delete(recursive: true);
        return null;
      }
      return SharedFileLease(file);
    } catch (_) {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<SharedFileLease?> prepareAttachment({
    required String url,
    required String filename,
    required CancelToken cancel,
    required bool Function() authorized,
    required void Function(int, int) onProgress,
  }) async {
    if (!supported || !authorized() || cancel.isCancelled) return null;
    final root = await _temporaryDirectory();
    final folder = await Directory(
      p.join(
        root.path,
        'raft-share',
        'share-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final file = File(
      p.join(folder.path, AttachmentFiles.safeFilename(filename)),
    );
    try {
      await _dio.download(
        AttachmentFiles.attachmentUri(url).toString(),
        file.path,
        cancelToken: cancel,
        onReceiveProgress: onProgress,
      );
      if (!authorized() || cancel.isCancelled) {
        await folder.delete(recursive: true);
        return null;
      }
      return SharedFileLease(file);
    } catch (_) {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    _closed = true;
    _receiver = null;
    _pending = null;
    if (supported) channel.setMethodCallHandler(null);
  }
}
