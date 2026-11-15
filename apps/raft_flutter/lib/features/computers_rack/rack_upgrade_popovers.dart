// RackRowAction's two popovers (Web v1.24 features/computer/RackRowAction.tsx
// :96-150): "Upgrade to v…" for a Computer the web cannot upgrade opens the
// command to run on that machine; beside a one-click Upgrade, a warning icon
// opens why the web upgrade may fail (the failed request's cause, or the
// installer repair advice) with the same command.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../computer_setup_commands.dart';

/// What the hint says: a failed request's cause, or "repair first".
class RackUpgradeHint {
  const RackUpgradeHint.failure(RaftUpgradeFailureHint this.failure);
  const RackUpgradeHint.repair() : failure = null;
  final RaftUpgradeFailureHint? failure;
}

void _openInstallGuide() => launchUrl(
  Uri.parse(computerInstallDocsUrl),
  mode: LaunchMode.externalApplication,
);

/// `manualUpgrade`: the row button with its popover.
class RackManualUpgradeButton extends StatelessWidget {
  const RackManualUpgradeButton({
    super.key,
    required this.machineId,
    required this.version,
    required this.lines,
  });
  final String machineId, version;
  final List<RaftComputerInstallLine> lines;

  @override
  Widget build(BuildContext context) => RaftRackRowPopover(
    popoverKey: const ValueKey('rack-manual-upgrade-popover'),
    trigger: (context, focus, toggle) => RaftButton(
      key: ValueKey('rack-manual-upgrade-$machineId'),
      label: raftFormat(context, 'Upgrade to v{version}', {'version': version}),
      // Not the one-click mark: this one opens the command to run there.
      glyph: RaftGlyph.terminal,
      secondary: true,
      focusNode: focus,
      onPressed: toggle,
    ),
    noteBuilder: (context, style) => RaftCssText(
      raftFormat(
        context,
        "v{version} is available. This computer can't be upgraded from the web; run this on that machine instead:",
        {'version': version},
      ),
      style: style,
    ),
    child: RaftComputerManualInstall(
      lines: lines,
      onOpenInstallGuide: _openInstallGuide,
    ),
  );
}

/// `oneClick` with a failure or repair hint: the warning icon before Upgrade.
class RackUpgradeHintButton extends StatelessWidget {
  const RackUpgradeHintButton({
    super.key,
    required this.machineId,
    required this.version,
    required this.hint,
    required this.lines,
  });
  final String machineId, version;
  final RackUpgradeHint hint;
  final List<RaftComputerInstallLine> lines;

  @override
  Widget build(BuildContext context) {
    final failure = hint.failure;
    final kind = failure != null ? 'upgrade-failure-hint' : 'repair-hint';
    final label = raftText(
      context,
      failure != null
          ? 'Why the web upgrade failed'
          : 'Why upgrading from the web may fail',
    );
    final warning = RaftTokens.of(context).colors['warning-strong'];
    return RaftRackRowPopover(
      popoverKey: ValueKey('rack-$kind-popover'),
      trigger: (context, focus, toggle) => RaftButton(
        key: ValueKey('rack-$kind-$machineId'),
        glyph: RaftGlyph.alertTriangle,
        foreground: warning,
        tooltip: label,
        semanticLabel: label,
        tone: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.iconMd,
        focusNode: focus,
        onPressed: toggle,
      ),
      noteBuilder: (context, style) => failure != null
          ? RaftUpgradeFailureHintText(hint: failure, style: style)
          : RaftCssText(
              raftFormat(
                context,
                'An earlier installation on this computer was not finished, and upgrading from the web may fail until it is repaired. Recommended: run the install command on that machine once; it repairs the installation and installs v{version}.',
                {'version': version},
              ),
              style: style,
            ),
      child: RaftComputerManualInstall(
        lines: lines,
        onOpenInstallGuide: _openInstallGuide,
      ),
    );
  }
}
