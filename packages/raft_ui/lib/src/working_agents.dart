import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dismiss_scope.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'design_primitives.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'popover_surface.dart';
import 'text_scaling.dart' show RaftChrome;
import 'theme.dart';

/// Raft Design System "Working agents" (decision 0006): working agents are
/// shown where they appear. These parts are presentation only; the caller owns
/// which agents are working, their order, authorized avatar artwork and text.
@immutable
class RaftWorkingAgent {
  const RaftWorkingAgent({
    required this.id,
    required this.name,
    required this.text,
    required this.avatar,
  });

  final String id, name;

  /// What the agent is doing, already localized ("Editing Flow.tsx · #25",
  /// or its state: Thinking…, Working…).
  final String text;

  /// Authorized artwork inside the avatar frame (pixel art or an image).
  final Widget avatar;
}

/// "2 agents working": the summary's accessible name and the channel line.
String raftWorkingAgentsLabel(BuildContext context, int count) => raftFormat(
  context,
  count == 1 ? '{count} agent working' : '{count} agents working',
  {'count': count},
);

/// The most faces a summary or a channel line shows; the rest only count.
const raftWorkingFaceLimit = 3;

const _faceExtent = 19.0, _faceOverlap = 5.0;

/// Up to three overlapping 19px faces, each over the one before by 5px. The
/// faces are decoration: hidden from assistive technology. A face that joins
/// after the first frame slides in and fades over about 200ms (it just appears
/// with reduced motion); nothing else moves while the work goes on.
class RaftWorkingFaces extends StatefulWidget {
  const RaftWorkingFaces({super.key, required this.agents});
  final List<RaftWorkingAgent> agents;

  @override
  State<RaftWorkingFaces> createState() => _RaftWorkingFacesState();
}

class _RaftWorkingFacesState extends State<RaftWorkingFaces> {
  late Set<String> shown;
  Set<String> joined = {};

  List<RaftWorkingAgent> get _faces =>
      widget.agents.take(raftWorkingFaceLimit).toList();

  @override
  void initState() {
    super.initState();
    shown = {for (final a in _faces) a.id};
  }

  @override
  void didUpdateWidget(RaftWorkingFaces old) {
    super.didUpdateWidget(old);
    final ids = {for (final a in _faces) a.id};
    joined = ids.difference(shown);
    shown = ids;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final faces = _faces;
    if (faces.isEmpty) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final width =
        faces.length * _faceExtent - (faces.length - 1) * _faceOverlap;
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('working-agent-faces'),
        width: width,
        height: _faceExtent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < faces.length; i++)
              Positioned(
                key: ValueKey('working-face-${faces[i].id}'),
                left: i * (_faceExtent - _faceOverlap),
                top: 0,
                child: _FaceIn(
                  animate: !reduced && joined.contains(faces[i].id),
                  child: DecoratedBox(
                    // A panel-colour ring separates the overlapping circles.
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: t.panel, spreadRadius: 1)],
                    ),
                    child: RaftMountedAvatarFrame(
                      name: faces[i].name,
                      avatarContext: RaftMountedAvatarContext.compactList,
                      identity: RaftMountedAvatarIdentity.agent,
                      extent: _faceExtent,
                      child: faces[i].avatar,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FaceIn extends StatelessWidget {
  const _FaceIn({required this.animate, required this.child});
  final bool animate;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      // ease-slide
      curve: const Cubic(.22, 1, .36, 1),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((1 - value) * -8, 0),
          child: child,
        ),
      ),
    );
  }
}

/// The summary: up to three faces and the count, which opens Working now.
/// Hidden (no zero) when nobody is working. Its accessible name is the full
/// sentence ("2 agents working").
class RaftWorkingSummary extends StatefulWidget {
  const RaftWorkingSummary({
    super.key,
    required this.agents,
    this.onOpenAgent,
    this.onFrame = false,
  });
  final bool onFrame;

  /// Working agents in the order they started.
  final List<RaftWorkingAgent> agents;

  /// Selecting a row opens the agent's page.
  final ValueChanged<String>? onOpenAgent;

  @override
  State<RaftWorkingSummary> createState() => _RaftWorkingSummaryState();
}

class _RaftWorkingSummaryState extends State<RaftWorkingSummary> {
  final portal = OverlayPortalController();
  final anchor = GlobalKey();
  final menuFocus = FocusNode(skipTraversal: true);
  bool open = false;

