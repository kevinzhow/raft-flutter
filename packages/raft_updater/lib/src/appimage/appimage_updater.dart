import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show AppExitType;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'appimage_environment.dart';
import 'appimage_failure.dart';
import 'appimage_http.dart';
import 'ed25519.dart';
import 'update_information.dart';
import 'zsync_control.dart';
import 'zsync_matcher.dart';
import 'zsync_plan.dart';

/// The release to install: the fields of the platform's
/// `build-manifest-appimage-x64.json` the update verifies against.
@immutable
class AppImageRelease {
  const AppImageRelease({
    required this.tag,
    required this.artifact,
    required this.sha256,
    required this.bytes,
    this.edSignature = '',
  });

  /// Full release tag, e.g. `v0.1.0+7`.
  final String tag;

  /// The AppImage asset name, e.g. `raft-flutter-0.1.0+7-appimage-x64.AppImage`.
  final String artifact;

  /// Lowercase hex SHA-256 of the AppImage the release published.
  final String sha256;
  final int bytes;

  /// Base64 Ed25519 signature (64 bytes) of the whole AppImage, the manifest's
  /// `edSignature`; made by the release publisher with the Sparkle key. Empty
  /// when the manifest has none; the update refuses to install without it.
  final String edSignature;
}

enum AppImageUpdatePhase { idle, running, ready, failed }

/// What the update is doing now; the Updates card renders this.
enum AppImageUpdateStage { preparing, downloading, verifying, installing }

@immutable
class AppImageUpdateStatus {
  const AppImageUpdateStatus._(
    this.phase,
    this.stage,
    this.progress,
    this.failure,
  );
  const AppImageUpdateStatus.idle()
    : this._(AppImageUpdatePhase.idle, null, 0, null);
  const AppImageUpdateStatus.running(AppImageUpdateStage stage, double progress)
    : this._(AppImageUpdatePhase.running, stage, progress, null);
  const AppImageUpdateStatus.ready()
    : this._(AppImageUpdatePhase.ready, null, 1, null);
  const AppImageUpdateStatus.failed(AppImageUpdateFailure failure)
    : this._(AppImageUpdatePhase.failed, null, 0, failure);

  final AppImageUpdatePhase phase;
  final AppImageUpdateStage? stage;

  /// Overall progress 0..1 (meaningful while running).
  final double progress;
  final AppImageUpdateFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is AppImageUpdateStatus &&
      other.phase == phase &&
      other.stage == stage &&
      other.progress == progress &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(phase, stage, progress, failure?.kind);
}

/// Numbers of the last finished update, logged once for diagnostics.
@immutable
class AppImageTransferReport {
  const AppImageTransferReport({
    required this.targetBytes,
    required this.reusedBytes,
    required this.downloadedBytes,
    required this.controlBytes,
    required this.requests,
    required this.scan,
    required this.download,
    required this.verify,
    required this.total,
  });

  final int targetBytes, reusedBytes, downloadedBytes, controlBytes, requests;
  final Duration scan, download, verify, total;

  @override
  String toString() =>
      'AppImage delta update: new file $targetBytes B, reused $reusedBytes B, '
      'downloaded $downloadedBytes B in $requests range requests '
      '(+$controlBytes B control file); scan ${scan.inMilliseconds} ms, '
      'download ${download.inMilliseconds} ms, verify ${verify.inMilliseconds} ms, '
      'total ${total.inMilliseconds} ms';
}

