import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:raft_ui/raft_ui.dart' show RaftVideoPreviewFailure;

import '../data/attachment_image_repository.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_player_sessions.dart';
import '../platform/attachment_stream.dart';
import '../platform/video_frame_probe.dart';
import '../platform/video_frame_scheduler.dart';
import 'attachment_image_loader.dart';
import 'attachment_shape.dart';

/// The picture and the shape of a video card.
///
/// The poster is the attachment's server `thumbnail` rendition, loaded like an
/// image card's (persisted per account and counted in Settings > Storage,
/// decoded at the card's size, kept across rebuilds). A message that carries no
/// `thumbnailUrl` (an upload from the CLI) falls back to the first frame of the
/// video itself: read once through [VideoFrameProbe] (ranged reads, never the
/// file), stored in the same private namespace as the `poster-frame` rendition
/// next to a tiny `video-shape` entry (size, rotation, length), so the next
/// view of the card has both at once and a server thumbnail added later wins
/// (it has its own rendition and is looked at first).
///
/// The read starts only for a card that has been near the viewport for
/// [settle], is cancelled when the card leaves it, runs at most twice at a time
/// app-wide ([VideoFrameScheduler]) and is not tried again after a failure.
class VideoCardPoster {
  VideoCardPoster({
    required this.controller,
    required this.metadata,
    required this.channelId,
    required this.files,
    required this.authorized,
    required this.nearViewport,
    required this.onChanged,
    this.probeOverride,
    VideoFrameScheduler? scheduler,
  }) : scheduler = scheduler ?? VideoFrameScheduler.shared;

  final WorkspaceController controller;
  final Map<String, dynamic> Function() metadata;
  final String Function() channelId;
  final AttachmentFiles files;
  final bool Function() authorized;

  /// Whether the card is within `margin` of the viewport.
  final bool Function({double margin}) nearViewport;
  final void Function() onChanged;

  /// The probe of this card; the platform's when null.
  final VideoFrameProbe? probeOverride;
  final VideoFrameScheduler scheduler;

  VideoFrameProbe? get probe => probeOverride ?? VideoFrameProbe.platform;

  /// A card must be near the viewport this long before its frame is read: a
  /// fast scroll past a column of clips reads none of them.
  static const settle = Duration(milliseconds: 250);

  /// Room around the viewport inside which a read goes on; leaving it cancels.
  static const startMargin = 160.0, keepMargin = 480.0;

  /// The picture longest edge asked of the platform.
  static const frameEdge = 960;

  WorkspaceAttachmentImageLease? _lease;
  AttachmentImageKey? _leaseKey;

  /// The thumbnail key this card is bound to, and a counter that ends async
  /// work started for an earlier binding.
  AttachmentImageKey? _boundKey;
  int _epoch = 0;
  ImageProvider? image;
  bool disposed = false;

  /// The shape from the message itself, else the remembered or read one.
  VideoShape? shape;

  /// The first frame could not be read (the card says so, see [failure]).
  bool failed = false;

  /// Whether the file is one the platform cannot decode (Download is the only
  /// help) or the read failed for a reason a Retry can fix.
  bool unsupported = false;

  RaftVideoPreviewFailure? get failure => !failed
      ? null
      : unsupported
      ? RaftVideoPreviewFailure.unsupported
      : RaftVideoPreviewFailure.unavailable;

  /// Retry on a failed card: forgets the failure and reads the frame again,
  /// which signs the link again (Web `useRefreshingMediaUrl.retry`).
  void retry() {
    if (disposed || !failed) return;
    _sessions.frameFailed.remove(_mediaKey);
    controller.attachmentMedia.invalidateUrl('${_meta['id']}');
    failed = false;
    unsupported = false;
    _boundKey = null;
    sync(box: _box, devicePixelRatio: _dpr);
    onChanged();
  }

  /// A frame read is queued or running for this card.
  bool get reading => _job != null;
  VideoFrameJob<VideoFrameInfo>? _job;
  Timer? _settleTimer;
  bool _waiting = false;
  bool _shapeRead = false;
  Size _box = const Size(448, 252);
  double _dpr = 1;

  PlayerSessions get _sessions => controller.attachmentMedia.playerSessions;
  Map<String, dynamic> get _meta => metadata();
  String get _mediaKey => attachmentMediaKey(_meta);

  /// The message's own size (width and height), when valid.
  static VideoShape? declaredShape(Map<String, dynamic> metadata) =>
      attachmentDeclaredShape(metadata);

