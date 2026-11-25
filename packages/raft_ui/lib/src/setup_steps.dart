// Server setup gate steps (packages/web/src/components/onboarding/
// ServerSetupSurveyStep.tsx, ServerSetupHandoffStep.tsx,
// ServerSetupComputerRuntimeStep.tsx, SetupSessionFooter.tsx). Presentation
// only: the app owns the projection, requests and state and passes values and
// callbacks in.
import 'dart:math' as math;

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
import 'dialog_surface.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'indicators.dart';
import 'keyboard_reveal.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'raft/avatar.dart';
import 'raft/css_box.dart';
import 'raft/status.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart' show RaftCssBoxDecoration;
import 'tokens/raft_tokens.g.dart';
import 'text_measure.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';

/// `sm:` breakpoint of the step footers (`flex-col-reverse gap-3
/// sm:flex-row sm:items-center sm:justify-between`).
bool _wide(BuildContext context, [double? available]) =>
    MediaQuery.sizeOf(context).width >= 640 &&
    (available == null || available >= _rowMinWidth);

/// Narrowest card that holds the `sm:flex-row` footer / header rows. Web uses
/// the viewport alone; a card in a narrower host (a pane, a test surface)
/// stacks instead of overflowing.
const double _rowMinWidth = 420;

/// Shared step frame matching Web `DialogSurface`: `rounded-dialog`,
/// `border-line-strong`, `elevation-float`, and `1px border-line-seam` dividers.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.maxWidth, this.height, required this.child});
  final double maxWidth;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RaftDialogSurface(
        child: height == null ? child : SizedBox(height: height, child: child),
      ),
    ),
  );
}

double _seamStroke(BuildContext context, RaftTokens t) =>
    raftControlBorderPx(context, t.size('border.seam', fallback: 1));
Color _seamColor(RaftTokens t) =>
    raftChromeBlend(t.ui.lineSeam, t.ui['layer-dialog']);
double _stickerStroke(BuildContext context, RaftTokens t) =>
    raftControlBorderPx(context, t.size('border.sticker', fallback: 1.5));

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
    final ui = t.ui;
    String tr(String s) => raftText(context, s);
    final size = MediaQuery.sizeOf(context);
    final wide = _wide(context, available), md = size.width >= 768;
    final frameHeight = md ? math.min(520.0, size.height - 48.0) : null;
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
    final footer = Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _seamColor(t), width: _seamStroke(context, t)),
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
            ),
    );
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 24, vertical: 24),
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
                    padding: const EdgeInsets.all(8),
                    style: t.scale(RaftTypeScale.callout, color: ui.foreground),
                    hintText: tr('Where did you hear about us?'),
                    semanticLabel: tr('How did you hear about Raft?'),
                  )
                : null,
          ),
        ],
      ),
    );
    return _StepCard(
      maxWidth: 720,
      height: frameHeight,
      child: Column(
        mainAxisSize: frameHeight != null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('setup-survey-header'),
            padding: EdgeInsets.fromLTRB(
              wide ? 36 : 24,
              24,
              wide ? 36 : 24,
              16,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _seamColor(t),
                  width: _seamStroke(context, t),
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
          if (frameHeight != null)
            Expanded(child: SingleChildScrollView(child: body))
          else
            body,
          footer,
        ],
      ),
    );
  }
}

