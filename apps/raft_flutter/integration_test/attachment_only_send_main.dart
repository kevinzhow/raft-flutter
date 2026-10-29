// Debug/profile-only entrypoint: the production RaftApp on perf-lab fixtures
// with a fake server that enforces the real `POST /v2/messages` rule (empty
// `content` is a 400 "Channel ID and content are required", attachments or
// not) and logs every upload and message request. Proves on a device that an
// attachment-only message sends Web's "[N attachment(s)]" body, and that Send
// while an upload runs posts nothing. No login. Never built into the release app.
//
//   tool/flutter build apk --profile --target-platform android-x64 \
//     --android-project-arg=raftApplicationIdSuffix=.linkperf \
//     -t integration_test/attachment_only_send_main.dart
//   adb -s <emulator> install -r build/app/outputs/flutter-apk/app-profile.apk   # only the .linkperf package
//   adb -s <emulator> logcat -s flutter:*                                       # `attach-only:` lines
//
// The first upload trickles in for ~15 s (UPLOAD_HOLD_MS) so Send can be
// pressed while it runs; later uploads finish at once.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

void log(String text) => debugPrint('attach-only: $text');

/// Answers `POST /attachments/upload` and `POST /v2/messages` like the Raft
/// server; every other route is the lab's.
class ProofAdapter extends LabAdapter {
  var uploads = 0, messages = 0;
  final stored = <String, Map<String, dynamic>>{};
  final holdMs = const int.fromEnvironment('UPLOAD_HOLD_MS', defaultValue: 15000);

  ResponseBody json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (o.method == 'POST' && o.path == '/attachments/upload') {
      final n = ++uploads;
      final head = BytesBuilder();
      var total = 0;
      log('upload #$n started');
      if (s != null) {
        await for (final chunk in s) {
          total += chunk.length;
          if (head.length < 2048) head.add(chunk);
        }
      }
      // The first upload is held after its bytes so Send can be pressed while
      // it is still in flight.
      if (n == 1) await Future<void>.delayed(Duration(milliseconds: holdMs));
      final name =
          RegExp(r'filename="([^"]+)"').firstMatch(latin1.decode(head.toBytes(), allowInvalid: true))?[1] ?? 'file.bin';
      final meta = {
        'id': '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
        'channelId': 'ps',
        'filename': name,
        'mimeType': name.endsWith('.mp4') ? 'video/mp4' : 'application/octet-stream',
        'sizeBytes': total,
      };
      stored[meta['id']! as String] = meta;
      log('upload #$n done: $name, $total bytes -> ${meta['id']}');
      return json(200, {
        'attachments': [meta],
      });
    }
    if (o.method == 'POST' && o.path == '/v2/messages') {
      final body = Map<String, dynamic>.from(o.data as Map);
      final content = body['content'];
      final ids = (body['attachmentIds'] as List?)?.cast<String>() ?? const <String>[];
      final n = ++messages;
      log(
        'POST /v2/messages #$n content=${jsonEncode(content)} '
        'attachmentIds=${jsonEncode(ids)} channelId=${body['channelId']}',
      );
      // packages/server messages.ts createHumanMessage: `!channelId || !content`.
      if (body['channelId'] == null ||
          content is! String ||
          content.isEmpty) {
        log('-> 400 Channel ID and content are required');
        return json(400, {'error': 'Channel ID and content are required'});
      }
      if (content.trim().isEmpty) {
        return json(400, {'error': 'Message content cannot be empty'});
      }
      if (content.contains('reject')) {
        // A failing send, to show where its error toast sits.
        log('-> 500 (text contains "reject")');
        return json(500, {'error': 'The server could not take this message.'});
      }
      log('-> 200 accepted');
      return json(200, {
        'message': {
          'id': 'sent-$n',
          'channelId': body['channelId'],
          'seq': '${100 + n}',
          'senderId': 'alice',
          'senderType': 'user',
          'senderName': 'Alice Zhang',
          'messageType': 'chat',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'content': content,
          'randomId': body['randomId'],
          'attachments': [for (final id in ids) ?stored[id]],
        },
      });
    }
    return super.fetch(o, s, c);
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final images = await LabImages.start();
  final channel = LabChannel('ps', const []);
  channel.rows.addAll([
    for (var n = 0; n < 3; n++)
      labRow('ps', 'plain', n)..['content'] = 'Earlier message ${n + 1}',
  ]);
  final (seed, api, client) = await labWorkspace(
    [channel],
    images,
    mobile: true,
    ownsClient: false,
    adapter: ProofAdapter(),
  );
  seed.dispose();
  api.routes['GET /auth/me'] = (_) => {
    'id': 'alice',
    'name': 'Alice Zhang',
    'email': 'alice@example.invalid',
    'emailVerified': true,
    'displayLanguage': const String.fromEnvironment('PROOF_LANG', defaultValue: 'en'),
  };
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /channels/ps'] = (_) => channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {
    'globalTotal': 0,
    'saved': <dynamic>[],
  };
  api.routes['GET /channels/threads/followed'] = (_) => {
    'threads': <dynamic>[],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  api.routes['GET /attachments/upload-capabilities'] = (_) => {
    'maxBytes': 100 * 1024 * 1024,
  };
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {
    'enabled': true,
  };
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {
      MobileTabs.home,
      MobileTabs.tasks,
      MobileTabs.members,
      MobileTabs.computers,
    },
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': const String.fromEnvironment('PROOF_THEME', defaultValue: 'brutal'),
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-attach-only-');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/ps'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
  );
}