/// Replaces the running AppImage with the next release, transferring only the
/// blocks that changed (the zsync algorithm, compatible with `.zsync` files
/// from `zsyncmake` and AppImageUpdate).
///
/// Flow: fetch the release's `.zsync` file, find the unchanged blocks in the
/// current file, download only the rest with HTTP range requests, assemble
/// `.<name>.part` beside the AppImage, verify SHA-1 (from the `.zsync`),
/// SHA-256 (from the release manifest) and the release's Ed25519 signature
/// (against the public key compiled into the app), then move it over the
/// original with the old file kept as a backup until the move succeeded. The running
/// process keeps using the old file's inode; [restart] starts the new one.
class AppImageUpdater {
  AppImageUpdater({
    required this.path,
    required this.information,
    required this._http,
    required this.publicKey,
    this._origin,
    Map<String, String>? environment,
    Future<void> Function()? quit,
    int? processId,
    this.rangeGap = 64 * 1024,
    this.pieceSize = 2 << 20,
    this.connections = 4,
    void Function(String message)? log,
  }) : _environment = environment ?? Platform.environment,
       _quit = quit ?? _exitApplication,
       _processId = processId ?? pid,
       _log = log ?? debugPrint;

  /// The real path of the AppImage this process runs from.
  final String path;
  final AppImageUpdateInformation information;

  /// Base64 Ed25519 public key (the Sparkle key) the release signature is
  /// verified against, compiled into the build.
  final String publicKey;
  final int rangeGap, pieceSize, connections;

  final AppImageHttp _http;
  final Uri? _origin;
  final Map<String, String> _environment;
  final Future<void> Function() _quit;
  final int _processId;
  final void Function(String message) _log;

  // ignore: raft_lints/avoid_unreleased_resource -- Owned by the app-wide AppUpdater, which is never torn down.
  final ValueNotifier<AppImageUpdateStatus> _status = ValueNotifier(
    const AppImageUpdateStatus.idle(),
  );
  ValueListenable<AppImageUpdateStatus> get status => _status;

  AppImageTransferReport? lastReport;

  bool _cancelled = false;
  Isolate? _scanner;

  String get _folder => File(path).parent.path;
  String get _name => path.substring(_folder.length + 1);
  String get _part => '$_folder/.$_name.part';
  String get _backup => '$_folder/.$_name.old';

  static Future<void> _exitApplication() => ServicesBinding.instance
      .exitApplication(AppExitType.required)
      .then((_) {});

  /// Leaves a failed state (the card offers the update again).
  void reset() {
    if (_status.value.phase == AppImageUpdatePhase.failed) {
      _status.value = const AppImageUpdateStatus.idle();
    }
  }

  /// Stops a running update and removes its partial file.
  void cancel() {
    if (_status.value.phase != AppImageUpdatePhase.running) return;
    _cancelled = true;
    _scanner?.kill(priority: Isolate.immediate);
    _http.close();
  }

  Uri _zsyncUrl(AppImageRelease release) {
    final info = information;
    switch (info) {
      case GithubReleasesInformation():
        final asset = '${release.artifact}.zsync';
        if (!info.matches(asset)) {
          throw AppImageUpdateFailure(
            AppImageUpdateFailureKind.releaseMismatch,
            asset,
          );
        }
        return info.assetUrl(release.tag, asset, origin: _origin);
      case DirectZsyncInformation():
        return info.url;
    }
  }

  void _set(AppImageUpdateStage stage, double progress) {
    if (_cancelled) {
      throw const AppImageUpdateFailure(AppImageUpdateFailureKind.cancelled);
    }
    _status.value = AppImageUpdateStatus.running(stage, progress.clamp(0, 1));
  }

