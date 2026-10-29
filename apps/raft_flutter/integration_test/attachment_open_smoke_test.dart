// Attachment open smoke: opens every kind of attachment the way a person does (tap the tile, the card, the play
// button) in the production RaftApp, from every entry point, against a fixture server that behaves like Raft's
// storage and API (tool/attachment-open-smoke/aos_server.py), and reports per case: did it open, how long to the first
// content, which requests it made. Run it with `tool/attachment-open-smoke/run`; see docs/attachment-open-smoke.md.
//
// Every case prints one `AOS-RESULT {json}` line and fails its test when the attachment did not open.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_flutter/features/attachment_html_preview.dart';
import 'package:raft_flutter/platform/attachment_html_webview.dart';
import 'package:raft_ui/raft_ui.dart';

import 'perf_lab/fixtures.dart' show LabChannel, labRow;
import 'support/cache_install.dart';
import 'support/open_smoke.dart';

const _base = String.fromEnvironment('AOS_BASE', defaultValue: 'http://127.0.0.1:8793');
const _hostDriven = bool.fromEnvironment('AOS_HOST', defaultValue: true);

class Outcome {
  Outcome(this.ok, this.detail, {this.ms, this.second, this.extra = const {}});
  final bool ok;
  final String detail;

  /// Milliseconds from the tap to the first content.
  final int? ms;

  /// The same open again after closing (cache warm), when measured.
  final int? second;
  final Map<String, Object?> extra;
}

late List<SmokeCase> manifest;
late Directory saveDir;

void record(String entry, SmokeCase c, Outcome o, Map<String, Object?> requests) {
  final line = jsonEncode({
    'entry': entry,
    'case': c.id,
    'kind': c.kind,
    'ok': o.ok,
    'detail': o.detail,
    'ms': o.ms,
    'reopenMs': o.second,
    'platform': Platform.operatingSystem,
    ...o.extra,
    'requests': requests,
  });
  debugPrint('AOS-RESULT $line');
  unawaited(postResult(_base, line));
}

/// A screenshot of what a person would see, taken by the host runner (adb screencap / the Xvfb display).
Future<void> hostShot(WidgetTester tester, String name) async {
  if (!_hostDriven) return;
  try {
    await tester.runAsync(() async {
      await serverGet(_base, '/__cmd?set=${Uri.encodeQueryComponent('shot:$name')}');
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if ((await serverGet(_base, '/__cmd'))['done'] == true) return;
      }
    });
  } on Object {
    // Evidence only.
  }
}

/// What the fixture server saw since the last reset, compressed to one string per request.
Future<Map<String, Object?>> serverRequests(WidgetTester tester, SmokeFixture fixture) async {
  final stats = await tester.runAsync(() => serverGet(_base, '/__stats'));
  final log = [
    for (final e in (stats!['log'] as List).cast<Map>())
      '${e['method']} ${e['path']} ${e['status']}'
          '${e['range'] != null ? ' range=${e['range']}' : ''}'
          ' ${'${e['ua']}'.startsWith('Dart') ? 'dart' : 'native'}'
          '${e['auth'] == true ? ' AUTH' : ''} ${e['bytes']}B',
  ];
  return {
    'storage': log,
    'api': {
      for (final e in fixture.api.hits.entries)
        if (e.key.contains('/attachments')) e.key: e.value,
    },
    'misses': fixture.api.misses,
  };
}

/// The attachment's widget: a message row's `attachment-<id>` or a forwarded bundle's `forwarded-attachment-<msg>-<id>`.
Finder attachment(SmokeCase c) => find.byWidgetPredicate((w) {
  final key = w.key;
  if (key is! ValueKey<String>) return false;
  return key.value == 'attachment-${c.attachmentId}' ||
      (key.value.startsWith('forwarded-attachment-') && key.value.endsWith('-${c.attachmentId}'));
});

/// The visible text of the screen, for the failure report.
String screenText(WidgetTester tester) => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data != null) (e.widget as Text).data!,
].where((t) => t.trim().isNotEmpty).take(40).join(' | ');

Future<void> tapCentre(WidgetTester tester, Finder finder) async {
  await tester.tapAt(tester.getCenter(finder.first));
  await tester.pump();
}

const failureGrace = Duration(seconds: 6);

