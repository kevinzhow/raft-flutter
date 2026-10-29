// The production RaftApp on perf-lab fixtures with a channel of video
// attachments served by an external S3-like range server
// (tool/video-parity-range-server). Shared by `video_parity_main.dart` (manual
// harness) and `player_interactions_test.dart` (the Android interaction
// suite). No login. Never built into the release app.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../perf_lab/fixtures.dart';
import '../perf_lab/navigation_host.dart';

/// One video (or audio) attachment of the fixture channel.
class VideoClip {
  const VideoClip(
    this.id,
    this.file,
    this.filename, {
    this.size,
    this.mime = 'video/mp4',
    this.rate,
    this.text,
    this.group,
    this.width,
    this.height,
  });

  /// Attachment id (`vp-...`).
  final String id;

  /// The file in the range server's directory.
  final String file;

  /// The name the message shows (and the cards' semantics label).
  final String filename;

  /// Declared `sizeBytes`; fetched from the server when null.
  final int? size;
  final String mime;

  /// Server-side throttle in bytes per second (`?rate=`), null for full speed.
  final int? rate;
  final String? text;

  /// Clips (and images: a `mime` of `image/...`) with the same group are the
  /// attachments of one message, in this order; null: a message of its own.
  final String? group;

  /// Declared pixel size of an image (attachment `width` / `height`).
  final int? width, height;
}

/// The clips of the manual parity harness (`video_parity_main.dart`).
const parityClips = [
  VideoClip('vp-portrait', 'portrait.mp4', 'kevin.mp4', size: 5416578, text: 'Portrait phone clip (720x1280, H.264 + AAC)'),
  VideoClip('vp-landscape', 'landscape.mp4', 'landscape.mp4', size: 4846435, text: 'Landscape clip'),
  VideoClip('vp-corrupt', 'corrupt.mp4', 'broken.mp4', size: 200000, text: 'A clip that cannot be decoded'),
  VideoClip('vp-landscape2', 'landscape.mp4', 'landscape2.mp4', size: 4846435, text: 'Second landscape clip (one at a time)'),
  VideoClip('vp-hevc4k', 'hevc4k.mp4', 'hevc4k.mp4', size: 41607413, text: '4K HEVC Main 8-bit bt709 30 fps'),
  VideoClip('vp-dolby', 'dolby.mp4', 'dolby.mp4', size: 22924840, text: 'Dolby Vision 8.4 (HLG base), HEVC Main 10, 4K'),
  VideoClip('vp-hevc1080', 'hevc1080.mp4', 'hevc1080.mp4', size: 3762953, text: '1080p HEVC Main'),
  VideoClip('vp-tone', 'tone.wav', 'tone.wav', size: 264678, mime: 'audio/wav', text: 'Audio only (WAV)'),
];

/// The app and the fixture handles a test needs.
class VideoFixture {
  const VideoFixture(this.app, this.api, this.base);
  final Widget app;
  final LabAdapter api;
  final String base;

  /// How often the app asked the (fake) API to sign attachment URLs: single
  /// reads (`GET /attachments/<id>/url`, what a re-sign uses) plus the batch
  /// reads the cards coalesce into (`POST /attachments/urls`).
  int urlRequests(String id) =>
      (api.hits['GET /attachments/$id/url'] ?? 0) + (api.hits['POST /attachments/urls'] ?? 0);
}

Future<int?> _length(String base, String file) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client.headUrl(Uri.parse('$base/$file'));
    final response = await request.close();
    await response.drain<void>();
    final length = response.contentLength;
    return length > 0 ? length : null;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Builds the app on the fixture workspace. [base] is the range server
/// (reachable from the device: `adb reverse` + 127.0.0.1).
Future<VideoFixture> buildVideoFixture({
  required String base,
  required bool mobile,
  required List<VideoClip> clips,
  String location = '/s/lab/channel/vp',
  String mode = 'light',
  String theme = 'brutal',
}) async {
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final images = await LabImages.start();
  final sizes = <String, int>{
    for (final clip in clips)
      clip.id: clip.size ?? await _length(base, clip.file) ?? 1,
  };
  Map<String, dynamic> row(int n, String text, List<Map<String, dynamic>> attachments) =>
      labRow('vp', 'plain', n)
        ..['content'] = text
        ..['attachments'] = attachments;
  final channel = LabChannel('vp', const []);
  // One message per clip, or per group of clips (the media browser pages
  // through the images and videos of one message).
  final messages = <String, List<VideoClip>>{};
  for (final clip in clips) {
    messages.putIfAbsent(clip.group ?? clip.id, () => []).add(clip);
  }
  channel.rows.addAll([
    for (final (i, group) in messages.values.indexed)
      row(i, group.first.text ?? group.first.filename, [
        for (final clip in group)
          {
            'id': clip.id,
            'channelId': 'vp',
            'filename': clip.filename,
            'mimeType': clip.mime,
            'sizeBytes': sizes[clip.id],
            'width': ?clip.width,
            'height': ?clip.height,
          },
      ]),
  ]);
  final (seed, api, client) = await labWorkspace([channel], images, mobile: mobile, ownsClient: false);
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': 'en',
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/vp'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {'enabled': true};
  final byId = {for (final clip in clips) clip.id: clip};
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/vp-') && o.path.endsWith('/url'),
    (o) {
      final clip = byId[o.path.split('/')[2]]!;
      final rate = clip.rate == null ? '' : '&rate=${clip.rate}';
      return {
        'url': '$base/${clip.file}?X-Amz-Expires=3600&X-Amz-Signature=fixture$rate',
      };
    },
  ));
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': mode,
    'raft.light': theme,
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-video-parity-');
  return VideoFixture(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: location),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
    api,
    base,
  );
}
