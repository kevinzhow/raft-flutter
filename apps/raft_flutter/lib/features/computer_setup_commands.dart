/// Native instructions for the pinned Web Computer install/setup contract.
/// This configuration contains no credentials; commands are copy-only.
class ComputerSetupCommands {
  const ComputerSetupCommands(this.install, this.setup);
  final String install, setup;
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
    final base = staging
        ? 'https://slock-cdn-staging.botiverse.dev/computer/staging'
        : 'https://cdn.raft.build/computer';
    final pin = version?.trim();
    final validPin =
        pin != null &&
            RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(pin)
        ? pin
        : null;
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
      final env = [
        if (staging) '\$env:RAFT_COMPUTER_RELEASE_BASE = "$base"',
        if (staging) '\$env:RAFT_COMPUTER_INSTALL_CHANNEL = "alpha"',
        if (validPin != null) '\$env:RAFT_COMPUTER_VERSION = "$validPin"',
      ];
      final install =
          '${env.isNotEmpty ? '${env.join('; ')}; ' : ''}irm ${staging ? '"\$env:RAFT_COMPUTER_RELEASE_BASE/install.ps1"' : '$base/install.ps1'} | iex';
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
    final env = [
      if (staging) 'RAFT_COMPUTER_RELEASE_BASE=$base',
      if (staging) 'RAFT_COMPUTER_INSTALL_CHANNEL=alpha',
      if (validPin != null) 'RAFT_COMPUTER_VERSION=$validPin',
    ];
    final install =
        'curl -fsSL $base/install.sh | ${env.isNotEmpty ? '${env.join(' ')} ' : ''}sh';
    if (!isolated) return ComputerSetupCommands(install, 'raft-computer $args');
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
    required this.restartService,
    required this.restart,
    required this.stop,
    required this.start,
  });
  final String install, setup, status, doctor, restartService, restart;
  final String stop, start;

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
    final base = staging
        ? 'https://slock-cdn-staging.botiverse.dev/computer/staging'
        : 'https://cdn.raft.build/computer';
    final pin = version?.trim();
    final validPin =
        pin != null &&
            RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$').hasMatch(pin)
        ? pin
        : null;
    String unixInstall() {
      final env = [
        if (staging) 'RAFT_COMPUTER_RELEASE_BASE=$base',
        if (staging) 'RAFT_COMPUTER_INSTALL_CHANNEL=alpha',
        if (validPin != null) 'RAFT_COMPUTER_VERSION=$validPin',
      ];
      return 'curl -fsSL $base/install.sh | ${env.isNotEmpty ? '${env.join(' ')} ' : ''}sh';
    }

    String windowsInstall() {
      final env = [
        if (staging) '\$env:RAFT_COMPUTER_RELEASE_BASE = "$base"',
        if (staging) '\$env:RAFT_COMPUTER_INSTALL_CHANNEL = "alpha"',
        if (validPin != null) '\$env:RAFT_COMPUTER_VERSION = "$validPin"',
      ];
      final url = staging
          ? '"\$env:RAFT_COMPUTER_RELEASE_BASE/install.ps1"'
          : '$base/install.ps1';
      return '${env.isNotEmpty ? '${env.join('; ')}; ' : ''}irm $url | iex';
    }

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
        restartService: '$environment $binary restart',
        restart: '$environment $binary restart /$s',
        stop: '$environment $binary stop',
        start: '$environment $binary start',
      );
    }
    return ComputerCommands(
      install: windows ? windowsInstall() : unixInstall(),
      setup: 'raft-computer setup /$s$setupArgs',
      status: 'raft-computer status',
      doctor: 'raft-computer doctor',
      restartService: 'raft-computer restart',
      restart: 'raft-computer restart /$s',
      stop: 'raft-computer stop',
      start: 'raft-computer start',
    );
  }
}
