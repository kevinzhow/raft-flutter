// Published raft-ui Steps CSS owns Raft styling. The structural adapter maps
// its horizontal grid/flex layout to Flutter; frozen looks retain their painter.
import 'package:flutter/material.dart';

import 'control_typography.dart';
import 'icons.dart';
import 'localization.dart';
import 'raft/css_box.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/steps_css.g.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

part 'steps_frozen.dart';

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

  /// Frozen-look breakpoint. Raft reads its responsive rule from published CSS.
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
    final t = RaftTokens.of(context);
    if (!t.isRaftLook) return _frozenSteps(context, this);
    final viewport = MediaQuery.sizeOf(context);
    final states = t.recipeStates().copyWith(
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
    );
    final rt = t.recipeTokens;
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final root = RaftStepsCssRecipe.resolve(
      states: states,
      tokens: rt,
    )['root']!;
    // The source's wide media rule sets flex-wrap; the threshold itself is
    // present only in the generated CSS table, not repeated in this adapter.
    final wide = switch (root['flex-wrap']) {
      CssKeyword(value: 'wrap') => true,
      _ => false,
    };
    final items = [
      for (var i = 0; i < steps.length; i++)
        _PublishedStep(
          step: steps[i],
          index: i + 1,
          status: _statusOf(i),
          isCurrent: i == current,
          wide: wide,
          slots: RaftStepsCssRecipe.resolve(
            status: RaftStepsCssStatus.values[_statusOf(i).index],
            last: i == steps.length - 1,
            states: states,
            tokens: rt,
          ),
        ),
    ];
    return Semantics(
      label: semanticLabel == null ? null : raftText(context, semanticLabel!),
      container: true,
      child: RaftRecipeBox(
        style: root,
        tokens: rt,
        child: wide
            ? Wrap(runSpacing: root.rowGap ?? 0, children: items)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(child: item)],
              ),
      ),
    );
  }
}

/// Read-only horizontal Steps consumer. Other published library capabilities
/// are retained in the CSS model; this API does not invent clickable/vertical
/// behavior which the real Slack progress rail never mounts.
class _PublishedStep extends StatelessWidget {
  const _PublishedStep({
    required this.step,
    required this.index,
    required this.status,
    required this.isCurrent,
    required this.wide,
    required this.slots,
  });
  final RaftStep step;
  final int index;
  final RaftStepStatus status;
  final bool isCurrent, wide;
  final Map<String, RaftSlotStyle> slots;

  Widget box(
    BuildContext context,
    String name, {
    Widget? child,
    double? width,
  }) {
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final style = slots[name]!;
    return Padding(
      padding: style.margin,
      child: RaftRecipeBox(
        style: style,
        tokens: RaftTokens.of(context).recipeTokens,
        width: width,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final indicator = slots['indicator']!;
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final icon = slots['icon']!;
    final marker = RaftRecipeBox(
      style: indicator,
      tokens: rt,
      alignment: Alignment.center,
      child: switch (status) {
        RaftStepStatus.finish || RaftStepStatus.error => RaftIcon(
          status == RaftStepStatus.finish ? RaftGlyph.check : RaftGlyph.x,
          size: icon.width!,
          color: icon.color?.resolve(rt),
        ),
        _ => Text('$index'),
      },
    );
    final title = box(
      context,
      'title',
      child: Text(raftText(context, step.title)),
    );
    final description = step.description == null
        ? null
        : box(context, 'description', child: Text(step.description!));
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final connector = slots['connector']!;
    final hasConnector =
        connector['display'] is! CssKeyword ||
        (connector['display'] as CssKeyword).value != 'none';
    Widget line() => box(context, 'connector', width: double.infinity);
    Widget contents;
    if (wide) {
      // CSS's third grid column includes the connector and its inline margins.
      // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
      final columns = slots['item']!['grid-template-columns'] as CssSeq;
      final connectorColumn = hasConnector
          ? (columns.items.last as CssNum).value
          : null;
      contents = IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                marker,
                Expanded(child: title),
                if (hasConnector)
                  SizedBox(width: connectorColumn, child: line()),
              ],
            ),
            if (description != null)
              Padding(
                // grid-column2/-1 begins immediately after the marker; the
                // title/description's own inline margin is source-owned.
                padding: EdgeInsets.only(left: indicator.width!),
                child: description,
              ),
          ],
        ),
      );
    } else {
      contents = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              marker,
              if (hasConnector) Expanded(child: line()),
            ],
          ),
          box(
            context,
            'content',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, ?description],
            ),
          ),
        ],
      );
    }
    return _semantic(
      context,
      step,
      status,
      isCurrent,
      box(context, 'item', child: contents),
    );
  }
}
