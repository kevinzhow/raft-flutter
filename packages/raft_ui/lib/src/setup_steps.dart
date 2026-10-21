// Server setup gate steps (packages/web/src/components/onboarding/
// ServerSetupSurveyStep.tsx, ServerSetupHandoffStep.tsx,
// ServerSetupComputerRuntimeStep.tsx, SetupSessionFooter.tsx). Presentation
// only: the app owns the projection, requests and state and passes values and
// callbacks in.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'raft_underline.dart';
import 'agent_profile.dart';
import 'auth_page.dart';
import 'cindy_setup_screen.dart';
import 'add_computer_dialog.dart';
import 'components.dart';
import 'css_pixel_snap.dart';
import 'design_primitives.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'keyboard_reveal.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'recipe_surface.dart' show RaftCssBoxDecoration;
import 'text_measure.dart';
import 'text_scaling.dart' show RaftChrome, RaftScaled;
import 'theme.dart';
import 'tokens/tokens.dart';

/// `sm:` breakpoint of the step footers (`flex-col-reverse gap-3
/// sm:flex-row sm:items-center sm:justify-between`).
bool _wide(BuildContext context, [double? available]) =>
    MediaQuery.sizeOf(context).width >= 640 &&
    (available == null || available >= _rowMinWidth);

/// Narrowest card that holds the `sm:flex-row` footer / header rows. Web uses
/// the viewport alone; a card in a narrower host (a pane, a test surface)
/// stacks instead of overflowing.
const double _rowMinWidth = 420;

/// The step card chrome shared by survey / handoff: `flex w-full max-w-[N]
/// flex-col overflow-hidden border border-line-muted bg-layer-panel
/// shadow-raft-md theme-brutal:border-2 theme-brutal:border-black
/// theme-brutal:bg-white theme-brutal:shadow-brutal` (+ `rounded-lg`, square in
/// brutal).
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.maxWidth,
    required this.child,
    this.rounded = true,
  });
  final double maxWidth;
  final bool rounded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: RaftCssBoxDecoration(
            color: t.brutal ? Colors.white : t.panel,
            border: Border.all(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
            borderRadius: rounded && !t.brutal
                ? BorderRadius.circular(8)
                : null,
            boxShadow: t.brutal
                ? RaftProductShadows.shadowBrutal.outer
                : t.themeShadows.md.outer,
          ),
          child: ClipRRect(
            borderRadius: rounded && !t.brutal
                ? BorderRadius.circular(7)
                : BorderRadius.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

Color _hairline(RaftTokens t) =>
    t.brutal ? Colors.black : t.colors['line-hairline']!;
double _hairlineWidth(RaftTokens t) => t.brutal ? 2 : 1;

/// ServerSetupSurveyStep: header (eyebrow, title, hint), two [chip groups],
/// footer with the session link and the Continue button.
class RaftSetupSurveyCard extends StatelessWidget {
  const RaftSetupSurveyCard({
    super.key,
    required this.roles,
    required this.sources,
    required this.role,
    required this.source,
    required this.otherController,
    required this.saving,
    this.error,
    this.agentName = 'Cindy',
    this.onRole,
    this.onSource,
    this.onContinue,
    this.onSwitchServer,
    this.onDeleteServer,
    this.showDeleteServer,
  });

  /// `id -> label`, in display order.
  final Map<String, String> roles, sources;
  final String? role, source, error;
  final String agentName;

  /// The "other source" input (`maxLength 200`), shown when [source] is
  /// `other`.
  final TextEditingController otherController;
  final bool saving;
  final ValueChanged<String>? onRole, onSource;
  final VoidCallback? onContinue, onSwitchServer;
  final VoidCallback? onDeleteServer;
  final bool? showDeleteServer;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double available) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final wide = _wide(context, available);
    final canContinue = !saving && role != null && source != null;
    final cont = RaftPrimaryAction(
      child: RaftButton(
        key: const Key('server-setup-survey-continue'),
        label: saving ? tr('Saving…') : tr('Continue'),
        tone: RaftButtonRecipeVariant.accent,
        size: RaftButtonRecipeSize.lg,
        expand: !wide,
        onPressed: canContinue ? onContinue : null,
      ),
    );
    final footer = wide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _SessionFooter(
                  onSwitchServer: onSwitchServer,
                  onDeleteServer: onDeleteServer,
                  showDeleteServer: showDeleteServer,
                ),
              ),
              cont,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cont,
              const SizedBox(height: 12),
              _SessionFooter(
                onSwitchServer: onSwitchServer,
                onDeleteServer: onDeleteServer,
                showDeleteServer: showDeleteServer,
              ),
            ],
          );
    return _StepCard(
      maxWidth: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('setup-survey-header'),
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _hairline(t),
                  width: _hairlineWidth(t),
                ),
              ),
            ),
            child: _StepHeading(
              eyebrow: tr('Set up your server'),
              title: raftFormat(context, 'Tell {agentName} about you', {
                'agentName': agentName,
              }),
              hint: tr(
                'She reads this before she says hello, and starts you somewhere that fits your work.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null) ...[
                  RaftAuthBanner(text: tr(error!)),
                  const SizedBox(height: 20), // space-y-5
                ],
                _ChipGroup(
                  question: tr('What best describes you?'),
                  prefix: 'role',
                  options: roles,
                  value: role,
                  onChanged: onRole,
                ),
                const SizedBox(height: 20),
                _ChipGroup(
                  question: tr('How did you hear about Raft?'),
                  prefix: 'source',
                  options: sources,
                  value: source,
                  onChanged: onSource,
                  trailing: source == 'other'
                      ? RaftTextInput(
                          key: const Key('signup-source-other-input'),
                          controller: otherController,
                          maxLength: 200,
                          // `input-brutal mt-2 w-full p-2 text-sm`.
                          padding: const EdgeInsets.all(8),
                          style: const TextStyle(fontSize: 14, height: 20 / 14),
                          hintText: tr('Where did you hear about us?'),
                          semanticLabel: tr('How did you hear about Raft?'),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `font-mono text-[10px] font-bold uppercase tracking-wide` eyebrow, `mt-2
/// text-xl font-bold` title, `mt-1 text-xs leading-5` hint.
class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.eyebrow,
    required this.title,
    required this.hint,
  });
  final String eyebrow, title, hint;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontFamily: t.monoFont,
            fontSize: 10,
            height: 15 / 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .25,
            color: t.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: RaftTypography.heading(t, size: 20, line: 28)),
        const SizedBox(height: 4),
        Text(
          hint,
          style: RaftTypography.heading(
            t,
            size: 12,
            line: 20,
            weight: FontWeight.w400,
          ).copyWith(color: t.muted),
        ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.question,
    required this.prefix,
    required this.options,
    required this.value,
    required this.onChanged,
    this.trailing,
  });
  final String question, prefix;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            question,
            style: RaftTypography.heading(t, size: 14, line: 20),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(:key, :value) in options.entries)
              _Chip(
                key: Key('signup-$prefix-$key'),
                label: value,
                selected: this.value == key,
                onTap: onChanged == null ? null : () => onChanged!(key),
              ),
          ],
        ),
        if (trailing != null) ...[const SizedBox(height: 8), trailing!],
      ],
    );
  }
}

