// Fixture for tool/tests/test_ds_audit.py: pins what tool/ds-audit counts.
// Not a test itself (no _test suffix). Expected counts live in the Python test;
// update both together. Mentions in comments or strings never count:
// ListTile( TextButton( Colors.red EdgeInsets.all(8)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

const String mention = 'ListTile( AlertDialog( Icons.add SizedBox(width: 8)';

Widget dsAuditSample(BuildContext context, VoidCallback onTap) {
  final t = RaftTokens.of(context);
  final theme = Theme.of(context);
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  Timer(const Duration(milliseconds: 300), onTap); // not an animation
  return Column(
    children: [
      // widget.list_tile: 2 enforced, 2 allowlisted, 1 malformed allow
      ListTile(title: const Text('row'), onTap: onTap),
      // ds-allow: fixture exercises the allowlist on the line above
      const ListTile(title: Text('allowed')),
      const ListTile(title: Text('same-line allow')), // ds-allow: inline form
      // ds-allow:
      const ListTile(title: Text('malformed allow still counts')),
      // widget.button x4: 2x TextButton, TextButton.icon, TextButton.styleFrom
      TextButton(
        style: TextButton.styleFrom(),
        onPressed: onTap,
        child: const Text('go'),
      ),
      TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add), // style.material_icons x1
        label: const Text('add'),
      ),
      // raft_ui counterparts never count (RaftTooltip extends Tooltip).
      RaftTooltip(
        message: 'tip',
        child: RaftButton(label: 'ok', onPressed: onTap),
      ),
      const Tooltip(message: 'raw'), // widget.tooltip x1
      const Divider(height: 1), // widget.divider x1 + style.dimension x1
      const CircularProgressIndicator(), // widget.progress x1
      const SelectableText('x'), // widget.other x1
      // style.edge_insets x2 (third uses no literal)
      const Padding(padding: EdgeInsets.all(8)),
      Padding(padding: EdgeInsets.symmetric(horizontal: t.border * 4)),
      Padding(padding: EdgeInsets.only(left: t.border)),
      // style.sized_box x2 (shrink and infinity carry no numeric literal)
      const SizedBox(width: 12),
      const SizedBox(height: 4, child: SizedBox.shrink()),
      const SizedBox(width: double.infinity),
      // style.text_style x1, font_size x2, font_weight x2, text_metrics x1
      Text(
        'styled',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
      Text(
        'copy',
        style: RaftTypography.body(t)
            .copyWith(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      // style.border_radius x2 (BorderRadius.all(Radius.circular) is one)
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xff112233), // style.color_literal x1
        ),
      ),
      ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: ColoredBox(color: t.panel),
      ),
      // style.material_colors x1
      const ColoredBox(color: Colors.transparent),
      // style.material_theme x2; extension<T>() and platform do not count
      Text('a', style: theme.textTheme.bodySmall),
      ColoredBox(color: Theme.of(context).colorScheme.surface),
      if (theme.extension<RaftTokens>() != null &&
          theme.platform == TargetPlatform.android)
        const SizedBox.shrink(),
      // style.duration x1 (through the conditional)
      AnimatedOpacity(
        opacity: 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 150),
        child: const SizedBox.shrink(),
      ),
      // widget.dialog x2, widget.snackbar x2
      TextButton(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(title: Text('t')),
          );
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('s')));
        },
        child: const Text('open'),
      ),
    ],
  );
}