  /// Binds to the current metadata and the logical [box] the poster is decoded
  /// for. Cheap when nothing changed.
  void sync({required Size box, required double devicePixelRatio}) {
    final id = _meta['id'];
    if (id is! String || disposed) return;
    _box = box;
    _dpr = devicePixelRatio;
    final declared = declaredShape(_meta);
    final remembered = _sessions.shapes[_mediaKey];
    final next = declared == null
        ? remembered
        : VideoShape(
            width: declared.width,
            height: declared.height,
            duration: remembered?.duration ?? Duration.zero,
          );
    if (next != shape) shape = next;
    final key = _thumbnailKey();
    if (_boundKey == key) return;
    release();
    _boundKey = key;
    failed = _sessions.frameFailed.contains(_mediaKey);
    final url = attachmentThumbnailUrl(_meta);
    try {
      final lease = controller.attachmentMedia.acquireImage(
        key,
        authorized: authorized,
        bestAvailable: true,
        // Only the thumbnail: never the (video) original, whatever the
        // status; no poster is a normal outcome.
        load: (cancel) async {
          if (url == null) throw const StaleAttachmentImage();
          return await files.image(url, cancel: cancel);
        },
      );
      _lease = lease;
      _leaseKey = key;
      image = lease.lease.value;
      if (image == null) {
        unawaited(
          lease.lease.ready.then<void>(
            (provider) {
              if (!disposed && identical(_lease, lease)) {
                image = provider;
                onChanged();
              }
            },
            onError: (Object _) {
              // No thumbnail anywhere: the video's own first frame.
              if (!disposed && identical(_lease, lease) && url == null) {
                unawaited(_startFrame());
              }
            },
          ),
        );
      }
    } catch (_) {
      _lease = null;
    }
    if (image == null && url == null && _lease == null) {
      unawaited(_startFrame());
    }
  }

  AttachmentImageKey _thumbnailKey() => AttachmentImageKey.fromMetadata(
    scope: controller.attachmentImageScope,
    channelId: channelId(),
    metadata: _meta,
    rendition: 'thumbnail',
    target: AttachmentDecodeTarget.box(
      _box.width,
      _box.height,
      devicePixelRatio: _dpr,
    ),
  );

  AttachmentImageKey _frameKey() => AttachmentImageKey.fromMetadata(
    scope: controller.attachmentImageScope,
    channelId: channelId(),
    metadata: _meta,
    rendition: 'poster-frame',
    target: AttachmentDecodeTarget.box(
      _box.width,
      _box.height,
      devicePixelRatio: _dpr,
    ),
  );

  AttachmentImageStoreKey _shapeKey() => controller.attachmentMedia.cacheKey(
    _meta,
    'video-shape',
    channelId: channelId(),
  );

  // ---- the video's own first frame -----------------------------------------

  Future<void> _startFrame() async {
    if (disposed || !authorized()) return;
    final epoch = _epoch;
    // The stored shape (size, rotation, length) first: it fixes the box.
    unawaited(_readShape());
    if (_sessions.frameFailed.contains(_mediaKey)) {
      failed = true;
      onChanged();
      return;
    }
    final key = _frameKey();
    final stored = await controller.attachmentMedia.stored(key);
    if (disposed || epoch != _epoch) return;
    if (stored) {
      _acquireFrame(key);
      return;
    }
    if (probe == null) return;
    _waiting = true;
    gate();
  }

  Future<void> _readShape() async {
    if (_shapeRead) return;
    _shapeRead = true;
    final disk = controller.attachmentMedia.diskCache;
    if (disk == null || _sessions.shapes[_mediaKey] != null) return;
    try {
      final bytes = await disk.read(_shapeKey());
      if (disposed || bytes == null || !authorized()) return;
      final stored = VideoShape.fromBytes(bytes);
      if (stored == null) return;
      _remember(stored, persist: false);
    } on Object {
      // Not stored: the shape comes with the first read.
    }
  }

  /// A shape learnt from the file or the disk. The message's own size, when it
  /// has one, still decides the box: only the length and a missing size are
  /// taken from [learnt].
  void _remember(VideoShape learnt, {required bool persist}) {
    _sessions.rememberShape(_mediaKey, learnt);
    final declared = declaredShape(_meta);
    final next = declared == null
        ? learnt
        : VideoShape(
            width: declared.width,
            height: declared.height,
            duration: learnt.duration,
          );
    if (next != shape) {
      shape = next;
      if (!disposed) onChanged();
    }
    if (persist) {
      final disk = controller.attachmentMedia.diskCache;
      if (disk != null) {
        unawaited(
          disk.write(_shapeKey(), learnt.toBytes()).catchError((Object _) {}),
        );
      }
    }
  }