  /// Runs the whole update. Never throws: the outcome is [status] (ready or
  /// failed with the reason).
  Future<void> install(AppImageRelease release) async {
    if (_status.value.phase == AppImageUpdatePhase.running) return;
    _cancelled = false;
    if (release.sha256.length != 64 || release.bytes <= 0) {
      _status.value = const AppImageUpdateStatus.failed(
        AppImageUpdateFailure(AppImageUpdateFailureKind.missingChecksum),
      );
      return;
    }
    final signature = release.edSignature.trim();
    if (signature.isEmpty || !Ed25519Verifier.isPublicKey(publicKey)) {
      _status.value = AppImageUpdateStatus.failed(
        AppImageUpdateFailure(
          AppImageUpdateFailureKind.missingSignature,
          signature.isEmpty ? 'no signature in the manifest' : 'no public key',
        ),
      );
      return;
    }
    try {
      Ed25519Verifier.fromBase64(publicKey, signature);
    } on FormatException catch (error) {
      _status.value = AppImageUpdateStatus.failed(
        AppImageUpdateFailure(
          AppImageUpdateFailureKind.badSignature,
          error.message,
        ),
      );
      return;
    }
    final clock = Stopwatch()..start();
    _set(AppImageUpdateStage.preparing, 0);
    try {
      await _run(release, clock);
      _status.value = const AppImageUpdateStatus.ready();
    } on Object catch (error) {
      await _discard();
      // Closing the client to cancel surfaces as a network error; the user's
      // reason wins.
      final failure = _cancelled
          ? const AppImageUpdateFailure(AppImageUpdateFailureKind.cancelled)
          : error is AppImageUpdateFailure
          ? error
          : _translate(error) ??
                AppImageUpdateFailure(
                  AppImageUpdateFailureKind.unexpected,
                  '$error',
                );
      _status.value = AppImageUpdateStatus.failed(failure);
      _log('AppImage update stopped: $failure');
    } finally {
      _http.close();
      _scanner = null;
    }
  }

