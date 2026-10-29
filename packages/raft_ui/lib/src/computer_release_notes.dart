// Web machine/ComputerReleaseNotesAffordance.tsx: the "What's new" link beside
// a Computer's "update available" hint. It opens the latest Computer version's
// release notes (markdown, from the machines read) in a dialog. Display only:
// no upgrade or other action.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// The notes of the version a Computer can upgrade to, already in the UI
/// language (the app picks the locale).
class RaftComputerReleaseNotes {
  const RaftComputerReleaseNotes({required this.version, required this.text});
  final String version, text;
}

/// `<TextLink variant="primary" className="text-xs">`: accent, medium weight,
/// underline on hover.
class RaftReleaseNotesLink extends StatefulWidget {
  const RaftReleaseNotesLink({super.key, required this.notes});
  final RaftComputerReleaseNotes notes;

  @override
  State<RaftReleaseNotesLink> createState() => _RaftReleaseNotesLinkState();
}

class _RaftReleaseNotesLinkState extends State<RaftReleaseNotesLink> {
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: () => showRaftComputerReleaseNotes(context, widget.notes),
      semanticLabel: raftText(context, "What's new"),
      builder: (context, state) => RaftCssText(
        raftText(context, "What's new"),
        key: const ValueKey('computer-release-notes-open'),
        underline: state.hovered || state.focusVisible,
        style: RaftTypography.body(
          t,
          size: 12,
          line: 16,
          weight: FontWeight.w500,
          color: t.colors['accent-strong'],
        ),
      ),
    );
  }
}

/// `DialogCard max-w-lg closeOnBackdrop`: X, Escape and a press on the
/// backdrop close it.
Future<void> showRaftComputerReleaseNotes(
  BuildContext context,
  RaftComputerReleaseNotes notes,
) {
  return showRaftDialog<void>(
    context: context,
    modal: true,
    legacyModal: true,
    barrierDismissible: true,
    barrierLabel: 'Close',
    builder: (context) => RaftDismissScope(
      child: RaftComputerReleaseNotesDialog(
        notes: notes,
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

class RaftComputerReleaseNotesDialog extends StatelessWidget {
  const RaftComputerReleaseNotesDialog({
    super.key,
    required this.notes,
    required this.onClose,
  });
  final RaftComputerReleaseNotes notes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => RaftDialog.agent(
    surfaceKey: const ValueKey('computer-release-notes-dialog'),
    title: raftFormat(context, "What's new in v{version}", {
      'version': notes.version,
    }),
    maxWidth: 512,
    onClose: onClose,
    onBackdrop: onClose,
    children: [
      // `max-h-[60vh] overflow-y-auto text-sm`.
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .6,
        ),
        child: SingleChildScrollView(
          child: RaftAnnouncementMarkdown(notes.text),
        ),
      ),
    ],
  );
}