Future<int> waitFor(
  WidgetTester tester,
  bool Function() done,
  String what, {
  Duration timeout = const Duration(seconds: 25),
  bool Function()? failed,
  String Function()? why,
  Future<void> Function()? poll,
}) async {
  final watch = Stopwatch()..start();
  // A failure state that is left again (the player signs the URL again after its first 403) is not a failure: it must
  // hold for [failureGrace].
  DateTime? failingSince;
  while (true) {
    if (poll != null) await poll();
    if (done()) return watch.elapsedMilliseconds;
    if (failed != null && failed()) {
      failingSince ??= DateTime.now();
      if (DateTime.now().difference(failingSince) > failureGrace) {
        throw TestFailure('$what: failed after ${watch.elapsedMilliseconds} ms: ${why?.call() ?? screenText(tester)}');
      }
    } else {
      failingSince = null;
    }
    if (watch.elapsed > timeout) {
      throw TestFailure('$what: no content after ${timeout.inSeconds} s: ${why?.call() ?? screenText(tester)}');
    }
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> closeTop(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

// ---- platform mocks: the save picker and the OS handoff -----------------------------------------------------

class SavePicker extends FileSelectorPlatform {
  SavePicker(this.dir);
  final Directory dir;
  final picked = <String>[];
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    final path = '${dir.path}/${options.suggestedName ?? 'attachment'}';
    picked.add(path);
    return FileSaveLocation(path);
  }
}

late SavePicker savePicker;
final opened = <String>[];

void installMocks(WidgetTester tester) {
  FileSelectorPlatform.instance = savePicker = SavePicker(saveDir);
  final messenger = tester.binding.defaultBinaryMessenger;
  // Android: the Storage Access Framework picker and writer are in Kotlin; the Dart side is what is under test.
  messenger.setMockMethodCallHandler(const MethodChannel('app.raft/attachment-files'), (call) async {
    switch (call.method) {
      case 'chooseSave':
        final path = '${saveDir.path}/${(call.arguments as Map)['filename']}';
        savePicker.picked.add(path);
        return path;
      case 'writeSaved':
        final args = call.arguments as Map;
        await File(args['path'] as String).copy(args['uri'] as String);
        return null;
      case 'openSaved':
        opened.add('${(call.arguments as Map)['uri']}');
        return null;
    }
    return null;
  });
  // Linux: url_launcher hands the URL to the desktop (xdg-open); record it instead of starting an application.
  const codec = StandardMessageCodec();
  messenger.setMockMessageHandler('dev.flutter.pigeon.url_launcher_linux.UrlLauncherApi.canLaunchUrl', (message) async {
    return codec.encodeMessage(<Object?>[true]);
  });
  messenger.setMockMessageHandler('dev.flutter.pigeon.url_launcher_linux.UrlLauncherApi.launchUrl', (message) async {
    opened.add('${(codec.decodeMessage(message) as List).first}');
    return codec.encodeMessage(<Object?>[null]);
  });
}

// ---- per-kind open procedures -------------------------------------------------------------------------------

bool shown(Type type) => find.byType(type).evaluate().isNotEmpty;
bool textShown(String text) => find.textContaining(text).evaluate().isNotEmpty;

/// Taps the tile of an image attachment and waits for the lightbox to show the full image.
Future<Outcome> openImage(WidgetTester tester, SmokeCase c, {required Future<void> Function() tap}) async {
  await tap();
  final ms = await waitFor(
    tester,
    () => find.byKey(const ValueKey('lightbox-stage')).evaluate().isNotEmpty,
    'the lightbox image',
    failed: () => shown(RaftLightboxFailure) || textShown('Failed to load image'),
  );
  final first = ms;
  await closeTop(tester);
  // The reopen is served from the cache: no storage request, content at once.
  await tap();
  final reopen = await waitFor(
    tester,
    () => find.byKey(const ValueKey('lightbox-stage')).evaluate().isNotEmpty,
    'the lightbox image (reopen)',
    failed: () => shown(RaftLightboxFailure) || textShown('Failed to load image'),
  );
  await closeTop(tester);
  return Outcome(true, 'full image shown', ms: first, second: reopen);
}

Future<Outcome> openPdf(WidgetTester tester, SmokeCase c, {required Future<void> Function() tap}) async {
  await tap();
  final ms = await waitFor(
    tester,
    () => textShown('1 / 3'),
    'the first PDF page',
    failed: () => shown(RaftLoadError),
    timeout: const Duration(seconds: 60),
  );
  await closeTop(tester);
  await tap();
  final reopen = await waitFor(
    tester,
    () => textShown('1 / 3'),
    'the first PDF page (reopen)',
    failed: () => shown(RaftLoadError),
  );
  await closeTop(tester);
  return Outcome(true, 'page 1 of 3 rendered', ms: ms, second: reopen);
}

Future<Outcome> openDocument(WidgetTester tester, SmokeCase c, {required Future<void> Function() tap}) async {
  // A document the app cannot draw shows the reason and the system-app action; every other one shows its content.
  bool ready() {
    if (c.panel) return shown(RaftPreviewUnavailable) && find.byKey(const ValueKey('preview-open-system')).evaluate().isNotEmpty;
    final text = c.shows;
    return shown(RaftDocumentPreview) &&
        (text == null || find.text(text).evaluate().isNotEmpty) &&
        (!c.notice || shown(RaftPreviewNotice));
  }

  bool failed() => shown(RaftLoadError) || (!c.panel && shown(RaftPreviewUnavailable));
  final what = c.panel ? 'the reason with Open with system app' : 'the document preview';
  await tap();
  final ms = await waitFor(tester, ready, what, failed: failed);
  await closeTop(tester);
  await tap();
  final reopen = await waitFor(tester, ready, '$what (reopen)', failed: failed);
  await closeTop(tester);
  return Outcome(true, c.panel ? 'reason and system-app action shown' : 'document preview shown', ms: ms, second: reopen);
}

bool htmlReady() => shown(RaftHtmlPreview) || (shown(AttachmentHtmlWebView) && !shown(RaftPreviewTransferStage));

Future<Outcome> openHtml(WidgetTester tester, SmokeCase c, {required Future<void> Function() tap}) async {
  await tap();
  final ms = await waitFor(
    tester,
    htmlReady,
    'the HTML preview',
    failed: () => shown(HtmlAttachmentPreviewDialog) && find.text('Retry Preview').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 40),
  );
  final webView = shown(AttachmentHtmlWebView);
  await closeTop(tester);
  // Close and reopen straight away: the native WebView of the first open is destroyed after a short delay and must not
  // take the second one with it.
  await tester.pump(const Duration(milliseconds: 100));
  await tap();
  final reopen = await waitFor(
    tester,
    htmlReady,
    'the HTML preview (reopen)',
    failed: () => shown(HtmlAttachmentPreviewDialog) && find.text('Retry Preview').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 40),
  );
  // Let the first WebView's delayed destroy run while the second is on screen, then check it is still showing.
  await tester.pump(const Duration(seconds: 2));
  expect(htmlReady(), true, reason: 'the second HTML preview died after the first WebView was destroyed');
  await closeTop(tester);
  return Outcome(true, webView ? 'WebView page loaded' : 'static HTML shown', ms: ms, second: reopen);
}

