import 'package:flutter/material.dart';

import 'agent_profile.dart' show RaftRecipeBadge, RaftRecipeTextButton;
import 'design_primitives.dart';
import 'dialog_card.dart' show RaftCloseButton;
import 'hover_card.dart';
import 'icons.dart';
import 'indicators.dart' show RaftProgressBar, RaftWebPalette;
import 'localization.dart';
import 'panel_layout.dart' show raftPanelInk;
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/card.g.dart';
import 'recipes/progress.g.dart';
import 'recipes/status.g.dart';
import 'theme.dart';

/// One usage window (`5h`, `weekly`…) of a runtime account.
@immutable
class RaftRuntimeUsageWindow {
  const RaftRuntimeUsageWindow({
    required this.label,
    required this.status,
    this.percent = 0,
    this.reset,
  });
  final String label;

  /// `ok` | `limit_reached` | `parse_unavailable`.
  final String status;
  final int percent;

  /// Relative reset time ("in 3 hours"); null when unavailable.
  final String? reset;
}

@immutable
class RaftRuntimeUsageAccount {
  const RaftRuntimeUsageAccount({
    required this.health,
    this.plan,
    this.identity,
    this.windows = const [],
  });

  /// `ok` | `rate_limited` | `reauth_required` | `unsupported` | `error`.
  final String health;
  final String? plan, identity;
  final List<RaftRuntimeUsageWindow> windows;
}

/// Everything the Web RuntimeAccountUsageChip surface shows; the adapter
/// owns reads, refreshes and permission.
@immutable
class RaftRuntimeUsageData {
  const RaftRuntimeUsageData({
    required this.provider,
    this.version,
    this.loading = false,
    this.loadError = false,
    this.state,
    this.accounts = const [],
    this.updated,
    required this.footer,
    this.refreshing = false,
    this.refreshDisabled = false,
  });

  /// Provider display name ("Claude").
  final String provider;
  final String? version;
  final bool loading, loadError;

  /// null before the first read; `missing` | `fresh` | `stale`.
  final String? state;
  final List<RaftRuntimeUsageAccount> accounts;

  /// Relative collection time of the snapshot.
  final String? updated;

  /// Footer status sentence (cache only / requested / countdown…).
  final String footer;
  final bool refreshing, refreshDisabled;

  /// isAttention: stale, or any account / window not `ok`.
  bool get attention =>
      state == 'stale' ||
      (state == 'fresh' &&
          accounts.any(
            (a) => a.health != 'ok' || a.windows.any((w) => w.status != 'ok'),
          ));
  bool get known => state != null && state != 'missing';
}