/// `rounded-md border border-line-muted px-3 py-1.5 text-sm font-bold
/// text-foreground-strong`; selected `bg-primary-soft shadow-raft-xs`
/// (brutal `bg-soft-signal text-black shadow-brutal-sm`), idle `bg-layer-panel`
/// (brutal `bg-white text-black`); brutal `rounded-none border-2
/// border-black`.
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final border = t.brutal ? 2.0 : 1.0;
    final fill = t.brutal
        ? (selected ? t.product.softSignal : Colors.white)
        : (selected ? t.colors['primary-soft']! : t.panel);
    final shadows = selected
        ? (t.brutal
              ? RaftProductShadows.shadowBrutalSm.outer
              : t.themeShadows.xs.outer)
        : const <BoxShadow>[];
    return RaftInteractive(
      onPressed: onTap,
      semanticLabel: label,
      selected: selected,
      builder: (context, state) {
        final active = state.enabled && (state.hovered || state.pressed);
        // Not selected: hover / pressed tint the idle surface.
        final shade = !selected && active
            ? (t.brutal
                  ? t.product.brutalCream
                  : t.colors['layer-canvas-muted']!)
            : fill;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
            boxShadow: [
              if (state.focusVisible)
                BoxShadow(
                  color: (t.brutal ? Colors.black : t.ink).withValues(
                    alpha: .8,
                  ),
                  spreadRadius: 2,
                ),
            ],
          ),
          child: RaftCssSnappedBox(
            color: shade,
            borderColor: t.brutal
                ? Colors.black
                : active
                ? t.colors['line-strong']!
                : t.colors['line-muted']!,
            borderWidth: border,
            radius: t.brutal ? 0 : 6,
            shadows: state.pressed && t.brutal ? const [] : shadows,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12 + border,
                vertical: 6 + border,
              ),
              child: Text(
                label,
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                ).copyWith(color: t.brutal ? Colors.black : t.strong),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// SetupSessionFooter: `flex items-center gap-4 text-sm` with the muted
/// "Switch server" TextLink and the owner-only "Delete this server" one.
class _SessionFooter extends StatelessWidget {
  const _SessionFooter({
    this.onSwitchServer,
    this.onDeleteServer,
    this.showDeleteServer,
  });
  final VoidCallback? onSwitchServer, onDeleteServer;
  final bool? showDeleteServer;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    heightFactor: 1,
    child: RaftCindySessionFooter(
      onSwitchServer: onSwitchServer,
      onDeleteServer: onDeleteServer,
      showDeleteServer: showDeleteServer,
    ),
  );
}

