import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/composer_directory.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

Widget host(WorkspaceController w, {double scale = 1, bool dark = false}) =>
    MaterialApp(
      theme: raftTheme(dark: dark),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: RaftChatView(controller: w)),
    );

Future<WorkspaceController> open(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  w.messageDomain.ledger.switchServer('s1');
  final rows = contextRows('reuse', count: 80);
  w.messageDomain.ledger.ingest(
    rows,
    expectedGeneration: w.messageDomain.ledger.generation,
  );
  w.messageDomain.visibleIds['c1'] = rows
      .map((row) => row['id'] as String)
      .toSet();
  await tester.pumpWidget(host(w));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
  return w;
}

void main() {
  testWidgets('thread live insert and edit preserve unrelated visible rows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final channel = RaftChannel({...w.channel!.json, 'type': 'channel'});
    w.channel = channel;
    w.channels = [channel];
    const humans = [
      {'id': 'alice', 'name': 'alice'},
      {'id': 'bob', 'name': 'bob'},
    ];
    rememberChannelRoster(w, channel, humans: humans, agents: const []);
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => humans;
    api.routes['GET /channels/c1/members'] = (_) => {'humans': humans};
    final replies = [
      for (final row in contextRows('reply'))
        {
          ...row,
          'channelId': 'thread-1',
          'createdAt': '2026-09-15T12:00:00Z',
          'content': '**Reply** ${row['id']}',
        },
    ];
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [
        {...contextRows('parent').first, 'id': 'parent'},
      ],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': replies};
    await tester.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'thread-1',
        navigate: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        home: Scaffold(body: RaftChatView(controller: w, thread: true)),
      ),
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RaftMessageTimeline),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    position.jumpTo(position.minScrollExtent + 950);
    await tester.pumpAndSettle();
    final visible = [
      for (final row in replies)
        if (paintedMessage(tester, row['id'] as String) != null) row,
    ];
    expect(visible.length, greaterThan(6));
    final at = visible.length ~/ 2;
    final edited = visible[at];
    final previousId = visible[at - 1]['id'] as String;
    final followingId = visible[at + 1]['id'] as String;
    final unchanged = [
      for (var index = 0; index < visible.length; index++)
        if (index != at) visible[index]['id'] as String,
    ];
    Finder tileKey(String id) =>
        find.byKey(ValueKey('message-$id'), skipOffstage: false);
    RaftMessageTile tile(String id) =>
        tester.widget<RaftMessageTile>(tileKey(id));
    final before = {for (final id in unchanged) id: tile(id)};
    final parent = tile('parent');
    final parentElement = tester.element(tileKey('parent'));
    var parentBuilds = 0;
    final previousRebuild = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtFirstTime) {
      if (identical(element, parentElement)) parentBuilds++;
      previousRebuild?.call(element, builtFirstTime);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousRebuild);
    final anchor = paintedMessage(tester, unchanged.first);
    int? bobRank() => tester
        .widget<RaftComposer>(find.byType(RaftComposer))
        .suggestions
        .singleWhere((suggestion) => suggestion.id == 'bob')
        .threadRank;
    expect(bobRank(), isNull);
    final builds = RaftMessageTimeline.debugRowBuilds;
    final initialProfiling = debugProfileLayoutsEnabled;
    final initialCollection = FlutterTimeline.debugCollectionEnabled;
    debugProfileLayoutsEnabled = true;
    FlutterTimeline.debugCollectionEnabled = true;
    try {
      const arrival = 'reply-80';
      final domain = w.messageDomain;
      domain.ledger.ingest([
        {...edited, 'content': '**Edited** live reply'},
        {
          ...replies.last,
          'id': arrival,
          'seq': '81',
          'senderId': 'bob',
          'content': 'New reply',
        },
      ], expectedGeneration: domain.ledger.generation);
      domain.visibleIds['thread-1']!.add(arrival);
      w.notifyListeners();
      await tester.pump();
      expect(
        find.textContaining('live reply', findRichText: true),
        findsNothing,
      );
      expect(tile(previousId), same(before[previousId]));
      expect(tile(followingId), same(before[followingId]));
      await tester.pumpAndSettle();
      final layouts = FlutterTimeline.debugCollect().timedBlocks;
      expect(bobRank(), 0);
      expect(
        find.textContaining('live reply', findRichText: true),
        findsOneWidget,
      );
      expect(
        tester
            .widget<RaftMessageTimeline>(find.byType(RaftMessageTimeline))
            .messages
            .last
            .id,
        arrival,
      );
      expect(paintedMessage(tester, unchanged.first), anchor);
      for (final id in unchanged) {
        expect(tile(id), same(before[id]), reason: 'Unchanged visible row $id');
      }
      expect(
        parentBuilds,
        0,
        reason: 'Reply ticks leave the parent unchanged.',
      );
      expect(tile('parent'), same(parent));
      expect(RaftMessageTimeline.debugRowBuilds - builds, lessThanOrEqualTo(2));
      expect(
        layouts.where((block) => block.name == '_RenderRowExtentRecorder'),
        hasLength(lessThanOrEqualTo(2)),
      );
      expect(tile(previousId).followedBy, RaftMessageFollowedBy.compact);
      expect(tile(followingId).continuation, isTrue);
      domain.ledger.ingest([
        {...edited, 'senderId': 'bob', 'content': '**Edited** live reply'},
      ], expectedGeneration: domain.ledger.generation);
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(tile(previousId).followedBy, RaftMessageFollowedBy.group);
      expect(tile(followingId).continuation, isFalse);
      final avatar = find.byKey(
        const ValueKey('message-avatar-parent-user:alice'),
        skipOffstage: false,
      );
      String? pixelKey() =>
          (tester.widget<RaftAvatar>(avatar).content as RaftAvatarContent)
              .pixelKey;
      expect(pixelKey(), isNull);
      const avatarUrl = 'pixel-human:v1:sky.3.curly.brown.grin.none.none';
      rememberChannelRoster(
        w,
        channel,
        humans: [
          {...humans.first, 'avatarUrl': avatarUrl},
          humans.last,
        ],
        agents: const [],
      );
      await tester.pumpAndSettle();
      expect(pixelKey(), avatarUrl);
    } finally {
      debugProfileLayoutsEnabled = initialProfiling;
      FlutterTimeline.debugCollectionEnabled = initialCollection;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('a live arrival starts light and settles at the latest edge', (
    tester,
  ) async {
    final w = await open(tester);
    final arrivals = contextRows('reuse', count: 83)
        .skip(80)
        .map(
          (row) => {
            ...row,
            'senderName': 'Alice',
            'createdAt': '2026-09-15T12:00:00Z',
          },
        );
    w.messageDomain.ledger.ingest(
      arrivals,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1']!.addAll(
      arrivals.map((row) => row['id'] as String),
    );
    w.notifyListeners();
    await tester.pump();
    final latest = find.byKey(const ValueKey('message-reuse-82'));
    expect(latest, findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'Alice, [^\n]+\nreuse message 82')),
      findsOneWidget,
    );
    for (var frame = 0; frame < 6; frame++) {
      final builds = RaftMessageTimeline.debugRowBuilds;
      await tester.pump(const Duration(milliseconds: 16));
      expect(RaftMessageTimeline.debugRowBuilds - builds, lessThanOrEqualTo(1));
    }
    for (final index in [80, 81, 82]) {
      expect(find.byKey(ValueKey('message-reuse-$index')), findsOneWidget);
    }
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RaftMessageTimeline),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.pixels, closeTo(position.maxScrollExtent, .5));
  });

  testWidgets('a remounted row uses its measured height until hydration', (
    tester,
  ) async {
    await open(tester);
    final timeline = find.byType(RaftMessageTimeline);
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: timeline, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    final row = find.byKey(const ValueKey('reuse-79'));
    final full = find.byKey(const ValueKey('message-reuse-79'));
    final height = tester.getSize(row).height;
    position.jumpTo(position.pixels - 1800);
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(full, findsNothing);
    expect(tester.getSize(row).height, height);
    await tester.pumpAndSettle();
    expect(full, findsOneWidget);
    expect(tester.getSize(row).height, height);
  });

  testWidgets('a shrinking edit keeps the following visible row anchored', (
    tester,
  ) async {
    final w = await open(tester);
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RaftMessageTimeline),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    position.jumpTo(position.pixels - 1000);
    await tester.pumpAndSettle();
    final edited = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('message-reuse-67')),
    );
    final viewport = RenderAbstractViewport.of(edited);
    position.jumpTo(viewport.getOffsetToReveal(edited, 0).offset + 20);
    await tester.pumpAndSettle();
    final old = paintedMessage(tester, 'reuse-67')!;
    final anchor = paintedMessage(tester, 'reuse-68');
    expect(anchor, isNotNull);
    w.messageDomain.ledger.ingest([
      {...contextRows('reuse')[67], 'content': 'Short edit'},
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.notifyListeners();
    await tester.pump();
    expect(paintedMessage(tester, 'reuse-67'), old);
    await tester.pumpAndSettle();
    expect(find.text('Short edit'), findsOneWidget);
    expect(paintedMessage(tester, 'reuse-68'), anchor);
  });

  testWidgets('a live append on Android lays out only nearby changed rows', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final w = await open(tester, size: const Size(390, 844));
      final view = find.byType(RaftMessageTimeline);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: view, matching: find.byType(Scrollable)).first,
          )
          .position;
      position.jumpTo(position.pixels - 220);
      await tester.pumpAndSettle();
      final anchor = paintedMessage(tester, 'reuse-76');
      expect(anchor, isNotNull);
      final before = RaftMessageTimeline.debugRowBuilds;
      final initialProfiling = debugProfileLayoutsEnabled;
      final initialBuildProfiling = debugProfileBuildsEnabled;
      final initialCollection = FlutterTimeline.debugCollectionEnabled;
      debugProfileLayoutsEnabled = true;
      debugProfileBuildsEnabled = true;
      FlutterTimeline.debugCollectionEnabled = true;
      try {
        final arrival = contextRows('reuse', count: 81).last
          ..['senderId'] = 'bob';
        w.messageDomain.ledger.ingest([
          arrival,
        ], expectedGeneration: w.messageDomain.ledger.generation);
        w.messageDomain.visibleIds['c1']!.add('reuse-80');
        w.notifyListeners();
        await tester.pumpAndSettle();
        final layouts = FlutterTimeline.debugCollect().timedBlocks;
        expect(paintedMessage(tester, 'reuse-76'), anchor);
        expect(
          tester.widget<RaftMessageTimeline>(view).messages.last.id,
          'reuse-80',
        );
        expect(
          RaftMessageTimeline.debugRowBuilds - before,
          lessThanOrEqualTo(3),
        );
        expect(
          layouts.where((block) => block.name == 'TimelineReusableRow'),
          hasLength(lessThanOrEqualTo(3)),
        );
        expect(
          layouts.where(
            (block) => block.name == '_RenderTimelineExtentRecorder',
          ),
          hasLength(lessThanOrEqualTo(4)),
        );
      } finally {
        debugProfileLayoutsEnabled = initialProfiling;
        debugProfileBuildsEnabled = initialBuildProfiling;
        FlutterTimeline.debugCollectionEnabled = initialCollection;
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('bottom controls do not invalidate displayed message rows', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Back to Bottom'), findsNothing);
    final rows = find.byType(RaftMessageTile);
    Map<Key?, RaftMessageTile> snapshot() => {
      for (final row in tester.widgetList<RaftMessageTile>(rows)) row.key: row,
    };
    final before = snapshot();
    expect(before, isNotEmpty);
    final scroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RaftMessageTimeline),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final latest = scroll.pixels;
    scroll.jumpTo(latest - 120);
    await tester.pumpAndSettle();
    expect(find.text('Back to Bottom'), findsOneWidget);
    final after = snapshot();
    final common = before.keys.toSet().intersection(after.keys.toSet());
    expect(common, isNotEmpty);
    for (final key in common) {
      expect(
        after[key],
        same(before[key]),
        reason: 'Crossing the bottom threshold must preserve row $key.',
      );
    }
    await tester.tap(find.text('Back to Bottom'));
    await tester.pumpAndSettle();
    expect(scroll.pixels, closeTo(latest, 1));
    expect(find.text('Back to Bottom'), findsNothing);
  });
  testWidgets(
    'unrelated workspace changes preserve message row builds and paint',
    (tester) async {
      final w = await open(tester);
      final rect = paintedMessage(tester, 'reuse-79');
      expect(rect, isNotNull);
      final builds = RaftMessageTimeline.debugRowBuilds;
      for (var i = 0; i < 5; i++) {
        w.notifyListeners();
        await tester.pump();
        await tester.pump();
        expect(paintedMessage(tester, 'reuse-79'), rect);
      }
      expect(RaftMessageTimeline.debugRowBuilds, builds);
    },
  );

  testWidgets(
    'retained rows refresh message edits, theme and system text size',
    (tester) async {
      final w = await open(tester);
      final old = paintedMessage(tester, 'reuse-79')!;
      final changed = contextRows('reuse')[79]
        ..['content'] = 'Edited live message';
      w.messageDomain.ledger.ingest([
        changed,
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('Edited live message'), findsWidgets);
      expect(find.textContaining('reuse message 79'), findsNothing);
      final edited = paintedMessage(tester, 'reuse-79')!;
      expect(edited.height, lessThan(old.height));
      var builds = RaftMessageTimeline.debugRowBuilds;
      await tester.pumpWidget(host(w, dark: true));
      await tester.pumpAndSettle();
      expect(RaftMessageTimeline.debugRowBuilds, greaterThan(builds));
      expect(paintedMessage(tester, 'reuse-79')!.height, edited.height);
      builds = RaftMessageTimeline.debugRowBuilds;
      await tester.pumpWidget(host(w, dark: true, scale: 2));
      await tester.pumpAndSettle();
      expect(RaftMessageTimeline.debugRowBuilds, greaterThan(builds));
      expect(
        paintedMessage(tester, 'reuse-79')!.height,
        greaterThan(edited.height),
      );
    },
  );
}