  void setOpen(bool next) {
    if (open == next) return;
    open = next;
    if (next) {
      portal.show();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && open) menuFocus.requestFocus();
      });
    } else {
      portal.hide();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RaftWorkingSummary old) {
    super.didUpdateWidget(old);
    // Nobody is working any more: the summary and its popover go away.
    if (widget.agents.isEmpty) open = false;
  }

  @override
  void dispose() {
    menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agents = widget.agents;
    final t = RaftTokens.of(context);
    if (agents.isEmpty && !open) return const SizedBox.shrink();
    final label = raftWorkingAgentsLabel(context, agents.length);
    final compact =
        MediaQuery.sizeOf(context).width < RaftLayoutMetrics.desktopBreakpoint;
    return TapRegion(
      groupId: this,
      onTapOutside: (_) => setOpen(false),
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) {
          final box = anchor.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize || agents.isEmpty) {
            return const SizedBox.shrink();
          }
          final rect = box.localToGlobal(Offset.zero) & box.size;
          return RaftBackDismiss(
            onDismiss: () => setOpen(false),
            child: CustomSingleChildLayout(
              delegate: _WorkingNowPlacement(rect),
              child: TapRegion(
                groupId: this,
                child: Focus(
                  focusNode: menuFocus,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      setOpen(false);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: RaftWorkingNow(
                    agents: agents,
                    onOpenAgent: (id) {
                      setOpen(false);
                      widget.onOpenAgent?.call(id);
                    },
                  ),
                ),
              ),
            ),
          );
        },
        child: RaftTouchTargetExpander(
          minSize: Size.square(compact ? 44 : 0),
          child: KeyedSubtree(
            key: anchor,
            child: agents.isEmpty
                ? const SizedBox(height: 32)
                : _SummaryButton(
                    label: label,
                    onFrame: widget.onFrame,
                    selected: open,
                    onPressed: () => setOpen(!open),
                    // The count is fixed chrome: bounded at 1.35x like badges.
                    child: RaftChrome(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RaftWorkingFaces(agents: agents),
                          const SizedBox(width: 6),
                          Text(
                            '${agents.length}',
                            key: const Key('working-agent-count'),
                            style: RaftTypography.mono(
                              t,
                              size: 12,
                              line: 16,
                              color: t.strong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A ghost, small button around [child] with the summary's accessible name.
class _SummaryButton extends StatelessWidget {
  const _SummaryButton({
    required this.label,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.onFrame = false,
  });
  final String label;
  final Widget child;
  final VoidCallback onPressed;
  final bool selected;
  final bool onFrame;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      expanded: selected,
      excludeSemantics: true,
      onTap: onPressed,
      child: RaftInteractive(
        key: const Key('working-agents-summary'),
        onPressed: onPressed,
        tooltip: label,
        button: false,
        builder: (context, state) => Container(
          height: onFrame ? 36 : 32,
          padding: EdgeInsets.symmetric(horizontal: onFrame ? 6 : 8),
          decoration: BoxDecoration(
            color: state.hovered || state.pressed || selected
                ? t.colors[onFrame ? 'fill-frame-pressed' : 'fill-muted']
                : Colors.transparent,
            borderRadius: BorderRadius.circular(onFrame ? t.radius : 6),
            border: state.focusVisible ? Border.all(color: t.strong) : null,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _WorkingNowPlacement extends SingleChildLayoutDelegate {
  const _WorkingNowPlacement(this.anchor);
  final Rect anchor;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(300, math.max(0, constraints.maxWidth - 16)),
        maxHeight: math.max(0, constraints.maxHeight - anchor.bottom - 12),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Aligned to the end of the summary, kept 8px inside the window.
    final left = (anchor.right - childSize.width)
        .clamp(8.0, math.max(8.0, size.width - childSize.width - 8))
        .toDouble();
    return Offset(left, anchor.bottom + 4);
  }

  @override
  bool shouldRelayout(_WorkingNowPlacement old) => old.anchor != anchor;
}

/// The Working now popover: a 300px list with one row per working agent.
class RaftWorkingNow extends StatelessWidget {
  const RaftWorkingNow({super.key, required this.agents, this.onOpenAgent});
  final List<RaftWorkingAgent> agents;
  final ValueChanged<String>? onOpenAgent;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SizedBox(
      width: 300,
      child: RaftPopoverSurface(
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: t.strong),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                key: const Key('working-now'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      child: Text(
                        raftText(context, 'Working now'),
                        style: RaftTypography.heading(
                          t,
                          size: 14,
                          line: 20,
                          weight: FontWeight.w700,
                          color: t.strong,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final agent in agents)
                            RaftWorkingNowRow(
                              key: ValueKey('working-now-row-${agent.id}'),
                              agent: agent,
                              onPressed: onOpenAgent == null
                                  ? null
                                  : () => onOpenAgent!(agent.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One Working now row: the agent's 27px avatar with its still yellow light,
/// its name in bold and what it is doing on up to two lines.
class RaftWorkingNowRow extends StatelessWidget {
  const RaftWorkingNowRow({super.key, required this.agent, this.onPressed});
  final RaftWorkingAgent agent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: onPressed,
      semanticLabel: '${agent.name}, ${agent.text}',
      builder: (context, state) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: state.hovered || state.pressed
              ? t.colors['fill-muted']
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: state.focusVisible ? Border.all(color: t.strong) : null,
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RaftMountedAvatarFrame(
                name: agent.name,
                avatarContext: RaftMountedAvatarContext.compactList,
                identity: RaftMountedAvatarIdentity.agent,
                extent: 27,
                presence: const RaftAvatarPresence(
                  activity: RaftAvatarActivity.working,
                  online: true,
                ),
                child: agent.avatar,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RaftTypography.heading(
                        t,
                        size: 14,
                        line: 20,
                        weight: FontWeight.w700,
                        color: t.strong,
                      ),
                    ),
                    Text(
                      agent.text,
                      key: const Key('working-now-text'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RaftTypography.heading(
                        t,
                        size: 12,
                        line: 16,
                        weight: FontWeight.w500,
                        color: t.colors['foreground-muted'],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The start of a channel header's subtitle: up to three faces and
/// "2 agents working". The caller adds " · " and the description.
class RaftWorkingLine extends StatelessWidget {
  const RaftWorkingLine({super.key, required this.agents, required this.style});
  final List<RaftWorkingAgent> agents;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('channel-working-line'),
    mainAxisSize: MainAxisSize.min,
    children: [
      RaftWorkingFaces(agents: agents),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          raftWorkingAgentsLabel(context, agents.length),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}