/// ServerSetupHandoffStep: avatar, title and body centred, then a footer with
/// the session link and the "Let's Go" button.
class RaftSetupHandoffCard extends StatelessWidget {
  const RaftSetupHandoffCard({
    super.key,
    required this.starting,
    this.agentName = 'Cindy',
    this.onDone,
    this.onSwitchServer,
    this.onDeleteServer,
    this.showDeleteServer,
  });
  final bool starting;
  final String agentName;
  final VoidCallback? onDone;
  final VoidCallback? onSwitchServer;
  final VoidCallback? onDeleteServer;
  final bool? showDeleteServer;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double available) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final wide = _wide(context, available);
    final done = RaftButton(
      key: const Key('server-setup-handoff-done'),
      label: starting ? tr('Starting…') : tr("Let's Go"),
      tone: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.lg,
      expand: !wide,
      onPressed: starting ? null : onDone,
    );
    return _StepCard(
      maxWidth: 560,
      rounded: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: RaftCssBoxDecoration(
                    boxShadow: t.brutal
                        ? RaftProductShadows.shadowBrutalLg.outer
                        : null,
                  ),
                  child: RaftAvatarSlot(
                    name: agentName,
                    avatarUrl: 'pixel:mug',
                    slot: RaftAvatarSlotContext.profileTile,
                    sizeOverride: 104,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  raftFormat(context, '{agentName} takes it from here', {
                    'agentName': agentName,
                  }),
                  textAlign: TextAlign.center,
                  style: RaftTypography.heading(
                    t,
                    size: 24,
                    line: 32,
                    weight: RaftTypography.black(t),
                  ).copyWith(color: t.brutal ? Colors.black : t.strong),
                ),
                const SizedBox(height: 12),
                _BalancedText(
                  raftFormat(
                    context,
                    "Your server is set up. {agentName} is waiting in your channel. She'll show you around Raft and get you working for real.",
                    {'agentName': agentName},
                  ),
                  maxChars: 42,
                  style:
                      RaftTypography.heading(
                        t,
                        size: 16,
                        line: 26,
                        weight: FontWeight.w400,
                      ).copyWith(
                        color: t.brutal ? const Color(0xB3000000) : t.muted,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: t.brutal ? Colors.black : t.colors['line-muted']!,
                  width: _hairlineWidth(t),
                ),
              ),
            ),
            child: wide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: _SessionFooter(
                          onSwitchServer: onSwitchServer,
                          onDeleteServer: onDeleteServer,
                          showDeleteServer: showDeleteServer,
                        ),
                      ),
                      done,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      done,
                      const SizedBox(height: 12),
                      _SessionFooter(
                        onSwitchServer: onSwitchServer,
                        onDeleteServer: onDeleteServer,
                        showDeleteServer: showDeleteServer,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ServerSetupComputerRuntimeStep

/// One runtime of the setup catalog (`ServerSetupRuntimeCatalogEntry`).
@immutable
class RaftSetupRuntime {
  const RaftSetupRuntime({
    required this.id,
    required this.displayName,
    required this.abbreviation,
    required this.detected,
    required this.recommended,
  });
  final String id, displayName, abbreviation;
  final bool detected, recommended;
}

/// A sleeping computer of the recovery list; [lastSeen] is the preformatted
/// relative time (null: no heartbeat on record).
@immutable
class RaftSetupOfflineComputer {
  const RaftSetupOfflineComputer(this.name, {this.lastSeen});
  final String name;
  final String? lastSeen;
}

const _runtimeInstallCommands = {
  'claude': 'npm install -g @anthropic-ai/claude-code',
  'codex': 'npm install -g @openai/codex',
};

/// The "Set up your server" computer/runtime step (the Web
/// `ServerSetupComputerRuntimeStep`): header, the connect flow (command guide,
/// instructions and progress log) or the offline recovery card, the "no usable
/// runtime" picker, and the footer with the session link and Next.
class RaftSetupComputerCard extends StatefulWidget {
  const RaftSetupComputerCard({
    super.key,
    required this.computerName,
    required this.computerOnline,
    required this.waiting,
    required this.runtimeReady,
    required this.runtimeNames,
    required this.runtimeAnswered,
    required this.recommendedRuntimes,
    required this.supportedRuntimes,
    required this.offlineComputers,
    required this.recovering,
    required this.legacyDaemon,
    required this.guidePlatform,
    required this.onGuidePlatform,
    required this.guideCommands,
    this.guideInstallAndSetup,
    required this.serverSlug,
    required this.canReset,
    required this.loading,
    this.error,
    this.onStartOver,
    this.onNext,
    this.onSwitchServer,
    this.onDeleteServer,
    this.showDeleteServer,
    this.onCopyInstallCommand,
  });

  /// Name of the connecting / connected computer (null: "your computer").
  final String? computerName;
  final bool computerOnline, waiting, runtimeReady, runtimeAnswered;
  final List<String> runtimeNames;
  final List<RaftSetupRuntime> recommendedRuntimes, supportedRuntimes;
  final List<RaftSetupOfflineComputer> offlineComputers;

  /// They connected a computer before; it is not running.
  final bool recovering, legacyDaemon;
  final String guidePlatform;
  final ValueChanged<String> onGuidePlatform;

  /// (install, setup) of the selected platform; null without a slug.
  final (String, String)? guideCommands;

  /// mac/Linux one-paste install + setup of the selected platform; null keeps
  /// the two steps (Web `computerInstallAndSetupCommand`).
  final String? guideInstallAndSetup;
  final String? serverSlug;
  final bool canReset, loading;
  final String? error;
  final VoidCallback? onStartOver, onNext, onSwitchServer;
  final VoidCallback? onDeleteServer;

  /// Owner-only "Delete this server" link; defaults to `onDeleteServer != null`.
  final bool? showDeleteServer;
  final void Function(String runtimeId, String command)? onCopyInstallCommand;

  @override
  State<RaftSetupComputerCard> createState() => _RaftSetupComputerCardState();
}

class _RaftSetupComputerCardState extends State<RaftSetupComputerCard> {
  String? expandedRuntime;

  bool get many => widget.recovering && widget.offlineComputers.length > 1;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _build(context, box.maxWidth));

  Widget _build(BuildContext context, double available) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final size = MediaQuery.sizeOf(context);
    final wide = _wide(context, available), md = size.width >= 768;
    final sideBody = wide ? 36.0 : 20.0;
    final title = many
        ? 'Start one of your computers'
        : widget.recovering
        ? 'Start your computer'
        : 'Connect a computer';
    final body = many
        ? "They're all set up already — setup continues as soon as any one of them comes online."
        : widget.recovering
        ? "Your computer is already set up — it just isn't running. Start it and setup continues on its own."
        : 'A computer is the machine your agents run on. Your server needs at least one online.';
    final next = RaftButton(
      key: const Key('setup-computer-next'),
      label: widget.loading ? tr('Saving...') : tr('Next'),
      tone: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.lg,
      expand: !wide,
      onPressed: widget.loading || !widget.runtimeReady ? null : widget.onNext,
    );
    final footer = Container(
      padding: EdgeInsets.symmetric(horizontal: sideBody, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _hairline(t), width: _hairlineWidth(t)),
        ),
      ),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _SessionFooter(
                    onSwitchServer: widget.onSwitchServer,
                    onDeleteServer: widget.onDeleteServer,
                    showDeleteServer: widget.showDeleteServer,
                  ),
                ),
                next,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                next,
                const SizedBox(height: 12),
                _SessionFooter(
                  onSwitchServer: widget.onSwitchServer,
                  onDeleteServer: widget.onDeleteServer,
                  showDeleteServer: widget.showDeleteServer,
                ),
              ],
            ),
    );
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: sideBody, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.error != null) ...[
            RaftAuthBanner(text: widget.error!),
            const SizedBox(height: 12),
          ],
          if (widget.recovering)
            _RecoveryCard(
              computers: widget.offlineComputers,
              serverSlug: widget.serverSlug,
              legacyDaemon: widget.legacyDaemon,
              many: many,
              canReset: widget.canReset,
              onStartOver: widget.onStartOver,
              guide: _guide(),
            )
          else ...[
            _guide(),
            if (!widget.computerOnline) ...[
              const SizedBox(height: 12),
              _Instructions(windows: widget.guidePlatform == 'windows'),
            ],
            const SizedBox(height: 12),
            _ProgressLog(
              computerName: widget.computerName,
              computerOnline: widget.computerOnline,
              waiting: widget.waiting,
              runtimeReady: widget.runtimeReady,
              runtimeNames: widget.runtimeNames,
              runtimesReported: widget.runtimeAnswered || widget.runtimeReady,
            ),
          ],
          if (widget.computerOnline &&
              !widget.runtimeReady &&
              widget.runtimeAnswered) ...[
            const SizedBox(height: 12),
            _runtimeBox(context, t),
          ],
        ],
      ),
    );
    // `md:h-[min(720px,calc(100dvh-3rem))] md:min-h-[520px] md:overflow-hidden`.
    final cardHeight = (size.height - 48).clamp(520.0, 720.0).toDouble();
    return _StepCard(
      maxWidth: 960,
      child: SizedBox(
        // border-box: the card chrome adds the border around this box.
        height: md ? cardHeight - 2 * _hairlineWidth(t) : null,
        child: Column(
          mainAxisSize: md ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('setup-computer-header'),
              padding: EdgeInsets.fromLTRB(
                wide ? 36 : 24,
                24,
                wide ? 36 : 24,
                16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _hairline(t),
                    width: _hairlineWidth(t),
                  ),
                ),
              ),
              child: _StepHeading(
                eyebrow: tr('Set up your server'),
                title: tr(title),
                hint: tr(body),
              ),
            ),
            if (md)
              Expanded(child: SingleChildScrollView(child: content))
            else
              content,
            footer,
          ],
        ),
      ),
    );
  }

  Widget _guide() => RaftComputerCommandGuide(
    platform: widget.guidePlatform,
    onPlatform: widget.onGuidePlatform,
    commands: widget.guideCommands,
    installAndSetup: widget.guideInstallAndSetup,
  );

  Widget _runtimeBox(BuildContext context, RaftTokens t) {
    String tr(String s) => raftText(context, s);
    final active =
        expandedRuntime ??
        (widget.recommendedRuntimes.isNotEmpty
            ? widget.recommendedRuntimes.first.id
            : 'claude');
    Widget row(RaftSetupRuntime r, {bool quiet = false}) => _RuntimeRow(
      runtime: r,
      computerName: widget.computerName,
      expanded: active == r.id,
      quiet: quiet,
      onToggle: () =>
          setState(() => expandedRuntime = active == r.id ? '' : r.id),
      onCopyInstallCommand: widget.onCopyInstallCommand,
    );
    return Container(
      decoration: RaftCssBoxDecoration(
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        borderRadius: t.brutal ? null : BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('No usable runtime yet'),
                  style: RaftTypography.heading(t, size: 14, line: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Install one of these on this computer, then hit refresh next to Runtime.',
                  ),
                  style: RaftTypography.heading(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w400,
                  ).copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          _GroupLabel(
            label: tr('Recommended'),
            note: tr('Claude Code and Codex are the best-tested with Raft.'),
            first: false,
          ),
          for (final r in widget.recommendedRuntimes) row(r),
          _GroupLabel(label: tr('All supported')),
          for (final r in widget.supportedRuntimes) row(r, quiet: !r.detected),
        ],
      ),
    );
  }
}