Future<Outcome> playAudio(WidgetTester tester, SmokeCase c) async {
  final play = find.descendant(of: attachment(c), matching: find.byKey(const Key('audio-play-toggle')));
  await waitFor(tester, () => play.evaluate().isNotEmpty, 'the audio card');
  RaftInlineAudio card() => tester.widget<RaftInlineAudio>(find.descendant(of: attachment(c), matching: find.byType(RaftInlineAudio)));
  await tapCentre(tester, play);
  final ms = await waitFor(
    tester,
    () => card().playing && card().position > const Duration(milliseconds: 500),
    'audio position to advance',
    failed: () => card().state == RaftInlineMediaState.failed,
    why: () => 'state ${card().state} position ${card().position}',
  );
  await tapCentre(tester, play); // pause
  return Outcome(true, 'playing, position ${card().position.inMilliseconds} ms of ${card().duration.inMilliseconds} ms', ms: ms);
}

Future<Outcome> playVideo(WidgetTester tester, SmokeCase c, {bool viewer = true}) async {
  Finder inner(Key key) => find.descendant(of: attachment(c), matching: find.byKey(key));
  RaftInlineVideo card() => tester.widget<RaftInlineVideo>(find.descendant(of: attachment(c), matching: find.byType(RaftInlineVideo)));
  await waitFor(tester, () => inner(const Key('inline-video-surface')).evaluate().isNotEmpty && card().state != RaftInlineMediaState.loading, 'the video card',
      failed: () => card().state == RaftInlineMediaState.failed, why: () => 'card state ${card().state}');
  await tapCentre(tester, inner(const Key('inline-video-surface')));
  var retapped = false;
  final started = DateTime.now();
  final ms = await waitFor(
    tester,
    () => card().playing && card().position > const Duration(milliseconds: 700),
    poll: () async {
      // Nothing happened (a play tap that met a source being signed again is lost): a person taps again.
      if (!retapped && !card().playing && DateTime.now().difference(started) > const Duration(seconds: 8)) {
        retapped = true;
        await tester.tapAt(tester.getCenter(inner(const Key('inline-video-surface')).first));
      }
    },
    'video position to advance',
    failed: () => card().state == RaftInlineMediaState.failed,
    why: () => 'state ${card().state} playing ${card().playing} position ${card().position} of ${card().duration}',
    timeout: const Duration(seconds: 40),
  );
  int? viewerMs;
  var carried = true;
  if (viewer) {
    await tapCentre(tester, inner(const Key('inline-video-expand')));
    viewerMs = await waitFor(
      tester,
      () => shown(RaftVideoViewer) && tester.widget<RaftVideoViewer>(find.byType(RaftVideoViewer)).duration > Duration.zero,
      'the video viewer',
      failed: () => shown(RaftLoadError),
    );
    await tester.pump(const Duration(seconds: 1));
    final v = tester.widget<RaftVideoViewer>(find.byType(RaftVideoViewer));
    carried = v.position > Duration.zero;
    await closeTop(tester);
  }
  return Outcome(true, 'card playing, position ${card().position.inMilliseconds} ms${retapped ? ' (needed a second tap)' : ''}${carried ? '' : ' (the viewer did not carry the card position)'}', ms: ms, second: viewerMs);
}

