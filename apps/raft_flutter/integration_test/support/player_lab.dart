// Helpers for `player_interactions_test.dart`: the range server's counters and
// the mailbox to the host runner (`tool/player-interactions`), which performs
// what only the host can (adb key events and swipes, screen recordings, the
// system save dialog).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

/// Set when a scenario is over (passed, failed or timed out). A failure that
/// surfaces as an uncaught async error (an image that answers 404, say) ends
/// the test at once, but its body keeps running as a zombie: still polling in
/// [until], still pumping frames, and a pump that overlaps the next scenario's
/// is "Guarded function conflict". Every helper below checks the token of the
/// scenario it runs in (a zone value, so it follows the body through every
/// `await`) and, once cancelled, parks the zombie for good instead of letting
/// it touch the app, the server or the host runner of the next scenario.
class ScenarioToken {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

const _tokenKey = #playerLabScenarioToken;

/// Runs [body] as the scenario [token] and cancels the token when the test
/// ends, however it ends. Use inside a `testWidgets` body.
Future<T> runAsScenario<T>(ScenarioToken token, Future<T> Function() body) {
  addTearDown(() async {
    token.cancel();
    // The body may sit in a guarded call (a pump) right now. The framework
    // pumps at the start of the next test body, before any code of ours runs
    // there, so wait here, before that test starts, until the call is over.
    try {
      await waitForBindingIdle();
    } on FlutterError {
      // Stuck for good: the next scenario reports it.
    }
  });
  return runZoned(body, zoneValues: {_tokenKey: token});
}

bool get _cancelled => (Zone.current[_tokenKey] as ScenarioToken?)?.cancelled ?? false;

/// A future that never completes: where a zombie body stops.
Future<T> _park<T>() => Completer<T>().future;

/// Waits (real time) until no guarded `WidgetTester` call is in flight, i.e.
/// the previous scenario's zombie, if any, has let go of the binding.
Future<void> waitForBindingIdle({Duration timeout = const Duration(seconds: 30)}) async {
  final watch = Stopwatch()..start();
  while (true) {
    try {
      TestAsyncUtils.verifyAllScopesClosed();
      return;
    } on FlutterError {
      if (watch.elapsed > timeout) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}

class PlayerLab {
  PlayerLab(this.base, {required this.hostDriven});
  final String base;

  /// A host runner is polling the mailbox (`--dart-define=VP_HOST=true`).
  final bool hostDriven;

  Future<Map<String, dynamic>> _get(String path) async {
    if (_cancelled) return _park();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await (await client.getUrl(Uri.parse('$base$path'))).close();
      final json = jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
      if (!_cancelled) return json;
    } finally {
      client.close(force: true);
    }
    return _park();
  }

  /// A file that is not in the range server's media directory would make the
  /// scenario fail on a 404 somewhere deep in the app (an image loader, the
  /// player); name it up front instead. A HEAD is counted by the server, so
  /// ask before [reset].
  Future<void> requireFiles(Iterable<String> files) async {
    final missing = <String>[];
    for (final file in files.toSet()) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final response = await (await client.headUrl(Uri.parse('$base/$file'))).close();
        await response.drain<void>();
        if (response.statusCode != 200) missing.add('$file (HTTP ${response.statusCode})');
      } finally {
        client.close(force: true);
      }
      if (_cancelled) return _park<void>();
    }
    if (missing.isNotEmpty) {
      throw TestFailure(
        'The range server has no ${missing.join(', ')}: the --media directory is incomplete for this scenario.',
      );
    }
  }