/// A localized template with `{name}` slots replaced by spans (the catalog's
/// `<b>{computer}</b>` runs), so the zh word order is the catalog's.
TextSpan _template(
  BuildContext context,
  String source,
  Map<String, InlineSpan> slots, {
  TextStyle? style,
}) {
  final text = raftText(context, source);
  final children = <InlineSpan>[];
  var from = 0;
  for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) {
    if (m.start > from)
      children.add(TextSpan(text: text.substring(from, m.start)));
    children.add(slots[m[1]] ?? TextSpan(text: m[0]));
    from = m.end;
  }
  if (from < text.length) children.add(TextSpan(text: text.substring(from)));
  return TextSpan(style: style, children: children);
}

TextStyle _mono(
  RaftTokens t,
  double size,
  double line, {
  FontWeight weight = FontWeight.w700,
  Color? color,
  double tracking = 0,
}) => TextStyle(
  fontFamily: t.monoFont,
  fontSize: size,
  height: line / size,
  fontWeight: weight,
  color: color ?? t.strong,
  letterSpacing: tracking,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `border-t border-line-hairline px-3.5 pb-1 pt-2.5` group heading.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, this.note, this.first = false});
  final String label;
  final String? note;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = t.colors['foreground-hint']!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: t.colors['line-hairline']!,
            width: first ? 0 : 1,
          ),
        ),
      ),
      child: Text.rich(
        // The spans are inline in a `text-base` (16/24) block: every line box
        // keeps the 24px strut.
        strutStyle: StrutStyle(
          fontFamily: t.headingFont,
          fontSize: 16,
          height: 1.5,
          forceStrutHeight: true,
        ),
        TextSpan(
          children: [
            TextSpan(
              text: label.toUpperCase(),
              style: _mono(t, 10, 15, color: hint, tracking: 1),
            ),
            if (note != null) const WidgetSpan(child: SizedBox(width: 8)),
            if (note != null)
              TextSpan(
                text: note,
                style: RaftTypography.heading(
                  t,
                  size: 10,
                  line: 15,
                  weight: FontWeight.w400,
                ).copyWith(color: hint),
              ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeRow extends StatelessWidget {
  const _RuntimeRow({
    required this.runtime,
    required this.computerName,
    required this.expanded,
    required this.quiet,
    required this.onToggle,
    required this.onCopyInstallCommand,
  });
  final RaftSetupRuntime runtime;
  final String? computerName;
  final bool expanded, quiet;
  final VoidCallback onToggle;
  final void Function(String, String)? onCopyInstallCommand;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final hint = t.colors['foreground-hint']!;
    final command = _runtimeInstallCommands[runtime.id];
    final tile = runtime.recommended ? 28.0 : 24.0;
    final badgeColors = runtime.detected
        ? (
            fill: t.brutal ? t.product.brutalLime : t.colors['success-soft']!,
            text: t.brutal ? Colors.black : t.colors['success-strong']!,
            border: t.brutal ? Colors.black : t.colors['line-muted']!,
          )
        : (
            fill: t.brutal ? Colors.white : t.colors['layer-inset']!,
            text: t.brutal ? const Color(0x66000000) : hint,
            border: t.brutal
                ? const Color(0x33000000)
                : t.colors['line-muted']!,
          );
    final detail = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 11,
      height: 20 / 11,
      color: t.muted,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final strong = detail.copyWith(
      fontWeight: FontWeight.w700,
      color: t.strong,
    );
    final computer = computerName ?? tr('your computer');
    return Container(
      decoration: BoxDecoration(
        color: expanded
            ? (t.brutal
                  ? t.product.softSignal.withValues(alpha: .2)
                  : t.colors['fill-muted']!.withValues(alpha: .4))
            : null,
        border: Border(
          top: BorderSide(color: t.colors['line-hairline']!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftInteractive(
            onPressed: onToggle,
            semanticLabel: runtime.displayName,
            checked: null,
            selected: expanded,
            builder: (context, state) => DecoratedBox(
              decoration: BoxDecoration(
                color: state.enabled && (state.pressed || state.hovered)
                    ? (t.brutal
                          ? t.product.softSignal.withValues(alpha: .35)
                          : t.colors['fill-muted']!.withValues(alpha: .6))
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: tile,
                      height: tile,
                      alignment: Alignment.center,
                      decoration: RaftCssBoxDecoration(
                        color: t.brutal ? Colors.white : t.panel,
                        border: Border.all(
                          color: t.brutal
                              ? Colors.black
                              : t.colors['line-muted']!,
                          width: t.brutal ? 2 : 1,
                        ),
                        borderRadius: t.brutal
                            ? null
                            : BorderRadius.circular(6),
                      ),
                      child: Text(
                        runtime.abbreviation,
                        style: _mono(t, 9, 13.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        runtime.displayName,
                        style: RaftTypography.heading(
                          t,
                          size: runtime.recommended ? 13 : 12,
                          line: runtime.recommended ? 19.5 : 16,
                        ).copyWith(color: quiet ? hint : t.ink),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: RaftCssBoxDecoration(
                        color: badgeColors.fill,
                        border: Border.all(
                          color: badgeColors.border,
                          width: t.brutal ? 2 : 1,
                        ),
                        borderRadius: t.brutal
                            ? null
                            : BorderRadius.circular(2),
                      ),
                      child: Text(
                        (runtime.detected ? tr('Detected') : tr('Not detected'))
                            .toUpperCase(),
                        style: _mono(t, 9, 13.5, color: badgeColors.text),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RotatedBox(
                      quarterTurns: expanded ? 1 : 0,
                      child: RaftIcon(
                        RaftGlyph.chevronRight,
                        size: 15,
                        color: quiet ? hint : t.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 14, 12),
              child: runtime.detected
                  ? Text.rich(
                      _template(
                        context,
                        runtime.id == 'claude'
                            ? 'Found on {computer}. This is the best-tested path - nothing to configure.'
                            : 'Found on {computer}. It is ready to use.',
                        {'computer': TextSpan(text: computer, style: strong)},
                        style: detail,
                      ),
                    )
                  : Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Text.rich(
                          _template(
                            context,
                            'Install {runtime}, then restart Raft Computer to detect it.',
                            {
                              'runtime': TextSpan(
                                text: runtime.displayName,
                                style: strong,
                              ),
                            },
                            style: detail,
                          ),
                        ),
                        if (command != null && onCopyInstallCommand != null)
                          RaftInteractive(
                            onPressed: () =>
                                onCopyInstallCommand!(runtime.id, command),
                            semanticLabel: tr('Copy install command'),
                            builder: (context, state) => Opacity(
                              opacity: state.pressed ? .6 : 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RaftIcon(
                                    RaftGlyph.copy,
                                    size: 12,
                                    color: t.strong,
                                  ),
                                  const SizedBox(width: 4),
                                  RaftUnderlinedText(
                                    tr('Copy install command'),
                                    style: strong,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// ConnectComputerInstructions: `space-y-1.5 text-xs leading-5` numbered list.
class _Instructions extends StatelessWidget {
  const _Instructions({required this.windows});
  final bool windows;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final steps = [
      tr(
        windows
            ? 'Open PowerShell and run the Install and Setup commands above.'
            : 'Paste the command above into your terminal and press Enter.',
      ),
      tr('Approve the request when it opens in your browser.'),
      tr('Your computer shows up here on its own. No need to refresh.'),
    ];
    final text = RaftTypography.heading(
      t,
      size: 12,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, label) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 6), // space-y-1.5
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                // ds-allow: Web ServerSetupComputerRuntimeStep.tsx step marker `mt-px`
                padding: const EdgeInsets.only(top: 1),
                // ignore: raft_lints/avoid_fixed_height_text -- a fixed 16px step marker: the digit is bounded by RaftChrome and always fits
                child: Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: RaftCssBoxDecoration(
                    border: Border.all(
                      color: t.brutal
                          ? const Color(0x4D000000)
                          : t.colors['line-muted']!,
                    ),
                    borderRadius: t.brutal ? null : BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${i + 1}',
                    // The digit fills a fixed 16px box: it grows with the text
                    // size only up to the chrome bound.
                    textScaler: RaftChrome.boundedScalerOf(context),
                    style: _mono(t, 9, 13.5, color: t.muted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: text)),
            ],
          ),
        ],
      ],
    );
  }
}

/// ConnectProgressLog: `space-y-1.5 font-mono text-xs leading-5`.
class _ProgressLog extends StatelessWidget {
  const _ProgressLog({
    required this.computerName,
    required this.computerOnline,
    required this.waiting,
    required this.runtimeReady,
    required this.runtimeNames,
    required this.runtimesReported,
  });
  final String? computerName;
  final bool computerOnline, waiting, runtimeReady, runtimesReported;
  final List<String> runtimeNames;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final computer = computerName ?? tr('your computer');
    final lines = <({String text, bool done, bool pending, bool failed})>[
      (
        text: waiting || computerOnline
            ? tr('Request approved.')
            : tr(
                'Waiting for you to run the command and approve it in your browser…',
              ),
        done: waiting || computerOnline,
        pending: !waiting && !computerOnline,
        failed: false,
      ),
    ];
    if (waiting || computerOnline) {
      lines.add((
        text: computerOnline
            ? raftFormat(context, '{computer} is connected.', {
                'computer': computer,
              })
            : raftFormat(context, 'Waiting for {computer} to come online…', {
                'computer': computer,
              }),
        done: computerOnline,
        pending: !computerOnline,
        failed: false,
      ));
    }
    if (computerOnline) {
      final failed = !runtimeReady && runtimesReported;
      final many = runtimeNames.length != 1;
      lines.add((
        text: runtimeReady
            ? (runtimeNames.isEmpty
                  ? tr(many ? 'Runtimes detected.' : 'Runtime detected.')
                  : raftFormat(
                      context,
                      many
                          ? 'Runtimes detected: {names}.'
                          : 'Runtime detected: {names}.',
                      {'names': runtimeNames.join(', ')},
                    ))
            : tr(
                failed
                    ? 'No usable runtime found on this computer.'
                    : 'Detecting runtime…',
              ),
        done: runtimeReady,
        pending: !runtimeReady && !failed,
        failed: failed,
      ));
    }
    return Column(
      key: const Key('setup-computer-log'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in lines.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: line.done
                      ? _Tick(
                          fill: t.product.brutalLime,
                          glyph: RaftGlyph.check,
                        )
                      : line.failed
                      ? _Tick(fill: t.product.brutalOrange, glyph: RaftGlyph.x)
                      : line.pending
                      ? const RaftSpinner(size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line.text,
                  style: _mono(
                    t,
                    12,
                    20,
                    weight: line.done || line.failed
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: line.done || line.failed ? t.strong : t.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// `flex size-4 items-center justify-center border-2 border-black` tick.
class _Tick extends StatelessWidget {
  const _Tick({required this.fill, required this.glyph});
  final Color fill;
  final RaftGlyph glyph;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      border: Border.all(color: Colors.black, width: 2),
    ),
    child: RaftIcon(
      glyph,
      size: 10,
      strokeWidth: 4,
      // currentColor: the page foreground (light in the dark theme).
      color: RaftTokens.of(context).ink,
    ),
  );
}

/// OfflineComputerRecovery (`space-y-4`).
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.computers,
    required this.serverSlug,
    required this.legacyDaemon,
    required this.many,
    required this.canReset,
    required this.onStartOver,
    required this.guide,
  });
  final List<RaftSetupOfflineComputer> computers;
  final String? serverSlug;
  final bool legacyDaemon, many, canReset;
  final VoidCallback? onStartOver;
  final Widget guide;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final note = RaftTypography.heading(
      t,
      size: 12,
      line: 20,
      weight: FontWeight.w400,
    ).copyWith(color: t.muted);
    Widget block(String text, List<Widget> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RaftCssPixelSnap(child: Text(text, style: note)),
        ),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          RaftCssPixelSnap(child: row),
        ],
      ],
    );
    final name = computers.isEmpty ? tr('your computer') : computers.first.name;
    return Column(
      key: const Key('setup-computer-recovery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RaftIcon(RaftGlyph.terminal, size: 16, color: t.strong),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (many
                        ? tr('Start one of your computers')
                        : raftFormat(context, 'Bring {computer} back online', {
                            'computer': name,
                          }))
                    .toUpperCase(),
                style: _mono(t, 10, 15, color: t.muted, tracking: .25),
              ),
            ),
          ],
        ),
        if (computers.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (i, c) in computers.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            RaftCssPixelSnap(child: _OfflineRow(computer: c)),
          ],
        ],
        const SizedBox(height: 16),
        if (legacyDaemon) ...[
          block(
            tr(
              'This machine was connected with the retired standalone daemon. Install Raft Computer on it to bring it back:',
            ),
            const [],
          ),
          guide,
        ] else ...[
          block(
            many
                ? tr(
                    'Any one of these will do — setup continues as soon as one comes online. Run this on whichever you can reach:',
                  )
                : raftFormat(
                    context,
                    "This computer is set up on /{server} but isn't connected right now. Run this on the machine to bring it back:",
                    {'server': serverSlug ?? tr('your server')},
                  ),
            const [_RecoveryCommand('raft-computer start')],
          ),
          const SizedBox(height: 16),
          block(tr("Not sure why it's offline? Check with:"), const [
            _RecoveryCommand('raft-computer status'),
            _RecoveryCommand('raft-computer doctor'),
            _RecoveryCommand('raft-computer restart'),
          ]),
        ],
        if (canReset) ...[
          const SizedBox(height: 16),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr(
                  many
                      ? 'None of these work?'
                      : "Can't get this computer back?",
                ),
                style: RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w400,
                ).copyWith(color: t.ink),
              ),
              const SizedBox(width: 4),
              RaftAuthTextLink(
                key: const Key('setup-computer-start-over'),
                label: tr('Start over'),
                onTap: onStartOver,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OfflineRow extends StatelessWidget {
  const _OfflineRow({required this.computer});
  final RaftSetupOfflineComputer computer;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: RaftCssBoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        borderRadius: t.brutal ? null : BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          RaftIcon(RaftGlyph.monitor, size: 16, color: t.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  computer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.heading(t, size: 12, line: 16),
                ),
                // CSS keeps the 16.5px line box; a paragraph would round up.
                RaftScaled.lineBox(
                  context,
                  height: 16.5,
                  child: Text(
                    computer.lastSeen == null
                        ? tr('Offline')
                        : raftFormat(context, 'Offline · last seen {when}', {
                            'when': computer.lastSeen,
                          }),
                    style: RaftTypography.heading(
                      t,
                      size: 11,
                      line: 16.5,
                      weight: FontWeight.w400,
                    ).copyWith(color: t.colors['foreground-hint']),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// RecoveryCommandRow: `flex items-center gap-2`, the black code box and a
/// `size="icon-sm" variant="outline"` copy button.
class _RecoveryCommand extends StatefulWidget {
  const _RecoveryCommand(this.command);
  final String command;

  @override
  State<_RecoveryCommand> createState() => _RecoveryCommandState();
}

class _RecoveryCommandState extends State<_RecoveryCommand> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: RaftCssBoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: t.brutal ? Colors.black : t.colors['line-strong']!,
                width: t.brutal ? 2 : 1,
              ),
              borderRadius: t.brutal ? null : BorderRadius.circular(6),
              boxShadow: t.brutal
                  ? RaftProductShadows.shadowBrutalSm.outer
                  : t.themeShadows.sm.outer,
            ),
            child: Text(
              widget.command,
              style: _mono(
                t,
                12,
                16,
                weight: FontWeight.w400,
                color: t.product.brutalLime,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RaftButton(
          label: '',
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          variant: RaftControlVariant.outline,
          size: RaftButtonRecipeSize.iconSm,
          semanticLabel: raftFormat(context, 'Copy {command}', {
            'command': widget.command,
          }),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.command));
            if (mounted) setState(() => copied = true);
          },
        ),
      ],
    );
  }
}

/// `max-w-[Nch] text-balance text-center`: the box is at most N `ch` wide and
/// the wrap width shrinks to the narrowest one that keeps the same line count,
/// so the lines come out even.
class _BalancedText extends StatelessWidget {
  const _BalancedText(this.text, {required this.maxChars, required this.style});
  final String text;
  final double maxChars;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      int lineCount(double width) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: width);
        final lines = painter.computeLineMetrics().length;
        painter.dispose();
        return lines;
      }

      final zeroWidth = raftTextWidth(
        TextSpan(text: '0', style: style),
        textDirection: Directionality.of(context),
      );
      final limit = (maxChars * zeroWidth).clamp(0.0, box.maxWidth);
      final lines = lineCount(limit);
      var low = 0.0, high = limit;
      for (var i = 0; i < 24; i++) {
        final mid = (low + high) / 2;
        if (lineCount(mid) <= lines) {
          high = mid;
        } else {
          low = mid;
        }
      }
      return SizedBox(
        width: high.ceilToDouble().clamp(0.0, limit),
        child: Text(text, textAlign: TextAlign.center, style: style),
      );
    },
  );
}
