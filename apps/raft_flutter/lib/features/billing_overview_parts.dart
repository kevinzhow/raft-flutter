// Web BillingTabContent's permission card and PlanBillingLoadingSection: the
// two cards every plan shows, built from their parts, so what loads in below
// them moves nothing above it.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// BillingTabContent without `viewBilling`: the Billing header over a card.
class BillingRestricted extends StatelessWidget {
  const BillingRestricted({super.key});

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      key: const ValueKey('billing-restricted'),
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Billing',
            glyph: RaftGlyph.creditCard,
          ),
          RaftCard(
            padding: const EdgeInsets.all(RaftSpace.x4),
            child: RaftCssText(
              raftText(
                context,
                'Only server owners and admins can view billing.',
              ),
              style: t.scale(
                RaftTypeScale.callout,
                color: t.ui.foregroundMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A `SkeletonTextBar`: a line 0.75em of the text it stands in for, in a row
/// as tall as that text's line, so the card is the loaded card's size.
class _Bar extends StatelessWidget {
  const _Bar(this.width, this.textSize, this.line);
  final double width, textSize, line;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: line,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: RaftSkeleton(
        fromRecipe: true,
        width: width,
        height: textSize * 0.75,
      ),
    ),
  );
}

/// Plan & billing while it loads: the plan card (its headline title and the
/// lines of its summary) and the usage card (its title, one meter and one line
/// of facts under it).
class BillingOverviewLoading extends StatelessWidget {
  const BillingOverviewLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 768;
    Widget card(List<Widget> children) => RaftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
    return Semantics(
      container: true,
      label: raftText(context, 'Loading'),
      child: Padding(
        key: const ValueKey('billing-overview-loading'),
        padding: const EdgeInsets.only(bottom: RaftSpace.x6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: card([
                RaftCardSectionHeader(
                  aboveContent: true,
                  title: RaftCardTitle(_Bar(64, 17, 22)),
                ),
                RaftCardContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Bar(320, 14, 20),
                      if (narrow) ...[
                        const SizedBox(height: RaftSpace.x1_5),
                        const _Bar(160, 14, 20),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: RaftSpace.x4),
            ExcludeSemantics(
              child: card([
                const RaftCardSectionHeader(
                  aboveContent: true,
                  title: RaftCardTitle(_Bar(56, 14, 22)),
                ),
                RaftCardContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RaftMeter(
                        label: '',
                        labelChild: const _Bar(48, 13, 18),
                        used: 0,
                        max: 1,
                        valueText: '',
                      ),
                      const SizedBox(height: RaftSpace.x2),
                      const RaftDescriptionList(
                        inline: true,
                        entries: [
                          RaftDescriptionEntry(
                            '',
                            '',
                            termChild: _Bar(48, 13, 18),
                            detailsChild: _Bar(64, 14, 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
