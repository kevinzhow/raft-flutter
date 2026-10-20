import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web v1.21.12 public server page: the channel column is the signed-in
// Sidebar's parts (PublicServerSidebarFrame + accent rows), the channel header
// is an attached panel header, the loading and empty states use Spinner and
// EmptyState, and older pages load from the timeline's top sentinel.
void main() {
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    RaftFamily family = RaftFamily.elegant,
    bool dark = false,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(family, dark: dark),
        home: Scaffold(body: child),
      ),
    );
  }

  Widget sidebar({String? selected = 'a'}) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      height: 600,
      child: RaftPublicChannelSidebar(
        serverName: 'Raft Design',
        channels: const [
          RaftPublicServerChannel(id: 'a', name: 'general'),
          RaftPublicServerChannel(id: 'b', name: 'design-crit'),
        ],
        selectedId: selected,
        onSelect: (_) {},
      ),
    ),
  );

  for (final (family, dark, header) in [
    (RaftFamily.elegant, false, 56.0),
    (RaftFamily.elegant, true, 56.0),
    (RaftFamily.brutal, false, 62.0),
  ]) {
    testWidgets('[$family/$dark] channel column frame', (tester) async {
      await mount(tester, sidebar(), family: family, dark: dark);
      final t = RaftTokens.of(
        tester.element(find.byType(RaftPublicChannelSidebar)),
      );
      final frame = find.byKey(const ValueKey('public-server-channel-sidebar'));
      expect(tester.getSize(frame).width, 240);
      final fill =
          (tester.widget<Container>(frame).decoration! as BoxDecoration).color;
      expect(
        fill,
        family == RaftFamily.brutal
            ? t.product.brutalCream
            : t.colors['layer-canvas-muted'],
        reason: 'SidebarRoot bg, not the old layer-inset',
      );
      // `h-panel-header` follows the shell's header height, not a fixed 62.
      final title = tester.getRect(find.text('Raft Design'));
      expect(title.center.dy, closeTo(header / 2, 2));
      // The label row and the rows share the signed-in Sidebar parts.
      expect(find.text('PUBLIC CHANNELS'), findsOneWidget);
      expect(find.byType(RaftNavItem), findsNWidgets(2));
      final selected = tester.widget<RaftNavItem>(
        find.byKey(const ValueKey('public-channel-a')),
      );
      expect(selected.selected, isTrue);
      expect(selected.conversationKind, RaftConversationNavKind.channel);
      expect(
        tester
            .widget<RaftNavItem>(find.byKey(const ValueKey('public-channel-b')))
            .selected,
        isFalse,
      );
    });
  }

  testWidgets('below sm the column is 144 wide and the label wraps', (
    tester,
  ) async {
    await mount(tester, sidebar(), size: const Size(500, 800));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('public-server-channel-sidebar')))
          .width,
      144,
    );
    expect(find.text('PUBLIC CHANNELS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting a row reports its id', (tester) async {
    String? picked;
    await mount(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 600,
          child: RaftPublicChannelSidebar(
            serverName: 'S',
            channels: const [RaftPublicServerChannel(id: 'a', name: 'general')],
            selectedId: null,
            onSelect: (id) => picked = id,
          ),
        ),
      ),
    );
    await tester.tap(find.text('general'));
    expect(picked, 'a');
  });

  testWidgets('Elegant channel header is a canvas-muted strip with a rule', (
    tester,
  ) async {
    await mount(
      tester,
      const RaftPublicChannelHeader(name: 'general', description: 'News'),
    );
    final t = RaftTokens.of(
      tester.element(find.byType(RaftPublicChannelHeader)),
    );
    final strip = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(RaftPublicChannelHeader),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((b) => b.decoration)
        .whereType<BoxDecoration>();
    expect(
      strip.any(
        (d) =>
            d.color == t.colors['layer-canvas-muted'] &&
            d.border is Border &&
            (d.border! as Border).bottom.color == t.colors['line-muted'],
      ),
      isTrue,
    );
  });

  testWidgets('the loading page is a centred spinner, not a word', (
    tester,
  ) async {
    await mount(tester, const RaftPublicServerLoading(label: 'Loading…'));
    expect(find.byType(RaftSpinner), findsOneWidget);
    expect(find.text('Loading…'), findsNothing);
  });

  testWidgets('an empty state is an icon over its title', (tester) async {
    await mount(
      tester,
      const RaftPublicEmptyMessage(
        'No messages have been posted here yet.',
        glyph: RaftGlyph.messageSquare,
      ),
    );
    expect(tester.widget<RaftIcon>(find.byType(RaftIcon)).size, 36);
    expect(find.text('No messages have been posted here yet.'), findsOneWidget);
    final icon = tester.getRect(find.byType(RaftIcon));
    final title = tester.getRect(
      find.text('No messages have been posted here yet.'),
    );
    expect(title.top - icon.bottom, closeTo(8, 1));
  });

  group('auto-loading older pages', () {
    Widget list(
      ScrollController c,
      int rows,
      VoidCallback onLoad, {
      bool enabled = true,
      bool reverse = false,
    }) => RaftPublicAutoLoadOlder(
      enabled: enabled,
      reverse: reverse,
      controller: c,
      onLoadOlder: onLoad,
      child: ListView(
        controller: c,
        reverse: reverse,
        children: [
          for (var i = 0; i < rows; i++)
            SizedBox(height: 50, child: Text('r$i')),
        ],
      ),
    );

    testWidgets('fires at the start, stays quiet away from it', (tester) async {
      var loads = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await mount(
        tester,
        list(c, 40, () => loads++),
        size: const Size(400, 400),
      );
      await tester.pump();
      expect(
        loads,
        greaterThan(0),
        reason: 'a forward view opens at its start',
      );
      c.jumpTo(600);
      await tester.pump();
      loads = 0;
      c.jumpTo(700);
      await tester.pump();
      expect(loads, 0, reason: 'far from the start');
      c.jumpTo(40);
      await tester.pump();
      expect(loads, greaterThan(0));
    });

    testWidgets('a reversed view starts at its far end', (tester) async {
      var loads = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await mount(
        tester,
        list(c, 40, () => loads++, reverse: true),
        size: const Size(400, 400),
      );
      await tester.pump();
      expect(loads, 0);
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();
      expect(loads, greaterThan(0));
    });

    testWidgets('content shorter than the view asks without scrolling', (
      tester,
    ) async {
      var loads = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await mount(
        tester,
        list(c, 3, () => loads++),
        size: const Size(400, 400),
      );
      await tester.pump();
      await tester.pump();
      expect(loads, greaterThan(0));
    });

    testWidgets('disabled never asks', (tester) async {
      var loads = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await mount(
        tester,
        list(c, 3, () => loads++, enabled: false),
        size: const Size(400, 400),
      );
      await tester.pump();
      await tester.pump();
      expect(loads, 0);
    });
  });

  testWidgets(
    'the read-only thread panel: muted channel, plain close, no old-page button',
    (tester) async {
      var closed = 0, loads = 0;
      final c = ScrollController();
      addTearDown(c.dispose);
      await mount(
        tester,
        RaftPublicThreadPanel(
          title: 'Thread',
          channelContext: '— #general',
          closeLabel: 'Close thread',
          onClose: () => closed++,
          showClose: true,
          parent: const Text('parent'),
          replies: const [Text('r1'), Text('r2')],
          loading: false,
          emptyTitle: 'No replies yet',
          scrollController: c,
          onLoadOlder: () => loads++,
        ),
        size: const Size(380, 800),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Load older messages'), findsNothing);
      expect(loads, greaterThan(0), reason: 'the short thread is at its start');
      await tester.tap(find.byKey(const ValueKey('thread-close')));
      expect(closed, 1);
      // The old boxed icon button is gone.
      expect(find.byType(RaftPanelIconButton), findsNothing);
    },
  );
}