/// Taps a card that only downloads: the save picker (mocked) opens, then the file is written and equals the source.
Future<Outcome> downloadOnly(WidgetTester tester, SmokeCase c, {required Future<void> Function() tap}) async {
  final before = savePicker.picked.length;
  await tap();
  final ms = await waitFor(
    tester,
    () => savePicker.picked.length > before && File(savePicker.picked.last).existsSync() && File(savePicker.picked.last).lengthSync() == c.size,
    'the downloaded file',
    timeout: const Duration(seconds: 90),
    failed: () => textShown('Download failed'),
  );
  return Outcome(true, 'saved ${c.size} bytes', ms: ms);
}

// ---- entry points -------------------------------------------------------------------------------------------

/// What an entry point puts on screen for one case and how a person taps the attachment there.
class Launch {
  Launch(this.fixture, this.target);
  final SmokeFixture fixture;

  /// The tappable attachment (or its row) on screen.
  final Finder Function() target;
}

typedef Opener = Future<Outcome> Function(WidgetTester tester, SmokeCase c, Future<void> Function() tap);

Opener opener(SmokeCase c) => switch (c.kind) {
  'image' || 'svg' => (t, c, tap) => openImage(t, c, tap: tap),
  'pdf' => (t, c, tap) => openPdf(t, c, tap: tap),
  'document' => (t, c, tap) => openDocument(t, c, tap: tap),
  'html' => (t, c, tap) => openHtml(t, c, tap: tap),
  'audio' => (t, c, tap) async => playAudio(t, c),
  'video' => (t, c, tap) async => playVideo(t, c),
  _ => (t, c, tap) => downloadOnly(t, c, tap: tap),
};

Future<Launch> pump(WidgetTester tester, SmokeFixture fixture, Finder Function() target, String what) async {
  await tester.pumpWidget(fixture.app);
  if (Platform.isAndroid && fixture.startsAtList) {
    // On the phone layout a deep link opens the channel empty (see video_parity_main.dart): open it from the list.
    await waitFor(tester, () => find.text('lab-oa').evaluate().isNotEmpty, 'the channel list');
    await tester.tap(find.text('lab-oa').first);
  }
  await waitFor(tester, () => target().evaluate().isNotEmpty, what, timeout: const Duration(seconds: 40));
  await tester.pump(const Duration(milliseconds: 300));
  return Launch(fixture, target);
}

Future<Launch> launchList(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [smokeRow(_base, 'oa', 0, 'Open ${c.id}', [c])],
    location: '/s/lab/channel/oa',
    mobile: mobile,
    listStart: mobile,
  );
  return pump(tester, fixture, () => attachment(c), 'the channel with ${c.id}');
}