  /// Called when the card moved relative to the viewport (scroll, layout):
  /// starts a waiting read once the card has been near for [settle], cancels a
  /// queued or running one when the card is far.
  void gate() {
    if (disposed) return;
    if (_job != null) {
      if (!nearViewport(margin: keepMargin)) {
        _cancelRead();
        _waiting = true;
      }
      return;
    }
    if (!_waiting) return;
    if (!nearViewport(margin: startMargin)) {
      _settleTimer?.cancel();
      _settleTimer = null;
      return;
    }
    if (_settleTimer != null) return;
    _settleTimer = Timer(settle, () {
      _settleTimer = null;
      if (disposed || !_waiting) return;
      if (nearViewport(margin: startMargin)) {
        _waiting = false;
        _acquireFrame(_frameKey());
      } else {
        gate();
      }
    });
  }

  void _acquireFrame(AttachmentImageKey key) {
    if (disposed || !authorized() || _leaseKey?.rendition == 'poster-frame') {
      return;
    }
    _releaseLease();
    try {
      final lease = controller.attachmentMedia.acquireImage(
        key,
        authorized: authorized,
        load: _extract,
      );
      _lease = lease;
      _leaseKey = key;
      image = lease.lease.value;
      unawaited(
        lease.lease.ready.then<void>(
          (provider) {
            if (disposed || !identical(_lease, lease)) return;
            image = provider;
            onChanged();
          },
          onError: (Object error) {
            if (disposed || !identical(_lease, lease)) return;
            // Ours leaving (scrolled away, released) is not a failure.
            if (error is StaleAttachmentImage) return;
            if (error is VideoFrameException &&
                error.kind == VideoFrameFailure.cancelled) {
              return;
            }
            _sessions.frameFailed.add(_mediaKey);
            failed = true;
            // The probe's reason picks the card's wording; it is never shown.
            // ignore: raft_lints/avoid_caught_exception_text -- Compared with two fixed reasons, not displayed.
            final reason = error is VideoFrameException ? error.message : null;
            unsupported =
                reason == 'unsupported' || reason == 'no video stream';
            _lease = null;
            _leaseKey = null;
            lease.release();
            onChanged();
          },
        ),
      );
    } catch (_) {
      _lease = null;
      _leaseKey = null;
    }
  }

  /// The loader of the `poster-frame` rendition: the first frame as JPEG bytes
  /// (which the repository stores and decodes), the shape remembered on the way.
  Future<Uint8List> _extract(CancelToken cancel) async {
    final platform = probe;
    if (platform == null) {
      throw const VideoFrameException(VideoFrameFailure.failed, 'unsupported');
    }
    final id = '${_meta['id']}';
    final jobId = '$id#${DateTime.now().microsecondsSinceEpoch}';
    final job = scheduler.submit<VideoFrameInfo>(
      (job) async {
        job.onCancel(() => unawaited(platform.cancel(jobId)));
        final source = await attachmentStreamSource(
          controller,
          id,
          channelId: channelId(),
        );
        Future<VideoFrameInfo> read(Uri url) =>
            platform.probe(id: jobId, url: url, maxEdge: frameEdge);
        try {
          return await read(source.url!);
        } on VideoFrameException catch (error) {
          // The signature expired between signing and the read: sign once more.
          if (error.kind != VideoFrameFailure.expired ||
              source.refresh == null ||
              job.cancelled) {
            rethrow;
          }
          return await read(await source.refresh!());
        }
      },
      wanted: () =>
          !disposed && authorized() && nearViewport(margin: keepMargin),
    );
    _job = job;
    unawaited(cancel.whenCancel.then<void>((_) => job.cancel()));
    try {
      final info = await job.result;
      if (cancel.isCancelled || disposed) {
        throw const VideoFrameException(VideoFrameFailure.cancelled);
      }
      if (info.valid) _remember(VideoShape.of(info), persist: true);
      final bytes = info.jpeg;
      if (bytes == null || bytes.isEmpty) {
        throw const VideoFrameException(VideoFrameFailure.failed, 'no frame');
      }
      return bytes;
    } finally {
      if (identical(_job, job)) _job = null;
    }
  }

  void _cancelRead() {
    _job?.cancel();
    _job = null;
    _releaseLease();
    image = null;
  }

  void _releaseLease() {
    final lease = _lease;
    _lease = null;
    _leaseKey = null;
    lease?.release();
  }

  /// Gives back the poster's lease and stops any read.
  void release() {
    _epoch++;
    _boundKey = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    _waiting = false;
    _job?.cancel();
    _job = null;
    _releaseLease();
    image = null;
  }

  void dispose() {
    disposed = true;
    release();
  }
}
