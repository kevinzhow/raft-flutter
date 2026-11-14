/// Web utils/computerSetupCommand.ts (v1.24): every environment installs from
/// the production CDN; staging adds `--channel alpha` unless a version is
/// pinned (the installer rejects the two together).
const computerCdnBase = 'https://cdn.raft.build/computer';
const stagingComputerChannel = 'alpha';

/// COMPUTER_INSTALL_DOCS_URL: the "Install guide" link.
const computerInstallDocsUrl =
    'https://docs.raft.build/features/server/computers/#connecting-a-computer';

String? _versionPin(String? version) {
  final pin = version?.trim();
  return pin != null &&
          RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(pin)
      ? pin
      : null;
}

List<String> _channelArgs(String deployment, String? pin) =>
    deployment == 'staging' && pin == null
    ? const ['--channel', stagingComputerChannel]
    : const [];

/// computerInstallShellCommand: `curl … | sh`, with the installer's own
/// arguments (`-s -- --channel alpha --setup …`) in one list.
String computerInstallShellCommand(
  String deployment,
  String? version, [
  List<String> extraArgs = const [],
]) {
  final pin = _versionPin(version);
  final env = pin != null ? 'RAFT_COMPUTER_VERSION=$pin ' : '';
  final args = [..._channelArgs(deployment, pin), ...extraArgs];
  return 'curl -fsSL $computerCdnBase/install.sh | ${env}sh'
      '${args.isNotEmpty ? ' -s -- ${args.join(' ')}' : ''}';
}

/// windowsComputerInstallCommand.
String windowsComputerInstallCommand(String deployment, String? version) {
  final pin = _versionPin(version);
  final env = pin != null ? '\$env:RAFT_COMPUTER_VERSION = "$pin"; ' : '';
  final args = _channelArgs(deployment, pin);
  return args.isNotEmpty
      ? '$env& ([scriptblock]::Create((irm $computerCdnBase/install.ps1))) ${args.join(' ')}'
      : '${env}irm $computerCdnBase/install.ps1 | iex';
}

/// Native instructions for the pinned Web Computer install/setup contract.
/// This configuration contains no credentials; commands are copy-only.
class ComputerSetupCommands {
  const ComputerSetupCommands(this.install, this.setup, [this.installAndSetup]);
  final String install, setup;

  /// mac/Linux production only: install, then run setup with the installed
  /// binary, in one paste (Web `ComputerCommands.installAndSetup`).
  final String? installAndSetup;
  static ComputerSetupCommands? build({
    required String slug,
    required String serverUrl,
    String deployment = const String.fromEnvironment(
      'RAFT_DEPLOYMENT_ENV',
      defaultValue: 'production',
    ),
    bool windows = false,
    String? version,
  }) {
    final normalized = slug.trim().replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(normalized)) {
      return null;
    }
    final staging = deployment == 'staging';
    final isolated = staging || deployment == 'slockdev';
    final destination = staging
        ? 'https://api-aws-staging.botiverse.dev'
        : serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final defaultServer = [
      'https://api.raft.build',
      'https://api.slock.ai',
    ].contains(destination);
    final includeServer = staging || deployment == 'slockdev' || !defaultServer;
    final args =
        'setup /$normalized${includeServer ? ' --server-url ${windows ? _powerShellQuote(destination) : _shellQuote(destination)}' : ''}';
    if (windows) {
      final install = windowsComputerInstallCommand(deployment, version);
      if (!isolated) {
        return ComputerSetupCommands(install, 'raft-computer $args');
      }
      final environment =
          '\$env:RAFT_HOME = "\$env:USERPROFILE\\.raft-computer-$normalized"; \$env:RAFT_COMPUTER_INSTALL_DIR = "\$env:RAFT_HOME\\bin";';
      return ComputerSetupCommands(
        '$environment $install',
        '$environment & "\$env:RAFT_COMPUTER_INSTALL_DIR\\raft-computer.exe" $args',
      );
    }
    final install = computerInstallShellCommand(deployment, version);
    if (!isolated) {
      return ComputerSetupCommands(
        install,
        'raft-computer $args',
        computerInstallShellCommand(deployment, version, ['--$args']),
      );
    }
    final home = '\$HOME/.raft-computer-$normalized';
    final environment =
        'RAFT_HOME="$home" RAFT_COMPUTER_INSTALL_DIR="$home/bin"';
    return ComputerSetupCommands(
      '$environment sh -c ${_shellQuote(install)}',
      '$environment "$home/bin/raft-computer" $args',
    );
  }
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";
String _powerShellQuote(String value) => "'${value.replaceAll("'", "''")}'";

