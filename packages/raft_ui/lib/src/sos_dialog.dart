// Presentation of the Web channel SOS dialog
// (packages/web/src/components/message/SOSDialog.tsx). The app adapter owns
// the `stop-all-agents` / `resume-all-agents` commands and passes them in as
// callbacks; this widget owns only the confirm → stopped → resuming phases.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'components.dart';
import 'dialog_card.dart';
import 'form_controls.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// Web `Phase`: `confirm` until the stop is accepted, then `stopped` (with
/// `resuming` as the busy sub-state of the guidance form).
enum RaftSosPhase { confirm, stopped }

/// Web `ResumeShortfall`: agents the resume did not reach, either still
/// starting (try again shortly) or failed. A resume that resolves to one keeps
/// the guidance and shows the counts in a warning banner.
class RaftSosShortfall {
  const RaftSosShortfall({required this.starting, required this.failed});
  final int starting, failed;
}

/// What a stop or resume that failed resolves to: Web changes nothing and
/// shows no message (a failed stop stays on the confirmation, a failed resume
/// keeps the guidance).
enum RaftSosOutcome { retained }

/// Web SOSDialog in a `DialogCard maxWidthClass="max-w-sm"`.
///
/// [onStop] and [onResume] resolve to null on success. A failure resolves to
/// [RaftSosOutcome.retained]: a failed stop stays on the confirm phase and a
/// failed resume keeps the guidance, with no message, exactly as Web.
/// [onResume] may also resolve to a [RaftSosShortfall].
class RaftSosDialog extends StatefulWidget {
  const RaftSosDialog({
    super.key,
    required this.channelName,
    required this.onStop,
    required this.onResume,
    required this.onClose,
    this.initialPhase = RaftSosPhase.confirm,
  });
  final String channelName;
  final Future<RaftSosOutcome?> Function() onStop;
  final Future<Object?> Function(String guidance) onResume;

  /// Cancel, Keep Stopped, the close button, and a successful resume.
  final VoidCallback onClose;
  final RaftSosPhase initialPhase;
  @override
  State<RaftSosDialog> createState() => _RaftSosDialogState();
}

class _RaftSosDialogState extends State<RaftSosDialog> {
  late RaftSosPhase phase = widget.initialPhase;
  bool stopping = false, resuming = false;
  RaftSosShortfall? shortfall;
  final guidance = TextEditingController();
  final guidanceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    guidance.addListener(() => setState(() {}));
    if (phase == RaftSosPhase.stopped) focusGuidance();
  }

  @override
  void dispose() {
    guidance.dispose();
    guidanceFocus.dispose();
    super.dispose();
  }

  void focusGuidance() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && phase == RaftSosPhase.stopped) guidanceFocus.requestFocus();
  });

  Future<void> stop() async {
    if (stopping) return;
    setState(() => stopping = true);
    final failure = await widget.onStop();
    if (!mounted) return;
    setState(() {
      stopping = false;
      if (failure == null) phase = RaftSosPhase.stopped;
    });
    if (failure == null) focusGuidance();
  }

  Future<void> resume() async {
    final text = guidance.text.trim();
    if (text.isEmpty || resuming) return;
    setState(() => resuming = true);
    final outcome = await widget.onResume(text);
    if (!mounted) return;
    if (outcome == null) {
      widget.onClose();
      return;
    }
    setState(() {
      resuming = false;
      if (outcome is RaftSosShortfall) shortfall = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final body = TextStyle(
      fontFamily: t.bodyFont,
      fontFamilyFallback: t.fontFallback,
      fontSize: 14,
      height: 20 / 14,
      color: t.ink,
    );
    Widget actions(List<Widget> children) => Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 8,
      children: children,
    );
    // Raft dialog routes carry no Material; the guidance editor needs one.
    return Material(
      type: MaterialType.transparency,
      child: RaftDialogCard(
        title: phase == RaftSosPhase.confirm
            ? 'Stop All Agents'
            : 'Agents Stopped',
        onClose: widget.onClose,
        maxWidth: 384, // max-w-sm
        // Pinned under the scrolling body at large text sizes.
        actions: phase == RaftSosPhase.confirm
            ? actions([
                RaftButton(
                  key: const ValueKey('sos-cancel'),
                  label: 'Cancel',
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: widget.onClose,
                ),
                RaftButton(
                  key: const ValueKey('sos-stop'),
                  label: stopping ? 'Stopping…' : 'Stop',
                  tone: RaftButtonRecipeVariant.warning,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: stopping ? null : stop,
                ),
              ])
            : actions([
                RaftButton(
                  key: const ValueKey('sos-keep-stopped'),
                  label: 'Keep Stopped',
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: resuming ? null : widget.onClose,
                ),
                RaftButton(
                  key: const ValueKey('sos-resume'),
                  label: resuming ? 'Resuming…' : 'Resume All',
                  tone: RaftButtonRecipeVariant.success,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: guidance.text.trim().isEmpty || resuming
                      ? null
                      : resume,
                ),
              ]),
        child: phase == RaftSosPhase.confirm
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      raftFormat(
                        context,
                        'All running agents in #{channel} will stop immediately. You can provide new guidance before resuming them.',
                        {'channel': widget.channelName},
                      ),
                      style: body.copyWith(
                        height: 1.625, // leading-relaxed
                        color: t.brutal
                            ? const Color(0xff000000).withValues(alpha: .75)
                            : t.muted,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: RaftBanner(
                      description: 'All agents have been stopped.',
                      status: RaftBannerRecipeStatus.success,
                      size: RaftBannerRecipeSize.sm,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      raftText(
                        context,
                        'Provide new guidance or corrections. All agents will see this when they resume.',
                      ),
                      style: body,
                    ),
                  ),
                  if (shortfall case final missed?)
                    Padding(
                      key: const ValueKey('sos-resume-shortfall'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RaftBanner(
                        size: RaftBannerRecipeSize.sm,
                        descriptionBuilder: (style) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (missed.starting > 0)
                              Text(
                                raftFormat(
                                  context,
                                  missed.starting == 1
                                      ? '{count} agent is still starting and did not get your guidance. Try again in a moment.'
                                      : '{count} agents are still starting and did not get your guidance. Try again in a moment.',
                                  {'count': missed.starting},
                                ),
                                style: style,
                              ),
                            if (missed.failed > 0)
                              Text(
                                raftFormat(
                                  context,
                                  missed.failed == 1
                                      ? '{count} agent could not be resumed.'
                                      : '{count} agents could not be resumed.',
                                  {'count': missed.failed},
                                ),
                                style: style,
                              ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: RaftTextarea(
                      key: const ValueKey('sos-guidance'),
                      controller: guidance,
                      focusNode: guidanceFocus,
                      rows: 4,
                      enabled: !resuming,
                      hintText: raftText(
                        context,
                        'e.g. Stop modifying the database schema — focus only on the frontend changes I described…',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
