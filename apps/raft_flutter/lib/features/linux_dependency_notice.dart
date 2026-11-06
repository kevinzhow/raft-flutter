import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/linux_dependencies.dart';
import 'appearance_section.dart';

String linuxDependencyName(LinuxDependency feature) => switch (feature) {
  LinuxDependency.webkit => 'Interactive HTML previews',
  LinuxDependency.mpv => 'Audio and video playback',
  LinuxDependency.poppler => 'PDF previews',
};

/// Feature-local remediation composed from existing design-system controls.
/// Retrying belongs to the feature so success restores its actual content.
class LinuxDependencyNotice extends StatelessWidget {
  const LinuxDependencyNotice({
    super.key,
    required this.feature,
    required this.onRetry,
    this.service,
    this.busy = false,
    this.onDownload,
  });
  final LinuxDependency feature;
  final LinuxDependencies? service;
  final VoidCallback? onRetry, onDownload;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final service = this.service ?? LinuxDependencies.instance;
    final status = service.state(feature);
    final backendFailure = {
      'backend_invalid',
      'backend_unavailable',
      'probe_unavailable',
    }.contains(status.reason);
    final command = status.requiresRestart || backendFailure
        ? null
        : service.installCommand(feature);
    final recipe = RaftAppearanceSectionRecipe(RaftTokens.of(context));
    return Semantics(
      container: true,
      child: Padding(
        key: Key('linux-dependency-notice-${feature.name}'),
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: RaftGapColumn(
          gap: RaftSpace.x3,
          children: [
            Text(
              raftText(context, linuxDependencyName(feature)),
              style: recipe.heading,
            ),
            Text(
              raftText(
                context,
                status.requiresRestart
                    ? 'The updated library needs an app restart. Your messages and drafts are kept.'
                    : backendFailure
                    ? 'This preview component could not be loaded. Check for an app update, then try again.'
                    : 'Install the system dependency to use this feature. The rest of Raft remains available.',
              ),
              style: recipe.description,
            ),
            if (command != null) ...[
              RaftSelectionArea(
                key: Key('linux-dependency-command-${feature.name}'),
                child: Text(command),
              ),
              RaftButton(
                key: Key('linux-dependency-copy-${feature.name}'),
                label: 'Copy install command',
                variant: RaftControlVariant.ghost,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: command)),
              ),
            ] else if (!status.requiresRestart && !backendFailure)
              Text(
                raftText(
                  context,
                  'Install the matching runtime package using your distribution’s package manager, then check again.',
                ),
              ),
            Wrap(
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              children: [
                RaftButton(
                  key: Key('linux-dependency-retry-${feature.name}'),
                  label: 'Check again',
                  busy: busy,
                  onPressed: busy ? null : onRetry,
                ),
                if (onDownload != null)
                  RaftButton(
                    label: 'Download Original',
                    variant: RaftControlVariant.ghost,
                    onPressed: onDownload,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
