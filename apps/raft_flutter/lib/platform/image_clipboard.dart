import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Web `resolvePngClipboardCapability` / `copyPngDataUrlToClipboard`: put a PNG
/// on the system clipboard. Linux owns an image/png GTK selection; Android
/// publishes a read-only FileProvider URI. The pasteboard plugin handles the
/// other native hosts. Only an accepted native write counts as a copy.
class ImageClipboard {
  const ImageClipboard({this.write, this.supportedOverride});
  final Future<void> Function(Uint8List png)? write;
  final bool? supportedOverride;
  static const _native = MethodChannel('app.raft/image-clipboard');

  bool get supported =>
      supportedOverride ??
      (!kIsWeb &&
          (Platform.isLinux ||
              Platform.isAndroid ||
              Platform.isMacOS ||
              Platform.isWindows ||
              Platform.isIOS));

  Future<void> copyPng(Uint8List png) async {
    if (!supported) {
      throw UnsupportedError('Image clipboard is unavailable.');
    }
    // Reject corrupt/truncated output before touching any system clipboard.
    // Hosts also decode and enforce the message export's 16M pixel budget.
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (png.length < 33 ||
        png.length > 32 * 1024 * 1024 ||
        !listEquals(png.sublist(0, 8), signature)) {
      throw const FormatException('Invalid PNG image.');
    }
    final header = ByteData.sublistView(png);
    final width = header.getUint32(16), height = header.getUint32(20);
    if (header.getUint32(8) != 13 ||
        header.getUint32(12) != 0x49484452 ||
        width == 0 ||
        height == 0 ||
        width * height > 16000000) {
      throw const FormatException('Invalid PNG image size.');
    }
    if (write != null) return write!(png);
    if (!kIsWeb && (Platform.isLinux || Platform.isAndroid)) {
      if (await _native.invokeMethod<bool>('copyPng', png) != true) {
        throw PlatformException(
          code: 'clipboard_unavailable',
          message: 'The clipboard did not accept the PNG.',
        );
      }
      return;
    }
    await Pasteboard.writeImage(png);
  }
}
