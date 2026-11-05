import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A bounded image of the native viewport, never document-supplied data.
class SystemWebViewSnapshot {
  const SystemWebViewSnapshot(this.png, this.width, this.height, this.sequence);
  final Uint8List png;
  final int width, height, sequence;
  static const maximumBytes = 8 * 1024 * 1024;
  static const maximumPixels = 16 * 1024 * 1024;

  static SystemWebViewSnapshot? parse(Object? value, int sequence) {
    if (value is! Map) return null;
    final png = value['png'], width = value['width'], height = value['height'];
    if (png is! Uint8List ||
        width is! int ||
        height is! int ||
        width <= 0 ||
        height <= 0 ||
        width > 8192 ||
        height > 8192 ||
        width * height > maximumPixels ||
        value['sequence'] != sequence ||
        png.length < 24 ||
        png.length > maximumBytes)
      return null;
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      if (png[i] != signature[i]) return null;
    }
    final header = ByteData.sublistView(png);
    if (header.getUint32(16) != width || header.getUint32(20) != height) {
      return null;
    }
    return SystemWebViewSnapshot(png, width, height, sequence);
  }
}

/// Owns one current image and at most one decode. No global ImageCache entry,
/// polling or retained image survives disposal/controller replacement.
class SystemWebViewSnapshotCache {
  SystemWebViewSnapshotCache({required this.capture, required this.changed});
  final Future<SystemWebViewSnapshot?> Function() capture;
  final VoidCallback changed;
  ui.Image? _image;
  ui.Image? get image => _image;
  final _retiring = <ui.Image>{};
  bool _disposed = false, _pending = false, _again = false;
  int _epoch = 0;

  void _retire(ui.Image image) {
    _retiring.add(image);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_retiring.remove(image)) image.dispose();
    });
  }

  void invalidate({bool clearImage = false}) {
    _epoch++;
    if (clearImage && _image != null) {
      _retire(_image!);
      _image = null;
      changed();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_pending) {
      _again = true;
      return;
    }
    _pending = true;
    final ticket = _epoch;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      final frame = await capture().timeout(const Duration(seconds: 2));
      if (frame == null || _disposed || ticket != _epoch) return;
      // ignore: raft_lints/avoid_raw_image_decode -- Bounded native viewport PNG is privately owned here, never inserted in ImageCache; codec and every image retire on replacement, resize or dispose.
      codec = await ui.instantiateImageCodec(frame.png);
      decoded = (await codec.getNextFrame()).image;
      if (_disposed ||
          ticket != _epoch ||
          decoded.width != frame.width ||
          decoded.height != frame.height) {
        decoded.dispose();
        decoded = null;
        return;
      }
      final previous = _image;
      _image = decoded;
      decoded = null;
      if (previous != null) _retire(previous);
      changed();
    } catch (_) {
      // A failed background snapshot retains the previous native pixels. It
      // cannot reopen native input over an overlay or fail the HTML session.
    } finally {
      decoded?.dispose();
      codec?.dispose();
      _pending = false;
      if (!_disposed && _again) {
        _again = false;
        unawaited(refresh());
      }
    }
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _image?.dispose();
    _image = null;
    for (final image in _retiring) {
      image.dispose();
    }
    _retiring.clear();
  }
}
