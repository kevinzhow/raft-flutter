// Published raft-ui Steps CSS owns Raft styling. The structural adapter maps
// its horizontal grid/flex layout to Flutter.
import 'package:flutter/material.dart';

import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show raftTextMetricsCache;
import 'recipe_surface.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/steps_css.g.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';

/// `status` of a step.
enum RaftStepStatus { wait, process, finish, error }

final _labelWidths =
    raftTextMetricsCache<
      (String, TextStyle?, TextDirection, TextScaler),
      double
    >();

RaftSlotStyle _stepsTitleStyle(RaftSlotStyle style, RaftTokens tokens) =>
    style.copyWith(
      properties: {
        ...style.properties,
        'font-size': CssNum(tokens.typeSlot('footnote').fontSize, 'px'),
      },
    );

/// One `Step`: a [title] and an optional [description]; its own [status] overrides the one `Steps` derives.
@immutable
class RaftStep {
  const RaftStep({
    required this.title,
    this.description,
    this.status,
    this.icon,
  });
  final String title;
  final String? description;
  final RaftStepStatus? status;
  final Widget? icon;
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
    this.fitLabels = false,
    this.finishLabel = 'Completed',
    this.errorLabel = 'Failed',
  });

  final List<RaftStep> steps;
  final int current;
  final RaftStepStatus status;
  final String? semanticLabel;
  final bool fitLabels;
  final String finishLabel, errorLabel;

  /// Frozen-look breakpoint. Raft reads its responsive rule from published CSS.
  static const double wideBreakpoint = 640;

  RaftStepStatus _statusOf(int index) =>
      steps[index].status ??
      (index < current
          ? RaftStepStatus.finish
          : index > current
          ? RaftStepStatus.wait
          : status);

  bool _fits(
    BuildContext context,
    double width,
    Map<String, RaftSlotStyle> slots,
    RaftTokens tokens,
  ) {
    final indicator = slots['indicator']?.width ?? 20;
    final gap = slots['main']?.columnGap ?? 8;
    final columns = slots['item']?['grid-template-columns'];
    final connectorWidth = switch (columns) {
      CssSeq(items: [..., CssNum(:final value)]) => value,
      _ => 32.0,
    };
    final titleSlot = slots['title'];
    final title = titleSlot == null
        ? null
        : _stepsTitleStyle(titleSlot, tokens).text(tokens.recipeTokens);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var needed = (steps.length - 1) * connectorWidth;
    for (final step in steps) {
      final text = raftText(context, step.title);
      needed +=
          indicator +
          gap +
          _labelWidths.putIfAbsent((text, title, direction, scaler), () {
            final painter = TextPainter(
              text: TextSpan(text: text, style: title),
              textDirection: direction,
              textScaler: scaler,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          });
    }
    return needed <= width;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildPublished(context, t, constraints),
    );
  }

  Widget _buildPublished(
    BuildContext context,
    RaftTokens t,
    BoxConstraints constraints,
  ) {
    final viewport = MediaQuery.sizeOf(context);
    final containerWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : null;
    final states = t.recipeStates().copyWith(
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      containerWidth: containerWidth,
    );
    final rt = t.recipeTokens;
    final vertical =
        fitLabels &&
        containerWidth != null &&
        !_fits(
          context,
          containerWidth,
          RaftStepsCssRecipe.resolve(
            states: states.copyWith(containerWidth: wideBreakpoint),
            tokens: rt,
          ),
          t,
        );
    final orientation = vertical
        ? RaftStepsCssOrientation.vertical
        : RaftStepsCssOrientation.horizontal;
    final slots = RaftStepsCssRecipe.resolve(
      orientation: orientation,
      states: states,
      tokens: rt,
    );
    // ignore: raft_lints/avoid_render_index_assertion -- The generated Steps schema always emits all eleven slots; no async/server data participates.
    final root = slots['root']!;
    // Current CSS always wraps the root. Its container query instead changes
    // content from display:contents to block when text stacks below the marker.
    final wide = switch (slots['content']?['display']) {
      CssKeyword(value: 'contents') => true,
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
          vertical: vertical,
          finishLabel: finishLabel,
          errorLabel: errorLabel,
          slots: RaftStepsCssRecipe.resolve(
            status: RaftStepsCssStatus.values[_statusOf(i).index],
            orientation: orientation,
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
        // The source root's inline-size:100% establishes the query container.
        width: containerWidth,
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items,
              )
            : wide
            ? Wrap(runSpacing: root.rowGap ?? 0, children: items)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(child: item)],
              ),
      ),
    );
  }
}

class _PublishedStep extends StatelessWidget {
  const _PublishedStep({
    required this.step,
    required this.index,
    required this.status,
    required this.isCurrent,
    required this.wide,
    required this.vertical,
    required this.slots,
    required this.finishLabel,
    required this.errorLabel,
  });
  final RaftStep step;
  final int index;
  final RaftStepStatus status;
  final bool isCurrent, wide, vertical;
  final String finishLabel, errorLabel;
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
        style: name == 'title'
            ? _stepsTitleStyle(style, RaftTokens.of(context))
            : style,
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
      key: ValueKey('raft-step-indicator-$index'),
      style: indicator.withCssUsedBorderWidths(),
      tokens: rt,
      alignment: Alignment.center,
      child:
          step.icon ??
          switch (status) {
            RaftStepStatus.finish || RaftStepStatus.error => RaftIcon(
              status == RaftStepStatus.finish ? RaftGlyph.check : RaftGlyph.x,
              size: icon.width!,
              color: icon.color?.resolve(rt),
            ),
            _ => Text(
              '$index',
              textScaler: RaftChrome.boundedScalerOf(context),
            ),
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
    if (vertical) {
      contents = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          marker,
          SizedBox(width: slots['main']?.columnGap),
          Expanded(
            child: box(
              context,
              'content',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, ?description],
              ),
            ),
          ),
        ],
      );
    } else if (wide) {
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
    final item = box(context, 'item', child: contents);
    return _semantic(
      context,
      step,
      status,
      isCurrent,
      finishLabel,
      errorLabel,
      vertical && hasConnector
          ? Stack(
              children: [
                item,
                PositionedDirectional(
                  start: connector.length('left'),
                  top: connector.length('top'),
                  bottom: connector.length('bottom'),
                  width: connector.borderWidth.left,
                  child: RaftRecipeBox(style: connector, tokens: rt),
                ),
              ],
            )
          : item,
    );
  }
}

Widget _semantic(
  BuildContext context,
  RaftStep step,
  RaftStepStatus status,
  bool isCurrent,
  String finishLabel,
  String errorLabel,
  Widget child,
) => Semantics(
  container: true,
  label: step.title,
  hint: switch (status) {
    RaftStepStatus.finish => raftText(context, finishLabel),
    RaftStepStatus.error => raftText(context, errorLabel),
    _ => null,
  },
  // `aria-current="step"`.
  selected: isCurrent,
  child: child,
);
