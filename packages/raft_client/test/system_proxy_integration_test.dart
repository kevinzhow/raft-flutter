import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:test/test.dart';

import 'support/test_proxy.dart';

const _password = 'S3cret:pa@ss/word-NOT-IN-LOGS';

class _FakeResolver implements SystemProxyResolver {
  _FakeResolver(this.snap, {this.pac = const {}, this.canPac = false});
  SystemProxySnapshot snap;
  final Map<String, List<ProxyEntry>> pac;
  final bool canPac;
  final resolved = <Uri>[];
  int snapshots = 0;
  Duration delay = Duration.zero;

  @override
  Future<SystemProxySnapshot> snapshot() async {
    snapshots++;
    return snap;
  }

  @override
  bool get canResolvePac => canPac;

  @override
  Future<List<ProxyEntry>> resolve(Uri url) async {
    resolved.add(url);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return pac[url.host] ?? const [ProxyEntry.direct()];
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

void main() {
  late HttpServer web, secure;
  late TestProxy proxy;
  TestProxy? proxyToClose;
  late String webHost, secureHost;
  final prints = <String>[];

  Future<void> startProxy({bool auth = true}) async {
    proxy = await TestProxy.start(
      hosts: {
        'api.test:${web.port}': web.port,
        'secure.test:${secure.port}': secure.port,
      },
      basicUser: auth ? 'alice' : null,
      basicPassword: auth ? _password : null,
    );
    proxyToClose = proxy;
  }

  setUpAll(() async {
    web = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    webHost = 'api.test:${web.port}';
    web.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        // Engine.IO v4 open packet, then accept the Socket.IO namespace.
        socket.add(
          '0{"sid":"eio1","upgrades":[],"pingInterval":25000,'
          '"pingTimeout":20000,"maxPayload":1000000}',
        );
        socket.listen((message) {
          if (message is String && message.startsWith('40')) {
            socket.add('40{"sid":"sio1"}');
          }
        });
        return;
      }
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'path': request.uri.path, 'via': 'web'}));
      await request.response.close();
    });

    // A TLS server with a throw-away certificate, to exercise CONNECT.
    final dir = await Directory.systemTemp.createTemp('proxy-cert');
    final cert = '${dir.path}/c.pem', key = '${dir.path}/k.pem';
    final made = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-subj',
      '/CN=secure.test',
      '-keyout',
      key,
      '-out',
      cert,
    ]);
    if (made.exitCode != 0) fail('openssl is needed for the CONNECT test');
    final context = SecurityContext()
      ..useCertificateChain(cert)
      ..usePrivateKey(key);
    secure = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    secureHost = 'secure.test:${secure.port}';
    secure.listen((request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'path': request.uri.path, 'via': 'secure'}));
      await request.response.close();
    });
    await dir.delete(recursive: true);
  });

  tearDownAll(() async {
    await web.close(force: true);
    await secure.close(force: true);
  });

  tearDown(() async {
    await proxyToClose?.close();
    proxyToClose = null;
  });

  ProxySettings manual({String? password = _password, String user = 'alice'}) =>
      ProxySettings(
        mode: ProxyMode.manual,
        host: '127.0.0.1',
        port: proxy.port,
        username: user,
        password: password ?? '',
      );

  Dio tlsDio(SystemProxy service) => createProxiedDio(
    BaseOptions(connectTimeout: const Duration(seconds: 5)),
    proxy: service,
    configure: (client) => client.badCertificateCallback = (_, _, _) => true,
  );

  test('API client: manual proxy with Basic auth, plain HTTP', () async {
    await startProxy();
    final service = SystemProxy(resolver: const NoSystemProxyResolver())
      ..configure(manual());
    final dio = createProxiedDio(BaseOptions(), proxy: service);
    final response = await dio.get<Map<String, dynamic>>('http://$webHost/x');
    expect(response.data!['via'], 'web');
    expect(proxy.seen.single.target, 'http://$webHost/x');
    expect(
      proxy.seen.single.authorization,
      'Basic ${base64Encode(utf8.encode('alice:$_password'))}',
    );
  });

  test('RaftClient default transport uses the shared proxy instance', () async {
    await startProxy();
    final previous = SystemProxy.instance;
    SystemProxy.instance = SystemProxy()..configure(manual());
    addTearDown(() => SystemProxy.instance = previous);
    final client = RaftClient(
      origin: 'http://$webHost',
      sessionStore: MemorySessionStore(),
    );
    final response = await client.http.get<Map<String, dynamic>>('/ping');
    expect(response.data!['path'], '/api/ping');
    expect(proxy.seen.single.target, 'http://$webHost/api/ping');
  });

  test('HTTPS tunnels through CONNECT with preemptive credentials', () async {
    await startProxy();
    final service = SystemProxy()..configure(manual());
    final response = await tlsDio(service)
        .get<Map<String, dynamic>>('https://$secureHost/secret');
    expect(response.data!['via'], 'secure');
    expect(proxy.seen.single.method, 'CONNECT');
    expect(proxy.seen.single.target, secureHost);
    expect(proxy.seen.single.authorization, isNotNull);
    expect(proxy.rejected, isEmpty);
  });

  test('a wrong or missing password is refused by the proxy', () async {
    await startProxy();
    for (final settings in [
      manual(password: 'wrong'),
      const ProxySettings(mode: ProxyMode.manual, host: '127.0.0.1', port: 1),
    ]) {
      final service = SystemProxy()
        ..configure(
          settings.port == 1 ? settings.copyWith(port: proxy.port) : settings,
        );
      await expectLater(
        tlsDio(service).get<void>('https://$secureHost/'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        createProxiedDio(
          BaseOptions(),
          proxy: service,
        ).get<void>('http://$webHost/'),
        throwsA(isA<DioException>()),
      );
    }
    expect(proxy.seen, isEmpty);
    expect(proxy.rejected, isNotEmpty);
  });

  test(
    'WebSocket (Socket.IO) goes through the proxy with credentials',
    () async {
      await startProxy();
      final service = SystemProxy()..configure(manual());
      final connected = Completer<void>();
      final socket = sio.io(
        'http://$webHost',
        sio.OptionBuilder()
            .setTransports(['websocket'])
            .setWebSocketConnector(
              (uri, {protocols, headers}) => proxiedWebSocketConnector(
                uri,
                protocols: protocols,
                headers: headers,
                proxy: service,
              ),
            )
            .disableAutoConnect()
            .enableForceNew()
            .build(),
      );
      socket.onConnect((_) => connected.complete());
      socket.onConnectError((e) {
        if (!connected.isCompleted) connected.completeError('$e');
      });
      socket.connect();
      await connected.future.timeout(const Duration(seconds: 10));
      socket.dispose();
      final upgrade = proxy.seen.firstWhere(
        (r) => r.target.contains('socket.io'),
      );
      expect(upgrade.method, 'GET');
      expect(upgrade.target, startsWith('http://$webHost/socket.io/'));
      expect(upgrade.authorization, isNotNull);
    },
  );

  test('RaftClient wires the proxy connector into its socket options', () {
    // Accept the App working directory used by the sharded gate, as well as
    // plain `flutter test` from the package or repository root.
    final source = [
      'lib/src/client.dart',
      'packages/raft_client/lib/src/client.dart',
      '../../packages/raft_client/lib/src/client.dart',
    ].map(File.new).firstWhere((f) => f.existsSync()).readAsStringSync();
    expect(source, contains('applyProxyTransport('));
    expect(source, contains('createProxiedDio('));
  });

  test('system mode: OS snapshot decides, no credentials', () async {
    await startProxy(auth: false);
    final service = SystemProxy(
      resolver: _FakeResolver(
        SystemProxySnapshot.fromMap({'http': '127.0.0.1:${proxy.port}'}),
      ),
      environment: const {},
    );
    await service.warm([Uri.parse('http://$webHost/')]);
    expect(
      service.findProxy(Uri.parse('http://$webHost/')),
      'PROXY 127.0.0.1:${proxy.port}',
    );
    final response = await createProxiedDio(
      BaseOptions(),
      proxy: service,
    ).get<Map<String, dynamic>>('http://$webHost/hello');
    expect(response.data!['path'], '/hello');
    expect(proxy.seen.single.authorization, isNull);
  });

  test('environment variables override the OS when set', () async {
    await startProxy(auth: false);
    final service = SystemProxy(
      resolver: _FakeResolver(SystemProxySnapshot.none),
      environment: {'http_proxy': 'http://127.0.0.1:${proxy.port}'},
    );
    final response = await createProxiedDio(
      BaseOptions(),
      proxy: service,
    ).get<Map<String, dynamic>>('http://$webHost/env');
    expect(response.data!['path'], '/env');
    expect(proxy.seen, hasLength(1));
    expect(service.status().source, ProxySource.environment);
  });

  test('direct mode and loopback never use the proxy', () async {
    await startProxy(auth: false);
    final service = SystemProxy()
      ..configure(
        ProxySettings(
          mode: ProxyMode.manual,
          host: '127.0.0.1',
          port: proxy.port,
        ),
      );
    // Loopback is exempt even from a manual proxy.
    final local = await createProxiedDio(
      BaseOptions(),
      proxy: service,
    ).get<Map<String, dynamic>>('http://127.0.0.1:${web.port}/direct');
    expect(local.data!['path'], '/direct');
    service.configure(const ProxySettings(mode: ProxyMode.direct));
    expect(service.findProxy(Uri.parse('https://api.raft.build/')), 'DIRECT');
    expect(proxy.seen, isEmpty);
  });

  test('a manual bypass list sends matching hosts direct', () {
    final service = SystemProxy()
      ..configure(
        const ProxySettings(
          mode: ProxyMode.manual,
          host: 'p.corp',
          port: 3128,
          bypass: ['*.internal', '10.0.0.0/8'],
        ),
      );
    expect(service.findProxy(Uri.parse('https://x.internal/')), 'DIRECT');
    expect(service.findProxy(Uri.parse('http://10.1.1.1/')), 'DIRECT');
    expect(
      service.findProxy(Uri.parse('https://api.raft.build/')),
      'PROXY p.corp:3128',
    );
  });

  test('the password never reaches logs, errors or status', () async {
    await startProxy();
    final captured = <String>[];
    final service = SystemProxy()..configure(manual(password: _password));
    await runZoned(
      () async {
        // Success, failure and diagnostics all run inside the capture.
        await tlsDio(service).get<void>('https://$secureHost/');
        service.configure(manual(password: 'wrong'));
        try {
          await tlsDio(service).get<void>('https://$secureHost/');
        } on DioException catch (error) {
          captured
            ..add(error.toString())
            ..add('${error.message}')
            ..add('${error.error}');
        }
        service.configure(manual());
        captured
          ..add(service.status().toString())
          ..add(service.settings.toString())
          ..add(manual().toString());
        print('proxy: ${service.status()}');
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => prints.add(line),
      ),
    );
    for (final line in [...captured, ...prints]) {
      expect(line, isNot(contains(_password)));
      expect(line, isNot(contains('wrong')));
    }
  });

  group('cache and fallback', () {
    test(
      'PAC: a cold miss answers from the static part, then the cache',
      () async {
        final resolver = _FakeResolver(
          const SystemProxySnapshot(
            mode: SnapshotMode.pac,
            pacUrl: 'http://pac/x.pac',
          ),
          pac: {
            'api.raft.build': [
              const ProxyEntry(ProxyKind.http, 'pac.proxy', 3128),
              const ProxyEntry.direct(),
            ],
          },
          canPac: true,
        );
        final service = SystemProxy(resolver: resolver, environment: const {});
        final url = Uri.parse('https://api.raft.build/api/messages?token=abc');
        // Snapshot not loaded yet: DIRECT, and a load starts in the background.
        expect(service.findProxy(url), 'DIRECT');
        await service.refresh();
        expect(service.findProxy(url), 'DIRECT'); // PAC answer still pending
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(service.findProxy(url), 'PROXY pac.proxy:3128; DIRECT');
        // The PAC script only ever sees the origin.
        expect(resolver.resolved.single.toString(), 'https://api.raft.build/');
        expect(service.status(url).source, ProxySource.pac);
      },
    );

    test('ready() waits for the first PAC answer, bounded', () async {
      final resolver = _FakeResolver(
        const SystemProxySnapshot(mode: SnapshotMode.pac, autoDetect: true),
        pac: {
          'slow.test': [const ProxyEntry(ProxyKind.http, 'p', 1)],
        },
        canPac: true,
      )..delay = const Duration(milliseconds: 50);
      final service = SystemProxy(
        resolver: resolver,
        environment: const {},
        readyTimeout: const Duration(milliseconds: 500),
      );
      final url = Uri.parse('https://slow.test/');
      await service.ready(url);
      expect(service.findProxy(url), 'PROXY p:1');

      resolver.delay = const Duration(seconds: 5);
      final bounded = SystemProxy(
        resolver: resolver,
        environment: const {},
        readyTimeout: const Duration(milliseconds: 100),
      );
      final started = DateTime.now();
      await bounded.ready(Uri.parse('https://slow.test/'));
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 2)),
      );
    });

    test('static configurations never wait', () async {
      final service = SystemProxy(
        resolver: _FakeResolver(SystemProxySnapshot.fromMap({'http': 'p:1'})),
        environment: const {},
      );
      await service.refresh();
      final started = DateTime.now();
      await service.ready(Uri.parse('https://api.raft.build/'));
      expect(DateTime.now().difference(started).inMilliseconds, lessThan(50));
    });

    test(
      'a failing resolver keeps the last snapshot and never throws',
      () async {
        var fail = false;
        final service = SystemProxy(
          resolver: _ThrowingResolver(() => fail),
          environment: const {},
          maxAge: Duration.zero,
        );
        await service.refresh();
        expect(service.findProxy(Uri.parse('https://x.test/')), 'PROXY good:1');
        fail = true;
        await service.refresh();
        expect(service.findProxy(Uri.parse('https://x.test/')), 'PROXY good:1');
      },
    );

    test('SOCKS-only system proxy goes direct and is flagged', () async {
      final service = SystemProxy(
        resolver: _FakeResolver(
          SystemProxySnapshot.fromMap({'socks': 's:1080'}),
        ),
        environment: const {},
      );
      await service.refresh();
      final url = Uri.parse('https://api.raft.build/');
      expect(service.findProxy(url), 'DIRECT');
      expect(service.status(url).socksOnly, isTrue);
    });

    test('PAC without a PAC engine is flagged unsupported', () async {
      final service = SystemProxy(
        resolver: _FakeResolver(
          const SystemProxySnapshot(
            mode: SnapshotMode.pac,
            pacUrl: 'http://p/x.pac',
          ),
        ),
        environment: const {},
      );
      await service.refresh();
      expect(service.findProxy(Uri.parse('https://x.test/')), 'DIRECT');
      expect(service.status().pacUnsupported, isTrue);
    });

    test('HttpOverrides makes plain HttpClient() follow the proxy', () async {
      await startProxy(auth: false);
      final service = SystemProxy()
        ..configure(
          ProxySettings(
            mode: ProxyMode.manual,
            host: '127.0.0.1',
            port: proxy.port,
          ),
        );
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse('http://$webHost/plain'));
        final response = await request.close();
        await response.drain<void>();
        client.close();
      }, ProxyHttpOverrides(service, null));
      expect(proxy.seen.single.target, 'http://$webHost/plain');
    });
  });
}

class _ThrowingResolver extends NoSystemProxyResolver {
  _ThrowingResolver(this.fail);
  final bool Function() fail;
  @override
  Future<SystemProxySnapshot> snapshot() async {
    if (fail()) throw StateError('boom');
    return SystemProxySnapshot.fromMap({'http': 'good:1'});
  }
}