  /// Brings the world to a known state before a scenario: the host runner
  /// stops a recording left running, closes a system dialog and brings the app
  /// to the front (a scenario that failed while the app was in the background
  /// leaves it there); the server forgets counters, failures and commands.
  Future<void> cleanSlate() async {
    if (hostDriven) {
      for (var attempt = 0; attempt < 5; attempt++) {
        // The mailbox has one slot: when the runner is still busy with a command
        // of a scenario that is over, ours is answered with that result.
        final result = await hostQuiet('clean', seconds: 40);
        if (result != null && result.startsWith('clean')) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    await reset();
    await _get('/__cmd?ack=');
  }

  Future<void> reset() => _get('/__reset');

  Future<void> failNext(String file, {int status = 403, int count = 1}) =>
      _get('/__fail?file=$file&status=$status&count=$count');

  Future<ServerStats> stats() async => ServerStats(await _get('/__stats'));

  /// Asks the host runner to do [command] and waits for it. Returns the
  /// runner's result text, or null when no runner is attached.
  Future<String?> host(WidgetTester tester, String command, {int seconds = 30}) async {
    if (!hostDriven) return null;
    await _get('/__cmd?set=${Uri.encodeQueryComponent(command)}');
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      if (_cancelled) return _park();
      await tester.pump(const Duration(milliseconds: 50));
      final state = await _get('/__cmd?poll');
      if (state['done'] == true) return state['result'] as String? ?? '';
    }
    throw TestFailure('The host runner did not answer "$command" in $seconds s.');
  }

  /// Like [host] but polls with real time instead of frames: for a command
  /// that takes the app out of the foreground, where no frame is produced.
  Future<String?> hostQuiet(String command, {int seconds = 60}) async {
    if (!hostDriven) return null;
    await _get('/__cmd?set=${Uri.encodeQueryComponent(command)}');
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      if (_cancelled) return _park();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final state = await _get('/__cmd?poll');
      if (state['done'] == true) return state['result'] as String? ?? '';
    }
    throw TestFailure('The host runner did not answer "$command" in $seconds s.');
  }
}

/// What the server really sent.
class ServerStats {
  ServerStats(this.json);
  final Map<String, dynamic> json;

  List<Map<String, dynamic>> get log => [
    for (final entry in json['log'] as List) Map<String, dynamic>.from(entry as Map),
  ];

  Map<String, dynamic> _file(String file) =>
      Map<String, dynamic>.from(((json['files'] as Map)[file] ?? const {'requests': 0, 'bytes': 0, 'size': 0}) as Map);

  int bytes(String file) => _file(file)['bytes'] as int;
  int requests(String file) => _file(file)['requests'] as int;

  /// Requests for [file] that asked for a byte range (a streaming player
  /// does; `Dio.download` does not).
  int ranged(String file) => log.where((e) => e['file'] == file && e['range'] != null).length;

  /// Requests for [file] made by the app's Dart HTTP client: a download
  /// (`Dio`/`HttpClient` send a `Dart/...` user agent), as opposed to the
  /// native player (ExoPlayer, AVPlayer) reading the stream itself.
  int dart(String file) =>
      log.where((e) => e['file'] == file && '${e['ua']}'.startsWith('Dart')).length;

  /// Requests for [file] made by anything but the Dart client.
  int player(String file) =>
      log.where((e) => e['file'] == file && !'${e['ua']}'.startsWith('Dart')).length;
}

/// Pumps real time until [done] holds; the failure names [what]. Stops (parks)
/// when the scenario it runs in is over, see [ScenarioToken].
Future<Duration> until(
  WidgetTester tester,
  bool Function() done,
  String what, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final watch = Stopwatch()..start();
  while (!done()) {
    if (_cancelled) return _park();
    if (watch.elapsed > timeout) throw TestFailure('Timed out after ${timeout.inSeconds} s waiting for: $what');
    await tester.pump(const Duration(milliseconds: 50));
  }
  return watch.elapsed;
}

/// A tap at the centre of [finder] as a finger would do it (through the
/// gesture arena, hit-testing what is really on top there).
Future<void> tapCentre(WidgetTester tester, Finder finder) async {
  final at = tester.getCenter(finder);
  await tester.tapAt(at);
  await tester.pump();
}

Offset centreOf(WidgetTester tester, Finder finder) => tester.getCenter(finder);
