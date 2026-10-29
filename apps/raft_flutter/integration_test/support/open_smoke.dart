// Fixture and plumbing of the attachment open smoke (integration_test/attachment_open_smoke_test.dart,
// tool/attachment-open-smoke/run): the production RaftApp on a lab workspace whose attachments are served by the
// fixture server (tool/attachment-open-smoke/aos_server.py), with a fake Raft API that signs URLs the way the real
// server does (presigned storage URL, or the server streaming the bytes itself with the token in the query).
import 'dart:async';
import 'dart:convert';
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

/// One attachment of the manifest.
class SmokeCase {
  SmokeCase(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get attachmentId => 'aos-$id';
  String get file => json['file'] as String;
  String get filename => json['filename'] as String;
  String get mime => json['mime'] as String;
  String get kind => json['kind'] as String;
  int get size => json['size'] as int;
  String get url => json['url'] as String;
  String? get thumb => json['thumb'] as String?;
  bool get expireFirst => json['expireFirst'] == true;
  /// The preview service answers HTTP 200 `{status: unsupported, reason}` instead of a preview.
  String? get previewRefusal => json['previewRefusal'] as String?;

  /// The viewer cannot draw it: it shows the reason with "Open with System App".
  bool get panel => json['panel'] == true;

  /// Only the first part of the file is shown, with the large-file notice.
  bool get notice => json['notice'] == true;

  /// Text that must be on screen once the document is shown.
  String? get shows => json['shows'] as String?;
  Map<String, dynamic>? get preview => (json['preview'] as Map?)?.cast<String, dynamic>();

  /// The attachment object of a message in [channel].
  Map<String, dynamic> metadata(String base, String channel, {bool channelId = true}) => {
    'id': attachmentId,
    if (channelId) 'channelId': channel,
    'filename': filename,
    'mimeType': mime,
    'sizeBytes': size,
    if (json['width'] != null) 'width': json['width'],
    if (json['height'] != null) 'height': json['height'],
    if (thumb != null)
      'thumbnailUrl': '$base/${const {'ok': 'thumb', 'missing': 'thumb-missing', 'expired': 'thumb-expired'}[thumb]}/${json['thumbFile']}',
  };
}

Future<List<SmokeCase>> fetchManifest(String base) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final response = await (await client.getUrl(Uri.parse('$base/__manifest'))).close();
    final body = jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
    return [for (final c in body['cases'] as List) SmokeCase((c as Map).cast<String, dynamic>())];
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> serverGet(String base, String path) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final response = await (await client.getUrl(Uri.parse('$base$path'))).close();
    return jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<void> postResult(String base, String line) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(Uri.parse('$base/__result'));
    final bytes = utf8.encode(line);
    request.contentLength = bytes.length;
    request.add(bytes);
    await (await request.close()).drain<void>();
  } on Object {
    // The line is also printed.
  } finally {
    client.close(force: true);
  }
}

