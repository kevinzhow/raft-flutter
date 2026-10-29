// Web ServerSetupProjectionGate "server-setup-resume-bar": the floating notice
// shown while the owner's server setup is deferred. Presentation only: the app
// owns the setup projection and the start transition.
import 'package:flutter/material.dart';

import 'components.dart';
import 'design_primitives.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// `pointer-events-none fixed inset-x-0 bottom-0 z-40 flex justify-center px-4
/// pb-4` around a `max-w-[560px]` row (`flex-wrap items-center
/// justify-between gap-3 rounded-lg border border-line-muted bg-primary-soft
/// px-4 py-3 shadow-raft-md`; brutal: square, `border-2 border-black
/// bg-soft-signal shadow-brutal`): the "not set up yet" sentence and an
/// outline "Resume Setup" button ("Opening…" while the request is in flight).
///
/// Place it at the bottom of the area it floats over (a [Stack]).
class RaftSetupResumeBar extends StatelessWidget {
  const RaftSetupResumeBar({
    super.key,
    required this.onResume,
    this.loading = false,
  });
  final VoidCallback onResume;

  /// The start request is running: the button is disabled and reads "Opening…".
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final foreground = t.strong;
    final bar = Container(
      key: const ValueKey('server-setup-resume-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.semantic.primarySoft,
        border: Border.all(color: t.semantic.lineMuted, width: t.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: t.themeShadows.md.paintOrder,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            raftText(context, 'Your server is not set up yet.'),
            style: RaftTypography.heading(
              t,
              size: 14,
              line: 20,
              color: foreground,
            ),
          ),
          RaftButton(
            key: const ValueKey('server-setup-resume'),
            label: raftText(context, loading ? 'Opening…' : 'Resume Setup'),
            variant: RaftControlVariant.outline,
            size: RaftButtonRecipeSize.md,
            onPressed: loading ? null : onResume,
          ),
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SizedBox(width: double.infinity, child: bar),
          ),
        ),
      ),
    );
  }
}
