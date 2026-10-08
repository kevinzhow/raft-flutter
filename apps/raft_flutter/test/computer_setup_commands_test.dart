import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/computer_setup_commands.dart';

void main() {
  test('production preserves default Computer and custom server targeting', () {
    final production = ComputerSetupCommands.build(
      slug: '/work',
      serverUrl: 'https://api.raft.build/',
      deployment: 'production',
    )!;
    expect(
      production.install,
      'curl -fsSL https://cdn.raft.build/computer/install.sh | sh',
    );
    expect(production.setup, 'raft-computer setup /work');
    expect(production.install, isNot(contains('RAFT_HOME')));
    final custom = ComputerSetupCommands.build(
      slug: 'work',
      serverUrl: 'https://example.invalid',
      deployment: 'production',
    )!;
    expect(
      custom.setup,
      "raft-computer setup /work --server-url 'https://example.invalid'",
    );
  });
  test('staging Linux installs and invokes the same isolated Computer', () {
    final commands = ComputerSetupCommands.build(
      slug: 'work',
      serverUrl: 'https://unused.invalid',
      deployment: 'staging',
      version: '1.2.3-alpha.4',
    )!;
    for (final command in [commands.install, commands.setup]) {
      expect(command, contains(r'RAFT_HOME="$HOME/.raft-computer-work"'));
      expect(
        command,
        contains(r'RAFT_COMPUTER_INSTALL_DIR="$HOME/.raft-computer-work/bin"'),
      );
    }
    expect(
      commands.install,
      contains(
        'https://slock-cdn-staging.botiverse.dev/computer/staging/install.sh',
      ),
    );
    expect(commands.install, contains('RAFT_COMPUTER_INSTALL_CHANNEL=alpha'));
    expect(commands.install, contains('RAFT_COMPUTER_VERSION=1.2.3-alpha.4'));
    expect(
      commands.setup,
      contains(r'"$HOME/.raft-computer-work/bin/raft-computer"'),
    );
    expect(
      commands.setup,
      contains("--server-url 'https://api-aws-staging.botiverse.dev'"),
    );
  });
  test(
    'development Windows keeps isolated home and executable with custom server',
    () {
      final commands = ComputerSetupCommands.build(
        slug: 'work',
        serverUrl: 'http://localhost:3000',
        deployment: 'slockdev',
        windows: true,
      )!;
      for (final command in [commands.install, commands.setup]) {
        expect(
          command,
          contains(r'$env:RAFT_HOME = "$env:USERPROFILE\.raft-computer-work"'),
        );
        expect(
          command,
          contains(r'$env:RAFT_COMPUTER_INSTALL_DIR = "$env:RAFT_HOME\bin"'),
        );
      }
      expect(
        commands.install,
        contains('https://cdn.raft.build/computer/install.ps1'),
      );
      expect(
        commands.setup,
        contains(r'& "$env:RAFT_COMPUTER_INSTALL_DIR\raft-computer.exe"'),
      );
      expect(commands.setup, contains("--server-url 'http://localhost:3000'"));
    },
  );
  test('unsafe workspace name is not rendered as an executable command', () {
    expect(
      ComputerSetupCommands.build(
        slug: r'work$(touch /tmp/unsafe)',
        serverUrl: 'https://api.raft.build',
      ),
      isNull,
    );
    expect(
      ComputerSetupCommands.build(
        slug: '',
        serverUrl: 'https://api.raft.build',
      ),
      isNull,
    );
    final commands = ComputerSetupCommands.build(
      slug: 'work',
      serverUrl: 'https://api.raft.build',
      version: '1.2.3;unsafe',
    )!;
    expect(commands.install, isNot(contains('RAFT_COMPUTER_VERSION')));
  });
}
