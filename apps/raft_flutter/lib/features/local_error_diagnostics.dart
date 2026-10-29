import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/local_error_diagnostics.dart';

void showLocalErrorToast(BuildContext context, String message) {
  final sample = LocalErrorDiagnostics.shared.forNotice(message);
  showRaftToast(
    context,
    message,
    actionLabel: sample == null ? null : 'Copy',
    onAction: sample == null
        ? null
        : () => copyLocalErrorDiagnostics(context, sample: sample),
  );
}

Future<bool> copyLocalErrorDiagnostics(
  BuildContext context, {
  LocalErrorDiagnostics? log,
  LocalErrorSample? sample,
}) async {
  final text = (log ?? LocalErrorDiagnostics.shared).export(sample: sample);
  final toast = RaftToastHost.maybeOf(context);
  final title = toast?.title, action = toast?.onAction;
  bool unchanged() => toast?.title == title && toast?.onAction == action;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted && unchanged()) {
      showRaftToast(
        context,
        'Diagnostics copied',
        tone: RaftToastRecipeTone.success,
      );
    }
    return true;
  } catch (_) {
    if (context.mounted && unchanged()) {
      showRaftToast(
        context,
        'Could not copy diagnostics. Try again.',
        actionLabel: 'Copy',
        onAction: () =>
            copyLocalErrorDiagnostics(context, log: log, sample: sample),
      );
    }
    return false;
  }
}

/// Storage always offers this entry, including before any failure is captured.
/// A diagnostic copy remains available after the error toast expires.
class LocalErrorDiagnosticsCard extends StatelessWidget {
  const LocalErrorDiagnosticsCard({super.key, this.log});
  final LocalErrorDiagnostics? log;

  @override
  Widget build(BuildContext context) {
    final held = log ?? LocalErrorDiagnostics.shared;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSettingsSectionHeader(
          label: 'Local error diagnostics',
          glyph: RaftGlyph.bug,
        ),
        RaftSettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                raftText(
                  context,
                  'Copy app version, foreground/background state and any storage errors recorded in this app run. Excludes messages, credentials and server addresses.',
                ),
                style: RaftSettingsText(RaftTokens.of(context)).description,
              ),
              const SizedBox(height: RaftSpace.x3),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RaftSettingsRecipeButton(
                  label: 'Copy',
                  onPressed: () =>
                      copyLocalErrorDiagnostics(context, log: held),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