/// A search result: the search page lists the message, tapping it jumps to it in a longer history.
Future<Launch> launchSearch(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final rows = [
    for (var i = 0; i < 30; i++)
      if (i == 15) smokeRow(_base, 'oa', i, 'Open ${c.id}', [c]) else labRow('oa', 'plain', i),
  ];
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: rows,
    location: Uri(path: '/s/lab/search', queryParameters: {'q': 'Open ${c.id}'}).toString(),
    mobile: mobile,
    extra: (api) {
      api.routes['GET /messages/context/oa-15'] = (_) => {
        'messages': rows,
        'targetMessageId': 'oa-15',
        'hasOlder': false,
        'hasNewer': false,
      };
      api.routes['GET /messages/search'] = (_) => {
        'hasMore': false,
        'results': [
          {
            'id': 'oa-15',
            'channelId': 'oa',
            'threadId': null,
            'parentMessageId': null,
            'parentMessageContent': null,
            'parentChannelId': 'oa',
            'parentChannelName': 'lab-oa',
            'parentChannelType': 'channel',
            'parentChannelArchivedAt': null,
            'senderId': 'alice',
            'senderType': 'user',
            'senderName': 'Alice Zhang',
            'channelName': 'lab-oa',
            'channelType': 'channel',
            'channelArchivedAt': null,
            'content': 'Open ${c.id}',
            'snippet': 'Open ${c.id}',
            'createdAt': DateTime.utc(2026, 10, 1, 0, 45).toIso8601String(),
          },
        ],
      };
    },
  );
  await tester.pumpWidget(fixture.app);
  final hit = find.textContaining('Open ${c.id}');
  await waitFor(tester, () => find.descendant(of: find.byType(Scrollable), matching: hit).evaluate().isNotEmpty, 'the search result');
  await tester.pump(const Duration(milliseconds: 500));
  // The field may hold the same words: tap the result row, which is the last match on screen.
  await tester.tapAt(tester.getCenter(hit.last));
  await waitFor(tester, () => attachment(c).evaluate().isNotEmpty, 'the searched message with ${c.id}', timeout: const Duration(seconds: 40));
  await tester.pump(const Duration(milliseconds: 500));
  return Launch(fixture, () => attachment(c));
}

/// A reply in the thread panel.
Future<Launch> launchThread(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  const thread = 'th-oa-0';
  final parent = labRow('oa', 'plain', 0)..['content'] = 'Thread parent';
  final reply = labRow(thread, 'plain', 0, id: 'oa-reply-0')..['content'] = 'Open ${c.id}'..['attachments'] = [c.metadata(_base, thread)];
  final replyChannel = LabChannel(thread, const []);
  replyChannel.rows.add(reply);
  final summary = {
    'threadChannelId': thread,
    'replyCount': 1,
    'latestReplies': [
      {
        'messageId': 'oa-reply-0',
        'senderType': 'user',
        'senderId': 'alice',
        'senderName': 'Alice Zhang',
        'preview': 'Open ${c.id}',
        'createdAt': DateTime.utc(2026, 10, 1, 9, 5).toIso8601String(),
      },
    ],
  };
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [parent],
    location: '/s/lab/channel/oa',
    mobile: mobile,
    listStart: mobile,
    extra: (api) {
      replyChannel.install(api);
      api.routes['GET /channels/$thread'] = (_) => {'id': thread, 'name': 'thread', 'type': 'thread', 'joined': true, 'parentChannelId': 'oa'};
      api.routes['GET /channels/oa/threads/oa-0'] = (_) => summary;
      api.routes['GET /messages/channel/oa'] = (_) => {
        'messages': [parent],
        'hasMore': false,
        'threadSummariesByParentMessageId': {'oa-0': summary},
      };
      api.routes['GET /messages/context/oa-0'] = (_) => {'messages': [parent], 'hasOlder': false, 'hasNewer': false};
    },
  );
  // Open the thread the way a person does: tap the reply count under the parent message.
  final label = find.textContaining('repl');
  final launch = await pump(tester, fixture, () => label, 'the thread label under the parent');
  await tapCentre(tester, label);
  await waitFor(tester, () => attachment(c).evaluate().isNotEmpty, 'the thread reply with ${c.id}', timeout: const Duration(seconds: 40));
  await tester.pump(const Duration(milliseconds: 300));
  return Launch(launch.fixture, () => attachment(c));
}

