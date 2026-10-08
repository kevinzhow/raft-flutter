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
