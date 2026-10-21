// Presentation of the Web Slack bridge setup wizard
// (packages/web/src/components/settings/SlackBridgeSetupWizard.tsx): the
// bordered section with the Hosted bridge heading, the three-step rail and the
// card of the current stage (connect, OAuth, channel pairs, preflight, enable,
// health), plus the disconnect action. The app adapter owns the provisioning
// requests, the draft channel pairs and every transition.
import 'package:flutter/material.dart';

import 'banner.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'list_items.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText, RaftSnappedDecoratedBox;
import 'recipes/button_variants.g.dart';
import 'select_field.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'tokens/shadows.g.dart';

/// `settings.slackBridge.*` option of a channel select.
typedef RaftSlackOption = ({String value, String label, bool enabled});

/// One preflight row: check label key and state (`passed` / `failed` /
/// `unverified`).
typedef RaftSlackCheck = ({String label, String state});

/// The wizard's stages; [RaftSlackWizardView.stage].
enum RaftSlackStage { connect, oauth, channels, preflight, enable, health }

class RaftSlackWizardView extends StatelessWidget {
  const RaftSlackWizardView({
    super.key,
    required this.stage,
    required this.canManage,
    required this.busy,
    this.workspaceName,
    this.errorMessage,
    this.onConnect,
    this.onAuthorize,
    // channels
    this.availableCount = 0,
    this.inviteRequiredCount = 0,
    this.raftOptions = const [],
    this.raftValue = '',
    this.onRaft,
    this.slackOptions = const [],
    this.slackValue = '',
    this.onSlack,
    this.canAddPair = false,
    this.onAddPair,
    this.onRefresh,
    this.pairLabels = const [],
    this.onRemovePair,
    this.pairInvalid = false,
    this.finishLabel = 'Save mappings and enable',
    this.finishEnabled = false,
    this.onFinish,
    // preflight / enable
    this.checks = const [],
    this.preflightPassed = false,
    this.onVerify,
    this.onEnable,
    // health
    this.healthState = 'unverified',
    this.healthReason = '',
    this.healthAction = '',
    this.lastVerified,
    this.failingSurface,
    this.recoveryTitle,
    this.recoveryDescription,
    this.inviteStepsOpen = false,
    this.onToggleInviteSteps,
    this.onManage,
    // disconnect
    this.canDisconnect = false,
    this.disconnectConfirming = false,
    this.onDisconnect,
    this.onDisconnectCancel,
    this.onDisconnectConfirm,
    this.onReauthorize,
  });

  final RaftSlackStage stage;
  final bool canManage, busy;
  final String? workspaceName, errorMessage;
  final VoidCallback? onConnect, onAuthorize;

  final int availableCount, inviteRequiredCount;
  final List<RaftSlackOption> raftOptions, slackOptions;
  final String raftValue, slackValue;
  final ValueChanged<String>? onRaft, onSlack;
  final bool canAddPair, pairInvalid, finishEnabled;
  final VoidCallback? onAddPair, onRefresh, onFinish;
  final List<String> pairLabels;
  final ValueChanged<int>? onRemovePair;
  final String finishLabel;

  final List<RaftSlackCheck> checks;
  final bool preflightPassed;
  final VoidCallback? onVerify, onEnable;

  final String healthState, healthReason, healthAction;
  final String? lastVerified, failingSurface;
  final String? recoveryTitle, recoveryDescription;
  final bool inviteStepsOpen;
  final VoidCallback? onToggleInviteSteps, onManage;

  final bool canDisconnect, disconnectConfirming;
  final VoidCallback? onDisconnect, onDisconnectCancel, onDisconnectConfirm;

  /// `canReauthorize`: re-runs Slack OAuth for the connected workspace (the
  /// server keeps its channel pairs). Offered next to Disconnect, null hides it.
  final VoidCallback? onReauthorize;

