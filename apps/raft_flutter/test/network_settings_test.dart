import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:raft_flutter/features/network_settings.dart';
import 'package:raft_flutter/platform/proxy_settings_store.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = 'Pa:ss@w0rd-secret';

class _Resolver implements SystemProxyResolver {
  _Resolver(this.snap);
  final SystemProxySnapshot snap;
  @override
  Future<SystemProxySnapshot> snapshot() async => snap;
  @override
  bool get canResolvePac => false;
  @override
  Future<List<ProxyEntry>> resolve(Uri url) async => const [];
  @override
  Stream<void> get changes => const Stream<void>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> secure;
  late List<String> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secure = {};
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<Object?, Object?>.from(call.arguments as Map);
          calls.add('${call.method}:${args['key']}');
          switch (call.method) {
            case 'read':
              return secure[args['key']];
            case 'write':
              secure['${args['key']}'] = '${args['value']}';
              return null;
            case 'delete':
              secure.remove(args['key']);
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<(SystemProxy, ProxySettingsStore)> pump(
    WidgetTester t, {
    SystemProxySnapshot snapshot = SystemProxySnapshot.none,
    Locale locale = const Locale('en'),
    Future<NetworkProbeResult> Function(SystemProxy, Uri)? probe,
    SystemProxy? existing,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProxySettingsStore(preferences: prefs);
    final proxy =
        existing ??
        (SystemProxy(resolver: _Resolver(snapshot), environment: const {})
          ..configure(await store.load()));
    await proxy.refresh();
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: NetworkSettingsPage(
              key: UniqueKey(),
              origin: 'https://api.example.test',
              proxy: proxy,
              store: store,
              probe: probe,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    return (proxy, store);
  }

  Future<void> type(WidgetTester t, String key, String text) async {
    await t.enterText(find.byKey(Key(key)), text);
    await t.pump();
  }

  testWidgets(
    'manual settings persist; the password goes to secure storage only',
    (t) async {
      final (proxy, store) = await pump(t);
      await t.tap(find.text('Manual Setup'));
      await t.pump();
      await type(t, 'network-host', 'proxy.corp.test');
      await type(t, 'network-port', '3128');
      await type(t, 'network-user', 'alice');
      await type(t, 'network-password', _secret);
      await type(t, 'network-bypass', '*.internal, 10.0.0.0/8');
      await t.tap(find.byKey(const Key('network-save')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();

      final live = proxy.settings;
      expect(live.mode, ProxyMode.manual);
      expect(live.host, 'proxy.corp.test');
      expect(live.port, 3128);
      expect(live.password, _secret);
      expect(live.bypass, ['*.internal', '10.0.0.0/8']);
      expect(
        proxy.findProxyForClient(Uri.parse('https://api.example.test/')),
        'PROXY alice:$_secret@proxy.corp.test:3128',
      );
      expect(
        proxy.findProxy(Uri.parse('https://api.example.test/')),
        'PROXY proxy.corp.test:3128',
      );
      expect(proxy.findProxy(Uri.parse('https://a.internal/')), 'DIRECT');

      // SharedPreferences holds everything except the password.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('raft.proxy.mode'), 'manual');
      expect(prefs.getString('raft.proxy.user'), 'alice');
      for (final key in prefs.getKeys()) {
        expect('${prefs.get(key)}', isNot(contains(_secret)));
      }
      expect(secure['raft.proxy.password'], _secret);

      // A fresh start reads it back.
      final loaded = await store.load();
      expect(loaded.mode, ProxyMode.manual);
      expect(loaded.password, _secret);

      // The field is cleared and shows that a password is kept.
      expect(find.text('Saved.'), findsWidgets);
      final field = t.widget<TextField>(
        find.byKey(const Key('network-password')),
      );
      expect(field.controller!.text, isEmpty);

      // Saving again without typing leaves the stored password alone.
      calls.clear();
      await t.tap(find.byKey(const Key('network-save')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(
        calls.where((c) => c.startsWith('write') || c.startsWith('delete')),
        isEmpty,
      );
      expect(secure['raft.proxy.password'], _secret);
      expect(proxy.settings.password, _secret);

      // Clearing the username removes the stored password.
      await type(t, 'network-user', '');
      await t.tap(find.byKey(const Key('network-save')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(secure, isEmpty);
      expect(proxy.settings.username, isEmpty);

      expect(proxy.settings.toString(), isNot(contains(_secret)));
    },
  );

  testWidgets('invalid input is refused with a message and nothing is saved', (
    t,
  ) async {
    final (proxy, _) = await pump(t);
    await t.tap(find.text('Manual Setup'));
    await t.pump();
    await t.tap(find.byKey(const Key('network-save')));
    await t.pump();
    expect(find.text('Enter the proxy host.'), findsOneWidget);
    await type(t, 'network-host', 'p.test');
    await type(t, 'network-port', '70000');
    await t.tap(find.byKey(const Key('network-save')));
    await t.pump();
    expect(find.text('Enter a port between 1 and 65535.'), findsOneWidget);
    await type(t, 'network-port', '8080');
    await type(t, 'network-user', 'bob');
    await type(t, 'network-password', 'a;b');
    await t.tap(find.byKey(const Key('network-save')));
    await t.pump();
    expect(
      find.text('The username and password cannot contain a semicolon.'),
      findsOneWidget,
    );
    expect(proxy.settings.mode, ProxyMode.system);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  testWidgets('direct mode persists and is reported', (t) async {
    final (proxy, _) = await pump(t);
    await t.tap(find.text('No Proxy'));
    await t.pump();
    await t.tap(find.byKey(const Key('network-save')));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(proxy.settings.mode, ProxyMode.direct);
    expect(find.text('No proxy: connecting directly.'), findsOneWidget);
    expect(proxy.findProxy(Uri.parse('https://api.example.test/')), 'DIRECT');
  });

  testWidgets(
    'system status: HTTP proxy, SOCKS-only note in English and Chinese',
    (t) async {
      await pump(
        t,
        snapshot: SystemProxySnapshot.fromMap({'http': 'sys.proxy:3128'}),
      );
      expect(find.text('System HTTP proxy sys.proxy:3128.'), findsOneWidget);
      await pump(t, snapshot: SystemProxySnapshot.fromMap({'socks': 's:1080'}));
      expect(
        find.textContaining('SOCKS proxy, which is not supported'),
        findsOneWidget,
      );
      await pump(
        t,
        snapshot: SystemProxySnapshot.fromMap({'socks': 's:1080'}),
        locale: const Locale('zh', 'CN'),
      );
      expect(find.textContaining('SOCKS'), findsOneWidget);
      expect(find.textContaining('系统使用 SOCKS 代理，暂不支持，已直连'), findsOneWidget);
      expect(find.text('网络'), findsWidgets);
    },
  );

  testWidgets(
    'test connection uses the form, reports success and proxy-auth failure',
    (t) async {
      final seen = <ProxySettings>[];
      var fail = false;
      await pump(
        t,
        probe: (service, url) async {
          seen.add(service.settings);
          expect(url.host, 'api.example.test');
          return fail
              ? const NetworkProbeResult.failed('proxy-auth')
              : const NetworkProbeResult.ok(200);
        },
      );
      await t.tap(find.text('Manual Setup'));
      await t.pump();
      await type(t, 'network-host', 'p.test');
      await type(t, 'network-port', '3128');
      await t.tap(find.byKey(const Key('network-test')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
      expect(seen.single.host, 'p.test'); // the unsaved draft was tested
      expect(
        find.text('Connected to api.example.test (HTTP 200).'),
        findsOneWidget,
      );
      fail = true;
      await t.tap(find.byKey(const Key('network-test')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump();
      expect(
        find.text('The proxy rejected the username or password.'),
        findsOneWidget,
      );
    },
  );
}
