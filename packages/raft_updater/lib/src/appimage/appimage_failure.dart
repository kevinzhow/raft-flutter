import 'package:flutter/foundation.dart';

/// Why an in-place AppImage update stopped. The app turns each kind into a
/// specific, actionable sentence; [detail] carries its one variable (a host
/// name, a folder, a status code or a size).
enum AppImageUpdateFailureKind {
  /// The server could not be reached (offline, DNS, proxy, TLS, timeout).
  network,

  /// The server answered with an unexpected HTTP status ([detail]).
  http,

  /// The release has no `.zsync` file for this AppImage.
  noDeltaFile,

  /// The `.zsync` file does not describe the release in the manifest.
  releaseMismatch,

  /// The server ignored a partial-download request.
  rangesUnsupported,

  /// The folder of the AppImage is full ([detail] is the folder).
  diskFull,

  /// The folder of the AppImage cannot be written ([detail] is the folder).
  notWritable,

  /// The release manifest lacks the SHA-256 the update is verified against.
  missingChecksum,

  /// The release manifest has no Ed25519 signature for the file, or this build
  /// has no public key to check one against.
  missingSignature,

  /// The signature is malformed, or does not match the new file's bytes under
  /// the app's public key; the file was discarded.
  badSignature,

  /// The new file's checksum differs from the release's; it was discarded.
  verification,

  /// The verified file could not be moved into place.
  replace,

  /// The user stopped the update.
  cancelled,

  /// Anything else.
  unexpected,
}

@immutable
class AppImageUpdateFailure implements Exception {
  const AppImageUpdateFailure(this.kind, [this.detail = '']);

  final AppImageUpdateFailureKind kind;
  final String detail;

  @override
  String toString() =>
      'AppImageUpdateFailure(${kind.name}${detail.isEmpty ? '' : ': $detail'})';
}
