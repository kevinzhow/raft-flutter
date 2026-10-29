import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/features/desktop_links_settings.dart';
import 'package:raft_flutter/platform/linux_uri_scheme.dart';
import 'package:raft_ui/raft_ui.dart';
import 'flutter_test_config.dart' show leakDebt;

class _Store extends LinuxSchemeStore {
  String? stored;
  bool asked = false;
  @override
  Future<String?> choice() async => stored;
  @override
  Future<void> setChoice(String? value) async => stored = value;
  @override
  Future<bool> prompted() async => asked;
  @override
  Future<void> setPrompted() async => asked = true;
}

void main() {
  // Leak debt (app root): see docs/development.md, Leak tracking.
  leakDebt(const ['LinuxUriSchemeRegistration']);
  late Directory root;
  late String handler;
  late _Store store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('raft-links');
    handler = '';
    store = _Store();
  });
  tearDown(() => root.deleteSync(recursive: true));

  LinuxUriSchemeRegistration service() => LinuxUriSchemeRegistration(
    environment: {
      'HOME': root.path,
      'XDG_DATA_HOME': p.join(root.path, 'data'),
      'XDG_CONFIG_HOME': p.join(root.path, 'config'),
      'PATH': '/usr/bin',
      'APPIMAGE': '/a/Raft.AppImage',
    },
    linux: true,
    store: store,
    executable: p.join(root.path, 'raft'),
    toolExists: (_) => true,
    run: (exe, args, env) async {
      if (p.basename(exe) == 'xdg-mime' && args.first == 'default') {
        handler = args[1];
      }
      // A removed launcher is no longer a handler, as on a real desktop.
      final gone =
          handler.startsWith('app.raft') &&
          !File(
            p.join(root.path, 'data', 'applications', handler),
          ).existsSync();
      return (exitCode: 0, stdout: gone ? '' : handler);
    },
  );

  Widget host(LinuxUriSchemeRegistration s) => MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en')],
    theme: raftTheme(dark: false),
    home: Scaffold(
      body: SingleChildScrollView(child: DesktopLinksSettings(service: s)),
    ),
  );

  Finder key(String name) => find.byKey(ValueKey(name));
  bool on(WidgetTester t) =>
      t.widget<RaftSwitch>(key('raft-uri-scheme-switch')).value;

  testWidgets('the switch registers and unregisters this launcher', (t) async {
    final s = service();
    await t.runAsync(s.ensure);
    await t.pumpWidget(host(s));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(on(t), isTrue);
    expect(find.text('Open raft:// links with this app'), findsOneWidget);
    await t.tap(key('raft-uri-scheme-switch'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(on(t), isFalse);
    expect(store.stored, 'disabled');
    await t.tap(key('raft-uri-scheme-switch'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(on(t), isTrue);
    expect(store.stored, 'enabled');
  });

  testWidgets('another handler gets a one-time prompt, never a silent change', (
    t,
  ) async {
    handler = 'org.example.Chat.desktop';
    final s = service();
    await t.runAsync(s.ensure);
    await t.pumpWidget(host(s));
    expect(on(t), isFalse);
    expect(key('raft-uri-scheme-other'), findsOneWidget);
    expect(find.textContaining('org.example.Chat.desktop'), findsOneWidget);
    expect(key('raft-uri-scheme-use'), findsOneWidget);
    expect(handler, 'org.example.Chat.desktop');

    await t.tap(key('raft-uri-scheme-keep'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(key('raft-uri-scheme-use'), findsNothing);
    expect(key('raft-uri-scheme-other'), findsOneWidget);
    expect(handler, 'org.example.Chat.desktop');

    // The switch stays available as the explicit consent.
    await t.tap(key('raft-uri-scheme-switch'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    expect(on(t), isTrue);
    expect(handler, 'app.raft.raft_flutter-appimage.desktop');
  });
}
