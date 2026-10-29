import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/computer_setup_commands.dart';

/// Web utils/computerSetupCommand.ts `installAndSetup`: install, then run
/// setup with the installed binary in one paste, mac/Linux production only.
void main() {
  group('ComputerCommands.installAndSetup', () {
    test('production mac/Linux pipes the installer into setup', () {
      final c = ComputerCommands.build(
        slug: 'work',
        serverUrl: 'https://api.raft.build',
        deployment: 'production',
      )!;
      expect(
        c.installAndSetup,
        'curl -fsSL https://cdn.raft.build/computer/install.sh | sh -s -- --setup /work',
      );
    });

    test('a custom server and a version pin ride along', () {
      final c = ComputerCommands.build(
        slug: 'work',
        serverUrl: 'https://example.invalid',
        deployment: 'production',
        version: '1.2.3',
      )!;
      expect(
        c.installAndSetup,
        'curl -fsSL https://cdn.raft.build/computer/install.sh | '
        'RAFT_COMPUTER_VERSION=1.2.3 sh -s -- --setup /work '
        '--server-url https://example.invalid',
      );
    });

    test('Windows and isolated deployments keep separate steps', () {
      for (final (deployment, windows) in [
        ('production', true),
        ('staging', false),
        ('slockdev', false),
        ('staging', true),
      ]) {
        final c = ComputerCommands.build(
          slug: 'work',
          serverUrl: 'https://api.raft.build',
          deployment: deployment,
          windows: windows,
        )!;
        expect(c.installAndSetup, isNull, reason: '$deployment $windows');
      }
    });
  });

  group('ComputerSetupCommands.installAndSetup (setup step)', () {
    test('production mac/Linux', () {
      final c = ComputerSetupCommands.build(
        slug: '/work',
        serverUrl: 'https://api.raft.build/',
        deployment: 'production',
      )!;
      expect(
        c.installAndSetup,
        'curl -fsSL https://cdn.raft.build/computer/install.sh | sh -s -- --setup /work',
      );
    });

    test('none on Windows or in isolated deployments', () {
      expect(
        ComputerSetupCommands.build(
          slug: 'work',
          serverUrl: 'https://api.raft.build',
          deployment: 'production',
          windows: true,
        )!.installAndSetup,
        isNull,
      );
      expect(
        ComputerSetupCommands.build(
          slug: 'work',
          serverUrl: 'https://api.raft.build',
          deployment: 'staging',
        )!.installAndSetup,
        isNull,
      );
    });
  });
}