  /// `fg/alpha` over [bg] as Chromium composites it. Brutal fills match a
  /// premultiplied model (alpha quantised to 8 bits, half-way rounding down,
  /// both terms rounded); the Elegant fills match Flutter's own blend.
  static Color _over(Color fg, double alpha, Color bg, {bool brutal = false}) {
    if (!brutal) return Color.alphaBlend(fg.withValues(alpha: alpha), bg);
    final a = (alpha * 255 - .5).ceil();
    int ch(double f, double b) =>
        ((f * 255).round() * a / 255).round() +
        ((b * 255).round() * (255 - a) / 255).round();
    return Color.fromARGB(255, ch(fg.r, bg.r), ch(fg.g, bg.g), ch(fg.b, bg.b));
  }

  /// A token fill that may carry its own alpha (Elegant dark `*-soft`).
  static Color _flat(Color c, Color bg) =>
      c.a >= 1 ? c : Color.alphaBlend(c, bg);

  // ------------------------------------------------------------- styles

  static TextStyle _text(
    RaftTokens t, {
    double size = 12,
    double? line,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double tracking = 0,
  }) => RaftTypography.heading(
    t,
    size: size,
    line: line ?? size * 1.5,
    weight: weight,
  ).copyWith(color: color ?? t.strong, letterSpacing: tracking);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftSettingsText(t);
    final strong = s.strong,
        muted = t.brutal ? Colors.black.withValues(alpha: .6) : t.muted;
    return RaftSnappedDecoratedBox(
      key: const ValueKey('slack-bridge-wizard'),
      padding: const EdgeInsets.all(16),
      decoration: RaftSettingsCard.decoration(t).copyWith(
        color: t.brutal
            ? t.colors['brutal-cream']
            : t.colors['layer-canvas-muted'],
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, t, s, muted),
          const SizedBox(height: 12),
          _stepRail(context, t),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            RaftBanner(
              description: errorMessage!,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.circleAlert,
            ),
          ],
          const SizedBox(height: 12),
          _stageCard(context, t, s, strong, muted),
          if (canDisconnect && !disconnectConfirming) ...[
            const SizedBox(height: 12),
            // `flex flex-wrap justify-end gap-2`
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onReauthorize != null)
                  RaftSettingsRecipeButton(
                    key: const ValueKey('slack-bridge-reauthorize'),
                    label: 'Update Slack authorization',
                    variant: RaftButtonRecipeVariant.default_,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: busy ? null : onReauthorize,
                  ),
                RaftSettingsRecipeButton(
                  key: const ValueKey('slack-bridge-disconnect'),
                  label: 'Disconnect Slack workspace',
                  variant: RaftButtonRecipeVariant.danger,
                  size: RaftButtonRecipeSize.sm,
                  onPressed: busy ? null : onDisconnect,
                ),
              ],
            ),
          ],
          if (canDisconnect && disconnectConfirming) ...[
            const SizedBox(height: 12),
            _disconnectConfirmation(context, t, s),
          ],
        ],
      ),
    );
  }

  /// `#a ↔ #b`: the arrow comes from a fallback font whose taller metrics
  /// would stretch the 16px line, so the strut pins it.
  Widget _pairText(RaftTokens t, RaftSettingsText s, String label) =>
      RaftCssText(
        label,
        strutStyle: const StrutStyle(
          fontSize: 12,
          height: 16 / 12,
          forceStrutHeight: true,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        style: _text(
          t,
          size: 12,
          line: 16,
          weight: FontWeight.w700,
          color: s.strong,
        ),
      );

  // ------------------------------------------------------------- header

  Widget _header(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color muted,
  ) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftSectionEyebrow(raftText(context, 'Hosted bridge')),
        const SizedBox(height: 4),
        RaftCssText(
          raftText(context, 'Raft for Slack'),
          style: _text(
            t,
            size: 18,
            line: 28,
            weight: RaftTypography.black(t),
            color: s.strong,
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: RaftCssText(
            raftText(
              context,
              'Connect Slack and choose channel mappings. Raft verifies the bridge and enables delivery for you.',
            ),
            style: _text(t, size: 12, line: 12 * 1.625, color: muted),
          ),
        ),
      ],
    );
    if (canManage) {
      return Align(alignment: Alignment.centerLeft, child: copy);
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 12,
      children: [copy, _pill(context, t, s, 'View only')],
    );
  }

  Widget _pill(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    String label,
  ) => RaftSnappedDecoratedBox(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: s.panel,
      border: Border.all(
        color: t.brutal ? Colors.black : t.colors['line-muted']!,
        width: 1,
      ),
      borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
    ),
    child: RaftCssText(
      raftText(context, label),
      style: _text(
        t,
        size: 12,
        line: 16,
        weight: FontWeight.w700,
        color: s.strong,
      ),
    ),
  );

  // ------------------------------------------------------------- step rail

  Widget _stepRail(BuildContext context, RaftTokens t) {
    final active = switch (stage) {
      RaftSlackStage.connect || RaftSlackStage.oauth => 0,
      RaftSlackStage.health => 2,
      _ => 1,
    };
    const labels = ['Connect', 'Channels', 'Health'];
    Widget step(int i) {
      final done = i < active, current = i == active;
      final Color fill = done
          ? (t.brutal
                ? _over(
                    t.colors['color-brutal-lime']!,
                    .4,
                    t.colors['brutal-cream']!,
                    brutal: true,
                  )
                : t.colors['success-soft']!)
          : current
          ? (t.brutal
                ? t.colors['color-brutal-pink']!
                : t.colors['accent-soft']!)
          : (t.brutal ? Colors.white : t.panel);
      final Color ink = done
          ? t.strong
          : current
          ? (t.brutal ? Colors.black : t.colors['accent-strong']!)
          : (t.brutal
                ? Colors.black.withValues(alpha: .45)
                : t.colors['foreground-hint']!);
      return RaftSnappedDecoratedBox(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: t.brutal ? Colors.black : t.colors['line-muted']!,
          ),
          borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
        ),
        child: RaftCssText(
          raftText(context, labels[i]).toUpperCase(),
          textAlign: TextAlign.center,
          style: _text(
            t,
            size: 10,
            line: 15,
            weight: FontWeight.w700,
            color: ink,
            tracking: .25,
          ),
        ),
      );
    }

    return Semantics(
      label: raftText(context, 'Slack bridge setup progress'),
      child: Row(
        spacing: 6,
        children: [for (var i = 0; i < 3; i++) Expanded(child: step(i))],
      ),
    );
  }

  // ------------------------------------------------------------- cards

  BoxDecoration _cardDecoration(RaftTokens t) => BoxDecoration(
    color: t.brutal ? Colors.white : t.panel,
    border: Border.all(
      color: t.brutal ? Colors.black : t.colors['line-muted']!,
      width: t.brutal ? 2 : 1,
    ),
    borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
  );

  Widget _titleDesc(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color muted,
    String title,
    String description,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RaftCssText(
        raftText(context, title),
        style: _text(
          t,
          size: 14,
          line: 20,
          weight: FontWeight.w700,
          color: s.strong,
        ),
      ),
      const SizedBox(height: 4),
      RaftCssText(
        raftText(context, description),
        style: _text(t, size: 12, line: 16, color: muted),
      ),
    ],
  );

  Widget _stageCard(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color strong,
    Color muted,
  ) {
    switch (stage) {
      case RaftSlackStage.connect:
        return _simpleCard(
          context,
          t,
          s,
          muted,
          title: 'Connect a Slack workspace',
          description:
              'Continue to Slack once; Raft creates the connection and starts authorization automatically.',
          action: canManage
              ? _accent(
                  'Connect with Slack',
                  onConnect,
                  key: 'slack-bridge-connect',
                )
              : null,
        );
      case RaftSlackStage.oauth:
        return _simpleCard(
          context,
          t,
          s,
          muted,
          title: 'Authorize with Slack',
          description:
              'Slack will show the requested scopes before you approve access.',
          action: canManage
              ? _accent(
                  'Authorize in Slack',
                  onAuthorize,
                  key: 'slack-bridge-authorize',
                )
              : null,
        );
      case RaftSlackStage.channels:
        return _channelsCard(context, t, s, muted);
      case RaftSlackStage.preflight:
        return RaftSnappedDecoratedBox(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _titleDesc(
                context,
                t,
                s,
                muted,
                'Verify the bridge before enabling it',
                'Check OAuth, the hosted endpoint, granted scopes, and channel audience.',
              ),
              if (checks.isNotEmpty) _preflightResults(context, t, s),
              if (canManage) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _accent(
                    'Verify and finish setup',
                    busy ? null : onVerify,
                    key: 'slack-bridge-verify',
                  ),
                ),
              ],
            ],
          ),
        );
      case RaftSlackStage.enable:
        return RaftSnappedDecoratedBox(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              if (checks.isNotEmpty)
                _preflightResults(context, t, s)
              else
                RaftBanner(
                  description:
                      'Preflight has not passed. The bridge cannot be enabled.',
                  status: RaftBannerRecipeStatus.warning,
                  size: RaftBannerRecipeSize.sm,
                  glyph: RaftGlyph.triangleAlert,
                ),
              if (canManage)
                Align(
                  alignment: Alignment.centerRight,
                  child: _accent(
                    'Verify and finish setup',
                    busy ? null : onEnable,
                    key: 'slack-bridge-enable',
                  ),
                ),
            ],
          ),
        );
      case RaftSlackStage.health:
        return _health(context, t, s, muted);
    }
  }

  Widget _accent(
    String label,
    VoidCallback? onPressed, {
    String? key,
    RaftButtonRecipeSize size = RaftButtonRecipeSize.md,
  }) => RaftSettingsRecipeButton(
    key: key == null ? null : ValueKey(key),
    label: label,
    variant: RaftButtonRecipeVariant.accent,
    size: size,
    onPressed: onPressed,
  );

  Widget _simpleCard(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color muted, {
    required String title,
    required String description,
    Widget? action,
  }) => RaftSnappedDecoratedBox(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(t),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleDesc(context, t, s, muted, title, description),
        if (action != null) ...[
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: action),
        ],
      ],
    ),
  );

  // ------------------------------------------------------------- channels

  String _summary(BuildContext context) {
    final zh = Localizations.maybeLocaleOf(context)?.languageCode == 'zh';
    if (zh) {
      return '$availableCount 个频道可映射 · $inviteRequiredCount 个频道需要先邀请 Raft 应用';
    }
    final ready = availableCount == 1
        ? '$availableCount channel ready to pair'
        : '$availableCount channels ready to pair';
    final invite = inviteRequiredCount == 1
        ? '$inviteRequiredCount needs the Raft app invited'
        : '$inviteRequiredCount need the Raft app invited';
    return '$ready · $invite';
  }

  Widget _channelsCard(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color muted,
  ) {
    Widget select(
      String label,
      List<RaftSlackOption> options,
      String value,
      ValueChanged<String>? onChanged,
      String key,
    ) => RaftSettingsField(
      label: label,
      child: RaftSelectField<String>(
        key: ValueKey(key),
        label: label,
        value: options.any((o) => o.value == value) ? value : null,
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o.value,
              enabled: o.enabled,
              child: RaftCssText(raftText(context, o.label)),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
    final hint = RaftCssText(
      raftText(
        context,
        'Invite the Raft app to a Slack channel before selecting it.',
      ),
      style: _text(t, size: 12, line: 16, color: t.colors['foreground-hint']),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        RaftSettingsRecipeButton(
          key: const ValueKey('slack-bridge-add-pair'),
          label: 'Add',
          variant: RaftButtonRecipeVariant.default_,
          glyph: RaftGlyph.plus,
          glyphSize: 14,
          onPressed: canAddPair ? onAddPair : null,
        ),
        RaftSettingsRecipeButton(
          key: const ValueKey('slack-bridge-refresh'),
          label: 'Refresh',
          variant: RaftButtonRecipeVariant.default_,
          glyph: RaftGlyph.refreshCw,
          glyphSize: 14,
          onPressed: busy ? null : onRefresh,
        ),
      ],
    );
    final raftSelect = select(
      'Raft channel',
      raftOptions,
      raftValue,
      onRaft,
      'slack-bridge-raft-channel',
    );
    final slackSelect = select(
      'Slack channel',
      slackOptions,
      slackValue,
      onSlack,
      'slack-bridge-slack-channel',
    );
    Widget pairGrid() => LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 600) {
          // sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto], gap-x-2 gap-y-1:
          // the hint sits under the Slack field, the actions bottom-align with
          // the selects (a 58px field: label 16 + 10 + select 32).
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Expanded(child: raftSelect),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [slackSelect, hint],
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 26), child: actions),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            raftSelect,
            slackSelect,
            hint,
            Align(alignment: Alignment.centerLeft, child: actions),
          ],
        );
      },
    );
    return RaftSnappedDecoratedBox(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _titleDesc(
            context,
            t,
            s,
            muted,
            'Choose channel pairs',
            'Each Raft channel and Slack channel can appear in exactly one pair. The Raft app must already be a member of the Slack channel.',
          ),
          RaftCssText(
            _summary(context),
            style: _text(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w700,
              color: muted,
            ),
          ),
          if (canManage) pairGrid(),
          if (pairLabels.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                for (var i = 0; i < pairLabels.length; i++)
                  _pairRow(
                    context,
                    t,
                    s,
                    pairLabels[i],
                    index: i,
                    removable: canManage ? () => onRemovePair?.call(i) : null,
                  ),
              ],
            ),
          if (pairInvalid && pairLabels.isNotEmpty)
            RaftBanner(
              description: 'Channel pairs must be complete and one-to-one.',
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
            ),
          if (canManage)
            Align(
              alignment: Alignment.centerRight,
              child: _accent(
                finishLabel,
                finishEnabled && !busy ? onFinish : null,
                key: 'slack-bridge-finish',
              ),
            ),
        ],
      ),
    );
  }

  Widget _pairRow(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    String label, {
    VoidCallback? removable,
    int index = 0,
  }) => RaftSnappedDecoratedBox(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: t.brutal ? t.colors['brutal-cream'] : t.colors['layer-inset'],
      border: Border.all(
        color: t.brutal ? Colors.black : t.colors['line-muted']!,
      ),
      borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
    ),
    child: Row(
      spacing: 12,
      children: [
        Expanded(child: _pairText(t, s, label)),
        if (removable != null)
          RaftSettingsRecipeButton(
            key: ValueKey('slack-bridge-remove-pair-$index'),
            label: '',
            glyph: RaftGlyph.trash2,
            glyphSize: 12,
            variant: RaftButtonRecipeVariant.danger,
            size: RaftButtonRecipeSize.iconXs,
            onPressed: removable,
          ),
      ],
    ),
  );

  // ------------------------------------------------------------- preflight

  Widget _preflightResults(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s, {
    bool topGap = true,
  }) {
    final items = [
      for (final c in checks)
        RaftSnappedDecoratedBox(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.brutal
                ? t.colors['brutal-cream']
                : t.colors['layer-inset'],
            border: Border.all(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
            ),
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RaftCssText(
                raftText(context, c.label),
                style: _text(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: s.strong,
                ),
              ),
              RaftCssText(
                raftText(context, switch (c.state) {
                  'passed' => 'Passed',
                  'failed' => 'Failed',
                  _ => 'Unverified',
                }).toUpperCase(),
                style: _text(t, size: 12, line: 16, color: s.strong),
              ),
            ],
          ),
        ),
    ];
    return Padding(
      padding: EdgeInsets.only(top: topGap ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          preflightPassed
              ? const RaftBanner(
                  description: 'All preflight checks passed.',
                  status: RaftBannerRecipeStatus.success,
                  size: RaftBannerRecipeSize.sm,
                  glyph: RaftGlyph.check,
                )
              : const RaftBanner(
                  description:
                      'Preflight has not passed. The bridge cannot be enabled.',
                  status: RaftBannerRecipeStatus.warning,
                  size: RaftBannerRecipeSize.sm,
                  glyph: RaftGlyph.triangleAlert,
                ),
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: items,
                );
              }
              return Column(
                spacing: 8,
                children: [
                  for (var i = 0; i < items.length; i += 2)
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: items[i]),
                        Expanded(
                          child: i + 1 < items.length
                              ? items[i + 1]
                              : const SizedBox(),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- health

  Widget _health(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
    Color muted,
  ) {
    // The translucent tone is composited over the section fill: Flutter would
    // paint the (brutal) outer shadow underneath it.
    final sectionFill = t.brutal
        ? t.colors['brutal-cream']!
        : t.colors['layer-canvas-muted']!;
    final Color tone = _flat(switch (healthState) {
      'connected' =>
        t.brutal
            ? _over(
                t.colors['color-brutal-lime']!,
                .3,
                sectionFill,
                brutal: true,
              )
            : t.colors['success-soft']!,
      'degraded' =>
        t.brutal
            ? _over(
                t.colors['color-brutal-orange']!,
                .25,
                sectionFill,
                brutal: true,
              )
            : t.colors['warning-soft']!,
      // `bg-soft-signal/30` / `dark:bg-fill-muted/50`: the measured Blink
      // composites over the section fill (the blends differ by one level).
      'unverified' =>
        t.brutal
            ? const Color(0xFFFFEFBB)
            : t.dark
            ? const Color(0xFF1F1F1D)
            : _over(t.colors['fill-muted']!, .5, sectionFill),
      _ =>
        t.brutal
            ? _over(
                t.colors['color-brutal-red']!,
                .2,
                sectionFill,
                brutal: true,
              )
            : t.colors['danger-soft']!,
    }, sectionFill);
    Widget cell(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftCssText(
          raftText(context, label),
          style: _text(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 2),
        RaftCssText(
          value,
          style: _text(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w600,
            color: s.strong,
          ),
        ),
      ],
    );
    final cells = [
      cell(
        'Verification',
        lastVerified == null
            ? raftText(context, 'Not verified yet')
            : raftFormat(context, 'Last verified {when}', {
                'when': lastVerified,
              }),
      ),
      cell('Failing surface', raftText(context, failingSurface ?? 'None')),
      cell('Next action', raftText(context, healthAction)),
    ];
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftSectionEyebrow(raftText(context, 'Bridge health')),
        const SizedBox(height: 4),
        RaftCssText(
          raftText(
            context,
            healthState == 'connected'
                ? 'Connected'
                : healthState == 'degraded'
                ? 'Degraded'
                : healthState == 'unverified'
                ? 'Unverified'
                : 'Disconnected',
          ),
          style: _text(
            t,
            size: 20,
            line: 28,
            weight: RaftTypography.black(t),
            color: s.strong,
          ),
        ),
        const SizedBox(height: 4),
        RaftCssText(
          raftText(context, healthReason),
          style: _text(t, size: 12, line: 12 * 1.625, color: muted),
        ),
      ],
    );
    return RaftSnappedDecoratedBox(
      key: const ValueKey('slack-bridge-health'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
        boxShadow: t.brutal
            ? RaftProductShadows.shadowBrutalSm.outer
            : t.themeShadows.sm.outer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              heading,
              if (workspaceName != null) _pill(context, t, s, workspaceName!),
            ],
          ),
          if (recoveryTitle != null) ...[
            const SizedBox(height: 16),
            RaftBanner(
              title: recoveryTitle,
              titleGap: t.brutal ? null : 4,
              description: recoveryDescription ?? '',
              status: RaftBannerRecipeStatus.warning,
              size: RaftBannerRecipeSize.sm,
              glyph: RaftGlyph.circleAlert,
              footer: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RaftSettingsRecipeButton(
                          key: const ValueKey('slack-bridge-invite-steps'),
                          label: 'How to invite the app',
                          variant: RaftButtonRecipeVariant.default_,
                          size: RaftButtonRecipeSize.sm,
                          restColor: t.colors['warning-strong'],
                          onPressed: onToggleInviteSteps,
                        ),
                        RaftSettingsRecipeButton(
                          label: 'Refresh and recheck',
                          glyph: RaftGlyph.refreshCw,
                          glyphSize: 13,
                          variant: RaftButtonRecipeVariant.accent,
                          size: RaftButtonRecipeSize.sm,
                          onPressed: busy ? null : onRefresh,
                        ),
                      ],
                    ),
                    if (inviteStepsOpen)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            for (final (i, step) in const [
                              'Open the affected channel in Slack.',
                              'Open channel settings or Integrations and invite the Raft app.',
                              'Return to Raft and select Refresh and recheck.',
                            ].indexed)
                              RaftCssText(
                                '${i + 1}. ${raftText(context, step)}',
                                style: _text(
                                  t,
                                  size: 13,
                                  line: 16,
                                  weight: FontWeight.w600,
                                  color: t.colors['warning-strong'],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [for (final c in cells) Expanded(child: c)],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: cells,
                  ),
          ),
          const SizedBox(height: 16),
          RaftSnappedDecoratedBox(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: t.colors['line-hairline']!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    RaftCssText(
                      raftText(context, 'Selected channel pairs').toUpperCase(),
                      style: _text(
                        t,
                        size: 12,
                        line: 16,
                        weight: FontWeight.w700,
                        color: muted,
                        tracking: .3,
                      ),
                    ),
                    if (canManage)
                      RaftSettingsRecipeButton(
                        key: const ValueKey('slack-bridge-manage'),
                        label: 'Manage channel mappings',
                        variant: RaftButtonRecipeVariant.default_,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: onManage,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 6,
                  children: [
                    for (final label in pairLabels)
                      RaftSnappedDecoratedBox(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: s.panel,
                          border: Border.all(
                            color: t.brutal
                                ? Colors.black
                                : t.colors['line-muted']!,
                          ),
                          borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
                        ),
                        child: _pairText(t, s, label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _disconnectConfirmation(
    BuildContext context,
    RaftTokens t,
    RaftSettingsText s,
  ) => RaftSnappedDecoratedBox(
    key: const ValueKey('slack-bridge-disconnect-confirmation'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: t.brutal
          ? t.colors['color-brutal-red']!.withValues(alpha: .2)
          : t.colors['danger-soft'],
      border: Border.all(
        color: t.brutal ? Colors.black : t.colors['line-muted']!,
        width: t.brutal ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        RaftCssText(
          raftText(
            context,
            "Disconnecting revokes this Raft Server's Slack credential, all channel mappings, outbound authorizations, and identity links. It does not uninstall the app in Slack; reconnecting requires a new authorization.",
          ),
          style: _text(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w600,
            color: s.strong,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            RaftSettingsRecipeButton(
              label: 'Cancel',
              variant: RaftButtonRecipeVariant.default_,
              size: RaftButtonRecipeSize.sm,
              onPressed: busy ? null : onDisconnectCancel,
            ),
            RaftSettingsRecipeButton(
              key: const ValueKey('slack-bridge-disconnect-confirm'),
              label: 'Confirm disconnect',
              variant: RaftButtonRecipeVariant.danger,
              size: RaftButtonRecipeSize.sm,
              onPressed: busy ? null : onDisconnectConfirm,
            ),
          ],
        ),
      ],
    ),
  );
}