/// A forwarded message: the bundle carries a projected snapshot of the attachment (no channel id, no thumbnail).
Future<Launch> launchForward(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final row = labRow('oa', 'plain', 0)
    ..['content'] = ''
    ..['actionMetadata'] = {
      'kind': 'forwarded-bundle',
      'version': 1,
      'forwardedItems': [
        {
          'index': 0,
          'provenanceState': 'available',
          'contentSnapshot': 'Forwarded ${c.id}',
          'sourceCreatedAt': DateTime.utc(2026, 9, 30, 12).toIso8601String(),
          'sourceMessageSeq': 3,
          'sourceAuthorSnapshot': {'type': 'user', 'name': 'Bob Li'},
          'sourceTargetSnapshot': {'type': 'channel', 'label': 'other', 'labelVisibility': 'public'},
          'attachmentPolicy': 'projected',
          'attachmentSnapshots': [
            for (final a in [c.metadata(_base, 'other', channelId: false)])
              {
                for (final key in ['id', 'filename', 'mimeType', 'sizeBytes', 'width', 'height'])
                  if (a[key] != null) key: a[key],
              },
          ],
        },
      ],
    };
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [row],
    location: '/s/lab/channel/oa',
    mobile: mobile,
    listStart: mobile,
  );
  return pump(tester, fixture, () => find.byKey(ValueKey('forwarded-attachment-oa-0-${c.attachmentId}')), 'the forwarded message with ${c.id}');
}

/// A joint channel: the message comes from the peer server.
Future<Launch> launchJoint(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final row = smokeRow(_base, 'oa', 0, 'Open ${c.id}', [c])
    ..['sourceServerId'] = 's2'
    ..['senderName'] = 'Peer Person';
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [row],
    location: '/s/lab/channel/oa',
    mobile: mobile,
    listStart: mobile,
    channelRecord: {'id': 'oa', 'name': 'lab-oa', 'joined': true, 'type': 'joint', 'jointPeers': <dynamic>[]},
  );
  return pump(tester, fixture, () => attachment(c), 'the joint channel message with ${c.id}');
}

Future<Launch> launchTwoImages(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final other = manifest.firstWhere((m) => m.id == 'img-jpg');
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [smokeRow(_base, 'oa', 0, 'Two images', [c, other])],
    location: '/s/lab/channel/oa',
    mobile: mobile,
    listStart: mobile,
  );
  return pump(tester, fixture, () => attachment(c), 'the message with two images');
}

/// The Files tab of the channel: a row per attachment.
Future<Launch> launchFiles(WidgetTester tester, SmokeCase c, {bool mobile = true}) async {
  final fixture = await buildSmokeFixture(
    base: _base,
    all: manifest,
    channelId: 'oa',
    rows: [smokeRow(_base, 'oa', 0, 'Open ${c.id}', [c])],
    location: '/s/lab/channel/oa?chatTab=files',
    mobile: mobile,
    extra: (api) {
      api.routes['GET /channels/oa/files'] = (_) => {
        'files': [
          {
            ...c.metadata(_base, 'oa'),
            'messageId': 'oa-0',
            'createdAt': DateTime.utc(2026, 10, 1, 9).toIso8601String(),
            'source': {'type': 'channel', 'channelId': 'oa'},
          },
        ],
        'nextCursor': null,
      };
    },
  );
  return pump(tester, fixture, () => find.text(c.filename), 'the Files tab with ${c.filename}');
}

