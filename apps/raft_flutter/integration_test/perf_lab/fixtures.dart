// Perf lab fixtures: fixed, deterministic chat content shared by every
// revision under comparison. Change this file only together with a new
// baseline; comparisons across fixture versions are refused by lab.py.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Bump when any generated content, size or route timing changes.
const fixtureVersion = 'perf-lab-fixture-v2';

/// Row kinds measured individually by the row-mount scenario.
const rowKinds = [
  'plain',
  'markdown',
  'code',
  'image',
  'attachments',
  'reactions',
  'thread-summary',
  'task',
];

/// The realistic mixed history: one 20-row cycle, repeated.
const mixCycle = [
  'plain', 'markdown', 'plain', 'reactions', 'code', //
  'plain', 'image', 'plain', 'thread-summary', 'markdown', //
  'plain', 'task', 'plain', 'attachments', 'reactions', //
  'markdown', 'plain', 'image', 'plain', 'code',
];

const _users = [
  ('alice', 'Alice Zhang'),
  ('bob', 'Bob Li'),
  ('chen', '陈思远'),
  ('dana', 'Dana Okafor'),
];

/// A dio adapter answering from fixed routes, with optional delays, that
/// records every endpoint the product asked for but the fixture lacks.
class LabAdapter implements HttpClientAdapter {
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  final List<(bool Function(RequestOptions), FutureOr<dynamic> Function(RequestOptions))> patterns = [];
  final misses = <String, int>{};
  var requests = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests++;
    var route = routes['${o.method} ${o.path}'];
    if (route == null) {
      for (final (match, handler) in patterns) {
        if (match(o)) {
          route = handler;
          break;
        }
      }
    }
    if (route == null) misses.update('${o.method} ${o.path}', (v) => v + 1, ifAbsent: () => 1);
    return ResponseBody.fromString(
      jsonEncode(route == null ? {'error': 'Unexpected endpoint'} : await route(o)),
      route == null ? 404 : 200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A client whose realtime events the lab drives.
class LabClient extends RaftClient {
  LabClient(LabAdapter adapter)
    : super(origin: 'https://example.invalid', sessionStore: MemorySessionStore(), transport: Dio()..httpClientAdapter = adapter);
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, dynamic payload) => stream.add(RaftEvent(name, payload));
}

/// Fixed test images (PNG, generated once per process, non-trivial to decode)
/// served from a loopback HTTP server.
class LabImages {
  LabImages._(this.server, this.pngs);
  final HttpServer server;
  final List<(int, int, Uint8List)> pngs;
  var reads = 0;
  static const sizes = [(1600, 1200), (1200, 1600), (2048, 1152), (800, 800)];

  static Future<LabImages> start() async {
    final pngs = <(int, int, Uint8List)>[];
    for (var k = 0; k < sizes.length; k++) {
      final (w, h) = sizes[k];
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final random = math.Random(1000 + k);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()
          ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(w.toDouble(), h.toDouble()), [
            ui.Color(0xff000000 | random.nextInt(0xffffff)),
            ui.Color(0xff000000 | random.nextInt(0xffffff)),
          ]),
      );
      // Photographic-ish entropy so PNG decode cost is realistic.
      for (var i = 0; i < 600; i++) {
        canvas.drawCircle(
          ui.Offset(random.nextDouble() * w, random.nextDouble() * h),
          4 + random.nextDouble() * 60,
          ui.Paint()..color = ui.Color((0x60 << 24) | random.nextInt(0xffffff)),
        );
      }
      final image = await recorder.endRecording().toImage(w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      pngs.add((w, h, data!.buffer.asUint8List()));
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final images = LabImages._(server, pngs);
    server.listen((request) async {
      images.reads++;
      final k = int.tryParse(request.uri.pathSegments.last.split('.').first) ?? 0;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(pngs[k % pngs.length].$3);
      await request.response.close();
    });
    return images;
  }

