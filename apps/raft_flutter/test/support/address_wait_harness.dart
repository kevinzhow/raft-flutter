import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_image_loader.dart';
import 'package:raft_flutter/features/media_browser.dart';
import 'package:raft_flutter/features/media_items.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/native_sharing.dart';

class AddressQuery {
  AddressQuery(this.ids, this.batch);
  final List<String> ids;
  final bool batch;
  final result = Completer<dynamic>();
}

/// A controlled server response, reached by the production URL cache/loader.
/// No image widget or loading flag is supplied to the production page.
class AddressClient extends RaftClient {
  AddressClient()
    : super(
        origin: 'https://parity.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'address-owner', 'name': 'Address Owner'});
    selectServer('address-server');
  }
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}

  final queries = <AddressQuery>[];
  bool immediate = false, fail = false, closed = false;
  int cancelled = 0;
  Future<void>? _disposal;
  int get pending => queries.where((q) => !q.result.isCompleted).length;

  dynamic _answer(AddressQuery q) {
    Map<String, dynamic> entry(String id) => {
      'id': id,
      'url': 'https://parity.invalid/original/$id.png',
      'expiresAt': null,
    };
    return q.batch
        ? {
            'urls': [for (final id in q.ids) entry(id)],
          }
        : entry(q.ids.single);
  }

  Future<dynamic> _query(List<String> ids, bool batch) {
    if (closed || fail) {
      return Future.error(RaftApiException('fixture failure', status: 503));
    }
    final q = AddressQuery(ids, batch);
    queries.add(q);
    if (immediate) q.result.complete(_answer(q));
    return q.result.future;
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    final match = RegExp(r'^/attachments/([^/]+)/url$').firstMatch(path);
    return match != null
        ? _query([match[1]!], false)
        : Future.value(<String, dynamic>{});
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) =>
      path == '/attachments/urls'
      ? _query(List<String>.from((data as Map)['attachmentIds'] as List), true)
      : Future.value(<String, dynamic>{});
  void resolve(String id) {
    for (final q in queries) {
      if (!q.result.isCompleted && q.ids.contains(id)) {
        q.result.complete(_answer(q));
      }
    }
  }

  void reject() {
    fail = true;
    for (final q in queries) {
      if (!q.result.isCompleted) {
        q.result.completeError(
          RaftApiException('fixture failure', status: 503),
        );
      }
    }
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    closed = true;
    for (final q in queries) {
      if (!q.result.isCompleted) {
        cancelled++;
        q.result.completeError(RaftApiException('fixture closed', status: 499));
      }
    }
    return _disposal = super.dispose();
  }
}

class ImageByteQuery {
  ImageByteQuery(this.url, this.cancel);
  final String url;
  final CancelToken cancel;
  final result = Completer<Uint8List>();
}

class AddressFiles extends AttachmentFiles {
  AddressFiles() : super(gallerySupported: false);
  final queries = <ImageByteQuery>[];
  Uint8List? immediate;
  int cancelled = 0;
  int get pending => queries.where((q) => !q.result.isCompleted).length;
  @override
  Future<Uint8List> image(
    String url, {
    required CancelToken cancel,
    void Function(int, int)? onProgress,
  }) {
    final q = ImageByteQuery(url, cancel);
    queries.add(q);
    if (immediate != null) q.result.complete(immediate!);
    unawaited(
      cancel.whenCancel.then((error) {
        if (!q.result.isCompleted) {
          cancelled++;
          q.result.completeError(error);
        }
      }),
    );
    return q.result.future;
  }

  void close() {
    for (final q in queries) {
      if (!q.result.isCompleted) q.cancel.cancel('fixture closed');
    }
  }
}

class AddressWaitHarness {
  AddressWaitHarness() {
    w = WorkspaceController(client)
      ..server = RaftRecord({
        'id': 'address-server',
        'name': 'Address Fixture',
        'role': 'owner',
      })
      ..channels = [
        RaftChannel({
          'id': 'address-channel',
          'serverId': 'address-server',
          'name': 'fixture',
          'type': 'channel',
          'joined': true,
        }),
      ];
    w.channel = w.channels.single;
  }
  final client = AddressClient();
  final files = AddressFiles();
  final sharing = NativeSharing(supported: false);
  late final WorkspaceController w;
  bool allowed = true;
  Future<void>? _disposal;
  Map<String, dynamic> metadata(String id) => {
    'id': id,
    'channelId': 'address-channel',
    'filename': '$id.png',
    'mimeType': 'image/png',
    'sizeBytes': 100,
    'width': 16,
    'height': 16,
  };
  Widget view({String id = 'a', Key? key}) => MediaBrowser(
    key: key,
    controller: w,
    files: files,
    sharing: sharing,
    items: [MediaItem.image(metadata(id))],
    initialIndex: 0,
    messageId: null,
    authorized: () => allowed,
    onClose: () {},
  );
  WorkspaceAttachmentImageLease warm(String id) {
    final meta = metadata(id);
    final key = attachmentOriginalKey(w, meta, 'address-channel');
    return w.attachmentMedia.acquireImage(
      key,
      authorized: () => allowed,
      load: attachmentImageLoader(
        controller: w,
        files: files,
        metadata: meta,
        key: key,
      ),
      foreground: true,
    );
  }

  Future<void> dispose() => _disposal ??= () async {
    w.dispose();
    files.close();
    await client.dispose();
    await sharing.dispose();
    // Drain only bounded completion/cancellation callbacks owned by this fixture.
    await Future<void>.delayed(Duration.zero);
  }();
}