/// Web utils/computerSetupCommand.ts getComputerCommands: the full command
/// bundle the Computer pages show (install, setup, status, doctor, restart
/// of the whole service, restart scoped to this server, stop, start).
class ComputerCommands {
  const ComputerCommands({
    required this.install,
    required this.setup,
    required this.status,
    required this.doctor,
    required this.upgrade,
    required this.restartService,
    required this.restart,
    required this.stop,
    required this.start,
    this.installAndSetup,
  });
  final String install, setup, status, doctor, restartService, restart;

  /// `raft-computer upgrade` (an old Computer's no-response hint).
  final String upgrade;
  final String stop, start;

  /// mac/Linux production only: install, then run setup with the installed
  /// binary, in one paste (`… | sh -s -- --setup /slug`). Null where install
  /// and setup stay separate steps (Windows, isolated test deployments).
  final String? installAndSetup;

  /// [deployment] is VITE_DEPLOYMENT_ENV: `production` adds `--server-url`
  /// only for a non-default server, `staging`/`slockdev` isolate the home,
  /// anything else (an unset Vite dev env) passes no server URL.
  static ComputerCommands? build({
    required String slug,
    required String serverUrl,
    String deployment = const String.fromEnvironment(
      'RAFT_DEPLOYMENT_ENV',
      defaultValue: 'production',
    ),
    bool windows = false,
    String? machineId,
    String? version,
  }) {
    final s = slug.trim().replaceFirst(RegExp(r'^/+'), '');
    if (s.isEmpty) return null;
    final normalized = serverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final isDefault = const [
      'https://api.raft.build',
      'https://api.slock.ai',
    ].contains(normalized);
    final commandServerUrl = deployment == 'production'
        ? (isDefault ? null : serverUrl)
        : deployment == 'staging'
        ? 'https://api-aws-staging.botiverse.dev'
        : deployment == 'slockdev'
        ? serverUrl
        : null;
    final setupArgs =
        '${commandServerUrl != null ? ' --server-url $commandServerUrl' : ''}'
        '${machineId != null ? ' --machine $machineId' : ''}';
    final staging = deployment == 'staging';
    String unixInstall() => computerInstallShellCommand(deployment, version);
    String windowsInstall() =>
        windowsComputerInstallCommand(deployment, version);

    if (staging || deployment == 'slockdev') {
      if (windows) {
        final home = '\$env:USERPROFILE\\.raft-computer-$s';
        final environment =
            '\$env:RAFT_HOME = "$home"; \$env:RAFT_COMPUTER_INSTALL_DIR = "\$env:RAFT_HOME\\bin";';
        const binary = '& "\$env:RAFT_COMPUTER_INSTALL_DIR\\raft-computer.exe"';
        return ComputerCommands(
          install: '$environment ${windowsInstall()}',
          setup: '$environment $binary setup /$s$setupArgs',
          status: '$environment $binary status',
          doctor: '$environment $binary doctor',
          upgrade: '$environment $binary upgrade',
          restartService: '$environment $binary restart',
          restart: '$environment $binary restart /$s',
          stop: '$environment $binary stop',
          start: '$environment $binary start',
        );
      }
      final home = '\$HOME/.raft-computer-$s';
      final environment =
          'RAFT_HOME="$home" RAFT_COMPUTER_INSTALL_DIR="$home/bin"';
      final binary = '"$home/bin/raft-computer"';
      return ComputerCommands(
        install: "$environment sh -c '${unixInstall()}'",
        setup: '$environment $binary setup /$s$setupArgs',
        status: '$environment $binary status',
        doctor: '$environment $binary doctor',
        upgrade: '$environment $binary upgrade',
        restartService: '$environment $binary restart',
        restart: '$environment $binary restart /$s',
        stop: '$environment $binary stop',
        start: '$environment $binary start',
      );
    }
    return ComputerCommands(
      install: windows ? windowsInstall() : unixInstall(),
      setup: 'raft-computer setup /$s$setupArgs',
      installAndSetup: windows
          ? null
          : computerInstallShellCommand(deployment, version, [
              '--setup /$s$setupArgs',
            ]),
      status: 'raft-computer status',
      doctor: 'raft-computer doctor',
      upgrade: 'raft-computer upgrade',
      restartService: 'raft-computer restart',
      restart: 'raft-computer restart /$s',
      stop: 'raft-computer stop',
      start: 'raft-computer start',
    );
  }
}