  AppImageUpdateFailure? _translate(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code == 28) {
        return AppImageUpdateFailure(
          AppImageUpdateFailureKind.diskFull,
          _folder,
        );
      }
      if (code == 13 || code == 1 || code == 30) {
        return AppImageUpdateFailure(
          AppImageUpdateFailureKind.notWritable,
          _folder,
        );
      }
    }
    return null;
  }

  Future<void> _discard() async {
    try {
      final file = File(_part);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Nothing more to do; the next attempt removes it first.
    }
  }

  Future<void> _run(AppImageRelease release, Stopwatch clock) async {
    await _discard();
    final baseline = _http.bytesReceived,
        baselineRequests = _http.rangeRequests;
    final zsyncUrl = _zsyncUrl(release);
    final controlBytes = await _http.getBytes(
      zsyncUrl,
      missing: AppImageUpdateFailureKind.noDeltaFile,
    );
    final ZsyncControl control;
    try {
      control = ZsyncControl.parse(controlBytes);
    } on FormatException catch (error) {
      throw AppImageUpdateFailure(
        AppImageUpdateFailureKind.releaseMismatch,
        error.message,
      );
    }
    final target = zsyncUrl.resolve(control.url);
    if (target.origin != zsyncUrl.origin ||
        control.length != release.bytes ||
        target.pathSegments.last != release.artifact) {
      throw AppImageUpdateFailure(
        AppImageUpdateFailureKind.releaseMismatch,
        'control file names ${control.url} (${control.length} B)',
      );
    }
    final controlTransfer = _http.bytesReceived - baseline;
    final afterControl = _http.bytesReceived;

    final scanWatch = Stopwatch()..start();
    final match = await _scan(control);
    scanWatch.stop();
    final plan = ZsyncPlan.build(control, match.source, gap: rangeGap);

    final downloadWatch = Stopwatch()..start();
    await _assemble(plan, target);
    downloadWatch.stop();

    final verifyWatch = Stopwatch()..start();
    _set(AppImageUpdateStage.verifying, 0.9);
    final part = _part;
    final key = publicKey, signature = release.edSignature;
    final digests = await Isolate.run(() => _hashFile(part, key, signature));
    if (_cancelled) {
      throw const AppImageUpdateFailure(AppImageUpdateFailureKind.cancelled);
    }
    if (File(_part).lengthSync() != release.bytes ||
        digests.$1 != control.sha1 ||
        digests.$2 != release.sha256.toLowerCase()) {
      throw const AppImageUpdateFailure(AppImageUpdateFailureKind.verification);
    }
    // The checksums only prove the file matches what the release lists; the
    // signature proves the publisher made it. Nothing is replaced before this.
    if (!digests.$3) {
      throw const AppImageUpdateFailure(
        AppImageUpdateFailureKind.badSignature,
        'the signature does not match the downloaded file',
      );
    }
    verifyWatch.stop();

    _set(AppImageUpdateStage.installing, 0.97);
    await _install();
    lastReport = AppImageTransferReport(
      targetBytes: control.length,
      reusedBytes: plan.reusedBytes,
      downloadedBytes: _http.bytesReceived - afterControl,
      controlBytes: controlTransfer,
      requests: _http.rangeRequests - baselineRequests,
      scan: scanWatch.elapsed,
      download: downloadWatch.elapsed,
      verify: verifyWatch.elapsed,
      total: clock.elapsed,
    );
    _log('$lastReport');
  }

  Future<ZsyncMatch> _scan(ZsyncControl control) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final done = Completer<ZsyncMatch>();
    messages.listen((Object? message) {
      if (message is double) {
        if (!_cancelled) {
          _status.value = AppImageUpdateStatus.running(
            AppImageUpdateStage.preparing,
            message * 0.1,
          );
        }
      } else if (message is ZsyncMatch && !done.isCompleted) {
        done.complete(message);
      }
    });
    errors.listen((Object? error) {
      if (!done.isCompleted) done.completeError(StateError('$error'));
    });
    try {
      _scanner = await Isolate.spawn(
        _scanEntry,
        (messages.sendPort, path, control),
        onError: errors.sendPort,
        onExit: errors.sendPort,
        errorsAreFatal: true,
      );
      if (_cancelled) {
        throw const AppImageUpdateFailure(AppImageUpdateFailureKind.cancelled);
      }
      return await done.future;
    } finally {
      messages.close();
      errors.close();
    }
  }

  Future<void> _assemble(ZsyncPlan plan, Uri target) async {
    final control = plan.control;
    final output = await File(_part).open(mode: FileMode.write);
    final seed = await File(path).open();
    var aborted = false;
    var lock = Future<void>.value();
    Future<void> write(int offset, Uint8List data) {
      final next = lock.then((_) async {
        if (aborted || _cancelled) {
          throw const AppImageUpdateFailure(
            AppImageUpdateFailureKind.cancelled,
          );
        }
        await output.setPosition(offset);
        await output.writeFrom(data);
      });
      lock = next.then((_) {}, onError: (Object _) {});
      return next;
    }

    var done = 0;
    final total = control.length;
    void advance(int bytes) {
      done += bytes;
      _set(AppImageUpdateStage.downloading, 0.1 + 0.8 * done / total);
    }

    try {
      await output.truncate(control.length);
      for (final copy in plan.copies) {
        for (var at = 0; at < copy.length; at += 1 << 20) {
          final length = copy.length - at < 1 << 20
              ? copy.length - at
              : 1 << 20;
          await seed.setPosition(copy.seedOffset + at);
          final data = await seed.read(length);
          if (data.length != length) {
            throw const AppImageUpdateFailure(
              AppImageUpdateFailureKind.unexpected,
              'the current file changed',
            );
          }
          await write(copy.targetOffset + at, data);
        }
        advance(copy.length);
      }
      final queue = plan.pieces(pieceSize);
      var next = 0;
      Future<void> worker() async {
        while (next < queue.length && !aborted) {
          final piece = queue[next++];
          await _http.getRange(target, piece.start, piece.end, (
            offset,
            chunk,
          ) async {
            await write(offset, chunk);
            advance(chunk.length);
          });
        }
      }

      try {
        await Future.wait([
          for (
            var i = 0;
            i < connections && i < (queue.isEmpty ? 1 : queue.length);
            i++
          )
            worker(),
        ]);
      } on Object {
        aborted = true;
        rethrow;
      }
      await lock;
      await output.flush();
    } finally {
      aborted = true;
      await seed.close();
      await output.close();
    }
    if (_cancelled) {
      throw const AppImageUpdateFailure(AppImageUpdateFailureKind.cancelled);
    }
    // The new file keeps the old one's permissions (the AppImage must stay
    // executable); chmod comes from the host's PATH, not the bundled libraries.
    final chmod = await Process.run(
      'chmod',
      ['--reference=$path', _part],
      environment: hostEnvironment(_environment),
      includeParentEnvironment: false,
    );
    if (chmod.exitCode != 0) {
      throw AppImageUpdateFailure(
        AppImageUpdateFailureKind.notWritable,
        _folder,
      );
    }
  }

  /// Old file -> backup, new file -> original name, backup removed on success
  /// and restored if the second rename fails.
  Future<void> _install() async {
    final backup = File(_backup);
    try {
      if (backup.existsSync()) backup.deleteSync();
      File(path).renameSync(_backup);
    } on FileSystemException {
      throw AppImageUpdateFailure(
        AppImageUpdateFailureKind.notWritable,
        _folder,
      );
    }
    try {
      File(_part).renameSync(path);
    } on FileSystemException catch (error) {
      try {
        backup.renameSync(path);
      } on FileSystemException {
        // The backup stays beside the AppImage under its own name.
      }
      throw AppImageUpdateFailure(
        AppImageUpdateFailureKind.replace,
        error.osError?.message ?? '',
      );
    }
    try {
      backup.deleteSync();
    } on FileSystemException {
      // Harmless leftover; the next update replaces it.
    }
  }

  /// Starts the installed AppImage once this process has exited, then quits
  /// this one. The new instance must not start while this one still holds the
  /// application's single-instance name, so a detached shell waits for our
  /// pid. Returns false when the new process could not be started.
  Future<bool> restart() async {
    if (_status.value.phase != AppImageUpdatePhase.ready) return false;
    const script =
        r'''i=0; while kill -0 "$1" 2>/dev/null && [ "$i" -lt 150 ]; do sleep 0.2; i=$((i+1)); done; exec "$2" ${3:+"$3"}''';
    // Started with --appimage-extract-and-run (no FUSE): the runtime unpacks
    // into appimage_extracted_*, so the new instance needs the same flag.
    final extracted = (_environment['APPDIR'] ?? '').contains(
      'appimage_extracted_',
    );
    try {
      await Process.start(
        '/bin/sh',
        [
          '-c',
          script,
          'sh',
          '$_processId',
          path,
          if (extracted) '--appimage-extract-and-run',
        ],
        environment: hostEnvironment(_environment),
        includeParentEnvironment: false,
        mode: ProcessStartMode.detached,
      );
    } on ProcessException {
      return false;
    }
    await _quit();
    return true;
  }
}

void _scanEntry((SendPort, String, ZsyncControl) job) {
  final (port, path, control) = job;
  final match = matchSeed(path, control, progress: port.send);
  Isolate.exit(port, match);
}

/// SHA-1, SHA-256 and whether [signature] is a valid Ed25519 signature of the
/// file under [publicKey], in one pass over the file.
(String, String, bool) _hashFile(
  String path,
  String publicKey,
  String signature,
) {
  final sha1Sink = _DigestSink(), sha256Sink = _DigestSink();
  final sha1Input = sha1.startChunkedConversion(sha1Sink);
  final sha256Input = sha256.startChunkedConversion(sha256Sink);
  final signed = Ed25519Verifier.fromBase64(publicKey, signature);
  final file = File(path).openSync();
  try {
    final buffer = Uint8List(1 << 20);
    while (true) {
      final read = file.readIntoSync(buffer);
      if (read <= 0) break;
      final view = Uint8List.sublistView(buffer, 0, read);
      sha1Input.add(view);
      sha256Input.add(view);
      signed.add(view);
    }
  } finally {
    file.closeSync();
  }
  sha1Input.close();
  sha256Input.close();
  return (
    sha1Sink.value.toString(),
    sha256Sink.value.toString(),
    signed.close(),
  );
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
