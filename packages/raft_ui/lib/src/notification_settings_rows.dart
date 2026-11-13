// Presentation pieces of Settings › Notifications, Web v1.24.0
// components/settings/notifications/* (ThisDeviceCard, PauseAndScheduleCard,
// ContentCard, ServersCard, TestNotificationButton): settings rows in a
// ListRowGroup (DS Forms › A setting's row), whose control ends the row or,
// where the group is under 32rem wide (`@max-lg`), goes under the text; a
// select as wide as its longest option (`SelectTrigger fit`); the test
// notification's result banner. The app adapter owns data and commands.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'localization.dart';
import 'raft/list_row.dart';
import 'raft/ui_tokens.dart';
import 'select_field.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Web `@container` `@max-lg`: under 32rem the select goes under the text.
const double raftSettingsRowNarrowWidth = 512;

/// `SelectTrigger fit`: 11rem to 20rem; under the text `max-w-sm` (24rem).
const double _fitMin = 176, _fitMax = 320, _belowMax = 384;

/// One settings row of a [RaftSettingsRowGroup].
@immutable
class RaftSettingsRowSpec {
  const RaftSettingsRowSpec({
    this.key,
    this.title,
    this.titleTrailing,
    this.description,
    this.body = const [],
    this.control,
    this.controlBelow = false,
    this.wrapNarrow = true,
    this.attached = false,
  });
  final Key? key;
  final String? title;

  /// Beside the title (a status badge).
  final Widget? titleTrailing;
  final String? description;

  /// Under the text: hints, banners, buttons.
  final List<Widget> body;

  /// A switch or select ending the row.
  final Widget? control;

  /// The control always sits under the text (Phone alerts' long options).
  final bool controlBelow;

  /// Under 32rem the control moves under the text (selects; never switches).
  final bool wrapNarrow;

  /// `ListRow attached`: belongs to the row above, no hairline between them.
  final bool attached;
}

/// `ListRowGroup` of plain, non-interactive settings rows.
class RaftSettingsRowGroup extends StatelessWidget {
  const RaftSettingsRowGroup({super.key, required this.rows});
  final List<RaftSettingsRowSpec> rows;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow =
          constraints.maxWidth.isFinite &&
          constraints.maxWidth < raftSettingsRowNarrowWidth;
      return RaftListRowGroup(
        children: [
          for (var i = 0; i < rows.length; i++)
            // Not a bare ListRow, so the group leaves the rules to us.
            KeyedSubtree(
              key: rows[i].key,
              child: _row(context, rows[i], narrow, i > 0 && !rows[i].attached),
            ),
        ],
      );
    },
  );

  Widget _row(
    BuildContext context,
    RaftSettingsRowSpec row,
    bool narrow,
    bool rule,
  ) {
    final below =
        row.control != null && (row.controlBelow || narrow && row.wrapNarrow);
    final title = row.title;
    return RaftListRow(
      variant: RaftListRowVariant.plain,
      interactive: false,
      topRule: rule,
      children: [
        RaftListRowBody(
          children: [
            if (title != null)
              row.titleTrailing == null
                  ? RaftListRowTitle(title)
                  : Wrap(
                      spacing: RaftSpace.x2,
                      runSpacing: RaftSpace.x1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [RaftListRowTitle(title), row.titleTrailing!],
                    ),
            if (row.description != null)
              RaftListRowDescription(row.description!, wrap: true),
            for (final child in row.body)
              Padding(
                padding: const EdgeInsets.only(top: RaftSpace.x2),
                child: child,
              ),
            if (below)
              Padding(
                padding: const EdgeInsets.only(top: RaftSpace.x2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _belowMax),
                    child: _ControlWidth(below: true, child: row.control!),
                  ),
                ),
              ),
          ],
        ),
        if (row.control != null && !below)
          _ControlWidth(below: false, child: row.control!),
      ],
    );
  }
}

class _ControlWidth extends InheritedWidget {
  const _ControlWidth({required this.below, required super.child});
  final bool below;
  static bool belowOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ControlWidth>()?.below ??
      true;
  @override
  bool updateShouldNotify(_ControlWidth old) => old.below != below;
}

/// A [RaftSelectField] sized for a settings row: at the row's end as wide as
/// its longest option (11-20rem), under the text the full width up to 24rem.
class RaftSettingsSelect<T> extends StatelessWidget {
  const RaftSettingsSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.placeholder,
  });
  final T? value;
  final List<RaftSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label, placeholder;

  @override
  Widget build(BuildContext context) {
    final select = RaftSelectField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      label: label == null ? null : raftText(context, label!),
      placeholder: placeholder == null
          ? 'Select...'
          : raftText(context, placeholder!),
    );
    if (_ControlWidth.belowOf(context)) return select;
    final style = RaftTokens.of(context).scale(RaftTypeScale.callout);
    var widest = 0.0;
    for (final label in [
      for (final item in items) item.label,
      if (placeholder != null) raftText(context, placeholder!),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    // Trigger padding (px-3 twice), the chevron and its gap.
    final width = (widest + RaftSpace.x3 * 2 + RaftSpace.x4 + RaftSpace.x2)
        .clamp(_fitMin, _fitMax)
        .toDouble();
    return SizedBox(width: width, child: select);
  }
}

/// What a test notification did (contract §6), as TestNotificationButton
/// shows it.
enum RaftTestNotificationResult { shown, notShown, unconfirmed, failed }

/// The banner above "Send test notification": the outcome and what to check.
class RaftTestNotificationBanner extends StatelessWidget {
  const RaftTestNotificationBanner({
    super.key,
    required this.result,
    required this.message,
  });
  final RaftTestNotificationResult result;

  /// Already localised.
  final String message;

  @override
  Widget build(BuildContext context) => RaftBanner(
    key: ValueKey('test-notification-${result.name}'),
    status: switch (result) {
      RaftTestNotificationResult.shown => RaftBannerRecipeStatus.success,
      RaftTestNotificationResult.unconfirmed => RaftBannerRecipeStatus.info,
      _ => RaftBannerRecipeStatus.warning,
    },
    size: RaftBannerRecipeSize.sm,
    description: message,
  );
}
