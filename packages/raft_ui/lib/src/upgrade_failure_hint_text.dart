import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// ComputerUpgradeFailureHintText: stop the unit, run the install command
/// once, start the unit again; names the unit and its commands (InlineCode,
/// the same in every language) when the failure did.
class RaftUpgradeFailureHintText extends StatelessWidget {
  const RaftUpgradeFailureHintText({
    super.key,
    required this.hint,
    required this.style,
  });
  final RaftUpgradeFailureHint hint;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final unit = hint.unit;
    if (unit == null ||
        unit.isEmpty ||
        (hint.unsafeKillMode && hint.killMode == null)) {
      return RaftCssText(
        raftText(
          context,
          hint.unsafeKillMode
              ? 'This Computer runs under your own systemd unit, whose KillMode stops a web upgrade on this version. On that machine: stop the unit, run the install command below once, then start the unit again.'
              : "The installer can't upgrade this Computer while it runs inside your systemd unit. Stop the unit, run the install command below once, then start it again.",
        ),
        style: style,
      );
    }
    final systemctl = switch (hint.scope) {
      'user' => 'systemctl --user',
      'system' => 'systemctl',
      _ => 'systemctl [--user]',
    };
    // The message is localized as one string; its placeholders are then
    // filled with plain text and inline code.
    final template = raftText(
      context,
      hint.unsafeKillMode
          ? 'This Computer runs under your own systemd unit {unit} (KillMode={killMode}), which stops a web upgrade on this version. On that machine: stop the unit ({stopCommand}), run the install command below once, then start the unit again ({startCommand}).'
          : "The installer can't upgrade this Computer while it runs inside your systemd unit {unit}. On that machine: stop the unit ({stopCommand}), run the install command below once, then start it again ({startCommand}).",
    );
    final values = {
      'unit': unit,
      'stopCommand': '$systemctl stop $unit',
      'startCommand': '$systemctl start $unit',
    };
    final spans = <InlineSpan>[];
    var rest = template.replaceAll('{killMode}', hint.killMode ?? '');
    final marker = RegExp(r'\{(unit|stopCommand|startCommand)\}');
    while (true) {
      final match = marker.firstMatch(rest);
      if (match == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      spans.add(TextSpan(text: rest.substring(0, match.start)));
      spans.add(raftInlineCodeSpan(context, values[match.group(1)] ?? ''));
      rest = rest.substring(match.end);
    }
    return RaftCssText.rich(TextSpan(children: spans), style: style);
  }
}
