import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/linux_dependencies.dart';

import 'linux_dependency_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DependencyHost host;
  late LinuxDependencies service;
  setUp(() {
    host = DependencyHost()..bind();
    service = LinuxDependencies(platformAvailable: () => true);
  });
  tearDown(() {
    host.unbind();
    service.dispose();
  });

  test('concurrent consumers share one pending backend registration', () async {
    host.wait = Completer<void>();
    final first = service.ensure(LinuxDependency.mpv);
    final second = service.ensure(LinuxDependency.mpv);
    await Future<void>.delayed(Duration.zero);
    expect(host.calls.length, 1);
    host.installed.add('mpv');
    host.wait!.complete();
    await Future.wait([first, second]);
    expect(service.state(LinuxDependency.mpv).registered, isTrue);
  });
  test(
    'construction and known-status inspection never load a feature',
    () async {
      expect(host.calls, isEmpty);
      await service.inspect();
      expect(host.calls.single.arguments, isNull);
      expect(
        service.state(LinuxDependency.webkit).status,
        LinuxDependencyStatus.unchecked,
      );
    },
  );
  test(
    'missing is not cached and installation can register without restart',
    () async {
      await expectLater(
        service.ensure(LinuxDependency.mpv),
        throwsA(isA<LinuxDependencyMissing>()),
      );
      host.installed.add('mpv');
      await service.ensure(LinuxDependency.mpv);
      expect(host.calls.length, 2);
      expect(service.state(LinuxDependency.mpv).registered, isTrue);
      expect(service.state(LinuxDependency.mpv).requiresRestart, isFalse);
    },
  );
  test(
    'inspect availability does not replace actual engine registration',
    () async {
      host.installed.add('webkit');
      await service.inspect(LinuxDependency.webkit);
      expect(service.state(LinuxDependency.webkit).available, isTrue);
      expect(service.state(LinuxDependency.webkit).registered, isFalse);
      await service.ensure(LinuxDependency.webkit);
      expect(host.registered, contains('webkit'));
    },
  );
  test('Poppler ensure needs tools, not a plugin registration', () async {
    host.installed.add('poppler');
    await service.ensure(LinuxDependency.poppler);
    expect(service.state(LinuxDependency.poppler).available, isTrue);
    expect(service.state(LinuxDependency.poppler).registered, isFalse);
  });
  test('non Linux callers never touch the native service', () async {
    final other = LinuxDependencies(platformAvailable: () => false);
    await other.ensure(LinuxDependency.mpv);
    await other.checkAll();
    expect(host.calls, isEmpty);
    other.dispose();
  });
  test(
    'commands use verified distro package names and reject unknown families',
    () async {
      await service.inspect();
      expect(
        service.installCommand(LinuxDependency.webkit),
        'sudo apt install libwebkit2gtk-4.1-0',
      );
      expect(
        service.installCommand(LinuxDependency.mpv),
        'sudo apt install libmpv2',
      );
      host.distro = 'fedora';
      host.idLike = '';
      await service.inspect();
      expect(
        service.installCommand(LinuxDependency.webkit),
        'sudo dnf install webkit2gtk4.1',
      );
      expect(
        service.installCommand(LinuxDependency.mpv),
        'sudo dnf install mpv-libs',
      );
      expect(
        service.installCommand(LinuxDependency.poppler),
        'sudo dnf install poppler-utils',
      );
      host.distro = 'arch';
      await service.inspect();
      expect(service.installCommand(LinuxDependency.webkit), isNull);
    },
  );
}