/// Files-tab specific verification: images open in the Files lightbox, previews in the preview dialogs, and what the
/// app cannot preview is handed to the OS as a URL.
Future<Outcome> openFromFiles(WidgetTester tester, SmokeCase c, Launch launch) async {
  Future<void> tap() => tapCentre(tester, find.text(c.filename));
  switch (c.kind) {
    case 'image' || 'svg':
      await tap();
      final ms = await waitFor(
        tester,
        () => shown(RaftLightboxStageTap),
        'the Files lightbox image',
        failed: () => textShown('Preview unavailable'),
      );
      await closeTop(tester);
      return Outcome(true, 'Files lightbox image shown', ms: ms);
    case 'pdf':
      return openPdf(tester, c, tap: tap);
    case 'document':
      return openDocument(tester, c, tap: tap);
    case 'html':
      return openHtml(tester, c, tap: tap);
    case 'audio':
      await tap();
      final ms = await waitFor(
        tester,
        () => shown(RaftAudioPreview) && tester.widget<RaftAudioPreview>(find.byType(RaftAudioPreview)).duration > Duration.zero,
        'the audio viewer',
        failed: () => shown(RaftLoadError),
      );
      await closeTop(tester);
      return Outcome(true, 'audio viewer ready', ms: ms);
    case 'video':
      await tap();
      final ms = await waitFor(
        tester,
        () => shown(RaftVideoViewer) && tester.widget<RaftVideoViewer>(find.byType(RaftVideoViewer)).duration > Duration.zero,
        'the video viewer',
        failed: () => shown(RaftLoadError),
        timeout: const Duration(seconds: 40),
      );
      await closeTop(tester);
      return Outcome(true, 'video viewer ready', ms: ms);
    default:
      // Not previewable: the row hands a signed URL to the operating system.
      opened.clear();
      await tap();
      if (Platform.isAndroid) {
        // The real url_launcher: the app the OS picks (a browser, the download manager) asks the server for the file.
        final ms = await waitFor(
          tester,
          () => lastNativeRequests.isNotEmpty,
          'the OS app to request the file',
          timeout: const Duration(seconds: 20),
          poll: () async {
            final stats = await tester.runAsync(() => serverGet(_base, '/__stats'));
            lastNativeRequests = [
              for (final e in (stats!['log'] as List).cast<Map>())
                if (!'${e['ua']}'.startsWith('Dart') && '${e['path']}'.contains(c.id) || '${e['path']}'.contains(c.file) && !'${e['ua']}'.startsWith('Dart')) e,
            ];
          },
        );
        final ok = lastNativeRequests.any((e) => e['status'] == 200 || e['status'] == 206);
        return Outcome(ok, ok ? 'an OS app fetched the file from the handed URL' : 'the OS app got ${lastNativeRequests.map((e) => e['status'])}', ms: ms);
      }
      final ms = await waitFor(tester, () => opened.isNotEmpty, 'the OS handoff', timeout: const Duration(seconds: 10));
      final url = Uri.parse(opened.last);
      final probe = await tester.runAsync(() async {
        final client = HttpClient();
        try {
          final response = await (await client.getUrl(url)).close();
          final bytes = await response.fold<int>(0, (a, b) => a + b.length);
          return '${response.statusCode}:$bytes';
        } finally {
          client.close(force: true);
        }
      });
      final ok = probe == '200:${c.size}';
      return Outcome(ok, ok ? 'URL handed to the OS and it serves the file' : 'URL handed to the OS answers $probe', ms: ms, extra: {'url': '${url.replace(query: '')}'});
  }
}

List<Map> lastNativeRequests = [];

Future<Outcome> openFromViewerDownload(WidgetTester tester, SmokeCase c, Launch launch) async {
  // A video card plays on a tap: its viewer opens from the eye button.
  Future<void> tap() => c.kind == 'video'
      ? tapCentre(tester, find.descendant(of: launch.target(), matching: find.byKey(const Key('inline-video-expand'))))
      : tapCentre(tester, launch.target());
  if (!const {'image', 'svg', 'pdf', 'document', 'video'}.contains(c.kind)) {
    return Outcome(true, 'no viewer for this kind');
  }
  await tap();
  final key = c.kind == 'image' || c.kind == 'svg' ? const ValueKey('attachment-download') : const ValueKey('attachment-preview-download');
  await waitFor(tester, () => find.byKey(key).evaluate().isNotEmpty, 'the viewer download button');
  // Let the viewer settle on its content first (the user presses Download after looking).
  await tester.pump(const Duration(seconds: 2));
  final before = savePicker.picked.length;
  await tapCentre(tester, find.byKey(key));
  final ms = await waitFor(
    tester,
    () => savePicker.picked.length > before && File(savePicker.picked.last).existsSync() && File(savePicker.picked.last).lengthSync() == c.size,
    'the viewer download',
    timeout: const Duration(seconds: 90),
    failed: () => textShown('Download failed'),
  );
  await closeTop(tester);
  return Outcome(true, 'saved ${c.size} bytes from the viewer', ms: ms);
}

/// Rows covered by a viewer are released after a few seconds; closing the viewer brings their previews back.
Future<Outcome> hiddenRowRelease(WidgetTester tester, SmokeCase c, Launch launch) async {
  final other = manifest.firstWhere((m) => m.id == 'img-jpg');
  Finder tile(SmokeCase m) => find.descendant(of: attachment(m), matching: find.byType(Image));
  await waitFor(tester, () => tile(c).evaluate().isNotEmpty && tile(other).evaluate().isNotEmpty, 'both tiles painted');
  await tapCentre(tester, attachment(c));
  await waitFor(tester, () => find.byKey(const ValueKey('lightbox-stage')).evaluate().isNotEmpty, 'the lightbox image');
  // The other tile is covered for longer than the release delay.
  await tester.pump(const Duration(seconds: 7));
  await closeTop(tester);
  final back = await waitFor(
    tester,
    () => tile(c).evaluate().isNotEmpty && tile(other).evaluate().isNotEmpty,
    'the covered tile to paint again',
    timeout: const Duration(seconds: 15),
  );
  await tapCentre(tester, attachment(other));
  final reopen = await waitFor(tester, () => find.byKey(const ValueKey('lightbox-stage')).evaluate().isNotEmpty, 'the released tile opens');
  await closeTop(tester);
  return Outcome(true, 'released tile painted again and opened', ms: back, second: reopen);
}

