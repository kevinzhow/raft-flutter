// Web utils/screenshotBudget.ts (v1.21.23, task #1302): a selected-message
// image is one canvas. Past a canvas budget the engine does not fail, it
// hands back an empty image, which used to reach preview, save and share as a
// 0-byte PNG. Every capture gets the same budget, picks the highest pixel
// ratio that fits, and is validated before anything can use it.
import 'dart:typed_data';

/// Web `SCREENSHOT_PIXEL_BUDGET`.
const screenshotPixelBudget = 16000000;

/// The tallest selection (CSS px) one image holds. Not in Web: a Flutter
/// texture of this height is the largest the export has always attempted.
const screenshotMaxCssHeight = 4096.0;

/// Web `planScreenshotPixelRatio`: the highest ratio, starting from
/// [preferred] and falling back 3, 2, 1, whose canvas stays within [budget]
/// pixels; null when even 1x does not fit (Web `needsPagination`).
double? planScreenshotPixelRatio(
  double cssWidth,
  double cssHeight,
  double preferred, {
  int budget = screenshotPixelBudget,
  double maxCssHeight = screenshotMaxCssHeight,
}) {
  if (cssHeight > maxCssHeight) return null;
  for (final ratio in [
    preferred,
    ...[3.0, 2.0, 1.0].where((r) => r < preferred),
  ]) {
    final width = (cssWidth * ratio).ceil(),
        height = (cssHeight * ratio).ceil();
    if (width > 0 && height > 0 && width * height <= budget) return ratio;
  }
  return null;
}

/// Web `ScreenshotInvalidReason`.
enum ScreenshotInvalidReason { notPng, emptyBlob, undecodable, zeroSize }

class ScreenshotInvalidOutputError implements Exception {
  const ScreenshotInvalidOutputError(this.reason);
  final ScreenshotInvalidReason reason;
  @override
  String toString() => 'Rendered image is unusable (${reason.name})';
}

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Web `validateScreenshotPng`: a PNG with a signature and a non-zero size
/// (read from its IHDR), or [ScreenshotInvalidOutputError].
void validateScreenshotPng(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const ScreenshotInvalidOutputError(ScreenshotInvalidReason.emptyBlob);
  }
  if (bytes.length < 8 ||
      !List.generate(8, (i) => bytes[i] == _pngSignature[i]).every((v) => v)) {
    throw const ScreenshotInvalidOutputError(ScreenshotInvalidReason.notPng);
  }
  // 8 signature + 4 length + 4 "IHDR" + width + height.
  if (bytes.length < 24) {
    throw const ScreenshotInvalidOutputError(
      ScreenshotInvalidReason.undecodable,
    );
  }
  final header = ByteData.sublistView(bytes);
  if (header.getUint32(16) == 0 || header.getUint32(20) == 0) {
    throw const ScreenshotInvalidOutputError(ScreenshotInvalidReason.zeroSize);
  }
}
