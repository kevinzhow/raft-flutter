import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_intent/receive_intent.dart' as intents;
import 'package:uri_content/uri_content.dart';

import 'attachment_files.dart';
import 'attachment_http.dart';
import 'cache_staging.dart';
import 'incoming_share_inbox.dart';

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
  const IncomingShare({this.text, this.files = const [], this.token});
  final String? token;
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
    bool staged = true,
  }) {
    _timer = Timer(lifetime, () => unawaited(dispose()));
    // While the lease lives its folder is in use: "Clear cache" leaves it.
    if (staged) _release = holdStaging(file.parent.path);
  }
  final File file;
  void Function()? _release;
  Timer? _timer;
  Future<void>? _disposal;

  /// Ends the expiry timer: the owner now decides when the file goes (the
  /// inline media session cache evicts by age and size, and on dispose).
  void cancelExpiry() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _timer?.cancel();
    _timer = null;
    _release?.call();
    _release = null;
    if (await file.parent.exists()) await file.parent.delete(recursive: true);
  }
}

class NativeSharing {
  NativeSharing({
    MethodChannel? channel,
    Dio? dio,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? stagingDirectory,
    bool? supported,
    bool? ios,
    Stream<Uint8List> Function(Uri)? readContent,
    Future<Directory> Function()? incomingDirectory,
  }) : channel = channel ?? const MethodChannel('app.raft/sharing'),
       _dio = dio ?? AttachmentHttp.shared,
       _readContent =
           readContent ??
           ((uri) =>
               UriContent().getContentStream(uri, bufferSize: 256 * 1024)),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _stagingDirectory = stagingDirectory ?? cacheStagingDirectory,
       _ios = ios ?? Platform.isIOS,
       supported = supported ?? (Platform.isAndroid || Platform.isIOS) {
    inbox = IncomingShareInbox(
      incomingDirectory ?? _incomingDirectory,
      _readContent,
      copyContent: readContent == null && Platform.isAndroid && this.supported
          ? (uri, file, limit, onBytes) async {
              // The host reports copied bytes under this id while it copies.
              final id = ++_copyIds;
              _copyProgress[id] = onBytes;
              try {
                return (await this.channel.invokeMethod<int>('copyIncoming', {
                      'uri': uri.toString(),
                      'path': file.path,
                      'limit': limit,
                      'id': id,
                    })) ??
                    (throw const FormatException('Shared file unavailable'));
              } finally {
                _copyProgress.remove(id);
              }
            }
          : null,
    );
    if (readContent == null && Platform.isAndroid && this.supported) {
      this.channel.setMethodCallHandler((call) async {
        if (call.method != 'copyProgress') {
          throw MissingPluginException(call.method);
        }
        final args = call.arguments;
        if (args is Map && args['id'] is int && args['bytes'] is int) {
          _copyProgress[args['id'] as int]?.call(args['bytes'] as int);
        }
        return null;
      });
    }
  }
  int _copyIds = 0;
  final _copyProgress = <int, void Function(int)>{};
  late final IncomingShareInbox inbox;
  Future<Directory> _incomingDirectory() async {
    if (supported) {
      final path = await channel.invokeMethod<String>('incomingDirectory');
      if (path != null) return Directory(path);
    }
    return Directory(
      p.join((await _temporaryDirectory()).path, 'raft-incoming'),
    );
  }

  final MethodChannel channel;
  final Dio _dio;

  /// Where received shares go when the host has no inbox directory of its own
  /// (user data: never swept, see [sweepStaging]).
  final Future<Directory> Function() _temporaryDirectory;

  /// Where share-sheet copies are staged.
  final Future<Directory> Function() _stagingDirectory;
  final bool supported;
  final bool _ios;
  final _deliveredInboxTokens = <String>{};
  final Stream<Uint8List> Function(Uri) _readContent;
  final _readers = <StreamIterator<Uint8List>>{};
  StreamSubscription<intents.Intent?>? _intentSubscription;
  Future<void> _incomingWork = Future.value();
  Future<void>? _initialization;
  static const maxIncomingBytes = 50 * 1024 * 1024;
  void Function(IncomingShare)? _receiver;
  final _pending = Queue<IncomingShare>();
  set onIncoming(void Function(IncomingShare)? receiver) {
    _receiver = receiver;
    while (receiver != null &&
        identical(_receiver, receiver) &&
        _pending.isNotEmpty &&
        !_closed) {
      receiver(_pending.removeFirst());
    }
  }