/// Web RuntimeAccountUsageChip `Surface`: header (title, version, privacy
/// note, close), the snapshot contents and the refresh footer.
class RaftRuntimeUsageSurface extends StatelessWidget {
  const RaftRuntimeUsageSurface({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onClose,
  });
  final RaftRuntimeUsageData data;
  final VoidCallback onRefresh, onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = _UsageInk(t);
    final rule = BorderSide(
      color: t.brutal ? Colors.black : t.colors['line-muted']!,
      width: 2,
    );
    return Column(
      key: ValueKey('runtime-usage-surface-${data.provider.toLowerCase()}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: rule)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      raftFormat(context, '{provider} usage', {
                        'provider': data.provider,
                      }),
                      style: ink.sans(14, 20, ink.strong, FontWeight.w900),
                    ),
                    Text(
                      (data.version?.trim().isNotEmpty == true
                              ? raftFormat(context, 'Version {version}', {
                                  'version': data.version!.trim(),
                                })
                              : raftText(context, 'Version unavailable'))
                          .toUpperCase(),
                      key: const ValueKey('runtime-usage-version'),
                      style: ink.eyebrow(ink.muted(.55)),
                    ),
                    Text(
                      raftText(
                        context,
                        'Visible with Computer edit permission or to the person who attached this Computer',
                      ).toUpperCase(),
                      style: ink.eyebrow(ink.muted(.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RaftCloseButton(
                onPressed: onClose,
                tooltip: 'Close runtime usage',
              ),
            ],
          ),
        ),
        _contents(context, ink),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(top: rule)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data.footer,
                  key: const ValueKey('runtime-usage-footer'),
                  style: ink.sans(11, 16.5, ink.muted(.5)),
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: data.refreshDisabled ? .5 : 1,
                child: RaftRecipeTextButton(
                  key: const ValueKey('runtime-usage-refresh'),
                  label: raftText(context, 'Refresh'),
                  glyph: RaftGlyph.refreshCw,
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: data.refreshDisabled || data.refreshing
                      ? null
                      : onRefresh,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contents(BuildContext context, _UsageInk ink) {
    final t = ink.t;
    const pad = EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    if (data.loading && data.state == null) {
      return Padding(
        padding: pad,
        child: Text(
          raftText(context, 'Reading cached snapshot…'),
          style: ink.sans(14, 20, ink.muted(.5)),
        ),
      );
    }
    if (data.loadError && data.state == null) {
      return Padding(
        padding: pad,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RaftIcon(
                RaftGlyph.circleAlert,
                size: 16,
                color: t.product.brutalOrange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                raftText(context, 'Cached usage could not be read.'),
                style: ink.sans(14, 20, t.product.brutalOrange),
              ),
            ),
          ],
        ),
      );
    }
    if (!data.known) {
      return Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raftText(context, 'No snapshot yet'),
              style: ink.sans(14, 20, ink.strong, FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              raftText(
                context,
                'A bounded refresh was requested from this Computer. Provider credentials never leave it.',
              ),
              style: ink.sans(12, 20, ink.muted(.55)),
            ),
          ],
        ),
      );
    }
    final stale = data.state == 'stale';
    final divider = BorderSide(
      color: t.brutal
          ? Colors.black.withValues(alpha: .15)
          : t.colors['line-muted']!,
      width: t.brutal ? 2 : 1,
    );
    return ColoredBox(
      color: stale
          ? (t.brutal ? RaftWebPalette.gray50 : t.colors['layer-inset']!)
          : (t.brutal ? Colors.white : t.colors['layer-panel']!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: t.brutal
                    ? t.product.brutalOrange.withValues(alpha: .2)
                    : t.colors['warning-soft'],
                border: Border(
                  bottom: BorderSide(
                    color: t.brutal ? Colors.black : t.colors['line-muted']!,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                raftText(
                  context,
                  'Stale snapshot · every value below is last known',
                ),
                style: ink.sans(
                  12,
                  16,
                  t.brutal ? Colors.black : t.colors['warning-strong']!,
                  FontWeight.w700,
                ),
              ),
            ),
          for (final (i, account) in data.accounts.indexed)
            Container(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Opacity(
                opacity: stale ? .65 : 1,
                child: _account(context, ink, account),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .15)
                      : t.colors['line-muted']!,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              raftFormat(context, 'Account-wide · updated {updated}', {
                'updated': data.updated ?? raftText(context, 'recently'),
              }),
              style: ink.sans(11, 16.5, ink.muted(.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _account(
    BuildContext context,
    _UsageInk ink,
    RaftRuntimeUsageAccount account,
  ) {
    final note = switch (account.health) {
      'unsupported' =>
        'Account usage is unavailable for this runtime or sign-in method.',
      'error' => 'Cached usage could not be read.',
      'reauth_required' => 'Sign in again on this Computer. Last-known percentages are hidden until the provider authenticates.',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.plan ?? raftText(context, 'Runtime account'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink.sans(14, 20, ink.strong, FontWeight.w700),
                  ),
                  if (account.identity != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        account.identity!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ink.sans(12, 16, ink.muted(.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            RaftRecipeBadge(
              raftText(context, account.health.replaceAll('_', ' ')),
              appearance: RaftBadgeRecipeAppearance.solid,
              variant: account.health == 'ok'
                  ? RaftBadgeRecipeVariant.success
                  : RaftBadgeRecipeVariant.warning,
              uppercase: true,
            ),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              raftText(context, note),
              style: ink.sans(12, 20, ink.muted(.6)),
            ),
          )
        else
          for (final (i, window) in account.windows.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 12 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        window.label,
                        style: ink.sans(12, 16, ink.strong, FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          window.status == 'parse_unavailable'
                              ? raftText(context, 'Usage format unavailable')
                              : window.reset != null
                              ? raftFormat(
                                  context,
                                  '{percent}% used · resets {reset}',
                                  {
                                    'percent': window.percent,
                                    'reset': window.reset!,
                                  },
                                )
                              : raftFormat(
                                  context,
                                  '{percent}% used · reset time unavailable',
                                  {'percent': window.percent},
                                ),
                          textAlign: TextAlign.right,
                          style: ink.sans(
                            12,
                            16,
                            window.status == 'parse_unavailable'
                                ? ink.t.product.brutalOrange
                                : ink.muted(.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (window.status != 'parse_unavailable')
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Semantics(
                        label: window.label,
                        child: RaftProgressBar(
                          value: window.percent.toDouble(),
                          size: RaftProgressRecipeSize.sm,
                          tone: window.status == 'limit_reached'
                              ? RaftProgressRecipeVariant.warning
                              : RaftProgressRecipeVariant.information,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _UsageInk {
  _UsageInk(this.t);
  final RaftTokens t;
  Color get strong => t.brutal ? Colors.black : t.colors['foreground-strong']!;
  Color muted(double brutal) =>
      raftPanelInk(t, brutal, t.colors['foreground-muted']!);
  TextStyle sans(double size, double line, Color color, [FontWeight? w]) =>
      raftCssText.merge(
        RaftTypography.body(
          t,
          size: size,
          line: line,
          color: color,
          weight: w ?? FontWeight.w400,
        ),
      );

  /// `text-[10px] font-bold uppercase tracking-wide`.
  TextStyle eyebrow(Color color) =>
      sans(10, 15, color, FontWeight.w700).copyWith(letterSpacing: .25);
}

/// Web RuntimeAccountUsageChip trigger + hover card: the runtime Badge as a
/// button (`cursor-help`) with its health Status; hovering opens the usage
/// card after 200ms (closes 160ms after leaving), keyboard focus opens it at
/// once and a click pins it until Escape, the close button or an outside
/// press. On narrow / touch layouts a tap opens [onOpenSheet] instead.
class RaftRuntimeUsageChip extends StatefulWidget {
  const RaftRuntimeUsageChip({
    super.key,
    required this.chip,
    required this.label,
    required this.data,
    required this.onOpen,
    required this.onRefresh,
    this.onOpenSheet,
  });

  /// The runtime Badge (label + optional [RaftRuntimeUsageStatus]).
  final Widget chip;
  final String label;
  final RaftRuntimeUsageData data;

  /// The card opened: re-read the snapshot (Web `openNow` → `readSnapshot`).
  final VoidCallback onOpen;
  final VoidCallback onRefresh;

  /// Mobile BottomSheet presentation; when set and the layout is narrow or
  /// touch, a tap calls it instead of pinning the hover card.
  final void Function(BuildContext context)? onOpenSheet;
  @override
  State<RaftRuntimeUsageChip> createState() => _RaftRuntimeUsageChipState();
}

class _RaftRuntimeUsageChipState extends State<RaftRuntimeUsageChip> {
  final card = RaftHoverCardController();
  @override
  void dispose() {
    card.dispose();
    super.dispose();
  }

  /// Web `useMediaQuery("(max-width: 767px)")`.
  bool get mobile => MediaQuery.sizeOf(context).width < 768;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftHoverCard(
      controller: card,
      enabled: !mobile,
      delay: const Duration(milliseconds: 200),
      closeDelay: const Duration(milliseconds: 160),
      // useViewportClamp "vertical-smart": centered on the chip, the side
      // with more room, 8px gutter.
      align: RaftHoverCardAlign.center,
      sideOffset: 8,
      collisionPadding: 8,
      surface: false,
      width: null,
      closeOnTriggerPress: false,
      onOpenChanged: (open) {
        if (open) widget.onOpen();
      },
      card: (context) {
        final width = (MediaQuery.sizeOf(context).width - 16).clamp(0, 390);
        final style = RaftCardRecipe.resolve(
          theme: t.recipeTheme,
          states: t.recipeStates(),
          tokens: t.recipeTokens,
        ).root;
        return Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: raftFormat(context, '{provider} runtime account usage', {
            'provider': widget.data.provider,
          }),
          child: RaftRecipeBox(
            key: const ValueKey('runtime-usage-card'),
            style: style,
            tokens: t.recipeTokens,
            width: width.toDouble(),
            padding: EdgeInsets.zero,
            clip: true,
            child: SingleChildScrollView(
              child: RaftRuntimeUsageSurface(
                data: widget.data,
                onRefresh: widget.onRefresh,
                onClose: card.close,
              ),
            ),
          ),
        );
      },
      child: RaftInteractive(
        semanticLabel: widget.label,
        onPressed: () {
          if (mobile && widget.onOpenSheet != null) {
            widget.onOpenSheet!(context);
          } else {
            card.open(pinned: true);
          }
        },
        builder: (context, state) => MouseRegion(
          cursor: SystemMouseCursors.help,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: state.focusVisible
                  ? Border.all(color: t.strong, width: 2)
                  : null,
            ),
            child: widget.chip,
          ),
        ),
      ),
    );
  }
}

/// The chip's health Status (`size="sm" className="ml-1 size-2"`).
class RaftRuntimeUsageStatus extends StatelessWidget {
  const RaftRuntimeUsageStatus({super.key, required this.attention});
  final bool attention;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftStatusRecipe.resolve(
      theme: t.recipeTheme,
      size: RaftStatusRecipeSize.sm,
      variant: attention
          ? RaftStatusRecipeVariant.warning
          : RaftStatusRecipeVariant.success,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        label: raftText(
          context,
          attention ? 'Usage needs attention' : 'Usage healthy',
        ),
        child: RaftRecipeBox(
          key: ValueKey('runtime-usage-health-$attention'),
          style: style,
          tokens: t.recipeTokens,
          width: 8,
          height: 8,
        ),
      ),
    );
  }
}

/// Mobile presentation (Web BottomSheet `max-h-[82vh] overflow-y-auto`,
/// `fixed inset-x-0 bottom-0 p-3`): the same surface in a bottom card.
class RaftRuntimeUsageSheet extends StatelessWidget {
  const RaftRuntimeUsageSheet({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onClose,
  });
  final RaftRuntimeUsageData data;
  final VoidCallback onRefresh, onClose;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    final padding = MediaQuery.paddingOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          padding.bottom > 12 ? padding.bottom : 12,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: RaftRecipeBox(
            key: const ValueKey('runtime-usage-sheet'),
            style: style,
            tokens: t.recipeTokens,
            width: double.infinity,
            padding: EdgeInsets.zero,
            clip: true,
            child: SingleChildScrollView(
              child: RaftRuntimeUsageSurface(
                data: data,
                onRefresh: onRefresh,
                onClose: onClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
