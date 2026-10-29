// Isolated native window acceptance. RaftApp, navigation, channel/thread UI,
// the canonical ledger and SQLite are production code. HTTP and accounts use
// fixed fixtures; only native pointer actions drive the product.
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

class _WindowApi extends LabAdapter {
  File? events;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancellation,
  ) async {
    void record(String kind, {int? status}) => events?.writeAsStringSync(
      '${jsonEncode({'atUtc': DateTime.now().toUtc().toIso8601String(), 'kind': kind, 'method': options.method, 'path': options.path, 'query': options.queryParameters, 'status': ?status})}\n',
      mode: FileMode.append,
    );
    record('start');
    final response = await super.fetch(options, body, cancellation);
    record('finish', status: response.statusCode);
    return response;
  }
}

Future<void> main() async {
  RaftWidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
  final alpha = LabChannel(
    'alpha',
    List.filled(75, 'plain'),
    firstPage: 50,
    pageDelay: const Duration(seconds: 4),
  );
  final beta = LabChannel('beta', List.filled(4, 'plain'));
  final thread = LabChannel(
    'thread-alpha-74',
    List.filled(3, 'plain'),
    pageDelay: const Duration(seconds: 2),
  );
  for (final c in [alpha, beta, thread]) {
    for (var i = 0; i < c.rows.length; i++) {
      c.rows[i]['content'] = '${c.id} 消息 $i — accepted window';
    }
  }
  alpha.summaries['alpha-74'] = threadSummary('alpha-74', 1);
  final images = await LabImages.start();
  final (seed, api, client) = await labWorkspace(
    [alpha, beta],
    images,
    mobile: true,
    ownsClient: false,
    origin: 'https://message-windows-acceptance.invalid',
    adapter: _WindowApi(),
  );
  seed.dispose();
  thread.install(api);
  api.routes['GET /auth/me'] = (_) => client.user!.json;
  api.routes['GET /servers'] = (_) => [
    {'id': 's1', 'name': 'Window Lab', 'slug': 'lab', 'role': 'owner'},
  ];
  api.routes['GET /channels/public'] = (_) => <dynamic>[];
  api.routes['GET /servers/unread-summary'] = (_) => <dynamic>[];
  api.routes['GET /announcements/active'] = (_) => {
    'announcements': <dynamic>[],
  };
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'unread_total': 0,
    'tickets': <dynamic>[],
  };
  for (final c in [alpha, beta]) {
    api.routes['GET /channels/${c.id}'] = (_) => {
      ...c.record.json,
      'serverId': 's1',
    };
  }
  api.routes['GET /messages/search'] = (_) => {
    'hasMore': false,
    'results': [
      {
        ...alpha.rows[5],
        'snippet': alpha.rows[5]['content'],
        'channelName': 'lab-alpha',
        'channelType': 'channel',
        'parentChannelId': 'alpha',
        'parentChannelName': 'lab-alpha',
        'parentChannelType': 'channel',
      },
    ],
  };
  api.routes['GET /channels/alpha/threads/alpha-74'] = (_) => {
    'threadChannelId': thread.id,
  };
  for (final index in [5, 74]) {
    api.routes['GET /messages/context/alpha-$index'] = (_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return {
        'messages': [alpha.rows[index]],
        'targetMessageId': 'alpha-$index',
        'hasOlder': true,
        'hasNewer': index < 74,
      };
    };
  }
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
  });
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}/message-windows-m5');
  await directory.create(recursive: true);
  (api as _WindowApi).events = File('${directory.path}/requests.jsonl');
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
