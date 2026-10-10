import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'sidebar_section.dart';
import 'theme.dart';

/// Mounted SidebarRoot surface. The host supplies its authorized contents;
/// colors and geometry stay in raft_ui for Chat, Members and Settings alike.
class RaftMountedSidebarFrame extends StatelessWidget {
  const RaftMountedSidebarFrame({
    super.key,
    required this.header,
    required this.body,
  });
  final Widget header, body;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final recipe = RaftSidebarRecipe(
      RaftTokens.of(context),
      viewportWidth: size.width,
      viewportHeight: size.height,
      variant: RaftSidebarVariant.mountedProduct,
    );
    return ColoredBox(
      color: recipe.bodyBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Sidebar.tsx4421–4438: controlled computer grouping within Members.
/// The caller owns identity, ordered groups, permissions and collapse scope.
class RaftSidebarMachineGroup extends StatelessWidget {
  const RaftSidebarMachineGroup({
    super.key,
    required this.name,
    required this.count,
    required this.expanded,
    required this.onExpandedChanged,
    required this.children,
    this.disclosureKey,
  });
  final String name;
  final int count;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final List<Widget> children;
  final Key? disclosureKey;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftTypography.mono(
      t,
      size: 10,
      line: 15,
      color: t.brutal
          ? Colors.black.withValues(alpha: .4)
          : t.colors['foreground-placeholder'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Semantics(
            expanded: expanded,
            child: RaftControl(
              key: disclosureKey,
              semanticLabel: '$name, $count',
              visualHeight: 15,
              minimumTargetSize: 15,
              recipe: _MachineGroupRecipe(t),
              onPressed: () => onExpandedChanged(!expanded),
              child: Builder(
                builder: (context) {
                  final foreground = DefaultTextStyle.of(context).style.color;
                  return Row(
                    children: [
                      AnimatedRotation(
                        turns: expanded ? .25 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : RaftSidebarSectionMetrics.disclosureDuration,
                        curve: RaftSidebarSectionMetrics.disclosureCurve,
                        child: const RaftIcon(RaftGlyph.chevronRight, size: 9),
                      ),
                      const SizedBox(width: 4),
                      const RaftIcon(RaftGlyph.monitor, size: 9),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          name.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(color: foreground),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('$count', style: style.copyWith(color: foreground)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }
}

class _MachineGroupRecipe extends RaftControlRecipe {
  const _MachineGroupRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => false;
  @override
  EdgeInsets get padding => const EdgeInsets.symmetric(horizontal: 8);
  @override
  Color get foreground => tokens.brutal
      ? Colors.black.withValues(alpha: .4)
      : tokens.colors['foreground-placeholder']!;
  @override
  Color foregroundFor({bool hovered = false}) => hovered
      ? tokens.brutal
            ? Colors.black.withValues(alpha: .6)
            : tokens.muted
      : foreground;
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => Colors.transparent;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}