/// `font-mono text-mono-meta` eyebrow, `mt-2 text-title` title, `mt-1.5 text-callout` hint.
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
    final ui = t.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: t.scale(
            RaftTypeScale.monoMeta,
            mono: true,
            color: ui.foregroundHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: t.scale(
            RaftTypeScale.title,
            weight: FontWeight.w700,
            color: ui.foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: t.scale(RaftTypeScale.callout, color: ui.foregroundMuted),
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
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: t.ui.foreground,
            ),
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

  /// `OptionGrid`: `h-8 rounded-control border-[1.5px] px-3 text-footnote font-bold`; the chosen one is
  /// the yellow sticker (brand fill, ink border and type), the others sit on the card with the strong line. Hover
  /// lays the press overlay on the resting fill.
  Widget _raftChip(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    return RaftInteractive(
      onPressed: onTap,
      semanticLabel: label,
      selected: selected,
      builder: (context, state) {
        final active = state.enabled && (state.hovered || state.pressed);
        final base = selected ? ui.brand : ui.layerCard;
        final fill = active
            ? Color.alphaBlend(
                selected ? ui.stickerPressed : ui.fillPressed,
                base,
              )
            : base;
        return RaftCssBox(
          radius: t.size('radius.control', fallback: 8),
          fill: fill,
          borderWidth: raftControlBorderPx(context, 1.5),
          borderColor: selected ? ui.stickerInk : ui.lineStrong,
          rings: [
            if (state.focusVisible)
              for (final layer in ui.focusRing.layers)
                RaftRing(layer.spread, layer.color),
          ],
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: t.scale(
              RaftTypeScale.footnote,
              weight: FontWeight.w700,
              color: selected ? ui.stickerInk : ui.foreground,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      _raftChip(context, RaftTokens.of(context));
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
/// the session link and the "Let's go" button.
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
    final ui = t.ui;
    String tr(String s) => raftText(context, s);
    final size = MediaQuery.sizeOf(context);
    final wide = _wide(context, available), md = size.width >= 768;
    final frameHeight = md ? math.min(520.0, size.height - 48.0) : null;
    final done = RaftButton(
      key: const Key('server-setup-handoff-done'),
      label: starting ? tr('Starting…') : tr("Let's go"),
      tone: RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.lg,
      expand: !wide,
      onPressed: starting ? null : onDone,
    );
    final body = Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 36 : 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftAvatarSlot(
            name: agentName,
            avatarUrl: 'pixel:mug',
            slot: RaftAvatarSlotContext.profileHero,
            sizeOverride: RaftAvatarSize.xl.extent,
          ),
          const SizedBox(height: 24),
          Text(
            raftFormat(context, '{agentName} takes it from here', {
              'agentName': agentName,
            }),
            textAlign: TextAlign.center,
            style: t.scale(
              wide ? RaftTypeScale.display : RaftTypeScale.title,
              weight: FontWeight.w700,
              color: ui.foreground,
            ),
          ),
          const SizedBox(height: 12),
          _BalancedText(
            raftFormat(
              context,
              "Your server is set up. {agentName} is waiting in your channel. She'll show you around Raft and get you working for real.",
              {'agentName': agentName},
            ),
            maxChars: 42,
            style: t.scale(RaftTypeScale.subhead, color: ui.foregroundMuted),
          ),
        ],
      ),
    );
    return _StepCard(
      maxWidth: 720,
      height: frameHeight,
      child: Column(
        mainAxisSize: frameHeight != null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (frameHeight != null)
            Expanded(child: Center(child: body))
          else
            body,
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 36 : 20,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _seamColor(t),
                  width: _seamStroke(context, t),
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
        ? "Your computer is already set up but isn't running. Start it and setup continues on its own."
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
          top: BorderSide(color: _seamColor(t), width: _seamStroke(context, t)),
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
      height: md ? cardHeight : null,
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
                  color: _seamColor(t),
                  width: _seamStroke(context, t),
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
    final ui = t.ui;
    final controlRadius = t.size(
      'radius.control',
      fallback: RaftRadius.control,
    );
    return Container(
      decoration: RaftCssBoxDecoration(
        color: ui.layerCanvas,
        border: Border.all(
          color: raftChromeBlend(ui.lineSeam, ui.layerCanvas),
          width: _seamStroke(context, t),
        ),
        borderRadius: BorderRadius.all(Radius.circular(controlRadius)),
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
                  style: t.scale(
                    RaftTypeScale.callout,
                    weight: FontWeight.w700,
                    color: ui.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Install one of these on this computer, then hit refresh next to Runtime.',
                  ),
                  style: t.scale(
                    RaftTypeScale.footnote,
                    color: ui.foregroundMuted,
                  ),
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
    if (m.start > from) {
      children.add(TextSpan(text: text.substring(from, m.start)));
    }
    children.add(slots[m[1]] ?? TextSpan(text: m[0]));
    from = m.end;
  }
  if (from < text.length) children.add(TextSpan(text: text.substring(from)));
  return TextSpan(style: style, children: children);
}

TextStyle _mono(
  RaftTokens t,
  RaftTypeStyle scale, {
  FontWeight weight = FontWeight.w700,
  Color? color,
}) =>
    t.scale(scale, mono: true, weight: weight, color: color ?? t.ui.foreground);

/// `border-t border-line-hairline px-3.5 pb-1 pt-2.5` group heading.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, this.note, this.first = false});
  final String label;
  final String? note;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hint = t.ui.foregroundHint;
    final seam = _seamStroke(context, t);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: t.ui.lineHairline, width: seam),
              ),
            ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: _mono(t, RaftTypeScale.monoMeta, color: hint),
            ),
            if (note != null) const WidgetSpan(child: SizedBox(width: 8)),
            if (note != null)
              TextSpan(
                text: note,
                style: t.scale(RaftTypeScale.monoMeta, color: hint),
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
    final ui = t.ui;
    String tr(String s) => raftText(context, s);
    final hint = ui.foregroundHint;
    final command = _runtimeInstallCommands[runtime.id];
    final tile = runtime.recommended ? 27.0 : 24.0;
    final tileRadius = runtime.recommended
        ? t.size('radius.chip', fallback: RaftRadius.chip)
        : t.size('radius.sticker', fallback: RaftRadius.sticker);
    final seam = _seamStroke(context, t);
    final detail = t.scale(RaftTypeScale.footnote, color: ui.foregroundMuted);
    final strong = detail.copyWith(
      fontWeight: FontWeight.w700,
      color: ui.foreground,
    );
    final computer = computerName ?? tr('your computer');
    return Container(
      decoration: BoxDecoration(
        color: expanded ? ui['fill-subtle'] : null,
        border: Border(
          top: BorderSide(color: ui.lineHairline, width: seam),
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
                    ? ui['fill-subtle']
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    RaftCssBox(
                      width: tile,
                      height: tile,
                      radius: tileRadius,
                      fill: ui['fill-muted'],
                      alignment: Alignment.center,
                      child: Text(
                        runtime.abbreviation,
                        style: _mono(
                          t,
                          RaftTypeScale.monoMeta,
                          color: ui.foregroundMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        runtime.displayName,
                        style: t.scale(
                          runtime.recommended
                              ? RaftTypeScale.callout
                              : RaftTypeScale.footnote,
                          weight: FontWeight.w600,
                          color: quiet ? hint : ui.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RaftBadge(
                      label: runtime.detected
                          ? tr('Detected')
                          : tr('Not detected'),
                      appearance: RaftBadgeRecipeAppearance.soft,
                      variant: runtime.detected
                          ? RaftBadgeRecipeVariant.success
                          : RaftBadgeRecipeVariant.muted,
                      leading: RaftStatus(
                        size: RaftStatusSize.xs,
                        variant: runtime.detected
                            ? RaftStatusVariant.success
                            : RaftStatusVariant.default_,
                      ),
                    ),
                    const SizedBox(width: 10),
                    RotatedBox(
                      quarterTurns: expanded ? 1 : 0,
                      child: RaftIcon(
                        RaftGlyph.chevronRight,
                        size: 16,
                        color: ui.foregroundMuted,
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
                            semanticLabel: tr('Copy Install Command'),
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
                                    tr('Copy Install Command'),
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
    final text = t.scale(RaftTypeScale.footnote, color: t.ui.foregroundMuted);
    final stickerRadius = t.size(
      'radius.sticker',
      fallback: RaftRadius.sticker,
    );
    final seam = _seamStroke(context, t);
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
                child: RaftCssBox(
                  width: 16,
                  height: 16,
                  radius: stickerRadius / 2,
                  borderWidth: seam,
                  borderColor: t.ui.lineHairline,
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    // The digit fills a fixed 16px box: it grows with the text
                    // size only up to the chrome bound.
                    textScaler: RaftChrome.boundedScalerOf(context),
                    style: _mono(
                      t,
                      RaftTypeScale.label,
                      color: t.ui.foregroundMuted,
                    ),
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
                      ? _Tick(fill: t.ui.success, glyph: RaftGlyph.check)
                      : line.failed
                      ? _Tick(fill: t.ui.warning, glyph: RaftGlyph.x)
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
                    RaftTypeScale.monoMeta,
                    weight: line.done || line.failed
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: line.done || line.failed
                        ? t.ui.foreground
                        : t.ui.foregroundMuted,
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

/// `flex size-4 items-center justify-center rounded-sticker border-[1.5px] border-sticker-ink` tick.
class _Tick extends StatelessWidget {
  const _Tick({required this.fill, required this.glyph});
  final Color fill;
  final RaftGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final tickStroke = t.size('border.width.3', fallback: 3);
    return RaftCssBox(
      width: 16,
      height: 16,
      radius: t.size('radius.sticker', fallback: RaftRadius.sticker),
      fill: fill,
      borderWidth: _stickerStroke(context, t),
      borderColor: ui.stickerInk,
      alignment: Alignment.center,
      child: RaftIcon(
        glyph,
        size: 10,
        strokeWidth: tickStroke,
        color: ui.stickerInk,
      ),
    );
  }
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
    final ui = t.ui;
    final note = t.scale(RaftTypeScale.footnote, color: ui.foregroundMuted);
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
            RaftIcon(RaftGlyph.terminal, size: 16, color: ui.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                many
                    ? tr('Start one of your computers')
                    : raftFormat(context, 'Bring {computer} back online', {
                        'computer': name,
                      }),
                style: _mono(
                  t,
                  RaftTypeScale.monoMeta,
                  color: ui.foregroundMuted,
                ),
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
              'This computer was connected with the retired standalone app. Install Raft Computer on it to bring it back:',
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
                    "This computer is set up on /{server} but isn't connected right now. Run this on that computer to bring it back:",
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
                style: t.scale(RaftTypeScale.callout, color: ui.foreground),
              ),
              const SizedBox(width: 4),
              RaftAuthTextLink(
                key: const Key('setup-computer-start-over'),
                label: tr('Start Over'),
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
    final ui = t.ui;
    String tr(String s) => raftText(context, s);
    return RaftCssBox(
      radius: t.size('radius.control', fallback: RaftRadius.control),
      fill: ui.layerCanvas,
      borderWidth: _seamStroke(context, t),
      borderColor: ui.lineHairline,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          RaftIcon(RaftGlyph.monitor, size: 16, color: ui.foregroundMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  computer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.scale(
                    RaftTypeScale.footnote,
                    weight: FontWeight.w600,
                    color: ui.foreground,
                  ),
                ),
                Text(
                  computer.lastSeen == null
                      ? tr('Offline')
                      : raftFormat(context, 'Offline · last seen {when}', {
                          'when': computer.lastSeen,
                        }),
                  style: t.scale(
                    RaftTypeScale.label,
                    weight: FontWeight.w400,
                    color: ui.foregroundHint,
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

/// RecoveryCommandRow: `flex items-center gap-2`, `bg-layer-code` command box
/// and a `size="icon-sm" variant="outline"` copy button.
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
    final ui = t.ui;
    return Row(
      children: [
        Expanded(
          child: RaftCssBox(
            radius: t.size('radius.control', fallback: RaftRadius.control),
            fill: t.colors['layer-code'] ?? ui.layerCard,
            borderWidth: _seamStroke(context, t),
            borderColor: ui.lineStrong,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              widget.command,
              style: _mono(
                t,
                RaftTypeScale.monoMeta,
                weight: FontWeight.w400,
                color: ui.foreground,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RaftButton(
          label: '',
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          uiVariant: RaftButtonVariant.outline,
          uiSize: RaftButtonSize.iconSm,
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