// ---- the run ------------------------------------------------------------------------------------------------

const _core = {'img-png', 'img-thumb', 'svg-thumb', 'pdf', 'doc-md', 'html', 'aud-m4a', 'vid-h264', 'zip'};

/// One test runs every case: `flutter drive` starts executing as soon as `main` yields, so the case list (read from the
/// server) cannot be awaited before declaring tests. A failing case is reported and the run goes on; the test fails at
/// the end when any case failed.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('attachment open smoke', timeout: const Timeout(Duration(hours: 3)), (tester) async {
    await prepareBindings();
    await installAttachmentCache();
    manifest = await tester.runAsync(() => fetchManifest(_base)) ?? [];
    final config = await tester.runAsync(() => serverGet(_base, '/__config')) ?? {};
    final onlyText = '${config['only'] ?? ''}';
    final selected = onlyText.isEmpty ? null : onlyText.split(',').map((e) => e.trim()).toSet();
    final entries = '${config['entries'] ?? 'list'}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    saveDir = await Directory.systemTemp.createTemp('aos-saved-');
    installMocks(tester);
    final mobile = Platform.isAndroid;
    final failures = <String>[];

    Future<void> scenario(String entry, SmokeCase c, Future<Launch> Function(WidgetTester, SmokeCase) launch,
        Future<Outcome> Function(WidgetTester, SmokeCase, Launch) run) async {
      await tester.runAsync(() => serverGet(_base, '/__reset'));
      lastFixture = null;
      Launch? launched;
      Outcome outcome;
      Object? failure;
      try {
        launched = await launch(tester, c);
        outcome = await run(tester, c, launched);
        if (!outcome.ok) failure = outcome.detail;
      } on Object catch (error) {
        failure = error;
        outcome = Outcome(false, '$error'.split('\n').first);
      }
      if (failure != null) await hostShot(tester, '$entry-${c.id}');
      final fixture = launched?.fixture ?? lastFixture;
      final requests = fixture == null ? <String, Object?>{} : await serverRequests(tester, fixture);
      record(entry, c, outcome, requests);
      if (failure != null) failures.add('$entry/${c.id}: ${outcome.detail}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      // A failed case can leave a dialog or a player behind: the next case builds a fresh app.
    }

    bool wanted(String entry, SmokeCase c) {
      if (selected != null) return selected.any((s) => c.id == s || c.id.startsWith(s));
      return entry == 'list' || _core.contains(c.id);
    }

    Future<Outcome> viaList(WidgetTester t, SmokeCase c, Launch l) => opener(c)(t, c, () => tapCentre(t, l.target()));
    // A forwarded bundle projects the attachment without its thumbnail: an SVG there is a download card.
    Future<Outcome> viaForward(WidgetTester t, SmokeCase c, Launch l) =>
        c.kind == 'svg' ? downloadOnly(t, c, tap: () => tapCentre(t, l.target())) : viaList(t, c, l);
    final launchers = <String, Future<Launch> Function(WidgetTester, SmokeCase)>{
      'list': (t, c) => launchList(t, c, mobile: mobile),
      'search': (t, c) => launchSearch(t, c, mobile: mobile),
      'thread': (t, c) => launchThread(t, c, mobile: mobile),
      'forward': (t, c) => launchForward(t, c, mobile: mobile),
      'joint': (t, c) => launchJoint(t, c, mobile: mobile),
    };
    for (final entry in entries) {
      for (final c in manifest) {
        if (!wanted(entry, c)) continue;
        if (launchers.containsKey(entry)) {
          await scenario(entry, c, launchers[entry]!, entry == 'forward' ? viaForward : viaList);
        } else if (entry == 'files') {
          await scenario(entry, c, (t, c) => launchFiles(t, c, mobile: mobile), openFromFiles);
        } else if (entry == 'hidden' && c.id == 'img-png') {
          await scenario(entry, c, (t, c) => launchTwoImages(t, c, mobile: mobile), hiddenRowRelease);
        } else if (entry == 'viewer') {
          await scenario(entry, c, (t, c) => launchList(t, c, mobile: mobile), openFromViewerDownload);
        }
      }
    }
    debugPrint('AOS-DONE ${failures.length} failed');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