String _amzDate(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// How the fake API answers `GET /attachments/:id/url` and `POST /attachments/urls`.
class FakeSigner {
  FakeSigner(this.base, this.cases);
  final String base;
  final Map<String, SmokeCase> cases;
  final signs = <String, int>{};

  /// Ids whose next signature is an expired one (set by a test).
  final expireNext = <String>{};

  ({String url, String? expiresAt}) sign(String attachmentId, {String? disposition, bool batch = false}) {
    final c = cases[attachmentId]!;
    final n = signs[attachmentId] = (signs[attachmentId] ?? 0) + 1;
    final bad = (c.expireFirst && n == 1) || expireNext.remove(attachmentId);
    final download = disposition == 'attachment';
    if (c.url == 'presigned') {
      final now = DateTime.now();
      final url =
          '$base/storage/${c.file}?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=${_amzDate(now)}&X-Amz-Expires=300'
          '&X-Amz-Signature=${bad ? 'expired' : 'ok'}'
          '${download ? '&response-content-disposition=attachment' : ''}';
      return (url: url, expiresAt: batch ? null : now.add(const Duration(seconds: 300)).toUtc().toIso8601String());
    }
    // Server-streamed (`stream`) or redirecting to storage (`redirect`): the bearer token travels in the query.
    final inlinePreview = const {'pdf', 'video', 'audio'}.contains(c.kind);
    final dispositionParam = batch
        ? 'inline'
        : download
        ? 'attachment'
        : (disposition == 'inline' && inlinePreview ? 'inline' : null);
    final url =
        '$base/api/attachments/$attachmentId?token=${bad ? 'jwt-expired' : 'jwt-ok'}&serverId=s1'
        '${dispositionParam == null ? '' : '&disposition=$dispositionParam'}';
    return (url: url, expiresAt: null);
  }
}

/// A fully built app on a fixture workspace.
class SmokeFixture {
  SmokeFixture(this.app, this.api, this.signer, this.client, {this.startsAtList = false});

  /// The app starts on the workspace list and the test opens the channel (phone layout).
  final bool startsAtList;
  final Widget app;
  final LabAdapter api;
  final FakeSigner signer;
  final LabClient client;
}

/// The fixture built last (a failed launch still has its request counters).
SmokeFixture? lastFixture;

Future<void> prepareBindings() async {
  await NativeSystemFonts.instance.initialize();
  await initializeSourceTimeFormatting();
  await DevicePreferences.load();
}

LabImages? _images;

/// Builds the app for [cases] shown in channel [channelId]. [rows] are the channel's messages; [extra] installs
/// more routes (threads, files). [location] is the route the app starts on.
Future<SmokeFixture> buildSmokeFixture({
  required String base,
  required List<SmokeCase> all,
  required String channelId,
  required List<Map<String, dynamic>> rows,
  required String location,
  bool mobile = true,
  bool listStart = false,
  Map<String, dynamic>? channelRecord,
  void Function(LabAdapter api)? extra,
}) async {
  _images ??= await LabImages.start();
  final images = _images!;
  final channel = LabChannel(channelId, const []);
  channel.rows.addAll(rows);
  final (seed, api, client) = await labWorkspace([channel], images, mobile: mobile, ownsClient: false, origin: base);
  seed.dispose();
  final signer = FakeSigner(base, {for (final c in all) c.attachmentId: c});
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
  api.routes['GET /channels/$channelId'] = (_) => channelRecord ?? channel.record.json;
  api.routes['GET /channels/inbox'] = (_) => {'items': <dynamic>[]};
  api.routes['GET /channels/saved'] = (_) => {'globalTotal': 0, 'saved': <dynamic>[]};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': <dynamic>[]};
  api.routes['GET /announcements/active'] = (_) => {'announcements': <dynamic>[]};
  api.routes['GET /product-feedback/tickets'] = (_) => {'unread_total': 0, 'tickets': <dynamic>[]};
  api.routes['GET /tasks/server'] = (_) => {'tasks': <dynamic>[]};
  api.routes['GET /messages/attachment-preview/enabled'] = (_) => {'enabled': true};
  // The fake server's attachment routes (packages/server/src/routes/attachments.ts).
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/aos-') && o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      final signed = signer.sign(id, disposition: o.queryParameters['disposition'] as String?);
      return {'url': signed.url, 'expiresAt': signed.expiresAt};
    },
  ));
  api.routes['POST /attachments/urls'] = (o) {
    final ids = ((o.data as Map)['attachmentIds'] as List).cast<String>();
    return {
      'urls': [
        for (final id in ids)
          if (signer.cases.containsKey(id))
            () {
              final signed = signer.sign(id, batch: true);
              return {'id': id, 'url': signed.url, 'expiresAt': null};
            }(),
      ],
    };
  };
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/aos-') && o.path.endsWith('/preview'),
    (o) {
      final c = signer.cases[o.path.split('/')[2]]!;
      final refusal = c.previewRefusal;
      if (refusal != null) return {'status': 'unsupported', 'reason': refusal};
      return {'status': 'ok', 'data': c.preview, 'truncated': false};
    },
  ));
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/aos-') && o.path.endsWith('/html-preview-url'),
    (o) {
      final id = o.path.split('/')[2];
      return {'url': '$base/api/attachments/$id/html-preview?previewToken=fixture', 'expiresAt': null};
    },
  ));
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/aos-') && o.path.endsWith('/comments'),
    (_) => {'comments': <dynamic>[]},
  ));
  api.routes['GET /attachments/comments/counts'] = (_) => {'counts': <String, dynamic>{}};
  extra?.call(api);
  const tabs = MobileTabbarSettings(
    order: MobileTabs.configurable,
    enabled: {MobileTabs.home, MobileTabs.tasks, MobileTabs.members, MobileTabs.computers},
  );
  SharedPreferences.setMockInitialValues({
    'raft.origin': client.origin,
    'raft.mode': 'light',
    'raft.light': 'elegant',
    MobileTabbarStore.preferenceKey: tabs.encode(),
  });
  final dir = await Directory.systemTemp.createTemp('raft-open-smoke-');
  return lastFixture = SmokeFixture(
    app.RaftApp(
      services: const AppServices.updatesDisabledForTestOrPreview(),
      sessionStore: client.sessionStore,
      createClient: (_, _, _) => client,
      initialLocation: Uri.parse(listStart ? '/s/lab' : location),
      nativeContent: LabNavigationContent(),
      nativeSharing: NativeSharing(supported: false),
      openWorkspaceCache: () async => LabNavigationCache(File('${dir.path}/workspace.sqlite')),
    ),
    api,
    signer,
    client,
    startsAtList: listStart,
  );
}

/// A chat message row in [channel] carrying [cases]' attachments.
Map<String, dynamic> smokeRow(String base, String channel, int n, String text, List<SmokeCase> cases, {bool channelId = true}) =>
    labRow(channel, 'plain', n)
      ..['content'] = text
      ..['attachments'] = [for (final c in cases) c.metadata(base, channel, channelId: channelId)];
