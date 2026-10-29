import 'dart:io';

import 'package:raft_updater/raft_updater.dart';

import 'app_update.dart';

/// Test-only driver for `tool/appimage-update-smoke.py`: with
/// `RAFT_UPDATE_SMOKE=1` the app checks the (fake) release feed, runs the
/// AppImage delta update exactly as the Updates card's "Update now" does and,
/// with `RAFT_UPDATE_SMOKE_RESTART=1`, restarts into the new file. It prints
/// `RAFT_UPDATE_SMOKE ...` lines the harness reads: appended to the file named
/// by `RAFT_UPDATE_SMOKE_LOG` (the restarted app has no stdout), else printed.
///
/// It only runs when [origin] (the `RAFT_UPDATE_ORIGIN` test override, which
/// official release builds ignore) is set, so an official build can never
/// start it, whatever its environment holds.
Future<void> runAppImageUpdateSmoke(
  AppUpdateService service,
  AppUpdater updater, {
  required Uri? origin,
  Map<String, String>? environment,
  void Function(String line)? write,
}) async {
  final env = environment ?? Platform.environment;
  if (origin == null || env['RAFT_UPDATE_SMOKE'] != '1') return;
  final logPath = env['RAFT_UPDATE_SMOKE_LOG'];
  final out =
      write ??
      (logPath == null || logPath.isEmpty
          ? (String line) => stdout.writeln(line)
          : (String line) => File(
              logPath,
            ).writeAsStringSync('$line\n', mode: FileMode.append, flush: true));
  void say(String message) => out('RAFT_UPDATE_SMOKE $message');
  say(
    'running build=${service.currentBuild} version=${service.currentVersion} '
    'pid=$pid appimage=${env['APPIMAGE'] ?? ''}',
  );
  await service.checkNow();
  final release = service.available;
  if (release == null) {
    say('uptodate build=${service.currentBuild}');
    return;
  }
  final appImage = updater.appImage;
  if (appImage == null) {
    say('unavailable ${updater.unavailableReason}');
    return;
  }
  say('available build=${release.buildNumber} tag=${release.releaseTag}');
  await appImage.install(
    AppImageRelease(
      tag: release.releaseTag,
      artifact: release.artifact,
      sha256: release.sha256,
      bytes: release.bytes,
      edSignature: release.edSignature,
    ),
  );
  final status = appImage.status.value;
  if (status.phase != AppImageUpdatePhase.ready) {
    say('failed ${status.failure}');
    return;
  }
  final report = appImage.lastReport;
  say(
    'ready downloaded=${report?.downloadedBytes} reused=${report?.reusedBytes} '
    'target=${report?.targetBytes} control=${report?.controlBytes} '
    'requests=${report?.requests} scanMs=${report?.scan.inMilliseconds} '
    'downloadMs=${report?.download.inMilliseconds} '
    'verifyMs=${report?.verify.inMilliseconds} totalMs=${report?.total.inMilliseconds}',
  );
  if (env['RAFT_UPDATE_SMOKE_RESTART'] == '1') {
    say('restarting ${await appImage.restart()}');
  }
}
