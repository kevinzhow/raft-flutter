// Isolated native attachment acceptance. Production UI, picker, uploader and
// SQLite are unchanged. Only the account and HTTP service use fixed fixtures.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/main.dart' as app;
import 'package:raft_flutter/platform/android_performance_hint.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/native_sharing.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'perf_lab/fixtures.dart';
import 'perf_lab/navigation_host.dart';

const _sendAcceptance = bool.fromEnvironment('M3_SEND_ACCEPTANCE');

/// Consumes the actual Dio multipart request. The delays keep transfer state
/// visible to native pointer input; no controller or progress callback is driven
/// by the fixture. The first retry.txt request returns a fixed server failure.
class _UploadsApi extends LabAdapter {
  File? events;
  final attempts = <String, int>{};
  final sendAttempts = <String, int>{};
  final accepted = <String, Map<String, dynamic>>{};
  final uploaded = <String, Map<String, dynamic>>{};
  List<LabChannel> channels = [];
  LabClient? replay;
  var sequence = 1000;

  void record(Map<String, Object?> event) {
    events?.writeAsStringSync(
      '${jsonEncode({'atUtc': DateTime.now().toUtc().toIso8601String(), ...event})}\n',
      mode: FileMode.append,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancellation,
  ) async {
    if (_sendAcceptance &&
        options.method == 'POST' &&
        options.path == '/v2/messages') {
      return send(options);
    }
    if (options.method != 'POST' || options.path != '/attachments/upload') {
      return super.fetch(options, body, cancellation);
    }
    final form = options.data as FormData;
    final file = form.files.single.value;
    final name = file.filename!;
    final attempt = attempts.update(name, (n) => n + 1, ifAbsent: () => 1);
    final channel = form.fields.firstWhere((f) => f.key == 'channelId').value;
    var consumed = 0, chunks = 0, cancelled = false;
    cancellation?.then((_) {
      cancelled = true;
      record({'kind': 'cancel', 'name': name, 'attempt': attempt});
    });
    record({
      'kind': 'start',
      'name': name,
      'attempt': attempt,
      'channel': channel,
      'mimeType': file.contentType.toString(),
      'fileBytes': file.length,
    });
    await for (final chunk in body!) {
      consumed += chunk.length;
      chunks++;
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    // Keep the response wait visible after the multipart body is received.
    // Earlier cancellation can already abort body reading through Dio.
    await Future<void>.delayed(const Duration(seconds: 3));
    final fail = name == 'retry.txt' && attempt == 1;
    final attachment = {
      'id': 'native-$name-$attempt',
      'filename': name,
      'mimeType': file.contentType.toString(),
      'sizeBytes': file.length,
    };
    if (!fail) uploaded[attachment['id'] as String] = attachment;
    record({
      'kind': 'finish',
      'name': name,
      'attempt': attempt,
      'channel': channel,
      'consumedMultipartBytes': consumed,
      'chunks': chunks,
      'cancelled': cancelled,
      'status': fail ? 500 : 200,
    });
    return ResponseBody.fromString(
      jsonEncode(
        fail
            ? {
                'error': 'The upload could not be completed.',
                'code': 'UPLOAD_COMPLETE_FAILED',
              }
            : {
                'attachments': [attachment],
              },
      ),
      fail ? 500 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Future<ResponseBody> send(RequestOptions options) async {
    final data = Map<String, dynamic>.from(options.data);
    final randomId = data['randomId'] as String;
    final text = data['content'] as String;
    final attempt = sendAttempts.update(
      randomId,
      (n) => n + 1,
      ifAbsent: () => 1,
    );
    record({'kind': 'send-start', 'attempt': attempt, ...data});
    await Future<void>.delayed(
      Duration(milliseconds: text.startsWith('M3 slow') ? 6000 : 1200),
    );
    final fail = text.startsWith('M3 retry') && attempt == 1;
    if (fail) {
      record({'kind': 'send-finish', 'randomId': randomId, 'status': 503});
      return ResponseBody.fromString(
        jsonEncode({'error': 'Fixture connection lost. Please retry.'}),
        503,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final row = accepted.putIfAbsent(
      randomId,
      () => {
        'id': 'native-send-${++sequence}',
        'seq': '$sequence',
        'channelId': data['channelId'],
        'randomId': randomId,
        'content': text,
        'attachments': [
          for (final id in data['attachmentIds'] as List? ?? const [])
            if (uploaded[id] != null) uploaded[id],
        ],
        'senderId': 'alice',
        'senderType': 'user',
        'senderName': 'Alice Zhang',
        'messageType': 'chat',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final channel = channels.firstWhere((c) => c.id == data['channelId']);
    if (!channel.rows.any((r) => r['id'] == row['id'])) channel.rows.add(row);
    void echo() => replay!.emit('message:new', row);
    if (text.startsWith('M3 HTTP')) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 400), echo));
    } else {
      echo();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    record({
      'kind': 'send-finish',
      'randomId': randomId,
      'status': 200,
      'messageId': row['id'],
      'seq': row['seq'],
    });
    return ResponseBody.fromString(
      jsonEncode({
        'message': row,
        'pendingMentionActions': [],
        'deliveryWarnings': [],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final channels = [
    LabChannel('alpha', ['plain', 'plain']),
    LabChannel('beta', ['plain', 'plain']),
  ];
  final images = await LabImages.start();
  final uploads = _UploadsApi();
  final (seed, api, client) = await labWorkspace(
    channels,
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://uploads-acceptance.invalid',
    adapter: uploads,
  );
  seed.dispose();
  uploads.channels = channels;
  uploads.replay = client;
  api.routes['GET /attachments/upload-capabilities'] = (_) => {
    'maxBytes': 10485760,
  };
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Uploads Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /servers/unread-summary'] = (_) => <dynamic>[];
  for (final channel in channels) {
    api.routes['GET /channels/${channel.id}'] = (_) => {
      ...channel.record.json,
      'serverId': 's1',
    };
    api.routes['POST /channels/${channel.id}/read-all'] = (_) => {
      'maxReadSeq': 2,
      'readStateVersion': 1,
    };
  }
  api.routes['GET /channels/inbox'] = (_) => {
    'hasMore': false,
    'totalCount': channels.length,
    'totalUnreadCount': 0,
    'items': [
      for (final channel in channels)
        {
          'kind': 'channel',
          'channelId': channel.id,
          'channelName': channel.id,
          'lastMessageId': '${channel.id}-1',
          'lastMessagePreview': 'Uploads acceptance ${channel.id}',
          'lastMessageSenderType': 'user',
          'lastMessageSenderId': 'alice',
          'lastMessageSenderName': 'Alice Zhang',
          'lastMessageAt': '2026-10-01T00:03:00Z',
          'latestActivitySeq': '2',
          'readState': {
            'kind': 'present',
            'maxReadSeq': '2',
            'readStateVersion': 1,
            'latestActivity': {'messageId': '${channel.id}-1', 'seq': '2'},
          },
          'unreadCount': 0,
          'firstUnreadMessageId': null,
          'hasMention': false,
        },
    ],
  };
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
  });
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/composer-m3-slice2');
  await directory.create(recursive: true);
  uploads.events = File('${directory.path}/upload-events.jsonl');
  runApp(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri(path: '/s/lab/channel/alpha'),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(),
      openWorkspaceCache: () async =>
          LabNavigationCache(File('${directory.path}/workspace.sqlite')),
    ),
  );
}
