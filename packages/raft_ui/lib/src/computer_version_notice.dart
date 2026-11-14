// Web components/machine/ComputerVersionNotice.tsx + ComputerManualInstall.tsx
// (v1.24.0): the always-on warning at the top of a Computer's page when its
// version is below the floor. The app decides the tier; this draws it.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// `upgrade`: the web can upgrade it (one click or the manual install);
/// `reinstall`: too old for that, or no SemVer version reported.
enum RaftComputerVersionNoticeKind { upgrade, reinstall }

/// One copyable manual-install line (the Add Computer dialog's command for
/// this machine's platform).
typedef RaftComputerInstallLine = ({
  String? label,
  String command,
  String copyLabel,
});

class RaftComputerVersionNoticeData {
  const RaftComputerVersionNoticeData({
    required this.kind,
    required this.unknown,
    required this.enforced,
    required this.minVersion,
    required this.canManage,
    this.computerVersion,
    this.dateLabel,
    this.upgradeTargetVersion,
    this.manualInstall = false,
    this.installLines = const [],
  });
  final RaftComputerVersionNoticeKind kind;

  /// The gate's reason is `computer_version_unknown` (no SemVer version).
  final bool unknown;
  final bool enforced;
  final String minVersion;
  final bool canManage;
  final String? computerVersion;

  /// The enforcement date, already formatted for the display language.
  final String? dateLabel;

  /// Set when the Computer card offers its one-click upgrade.
  final String? upgradeTargetVersion;

  /// The card gives the manual install instead of one click.
  final bool manualInstall;
  final List<RaftComputerInstallLine> installLines;
}

class RaftComputerVersionNotice extends StatelessWidget {
  const RaftComputerVersionNotice({
    super.key,
    required this.data,
    required this.onUpgrade,
    required this.onOpenInstallGuide,
  });
  final RaftComputerVersionNoticeData data;
  final VoidCallback onUpgrade;
  final VoidCallback onOpenInstallGuide;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final upgrade = d.kind == RaftComputerVersionNoticeKind.upgrade;
    final date = d.dateLabel;
    final title = d.enforced
        ? raftText(
            context,
            d.unknown
                ? "Agents on this computer aren't running: it doesn't report its version"
                : "Agents on this computer aren't running: the version is too old",
          )
        : upgrade
        ? date != null
              ? raftFormat(
                  context,
                  'Upgrade soon: from {date}, agents on this computer stop running',
                  {'date': date},
                )
              : raftText(context, 'Upgrade soon')
        : date != null
        ? raftFormat(
            context,
            'Reinstall soon: from {date}, agents on this computer stop running',
            {'date': date},
          )
        : raftText(
            context,
            d.unknown
                ? "This computer doesn't report its version"
                : 'This version needs a reinstall',
          );
    final version = d.computerVersion;
    final body = upgrade
        ? raftFormat(
            context,
            'v{version} is out of date. Please upgrade to v{floor} or later.',
            {'version': version ?? '', 'floor': d.minVersion},
          )
        : d.unknown || version == null
        ? raftText(
            context,
            "This computer doesn't report its version, so it's too old for Raft. Reinstall it to keep its agents running. Run this on that machine:",
          )
        : raftFormat(
            context,
            'v{version} is too old to upgrade from here. Run this on that machine to reinstall Raft Computer:',
            {'version': version},
          );
    final target = d.upgradeTargetVersion;
    final showUpgrade = upgrade && d.canManage && target != null;
    final t = RaftTokens.of(context);
    return RaftBanner(
      key: const ValueKey('computer-version-notice'),
      live: false,
      title: title,
      titleGap: 4,
      description: body,
      size: RaftBannerRecipeSize.sm,
      action: showUpgrade
          ? RaftAgentDialogButton(
              key: const ValueKey('computer-version-notice-upgrade'),
              label: raftFormat(context, 'Upgrade to v{version}', {
                'version': target,
              }),
              size: RaftButtonRecipeSize.md,
              onPressed: onUpgrade,
            )
          : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!d.canManage)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                raftText(
                  context,
                  upgrade
                      ? 'Ask an admin to upgrade it.'
                      : 'Ask an admin to reinstall it.',
                ),
                style: RaftTypography.body(t, size: 14, line: 20),
              ),
            ),
          if (d.canManage && (!upgrade || d.manualInstall))
            Padding(
              key: const ValueKey('computer-version-notice-reinstall'),
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in d.installLines) ...[
                    if (line.label != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line.label!,
                          style: RaftTypography.body(
                            t,
                            size: 12,
                            line: 16,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    RaftCopyableCode(line.command, copyLabel: line.copyLabel),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RaftUnderlineTextButton(
                      key: const ValueKey('computer-version-notice-docs'),
                      label: raftText(context, 'Install guide'),
                      style: RaftTypography.body(
                        t,
                        size: 14,
                        line: 20,
                        weight: FontWeight.w700,
                      ),
                      onPressed: onOpenInstallGuide,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
