import 'dart:io';

import 'package:raft_client/system_proxy.dart';
import 'package:test/test.dart';

void main() {
  group('PAC result parsing', () {
    test('PROXY, DIRECT and the fallback order', () {
      final entries = parsePacResult('PROXY proxy.corp:8080; DIRECT');
      expect(entries.map((e) => e.toString()), [
        'PROXY proxy.corp:8080',
        'DIRECT',
      ]);
      expect(
        decisionFromEntries(entries).findProxyString,
        'PROXY proxy.corp:8080; DIRECT',
      );
    });

    test('case, whitespace, HTTP keyword, IPv6 and missing port', () {
      final entries = parsePacResult(
        '  proxy a:1 ; Proxy [::1]:3128;http h2;PROXY h3:70000; junk; ',
      );
      // "proxy a:1" has a space in the host: the token is word "PROXY",
      // rest "a:1".
      expect(entries.map((e) => e.toString()), [
        'PROXY a:1',
        'PROXY [::1]:3128',
        'PROXY h2:80',
      ]);
    });

    test('SOCKS is ignored and reported', () {
      final entries = parsePacResult('SOCKS5 s:1080; SOCKS s2:1081');
      final decision = decisionFromEntries(entries);
      expect(decision.isDirect, isTrue);
      expect(decision.skippedUnsupported, isTrue);
      expect(decision.findProxyString, 'DIRECT');
    });

    test('SOCKS before HTTP keeps the HTTP proxy', () {
      final decision = decisionFromEntries(
        parsePacResult('SOCKS s:1080; PROXY p:3128; DIRECT'),
      );
      expect(decision.findProxyString, 'PROXY p:3128; DIRECT');
      expect(decision.skippedUnsupported, isTrue);
    });

    test('entries after DIRECT are dropped; HTTPS (TLS proxy) unsupported', () {
      expect(
        decisionFromEntries(parsePacResult('DIRECT; PROXY p:1'))
            .findProxyString,
        'DIRECT',
      );
      final tls = decisionFromEntries(parsePacResult('HTTPS p:443'));
      expect(tls.isDirect, isTrue);
      expect(tls.skippedUnsupported, isTrue);
    });

    test('empty answer is DIRECT', () {
      expect(decisionFromEntries(parsePacResult('')).findProxyString, 'DIRECT');
    });
  });

  group('bypass', () {
    bool hit(String url, List<String> patterns, {bool simple = false}) =>
        ProxyBypass(
          patterns,
          excludeSimpleHostnames: simple,
        ).matches(Uri.parse(url));

    test('loopback is always direct', () {
      expect(hit('http://localhost:8080/', []), isTrue);
      expect(hit('http://127.0.0.1/', []), isTrue);
      expect(hit('http://[::1]:3000/', []), isTrue);
      expect(hit('http://a.localhost/', []), isTrue);
      expect(hit('https://api.raft.build/', []), isFalse);
    });

    test('domain, suffix, wildcard and port forms', () {
      expect(hit('https://corp.example.com/', ['example.com']), isTrue);
      expect(hit('https://example.com/', ['.example.com']), isTrue);
      expect(hit('https://a.example.com/', ['*.example.com']), isTrue);
      expect(hit('https://notexample.com/', ['example.com']), isFalse);
      expect(hit('http://10.1.2.3/', ['10.*']), isTrue);
      expect(hit('https://h.test:8443/', ['h.test:8443']), isTrue);
      expect(hit('https://h.test/', ['h.test:8443']), isFalse);
      expect(hit('https://anything.test/', ['*']), isTrue);
    });

    test('CIDR and <local>', () {
      expect(hit('http://192.168.5.9/', ['192.168.0.0/16']), isTrue);
      expect(hit('http://192.169.5.9/', ['192.168.0.0/16']), isFalse);
      expect(hit('http://10.0.0.1/', ['10.0.0.0/8']), isTrue);
      expect(hit('http://intranet/', ['<local>']), isTrue);
      expect(hit('http://intranet.corp/', ['<local>']), isFalse);
      expect(hit('http://printer/', [], simple: true), isTrue);
    });

    test('user-typed list splits on commas, semicolons and spaces', () {
      expect(parseBypassList('a.com, b.com;c.com\n d.com'), [
        'a.com',
        'b.com',
        'c.com',
        'd.com',
      ]);
    });
  });

  group('snapshot', () {
    test('per-scheme static proxies', () {
      final s = SystemProxySnapshot.fromMap({
        'http': 'h.corp:3128',
        'https': 'https.corp:3129',
        'bypass': ['*.internal'],
      });
      expect(s.mode, SnapshotMode.staticProxy);
      expect(
        s.decide(Uri.parse('http://x.test/')).findProxyString,
        'PROXY h.corp:3128',
      );
      expect(
        s.decide(Uri.parse('https://x.test/')).findProxyString,
        'PROXY https.corp:3129',
      );
      expect(
        s.decide(Uri.parse('wss://x.test/')).findProxyString,
        'PROXY https.corp:3129',
      );
      expect(s.decide(Uri.parse('https://a.internal/')).isDirect, isTrue);
    });

    test('https falls back to the http proxy', () {
      final s = SystemProxySnapshot.fromMap({'http': 'h:1'});
      expect(
        s.decide(Uri.parse('https://x.test/')).findProxyString,
        'PROXY h:1',
      );
    });

    test('SOCKS-only is direct and flagged', () {
      final s = SystemProxySnapshot.fromMap({'socks': 's:1080'});
      expect(s.socksOnly, isTrue);
      final d = s.decide(Uri.parse('https://x.test/'));
      expect(d.isDirect, isTrue);
      expect(d.skippedUnsupported, isTrue);
    });

    test('PAC wins over static; empty map is none', () {
      expect(
        SystemProxySnapshot.fromMap({'pacUrl': 'http://pac/x.pac'}).isPac,
        isTrue,
      );
      expect(SystemProxySnapshot.fromMap({'autoDetect': true}).isPac, isTrue);
      expect(SystemProxySnapshot.fromMap({}).mode, SnapshotMode.none);
    });
  });

  group('WinHTTP strings', () {
    test('bare, per-scheme, socks', () {
      final bare = parseWinHttpProxy('proxy:8080');
      expect(bare.http?.authority, 'proxy:8080');
      expect(bare.https?.authority, 'proxy:8080');
      final per = parseWinHttpProxy('http=a:1;https=b:2;socks=c:3');
      expect(per.http?.authority, 'a:1');
      expect(per.https?.authority, 'b:2');
      expect(per.socks?.authority, 'c:3');
      expect(parseWinHttpProxy('http://a:1').http?.authority, 'a:1');
    });

    test('IE configuration to snapshot', () {
      final s = windowsSnapshot(
        const WindowsIeProxy(
          proxy: 'http=a:1;https=a:1',
          bypass: '<local>;*.corp.com;10.*',
        ),
      );
      expect(s.mode, SnapshotMode.staticProxy);
      expect(s.bypass.excludeSimpleHostnames, isTrue);
      expect(s.decide(Uri.parse('https://x.corp.com/')).isDirect, isTrue);
      expect(s.decide(Uri.parse('http://10.2.3.4/')).isDirect, isTrue);
      expect(s.decide(Uri.parse('http://intranet/')).isDirect, isTrue);
      expect(
        s.decide(Uri.parse('https://api.raft.build/')).findProxyString,
        'PROXY a:1',
      );
      final auto = windowsSnapshot(const WindowsIeProxy(autoDetect: true));
      expect(auto.isPac, isTrue);
      final pac = windowsSnapshot(
        const WindowsIeProxy(pacUrl: 'http://wpad/wpad.dat'),
      );
      expect(pac.pacUrl, 'http://wpad/wpad.dat');
      expect(windowsSnapshot(const WindowsIeProxy()).mode, SnapshotMode.none);
      final socks = windowsSnapshot(
        const WindowsIeProxy(proxy: 'socks=s:1080'),
      );
      expect(socks.socksOnly, isTrue);
    });
  });

  group('Linux desktop configuration', () {
    test('GNOME manual', () {
      final s = gnomeSnapshot('''
org.gnome.system.proxy autoconfig-url ''
org.gnome.system.proxy ignore-hosts ['localhost', '127.0.0.0/8', '*.corp.test']
org.gnome.system.proxy mode 'manual'
org.gnome.system.proxy use-same-proxy true
org.gnome.system.proxy.http authentication-password ''
org.gnome.system.proxy.http authentication-user ''
org.gnome.system.proxy.http enabled true
org.gnome.system.proxy.http host 'proxy.corp'
org.gnome.system.proxy.http port 3128
org.gnome.system.proxy.http use-authentication false
org.gnome.system.proxy.https host 'sproxy.corp'
org.gnome.system.proxy.https port 3129
org.gnome.system.proxy.socks host ''
org.gnome.system.proxy.socks port 0
''')!;
      expect(s.mode, SnapshotMode.staticProxy);
      expect(
        s.decide(Uri.parse('http://x.test/')).findProxyString,
        'PROXY proxy.corp:3128',
      );
      expect(
        s.decide(Uri.parse('https://x.test/')).findProxyString,
        'PROXY sproxy.corp:3129',
      );
      expect(s.decide(Uri.parse('https://a.corp.test/')).isDirect, isTrue);
    });

    test('GNOME none, auto with and without a PAC URL, SOCKS only', () {
      expect(
        gnomeSnapshot("org.gnome.system.proxy mode 'none'")!.mode,
        SnapshotMode.none,
      );
      final pac = gnomeSnapshot('''
org.gnome.system.proxy autoconfig-url 'http://pac.corp/proxy.pac'
org.gnome.system.proxy mode 'auto'
''')!;
      expect(pac.isPac, isTrue);
      expect(pac.pacUrl, 'http://pac.corp/proxy.pac');
      final wpad = gnomeSnapshot('''
org.gnome.system.proxy autoconfig-url ''
org.gnome.system.proxy mode 'auto'
''')!;
      expect(wpad.autoDetect, isTrue);
      final socks = gnomeSnapshot('''
org.gnome.system.proxy mode 'manual'
org.gnome.system.proxy.http host ''
org.gnome.system.proxy.http port 8080
org.gnome.system.proxy.socks host 'sx'
org.gnome.system.proxy.socks port 1080
''')!;
      expect(socks.socksOnly, isTrue);
      expect(gnomeSnapshot(''), isNull);
    });

    test('KDE kioslaverc', () {
      final manual = kdeSnapshot('''
[Proxy Settings]
ProxyType=1
httpProxy=http://kde.proxy:3128
httpsProxy=kde.sproxy 3129
NoProxyFor=localhost,.intranet,192.168.0.0/16
ReversedException=false

[Other]
x=1
''')!;
      expect(
        manual.decide(Uri.parse('http://a.test/')).findProxyString,
        'PROXY kde.proxy:3128',
      );
      expect(
        manual.decide(Uri.parse('https://a.test/')).findProxyString,
        'PROXY kde.sproxy:3129',
      );
      expect(manual.decide(Uri.parse('http://x.intranet/')).isDirect, isTrue);
      expect(manual.decide(Uri.parse('http://192.168.1.2/')).isDirect, isTrue);
      final pac = kdeSnapshot('''
[Proxy Settings]
ProxyType=2
Proxy Config Script=http://kde/pac.js
''')!;
      expect(pac.pacUrl, 'http://kde/pac.js');
      expect(kdeSnapshot('[Proxy Settings]\nProxyType=3')!.autoDetect, isTrue);
      expect(
        kdeSnapshot('[Proxy Settings]\nProxyType=0')!.mode,
        SnapshotMode.none,
      );
      expect(
        kdeSnapshot('[Proxy Settings]\nProxyType=4')!.mode,
        SnapshotMode.none,
      );
      expect(kdeSnapshot('[General]\nx=1'), isNull);
    });

    test('resolver prefers an active GNOME mode, else KDE', () async {
      final gnome = LinuxProxyResolver(
        gsettings: () async => "org.gnome.system.proxy mode 'none'",
        kioslaverc: () async =>
            '[Proxy Settings]\nProxyType=1\nhttpProxy=http://k:1',
      );
      expect((await gnome.snapshot()).http?.authority, 'k:1');
      final both = LinuxProxyResolver(
        gsettings: () async => '''
org.gnome.system.proxy mode 'manual'
org.gnome.system.proxy.http host 'g'
org.gnome.system.proxy.http port 2
''',
        kioslaverc: () async =>
            '[Proxy Settings]\nProxyType=1\nhttpProxy=http://k:1',
      );
      expect((await both.snapshot()).http?.authority, 'g:2');
      final none = LinuxProxyResolver(
        gsettings: () async => null,
        kioslaverc: () async => null,
        pacAvailable: false,
      );
      expect((await none.snapshot()).mode, SnapshotMode.none);
    });
  });

  group('settings', () {
    test('toString never carries the password', () {
      const s = ProxySettings(
        mode: ProxyMode.manual,
        host: 'p',
        port: 1,
        username: 'alice',
        password: 'hunter2-secret',
      );
      expect(s.toString(), isNot(contains('hunter2')));
      expect(s.toString(), isNot(contains('alice')));
    });

    test('credential limits imposed by the dart:io proxy string', () {
      ProxySettings with_(String u, String p) =>
          ProxySettings(username: u, password: p);
      expect(with_('a', 'b').credentialsProblem, isNull);
      expect(with_('a', 'p:ss@w;rd').credentialsProblem, 'semicolon');
      expect(with_('a', 'p:ss@word').credentialsProblem, isNull);
      expect(with_('a:b', 'x').credentialsProblem, 'username-colon');
      expect(with_('a', ' x').credentialsProblem, 'whitespace');
      expect(with_('a', '').credentialsProblem, 'password-empty');
      expect(const ProxySettings().credentialsProblem, isNull);
    });
  });

  group('this machine (Linux only)', () {
    test(
      'the real gsettings / kioslaverc / libproxy queries run cleanly',
      () async {
        final resolver = LinuxProxyResolver();
        final snapshot = await resolver.snapshot();
        expect(SnapshotMode.values, contains(snapshot.mode));
        if (resolver.canResolvePac) {
          final entries = await resolver.resolve(
            Uri.parse('https://example.com/'),
          );
          expect(entries, isA<List<ProxyEntry>>());
        }
      },
      skip: !Platform.isLinux,
    );
  });
}