  void receive(IncomingShare incoming) {
    if (_closed) return;
    if (_receiver == null) {
      _pending.addLast(incoming);
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

  Future<void> init() => _initialization ??= _init();

  /// A wake-up signal only; content is read from the validated shared inbox.
  static bool isIncomingShareLink(Uri uri) =>
      uri.scheme == 'raft' &&
      uri.host == 'share' &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      RegExp(r'^/[a-f0-9]{32}$').hasMatch(uri.path);

  Future<void> _init() async {
    if (!supported || _closed) return;
    // Android provider events remain owned by receive_intent. An iOS extension
    // publishes already copied envelopes; it never grants arbitrary file paths.
    if (_ios) {
      await _recoverInbox();
      return;
    }
    _intentSubscription = intents.ReceiveIntent.receivedIntentStream.listen(
      (intent) => unawaited(_queueIntent(intent)),
      onError: (Object _) {},
    );
    // Start both reads immediately. A slow old inbox cannot delay the launching
    // share, and recovered shares wait until that intent has entered the queue.
    final launching = _queueInitialIntent();
    await Future.wait([launching, _recoverInbox(after: launching)]);
    try {
      if (!_closed) await channel.invokeMethod<void>('sharingReady');
    } on PlatformException {
      // A platform without a receiving Activity still supports outgoing shares.
    } on MissingPluginException {
      // Optional in tests and other platform hosts.
    }
  }

  Future<void> _queueInitialIntent() async {
    try {
      await _queueIntent(await intents.ReceiveIntent.getInitialIntent());
    } on PlatformException {
      // A missing launching intent must not prevent recovery of saved shares.
    } on MissingPluginException {
      // Optional in tests and other platform hosts.
    }
  }

  Future<void> _recoverInbox({Future<void>? after}) async {
    try {
      final pending = await inbox.pending();
      if (after != null) await after;
      for (final share in pending) {
        if (_closed) return;
        if (share.token != null && !_deliveredInboxTokens.add(share.token!)) {
          continue;
        }
        if (_deliveredInboxTokens.length > 256) {
          _deliveredInboxTokens.remove(_deliveredInboxTokens.first);
        }
        receive(share);
      }
    } catch (_) {
      // A failed recovery must not prevent admission of a later share.
    }
  }

  /// The user returns to Raft after its iOS Share Extension saved content.
  /// Serial admission and token identity prevent repeated resume events from
  /// appending the same share twice. Cold recovery uses the same durable inbox.
  Future<void> resume() async {
    if (!_ios || !supported || _closed) return;
    await init();
    if (_closed) return;
    _incomingWork = _incomingWork.then((_) => _recoverInbox());
    await _incomingWork;
  }

  Future<void> _queueIntent(intents.Intent? intent) {
    // Serialize provider metadata lookups so rapid shares retain arrival order.
    return _incomingWork = _incomingWork.then((_) async {
      if (_closed ||
          intent == null ||
          !const [
            'android.intent.action.SEND',
            'android.intent.action.SEND_MULTIPLE',
          ].contains(intent.action)) {
        return;
      }
      final extras = intent.extra ?? const <String, dynamic>{};
      final raw =
          extras['app.raft.sharedUris'] ??
          extras['android.intent.extra.STREAM'];
      final uris = (raw is List ? raw : [?raw]);
      final text = extras['android.intent.extra.TEXT'];
      // Validate before asking a content provider for metadata.
      if (uris.length > 10 ||
          uris.any((raw) {
            final uri = raw is String ? Uri.tryParse(raw) : null;
            return uri == null || uri.scheme != 'content' || uri.host.isEmpty;
          }) ||
          (text != null && (text is! String || text.length > 65536))) {
        return;
      }
      var files = <dynamic>[
        for (final uri in uris) {'uri': uri, 'filename': 'attachment'},
      ];
      if (uris.isNotEmpty) {
        try {
          files =
              await channel.invokeListMethod<dynamic>('sharedFileInfo', {
                'uris': uris,
              }) ??
              files;
        } on PlatformException {
          // Missing metadata must not discard an otherwise readable grant.
        } on MissingPluginException {
          // Optional in tests and other platform hosts.
        }
      }
      final share = IncomingShare.parse({'text': text, 'files': files});
      if (share != null) receive(share);
    });
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
    if (!supported || _closed || !authorized()) {
      throw PlatformException(
        code: 'stale',
        message: 'The conversation changed.',
      );
    }
    final uri = Uri.tryParse(file.uri);
    if (uri == null || uri.scheme != 'content' || uri.host.isEmpty) {
      throw PlatformException(code: 'invalid', message: 'Invalid shared file.');
    }
    if ((file.sizeBytes ?? 0) > maxIncomingBytes) {
      throw PlatformException(
        code: 'too_large',
        message: 'The shared file exceeds 50 MB.',
      );
    }
    final reader = StreamIterator(_readContent(uri));
    _readers.add(reader);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await reader.moveNext()) {
        if (_closed || !authorized()) {
          throw PlatformException(
            code: 'stale',
            message: 'The conversation changed.',
          );
        }
        if (bytes.length + reader.current.length > maxIncomingBytes) {
          throw PlatformException(
            code: 'too_large',
            message: 'The shared file exceeds 50 MB.',
          );
        }
        bytes.add(reader.current);
      }
      if (_closed || !authorized()) {
        throw PlatformException(
          code: 'stale',
          message: 'The conversation changed.',
        );
      }
      return bytes.takeBytes();
    } finally {
      _readers.remove(reader);
      await reader.cancel();
    }
  }

  Future<SharedFileLease?> prepareBytes(
    Uint8List bytes, {
    required String filename,
    required bool Function() authorized,
  }) async {
    if (!supported || !authorized()) return null;
    final root = await _stagingDirectory();
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

  /// A private copy of a local [source] (a file the attachment cache holds)
  /// for the share sheet, so the cache's own file is never handed out.
  Future<SharedFileLease?> prepareFile(
    File source, {
    required String filename,
    required bool Function() authorized,
  }) async {
    if (!supported || !authorized()) return null;
    final root = await _stagingDirectory();
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
      await source.copy(file.path);
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
    final root = await _stagingDirectory();
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
    _pending.clear();
    _deliveredInboxTokens.clear();
    await _intentSubscription?.cancel();
    await Future.wait(_readers.toList().map((reader) => reader.cancel()));
    _readers.clear();
  }
}
