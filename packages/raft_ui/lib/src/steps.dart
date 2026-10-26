// raft-ui `Steps` / `Step`: where someone is in a short flow of 3 to 5 steps. Each step is a 20px sticker-cornered
// marker (an outline for a step ahead, the yellow sticker for the current one, solid ink with a check once finished,
// the orange sticker for a failed one), its title, and a 1px seam connector to the next step. A row on wide screens;
// on narrow ones the steps share the width and the titles sit under their markers.
import 'package:flutter/material.dart';

import 'control_typography.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

/// `status` of a step.
enum RaftStepStatus { wait, process, finish, error }

/// One `Step`: a [title] and an optional [description]; its own [status] overrides the one `Steps` derives.
@immutable
class RaftStep {
  const RaftStep({required this.title, this.description, this.status});
  final String title;
  final String? description;
  final RaftStepStatus? status;
}

/// raft-ui `Steps`. [current] is the 0-based index of the current step: earlier ones are finished, later ones wait and
/// the current one takes [status] (`process`, or `error` for a failed step).
class RaftSteps extends StatelessWidget {
  const RaftSteps({
    super.key,
    required this.steps,
    required this.current,
    this.status = RaftStepStatus.process,
    this.semanticLabel,
  });

  final List<RaftStep> steps;
  final int current;
  final RaftStepStatus status;
  final String? semanticLabel;

  /// `min-width: 40rem`: below it the steps share the width.
  static const double wideBreakpoint = 640;

  RaftStepStatus _statusOf(int index) =>
      steps[index].status ??
      (index < current
          ? RaftStepStatus.finish
          : index > current
          ? RaftStepStatus.wait
          : status);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    return Semantics(
      label: semanticLabel == null ? null : raftText(context, semanticLabel!),
      container: true,
      child: wide
          ? Wrap(
              runSpacing: RaftSpace.x2,
              children: [
                for (var i = 0; i < steps.length; i++)
                  _WideStep(
                    step: steps[i],
                    index: i + 1,
                    status: _statusOf(i),
                    last: i == steps.length - 1,
                    isCurrent: i == current,
                  ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: _NarrowStep(
                      step: steps[i],
                      index: i + 1,
                      status: _statusOf(i),
                      last: i == steps.length - 1,
                      isCurrent: i == current,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Look {
  const _Look(
    this.fill,
    this.border,
    this.borderWidth,
    this.mark,
    this.title,
    this.description,
  );
  final Color fill, border, mark, title, description;
  final double borderWidth;

  factory _Look.of(RaftUiColors ui, RaftStepStatus s) => switch (s) {
    RaftStepStatus.wait => _Look(
      ui.layerCard,
      ui.lineSeam,
      1,
      ui.foregroundHint,
      ui.foregroundHint,
      ui.foregroundHint,
    ),
    RaftStepStatus.process => _Look(
      ui.brand,
      ui.stickerInk,
      1.5,
      ui.stickerInk,
      ui.foreground,
      ui.foregroundMuted,
    ),
    RaftStepStatus.finish => _Look(
      ui.foreground,
      ui.foreground,
      1.5,
      ui.layerCanvas,
      ui.foregroundMuted,
      ui.foregroundHint,
    ),
    RaftStepStatus.error => _Look(
      ui.warning,
      ui.stickerInk,
      1.5,
      ui.stickerInk,
      ui.foreground,
      ui.foregroundMuted,
    ),
  };
}

const double _marker = 20;

class _Marker extends StatelessWidget {
  const _Marker({
    required this.index,
    required this.look,
    required this.status,
  });
  final int index;
  final _Look look;
  final RaftStepStatus status;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ExcludeSemantics(
      child: RaftCssBox(
        radius: t.size('radius.sticker', fallback: 4),
        fill: look.fill,
        borderWidth: raftControlBorderPx(context, look.borderWidth),
        borderColor: look.border,
        width: _marker,
        height: _marker,
        alignment: Alignment.center,
        child: switch (status) {
          RaftStepStatus.finish => RaftIcon(
            RaftGlyph.check,
            size: 14,
            color: look.mark,
          ),
          RaftStepStatus.error => RaftIcon(
            RaftGlyph.x,
            size: 14,
            color: look.mark,
          ),
          _ => Text(
            '$index',
            style: t.scale(
              RaftTypeScale.monoMeta,
              mono: true,
              weight: FontWeight.w700,
              color: look.mark,
            ),
          ),
        },
      ),
    );
  }
}

TextStyle _title(BuildContext context, RaftTokens t, _Look look) =>
    RaftControlTypography.of(
      context,
      t.scale(
        RaftTypeScale.footnote,
        weight: FontWeight.w600,
        color: look.title,
      ),
    );

TextStyle _description(RaftTokens t, _Look look) => t.scale(
  RaftTypeScale.caption,
  weight: FontWeight.w400,
  color: look.description,
);

Widget _semantic(
  BuildContext context,
  RaftStep step,
  RaftStepStatus status,
  bool isCurrent,
  Widget child,
) => Semantics(
  container: true,
  label: step.title,
  hint: switch (status) {
    RaftStepStatus.finish => raftText(context, 'Completed'),
    RaftStepStatus.error => raftText(context, 'Failed'),
    _ => null,
  },
  // `aria-current="step"`.
  selected: isCurrent,
  child: child,
);

/// `.r-steps--horizontal > .r-step`: marker, title and a 16px connector with 8px each side; the description sits
/// under the title.
class _WideStep extends StatelessWidget {
  const _WideStep({
    required this.step,
    required this.index,
    required this.status,
    required this.last,
    required this.isCurrent,
  });
  final RaftStep step;
  final int index;
  final RaftStepStatus status;
  final bool last, isCurrent;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final look = _Look.of(t.ui, status);
    return _semantic(
      context,
      step,
      status,
      isCurrent,
      IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Marker(index: index, look: look, status: status),
                const SizedBox(width: RaftSpace.x2),
                Text(
                  raftText(context, step.title),
                  maxLines: 1,
                  softWrap: false,
                  style: _title(context, t, look),
                ),
                if (!last) ...[
                  const SizedBox(width: RaftSpace.x2),
                  Container(
                    width: RaftSpace.x4,
                    height: 1,
                    color: t.ui.lineSeam,
                  ),
                  const SizedBox(width: RaftSpace.x2),
                ],
              ],
            ),
            if (step.description != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: _marker + RaftSpace.x2,
                  top: RaftSpace.half,
                ),
                child: Text(step.description!, style: _description(t, look)),
              ),
          ],
        ),
      ),
    );
  }
}

/// `width < 40rem`: the marker and its connector share the top line, the title and description span the step below.
class _NarrowStep extends StatelessWidget {
  const _NarrowStep({
    required this.step,
    required this.index,
    required this.status,
    required this.last,
    required this.isCurrent,
  });
  final RaftStep step;
  final int index;
  final RaftStepStatus status;
  final bool last, isCurrent;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final look = _Look.of(t.ui, status);
    return _semantic(
      context,
      step,
      status,
      isCurrent,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x1_5,
        children: [
          Row(
            children: [
              _Marker(index: index, look: look, status: status),
              if (!last)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RaftSpace.x2,
                    ),
                    child: Container(height: 1, color: t.ui.lineSeam),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: RaftSpace.x2),
            child: Text(
              raftText(context, step.title),
              style: _title(context, t, look),
            ),
          ),
          if (step.description != null)
            Text(step.description!, style: _description(t, look)),
        ],
      ),
    );
  }
}