  String url(int k, String id) => 'http://127.0.0.1:${server.port}/img/$k.png?a=$id';
}

String longMarkdown(int i) => '''## 第 $i 条固定性能消息

这是用于复现真实频道滚动卡顿的中文长消息。我们必须保留同一份输入和原始测量结果，不能用短消息或空列表替代用户正在阅读的内容。一次完整的回归应覆盖长段落、内联格式、链接、列表、代码以及附件，检查真实构建和布局成本。

这里继续说明产品的实现约束。界面显示的资料来自当前工作区，频道和线程分别保留自己的滚动位置，长内容在需要的时候折叠。**同样的文字**应该在不同主题下保持可读，*文字选择*和鼠标菜单应当持续可用，不能为了测量而关闭产品原本的功能。查看 [来源资料](https://example.invalid/reference/$i) 了解固定输入。

- 第一项：这是一段包含中文、English、日本語和多个标点的长列表内容，用于测量换行、内联解析、选择区域和约束变化时的实际布局。
- 第二项：固定消息的内容不随版本更改，页面结构和绘制成本才能进行比较；任何测量失败都必须保留，不能仅汇总成功的最后一次运行。
- 第三项：当前频道含有几百条不同类型的消息，我们连续滚动，再在消息上下文内重复滚动，最后调整窗口大小。

> 引用的一段讨论：外观对齐需要保留交互和滚动流畅度，真实平台的证据必须覆盖显示、绘制、输入和状态变化。
''';

String plainText(int i) => switch (i % 4) {
  0 => 'Message $i: plain text with 中文、日本語 and a short reply.',
  1 => '好的，我下午把第 $i 版的截图发到频道里，顺便确认一下发布时间。',
  2 => 'Sounds good — shipping build $i after the review. Ping me if anything regresses.',
  _ => '收到 👍 we will sync on #$i tomorrow morning.',
};

String codeMessage(int i) {
  final lines = [
    for (var l = 0; l < 28; l++) '  final value$l = await fetchRow(${i + l}, retry: ${l % 3}); // 第 $l 行',
  ].join('\n');
  return 'Code $i — the repro:\n\n```dart\nFuture<int> repro$i(Client client) async {\n$lines\n  return value0 + value27;\n}\n```\n\nThe line `fetchRow` dominates.';
}

/// One fixed message row of [kind]. [n] is the message's position.
/// The signed-in fixture user is `alice` (`_users[0]`); [others] picks only
/// other senders, as for live arrivals from teammates.
Map<String, dynamic> labRow(String channel, String kind, int n, {String? id, DateTime? base, int seqBase = 0, bool others = false}) {
  final (sender, name) = others ? _users[1 + n % (_users.length - 1)] : _users[(n ~/ 2) % _users.length];
  final messageId = id ?? '$channel-$n';
  final row = <String, dynamic>{
    'id': messageId,
    'channelId': channel,
    'seq': '${seqBase + n + 1}',
    'senderId': sender,
    'senderType': 'user',
    'senderName': name,
    'messageType': 'chat',
    'createdAt': (base ?? DateTime.utc(2026, 10, 1)).add(Duration(minutes: n * 3)).toIso8601String(),
    'content': switch (kind) {
      'markdown' => longMarkdown(n),
      'code' => codeMessage(n),
      'image' => 'Screenshots for build $n',
      'attachments' => 'Spec and logs for $n',
      _ => plainText(n),
    },
  };
  if (kind == 'image') {
    final count = 1 + n % 3;
    row['attachments'] = [
      for (var a = 0; a < count; a++)
        {
          'id': 'img-$messageId-$a',
          'channelId': channel,
          'filename': 'screenshot-$n-$a.png',
          'mimeType': 'image/png',
          'width': LabImages.sizes[(n + a) % LabImages.sizes.length].$1,
          'height': LabImages.sizes[(n + a) % LabImages.sizes.length].$2,
          'sizeBytes': 900000,
        },
    ];
  }
  if (kind == 'attachments') {
    row['attachments'] = [
      {'id': 'file-$messageId-0', 'channelId': channel, 'filename': 'Quarterly report $n.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 2400000},
      {'id': 'file-$messageId-1', 'channelId': channel, 'filename': 'logs-$n.zip', 'mimeType': 'application/zip', 'sizeBytes': 18000000},
    ];
  }
  if (kind == 'reactions') {
    row['reactions'] = [
      for (final (e, c) in [('👍', 4), ('🎉', 2), ('❤️', 3), ('👀', 1), ('🚀', 5), ('✅', 2)])
        {'emoji': e, 'count': c, 'userIds': [for (var u = 0; u < c; u++) 'user-$u']},
    ];
  }
  if (kind == 'task') {
    row['taskNumber'] = 100 + n;
    row['taskStatus'] = 'in_progress';
    row['taskTitle'] = 'Fix scrolling regression $n';
    row['taskId'] = 'task-$messageId';
  }
  return row;
}

Map<String, dynamic> threadSummary(String parentId, int n) => {
  'threadChannelId': 'thread-$parentId',
  'replyCount': 3 + n % 7,
  'latestReplies': [
    for (var r = 0; r < 2; r++)
      {
        'messageId': 'thread-$parentId-r$r',
        'senderType': 'user',
        'senderId': _users[r].$1,
        'senderName': _users[r].$2,
        'preview': r == 0 ? '我看了一下，问题在列表的布局阶段。' : 'Agreed, let us measure before changing it.',
        'createdAt': DateTime.utc(2026, 10, 1).add(Duration(minutes: n * 3 + r + 1)).toIso8601String(),
      },
  ],
};

/// A channel's fixed history plus the side data its kinds need.
class LabChannel {
  LabChannel(this.id, this.kinds, {this.pageDelay = Duration.zero, this.firstPage}) {
    for (var n = 0; n < kinds.length; n++) {
      final row = labRow(id, kinds[n], n);
      rows.add(row);
      if (kinds[n] == 'thread-summary') summaries[row['id']] = threadSummary(row['id'], n);
      if (kinds[n] == 'task') {
        tasks.add({
          'id': row['taskId'], 'messageId': row['id'], 'channelId': id, 'taskNumber': row['taskNumber'],
          'title': row['taskTitle'], 'status': 'in_progress', 'claimedByName': 'Bob Li',
        });
      }
    }
  }
  final String id;
  final List<String> kinds;
  final Duration pageDelay;

  /// When set, the first page holds only the newest [firstPage] rows and
  /// older pages of 50 are served on `before` requests.
  final int? firstPage;
  final rows = <Map<String, dynamic>>[];
  final summaries = <String, dynamic>{};
  final tasks = <Map<String, dynamic>>[];
  var olderPagesServed = 0;
  RaftChannel get record => RaftChannel({'id': id, 'name': 'lab-$id', 'joined': true});

  Future<Map<String, dynamic>> page(RequestOptions o) async {
    final before = BigInt.tryParse('${o.queryParameters['before'] ?? ''}');
    if (pageDelay > Duration.zero) await Future<void>.delayed(pageDelay);
    if (before != null) {
      final older = rows.where((r) => BigInt.parse(r['seq']) < before).toList();
      final slice = older.sublist(math.max(0, older.length - 50));
      if (slice.isNotEmpty) olderPagesServed++;
      return {'messages': slice, 'hasMore': older.length > 50, 'threadSummariesByParentMessageId': summaries};
    }
    final first = firstPage == null ? rows : rows.sublist(rows.length - firstPage!);
    return {'messages': first, 'hasMore': firstPage != null, 'threadSummariesByParentMessageId': summaries};
  }

  void install(LabAdapter api) {
    api.routes['GET /messages/channel/$id'] = page;
    api.routes['POST /channels/$id/read'] = (_) => {};
    api.routes['GET /tasks/channel/$id'] = (_) => {'tasks': tasks};
  }
}

List<String> mixKinds(int count) => [for (var i = 0; i < count; i++) mixCycle[i % mixCycle.length]];

/// Signs in a fixture workspace with the lab's routes. Every channel's rows
/// arrive through the product's own network page path.
Future<(WorkspaceController, LabAdapter, LabClient)> labWorkspace(List<LabChannel> channels, LabImages images) async {
  final api = LabAdapter();
  api.routes['POST /auth/login'] = (_) => {'accessToken': 'fixture-only', 'refreshToken': 'fixture-only', 'user': {'id': 'alice'}};
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /tasks'] = (_) => [];
  api.routes['GET /channels/unread'] = (_) => {'channels': {}};
  api.routes['GET /channels/dm'] = (_) => [];
  api.routes['GET /channels'] = (_) => [for (final c in channels) c.record.json];
  api.patterns.add((
    (o) => o.method == 'GET' && o.path.startsWith('/channels/') && o.path.endsWith('/members'),
    (_) => [for (final (id, name) in _users) {'userId': id, 'name': name}],
  ));
  // The viewer's own reactions, fetched once per mounted reaction row.
  api.patterns.add((
    (o) => o.method == 'GET' && o.path.startsWith('/messages/') && o.path.endsWith('/reactions/viewer'),
    (o) => {'serverId': 's1', 'messageId': o.path.split('/')[2], 'viewerVersion': 1, 'reactedEmojis': ['👍']},
  ));
  api.patterns.add((
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/') && o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      return {'url': images.url(id.hashCode.abs() % LabImages.sizes.length, id)};
    },
  ));
  // Image attachment URLs keep the image's true aspect: pick by declared size.
  api.patterns.insert(0, (
    (o) => o.method == 'GET' && o.path.startsWith('/attachments/img-') && o.path.endsWith('/url'),
    (o) {
      final id = o.path.split('/')[2];
      for (final c in channels) {
        for (final r in c.rows) {
          for (final a in (r['attachments'] as List? ?? const [])) {
            if (a['id'] == id) {
              final k = LabImages.sizes.indexWhere((s) => s.$1 == a['width'] && s.$2 == a['height']);
              return {'url': images.url(k < 0 ? 0 : k, id)};
            }
          }
        }
      }
      return {'url': images.url(0, id)};
    },
  ));
  for (final c in channels) {
    c.install(api);
  }
  final client = LabClient(api);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'member'});
  w.channels = [for (final c in channels) c.record];
  w.ledger.switchServer('s1');
  return (w, api, client);
}
