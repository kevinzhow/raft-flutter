// Web components/machine/MachineRuntimeChips.tsx: the Computer page's
// Detected runtimes row. Detected runtimes keep their usage / sign-in chip,
// an in-process runtime the Computer predates is a warning chip with a small
// card, and the runtimes it did not detect stay behind "Show all supported".
// The app decides the groups and draws the detected chips; this row owns the
// layout, the update-computer chip and the Show all toggle.
import 'package:flutter/material.dart';

import '../raft_ui.dart';

/// A warning chip (`Badge appearance="soft" variant="warning"` as a button)
/// that opens a card saying [runtimeName] needs a newer Raft Computer, with
/// the page's own Upgrade when it offers one.
class RaftRuntimeUpdateComputerChip extends StatelessWidget {
  const RaftRuntimeUpdateComputerChip({
    super.key,
    required this.label,
    required this.runtimeName,
    required this.description,
    this.upgradeLabel,
    this.onUpgrade,
    this.upgradeKey,
  });

  /// The chip text, the runtime name and its " (update required)" suffix.
  final String label;

  /// The card title.
  final String runtimeName;
  final String description;
  final String? upgradeLabel;
  final VoidCallback? onUpgrade;
  final Key? upgradeKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    TextStyle body(double size, double line, {FontWeight? w, Color? color}) =>
        raftCssText.merge(
          RaftTypography.body(
            t,
            size: size,
            line: line,
            color: color,
            weight: w ?? FontWeight.w400,
          ),
        );
    return RaftHoverCard(
      width: 300,
      delay: const Duration(milliseconds: 200),
      align: RaftHoverCardAlign.center,
      card: (context) => Padding(
        // `grid w-[300px] gap-2 p-4`.
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RaftCssText(
              runtimeName,
              style: body(
                14,
                20,
                w: FontWeight.w600,
                color: t.colors['foreground-strong'],
              ),
            ),
            const SizedBox(height: 8),
            RaftCssText(
              description,
              style: body(14, 20, color: t.colors['foreground-muted']),
            ),
            if (upgradeLabel != null && onUpgrade != null) ...[
              const SizedBox(height: 8),
              // A popover confirms with an ink-border button, never a pink one.
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  key: upgradeKey,
                  label: upgradeLabel!,
                  tone: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.md,
                  onPressed: onUpgrade,
                ),
              ),
            ],
          ],
        ),
      ),
      child: RaftBadge(
        label: label,
        appearance: RaftBadgeRecipeAppearance.soft,
        variant: RaftBadgeRecipeVariant.warning,
        onPressed: () {},
      ),
    );
  }
}

/// The Detected runtimes chips: [detected] and [updateComputer] always,
/// [notInstalled] only after "Show all supported". The toggle shows whenever
/// there is a runtime to reveal.
class RaftRuntimeChipsRow extends StatefulWidget {
  const RaftRuntimeChipsRow({
    super.key,
    required this.detected,
    required this.updateComputer,
    required this.notInstalled,
  });
  final List<Widget> detected, updateComputer, notInstalled;

  @override
  State<RaftRuntimeChipsRow> createState() => _RaftRuntimeChipsRowState();
}

class _RaftRuntimeChipsRowState extends State<RaftRuntimeChipsRow> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...widget.detected,
        ...widget.updateComputer,
        if (showAll) ...widget.notInstalled,
        if (widget.notInstalled.isNotEmpty)
          // The link is one line: a narrow row at a large text size shrinks
          // it rather than overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RaftTextLink(
              key: const ValueKey('machine-runtime-show-all'),
              label: raftText(
                context,
                showAll ? 'Show installed only' : 'Show all supported',
              ),
              textStyle: raftCssText.merge(
                RaftTypography.body(t, size: 12, line: 16),
              ),
              onPressed: () => setState(() => showAll = !showAll),
            ),
          ),
      ],
    );
  }
}
