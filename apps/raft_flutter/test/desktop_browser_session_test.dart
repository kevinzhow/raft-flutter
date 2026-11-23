import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/desktop_browser_panel.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_system_webview/raft_system_webview.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewPlatform;

import 'support/fake_webview.dart';
import 'support/web_preview_fixture.dart';

const _failure = 'This page can’t be shown here';
final _url = Uri.parse('https://example.test/fixture');

void main() {
  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  final linux = TargetPlatformVariant({TargetPlatform.linux});
  final requests = <MethodCall>[];
  final pages = <int, List<MethodCall>>{};
  final channels = <int, MethodChannel>{};

  Future<WorkspaceController> mount(
    WidgetTester tester, {
    bool projection = false,
    bool legacyPreview = false,
    bool enableBrowserAfterMount = false,
  }) async {
    requests.clear();
    pages.clear();
    channels.clear();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('app.raft/linux_dependencies'),
      (_) async => {
        'protocol': 1,
        'features': {
          'webkit': {
            'status': 'available',
            'available': true,
            'registered': true,
          },
        },
      },
    );
    messenger.setMockMethodCallHandler(SystemWebViewController.rootChannel, (
      call,
    ) async {
      requests.add(call);
      if (call.method != 'createBrowser') return null;
      final id = channels.length + 1;
      final calls = pages[id] = [];
      final channel = channels[id] = MethodChannel(
        'app.raft/system_webview/$id',
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      return {
        'id': id,
        'protocol': 1,
        'browser': true,
        'ephemeral': true,
        'sandboxed': true,
      };
    });
    final (workspace, adapter) = (await tester.runAsync(
      () => webPreviewFixture(
        flag: legacyPreview,
        os: 'linux',
        desktopBrowser: !legacyPreview,
        tasks: legacyPreview,
      ),
    ))!;
    addTearDown(workspace.dispose);
    if (legacyPreview) {
      WebPreviewStore.of(workspace).platform = const WebPreviewPlatform(
        operatingSystem: 'macos',
      );
      workspace.section = 'chat';
      adapter.routes['GET /channels/c1/messages'] = (_) => [];
      adapter.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {
            'key': ChannelSideFlags.desktopBrowserKey,
            'enabled': enableBrowserAfterMount,
          },
        ],
      };
    }
    tester.view.physicalSize = Size(legacyPreview ? 390 : 1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppServicesScope(
        services: const AppServices.updatesDisabledForTestOrPreview(),
        child: MaterialApp(
          theme: raftTheme(),
          home: projection
              ? WorkspaceView(
                  controller: workspace,
                  appearance: const RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                )
              : Scaffold(
                  body: ChannelSideArea(
                    controller: workspace,
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
      ),
    );
    if (!legacyPreview) {
      openWebPreviewBeside(workspace, _url.toString(), conversationId: 'c1');
    }
    await tester.pumpAndSettle();
    return workspace;
  }

  Future<void> event(
    WidgetTester tester,
    String type, [
    Map<String, Object?> fields = const {},
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channels[1]!.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('event', {'type': type, ...fields}),
      ),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets(
    'a failed page can reload or move through history and fail again',
    (tester) async {
      await mount(tester);
      await event(tester, 'browserState', {
        'url': _url.toString(),
        'back': true,
        'forward': true,
      });
      final result = <(bool, bool, String)>[];
      for (final (key, method) in [
        ('refresh', 'reload'),
        ('history-back', 'back'),
        ('history-forward', 'forward'),
      ]) {
        await event(tester, 'failed');
        final failed = find.text(_failure).evaluate().isNotEmpty;
        await tester.tap(find.byKey(ValueKey('browser-$key')));
        await tester.pump();
        result.add((
          failed,
          find.text(_failure).evaluate().isEmpty,
          pages[1]!.where((call) => call.method == method).isEmpty
              ? 'missing'
              : method,
        ));
      }
      await tester.pumpWidget(const SizedBox());
      expect(result, [
        (true, true, 'reload'),
        (true, true, 'back'),
        (true, true, 'forward'),
      ]);
    },
    variant: linux,
  );

  testWidgets(
    'a loaded native page and its history survive a conversation switch',
    (tester) async {
      final workspace = await mount(tester);
      await event(tester, 'browserState', {
        'url': _url.replace(path: '/second').toString(),
        'title': 'Loaded document',
        'back': true,
      });
      final conversation = workspace.channel!;
      workspace.channel = RaftChannel({'id': 'other', 'joined': true});
      workspace.notifyListeners();
      await tester.pumpAndSettle();
      final hidden = find
          .byKey(const ValueKey('browser-history-back'))
          .evaluate()
          .isEmpty;
      final retired = pages[1]!.any((call) => call.method == 'dispose');
      workspace.channel = conversation;
      workspace.notifyListeners();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browser-history-back')));
      await tester.pump();
      final hadHistory = pages[1]!.any((call) => call.method == 'back');
      final started = channels.length;
      await tester.pumpWidget(const SizedBox());
      expect(hidden, isTrue);
      expect(retired, isFalse);
      expect(started, 1);
      expect(hadHistory, isTrue);
    },
    variant: linux,
  );

  testWidgets('changing account retires the native browsing data store', (
    tester,
  ) async {
    final workspace = await mount(tester);
    final store = WebPreviewStore.of(workspace);
    store.browserTabs.close('c1');
    await tester.pumpAndSettle();
    final beforeAccountSwitch = requests.map((call) => call.method).toList();
    workspace.client.user = RaftRecord({'id': 'other-account'});
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    final afterAccountSwitch = requests.map((call) => call.method).toList();
    await tester.pumpWidget(const SizedBox());
    expect(beforeAccountSwitch, ['createBrowser']);
    expect(afterAccountSwitch, ['createBrowser', 'retireBrowserSession']);
  }, variant: linux);

  testWidgets('returning to an open browser preserves the last picked card', (
    tester,
  ) async {
    final workspace = await mount(tester);
    final store = ChannelSideStore.of(workspace);
    const cards = ['app', 'tasks'];
    final justOpened = store.activeCard(cards);
    store.focus('tasks');
    final conversation = workspace.channel!;
    workspace.channel = RaftChannel({'id': 'other', 'joined': true});
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    workspace.channel = conversation;
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    final onReturn = store.activeCard(cards);
    await tester.pumpWidget(const SizedBox());
    expect(justOpened, 'app');
    expect(onReturn, 'tasks');
  }, variant: linux);

  testWidgets('opening an existing link brings Browser ahead of Tasks', (
    tester,
  ) async {
    final workspace = await mount(tester);
    final store = ChannelSideStore.of(workspace);
    store.focus('tasks');
    await tester.pumpAndSettle();

    openWebPreviewBeside(workspace, _url.toString(), conversationId: 'c1');
    await tester.pumpAndSettle();
    final card = store.activeCard(['app', 'tasks']);
    final nativePages = channels.length;
    await tester.pumpWidget(const SizedBox());

    expect(card, 'app');
    expect(nativePages, 1);
  }, variant: linux);

  testWidgets('compact layout and conversation changes keep the same page', (
    tester,
  ) async {
    final workspace = await mount(tester, projection: true);
    await event(tester, 'browserState', {
      'url': _url.replace(path: '/second').toString(),
      'title': 'Loaded document',
      'back': true,
    });
    tester.view.physicalSize = const Size(760, 900);
    await tester.pumpAndSettle();
    final conversation = workspace.channel!;
    final other = RaftChannel({'id': 'other', 'name': 'Other', 'joined': true});
    workspace.channels = [conversation, other];
    workspace.channel = other;
    workspace.section = 'chat';
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    workspace.channel = conversation;
    workspace.section = 'chat';
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    final browser = WebPreviewStore.of(workspace).browserTabs;
    browser.navigate('c1', browser.forConversation('c1')!.activeId, _url);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopBrowserPanel), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();

    final nativePages = channels.length;
    final loads = pages.values
        .expand((calls) => calls)
        .where((call) => call.method == 'load')
        .length;
    await tester.pumpWidget(const SizedBox());
    expect(nativePages, 1);
    expect(loads, 2);
  }, variant: linux);

  for (final desktop in [false, true]) {
    testWidgets(
      desktop
          ? 'a retained legacy preview does not duplicate the desktop pane'
          : 'flag off keeps Tasks selected on Back from a covered route',
      (tester) async {
        final workspace = await mount(
          tester,
          projection: true,
          legacyPreview: true,
          enableBrowserAfterMount: desktop,
        );
        final channel = workspace.channel!.id;
        final original = workspace.location;
        workspace.navigation.navigate(
          original.withQuery({'thread': '$channel:parent'}),
        );
        workspace.notifyListeners();
        await tester.pumpAndSettle();
        expect(workspace.location.thread, isNotNull);
        expect(
          find.byType(ChannelSideArea, skipOffstage: false),
          findsAtLeastNWidgets(2),
        );
        expect(
          openWebPreviewBeside(
            workspace,
            _url.toString(),
            conversationId: channel,
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        final preview = WebPreviewStore.of(workspace);
        expect(preview.pageFor(channel), isNotNull);
        if (desktop) {
          ChannelSideFlags.of(workspace).reevaluate();
          await tester.pumpAndSettle();
          expect(
            openWebPreviewBeside(
              workspace,
              _url.replace(path: '/desktop').toString(),
              conversationId: channel,
            ),
            isTrue,
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(DesktopBrowserPanel, skipOffstage: false),
            findsOneWidget,
          );
          expect(channels, hasLength(1));
        } else {
          const cards = ['app', 'tasks'];
          final store = ChannelSideStore.of(workspace);
          expect(store.activeCard(cards), 'app');
          store.focus('tasks');
          await tester.pumpAndSettle();
          workspace.navigation.back();
          workspace.notifyListeners();
          await tester.pumpAndSettle();
          expect(workspace.location.uri, original.uri);
          expect(store.activeCard(cards), 'tasks');
        }
        await tester.pumpWidget(const SizedBox());
      },
      variant: linux,
    );
  }

  testWidgets('Escape restores expanded chrome and leaves both tabs open', (
    tester,
  ) async {
    final workspace = await mount(tester);
    final tabs = WebPreviewStore.of(workspace).browserTabs;
    tabs.open('c1', _url.replace(path: '/second'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('browser-expand')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DesktopBrowserPanel>(find.byType(DesktopBrowserPanel))
          .expanded,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tabs.forConversation('c1')?.tabs, hasLength(2));
    expect(
      tester
          .widget<DesktopBrowserPanel>(find.byType(DesktopBrowserPanel))
          .expanded,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  }, variant: linux);
}
