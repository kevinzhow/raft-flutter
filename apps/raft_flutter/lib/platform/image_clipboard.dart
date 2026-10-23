import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

/// Web `resolvePngClipboardCapability` / `copyPngDataUrlToClipboard`: put a PNG
/// on the system clipboard. The pasteboard plugin writes images on macOS, iOS
/// and Windows; elsewhere (Linux has no writer, Android needs a FileProvider
/// this app does not declare) the "Copy image" action is not offered, like
/// Web when the browser blocks it.
class ImageClipboard {
  const ImageClipboard({this.write, this.supportedOverride});
  final Future<void> Function(Uint8List png)? write;
  final bool? supportedOverride;

  bool get supported =>
      supportedOverride ??
      (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isIOS));

  Future<void> copyPng(Uint8List png) =>
      (write ?? Pasteboard.writeImage).call(png);
}
