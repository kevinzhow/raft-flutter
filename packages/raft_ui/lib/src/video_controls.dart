// The video control language shared by the inline message card and the media
// viewer: the browser-shaped control panel (play / pause, time, mute + volume
// rail, full screen, open, download, seek rail), the click / hover / tap
// behaviour around it, and the thin rails. No Material Slider.
// (test/media_controls_guard_test.dart)
import 'hover_region.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftSpinner;
import 'icons.dart';
import 'localization.dart';
import 'inline_media.dart' show raftAudioTimestamp;
import 'theme.dart';
import 'tokens/media_motion.g.dart';

const _videoFade = [
  0.0,
  0.017,
  0.05,
  0.099,
  0.182,
  0.281,
  0.388,
  0.504,
  0.628,
  0.744,
  0.835,
  0.912,
  0.967,
  0.992,
  1.0,
];
const _videoFadeStops = [
  0.0,
  .0714,
  .1429,
  .2143,
  .2857,
  .3571,
  .4286,
  .5,
  .5714,
  .6429,
  .7143,
  .7857,
  .8571,
  .9286,
  1.0,
];

/// How long a playing video keeps its controls after the last pointer movement
/// (mouse) or the last tap (touch).
const raftVideoControlsIdle = Duration(seconds: 3);

/// The phone chrome's fade (top bar, bottom band and the video controls leave
/// and return together); reduced motion cuts.
const raftMediaChromeFade = RaftMediaMotionTokens.chromeFadeIn;

/// Fades [child] in and out with [visible] over [raftMediaChromeFade]. It is
/// built only while it shows or fades, takes no touch once it is leaving, and
/// cuts under reduced motion.
class RaftChromeFade extends StatefulWidget {
  const RaftChromeFade({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  State<RaftChromeFade> createState() => _RaftChromeFadeState();
}

class _RaftChromeFadeState extends State<RaftChromeFade> {
  /// Built: visible, or fading out.
  late bool present = widget.visible;

  @override
  void didUpdateWidget(RaftChromeFade old) {
    super.didUpdateWidget(old);
    if (widget.visible) present = true;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.visible && (reduced || !present)) {
      present = false;
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        duration: reduced ? Duration.zero : raftMediaChromeFade,
        opacity: widget.visible ? 1 : 0,
        onEnd: () {
          if (!widget.visible && mounted) setState(() => present = false);
        },
        child: widget.child,
      ),
    );
  }
}

/// The interactive layer over a video picture: click toggles playback, a
/// centred Play while paused (on hover with a mouse, always on touch) and the
/// [RaftVideoControlBar] (paused: always; playing: while the mouse moves over
/// the picture and for [raftVideoControlsIdle] after it stops, or for that long
/// after a tap on touch). [child] is the picture; [extra] stacks on
/// top (the card's Eye action).
class RaftVideoOverlay extends StatefulWidget {
  const RaftVideoOverlay({
    super.key,
    required this.child,
    required this.filename,
    this.extra = const [],
    this.interactive = true,
    this.ready = true,
    this.buffering = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.touch,
    this.fullscreen = false,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
    this.onOpen,
    this.onDownload,
    this.onFullscreen,
    this.onSurfaceTap,
    this.controlsInset = 0,
    this.controlsVisible,
  });
  final Widget child;
  final String filename;
  final List<Widget> extra;

  /// The browser's phone page owns the controls' visibility with its chrome:
  /// the bar and the centre Play show exactly when this is true, paused or
  /// playing (a surface tap toggles it through [onSurfaceTap]), and fade with
  /// the chrome. Null keeps the card behaviour (paused: always; playing: mouse
  /// hover / tap-to-reveal timer).
  final bool? controlsVisible;

  /// Replaces the surface tap (play / pause, or the bar on a playing touch
  /// video): the media browser's phone page toggles its chrome with it and
  /// starts playback only from the Play button and the bar.
  final VoidCallback? onSurfaceTap;

  /// Space kept free under the control bar (the browser's strip).
  final double controlsInset;

  /// The picture reacts to clicks (idle, loading or ready: a tap while the
  /// player is prepared is queued by the caller); false when failed.
  final bool interactive;

  /// The video is open: the bar and the Play button may show.
  final bool ready;

  /// The player waits for data: a spinner over the picture.
  final bool buffering;
  final bool playing, fullscreen;
  final Duration position, duration;

  /// 0..100.
  final double volume;
  final bool? touch;
  final VoidCallback? onTogglePlay, onOpen, onDownload, onFullscreen;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  State<RaftVideoOverlay> createState() => _RaftVideoOverlayState();
}

class _RaftVideoOverlayState extends State<RaftVideoOverlay> {
  bool hovered = false, barTapped = false;

  /// Mouse: the pointer rested over the playing picture; the bar is hidden
  /// until it moves again.
  bool idleHidden = false;

  /// Mouse: the pointer is over the bar, or a seek / volume drag is running.
  /// The bar stays while either holds.
  bool overBar = false, dragging = false;
  Timer? barTimer, idleTimer;
  double mutedFrom = 100;

  bool get touch =>
      widget.touch ??
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    barTimer?.cancel();
    idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RaftVideoOverlay old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing || old.ready != widget.ready) {
      idleHidden = false;
      armIdle();
    }
  }

  /// Mouse: (re)start the rest timer. It only runs while the video plays under
  /// a resting pointer that is not on the bar and not dragging a rail; any
  /// other state cancels it, so nothing ticks while paused or hidden.
  void armIdle() {
    idleTimer?.cancel();
    idleTimer = null;
    if (touch ||
        !hovered ||
        !widget.ready ||
        !widget.playing ||
        overBar ||
        dragging) {
      return;
    }
    idleTimer = Timer(raftVideoControlsIdle, () {
      idleTimer = null;
      if (mounted) setState(() => idleHidden = true);
    });
  }

  void pointerMoved() {
    if (touch) return;
    if (idleHidden) setState(() => idleHidden = false);
    armIdle();
  }

  void pointerEntered() {
    setState(() {
      hovered = true;
      idleHidden = false;
    });
    armIdle();
  }

  void pointerLeft() {
    setState(() {
      hovered = false;
      overBar = dragging = false;
      idleHidden = false;
    });
    armIdle();
  }

  void barHovered(bool over) {
    if (overBar == over) return;
    overBar = over;
    armIdle();
  }

  void dragChanged(bool active) {
    if (dragging == active) return;
    dragging = active;
    armIdle();
  }

  /// A tap on a playing picture (touch) reveals the bar for a few seconds.
  void showBarBriefly() {
    barTimer?.cancel();
    setState(() => barTapped = true);
    barTimer = Timer(raftVideoControlsIdle, () {
      if (mounted) setState(() => barTapped = false);
    });
  }

  void surfaceTap() {
    if (widget.onSurfaceTap != null) {
      widget.onSurfaceTap!();
      return;
    }
    if (touch && widget.ready && widget.playing) {
      if (barTapped) {
        barTimer?.cancel();
        setState(() => barTapped = false);
      } else {
        showBarBriefly();
      }
      return;
    }
    widget.onTogglePlay?.call();
  }

  bool get showBar =>
      widget.ready &&
      (widget.controlsVisible ??
          (!widget.playing
              ? true
              : (touch ? barTapped : hovered && !idleHidden)));
  bool get showCenterPlay =>
      widget.ready &&
      !widget.playing &&
      !widget.buffering &&
      (widget.controlsVisible ?? (touch || hovered));

  /// The browser's chrome fades its controls with it; a card cuts.
  Widget fading(bool visible, Widget child) => widget.controlsVisible == null
      ? child
      : RaftChromeFade(visible: visible, child: child);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final playLabel = raftFormat(
      context,
      widget.playing ? 'Pause video {filename}' : 'Play video {filename}',
      {'filename': widget.filename},
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: raftFormat(context, 'Video {filename}', {
        'filename': widget.filename,
      }),
      child: RaftHoverRegion(
        onEnter: (_) => pointerEntered(),
        onHover: (_) => pointerMoved(),
        onExit: (_) => pointerLeft(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (widget.interactive)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: playLabel,
                  excludeSemantics: true,
                  onTap: widget.onTogglePlay,
                  child: RaftHoverRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const Key('inline-video-surface'),
                      behavior: HitTestBehavior.opaque,
                      onTap: surfaceTap,
                    ),
                  ),
                ),
              ),
            if (showCenterPlay || widget.controlsVisible != null)
              Center(
                // The browser's phone page has no tap-to-play surface: the
                // Play button itself takes the tap.
                child: fading(
                  showCenterPlay,
                  IgnorePointer(
                    ignoring: widget.onSurfaceTap == null,
                    child: GestureDetector(
                      onTap: widget.onTogglePlay,
                      child: Container(
                        key: const Key('inline-video-play'),
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .6),
                          shape: t.brutal
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .9),
                            width: t.brutal ? 2 : 1,
                          ),
                        ),
                        child: const RaftIcon(
                          RaftGlyph.play,
                          size: 22,
                          color: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.buffering && widget.ready)
              const Center(
                child: IgnorePointer(
                  child: RaftSpinner(
                    key: Key('inline-video-buffering'),
                    size: 32,
                    inverse: true,
                  ),
                ),
              ),
            if (showBar || widget.controlsVisible != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: widget.controlsInset,
                // Translucent: the bar's box is 112 px tall and, on a phone-sized
                // card (~170 px), reaches past the middle of the picture. An
                // opaque region there swallowed taps (it has no recognizer) and
                // the centre play button did nothing; the picture behind still
                // gets the hit, the controls keep their own taps.
                child: fading(
                  showBar,
                  RaftHoverRegion(
                    hitTestBehavior: HitTestBehavior.translucent,
                    onEnter: (_) => barHovered(true),
                    onExit: (_) => barHovered(false),
                    child: RaftVideoControlBar(
                      key: const Key('inline-video-bar'),
                      filename: widget.filename,
                      playing: widget.playing,
                      position: widget.position,
                      duration: widget.duration,
                      volume: widget.volume,
                      touch: touch,
                      hovered: hovered,
                      fullscreen: widget.fullscreen,
                      playLabel: playLabel,
                      onTogglePlay: widget.onTogglePlay,
                      onSeek: widget.onSeek,
                      onVolume: widget.onVolume,
                      onOpen: widget.onOpen,
                      onDownload: widget.onDownload,
                      onFullscreen: widget.onFullscreen,
                      onMute: widget.onVolume == null
                          ? null
                          : () {
                              if (widget.volume > 0) {
                                mutedFrom = widget.volume;
                                widget.onVolume!(0);
                              } else {
                                widget.onVolume!(
                                  mutedFrom > 0 ? mutedFrom : 100,
                                );
                              }
                            },
                      onInteract:
                          touch &&
                              widget.playing &&
                              widget.controlsVisible == null
                          ? showBarBriefly
                          : null,
                      onDragChanged: dragChanged,
                    ),
                  ),
                ),
              ),
            ...widget.extra,
          ],
        ),
      ),
    );
  }
}

/// Bottom control bar over the picture, laid out like the browser's native
/// `<video controls>` panel: play / pause, time, then (right) mute with a
/// volume rail on hover and the open-in-viewer control, and the full-width
/// seek rail below, over a dark fade.
class RaftVideoControlBar extends StatefulWidget {
  const RaftVideoControlBar({
    super.key,
    required this.filename,
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    required this.touch,
    required this.hovered,
    required this.playLabel,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
    this.onMute,
    this.onOpen,
    this.onDownload,
    this.onFullscreen,
    this.fullscreen = false,
    this.onInteract,
    this.onDragChanged,
  });
  final String filename, playLabel;
  final bool playing, touch, hovered, fullscreen;
  final Duration position, duration;
  final double volume;
  final VoidCallback? onTogglePlay,
      onMute,
      onOpen,
      onDownload,
      onFullscreen,
      onInteract;

  /// A seek or volume drag started (true) or ended (false).
  final ValueChanged<bool>? onDragChanged;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  State<RaftVideoControlBar> createState() => _RaftVideoControlBarState();
}

class _RaftVideoControlBarState extends State<RaftVideoControlBar> {
  bool volumeHovered = false;
  Timer? volumeTimer;

  /// The volume rail follows the pointer over the speaker or the rail itself;
  /// leaving one for the other must not close it in between.
  void volumeEnter(PointerEvent _) {
    volumeTimer?.cancel();
    if (!volumeHovered) setState(() => volumeHovered = true);
  }

  void volumeExit(PointerEvent _) {
    volumeTimer?.cancel();
    volumeTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => volumeHovered = false);
    });
  }

  @override
  void dispose() {
    volumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final known = widget.duration > Duration.zero;
    final bounded = known && widget.position > widget.duration
        ? widget.duration
        : widget.position;
    final progress = known
        ? (bounded.inMilliseconds / widget.duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final timeLabel =
        '${raftAudioTimestamp(bounded)} / ${raftAudioTimestamp(widget.duration)}';
    const box = 48.0;
    final muted = widget.volume <= 0;
    final openLabel = raftFormat(context, 'Open {filename} in preview', {
      'filename': widget.filename,
    });
    Widget button({
      required Key key,
      required RaftGlyph glyph,
      required String label,
      required VoidCallback? onTap,
      bool filled = false,
    }) => _ControlButton(
      key: key,
      glyph: glyph,
      label: label,
      onTap: onTap,
      filled: filled,
      box: box,
      onInteract: widget.onInteract,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Like the browser panel, drop controls from the end when narrow:
        // mute first to go last, then open, then download.
        // Play + time + padding, and the volume rail a mouse opens.
        final reserved = 6 + 150 + (widget.touch ? 0 : 64);
        final fit = ((constraints.maxWidth - reserved) / box).floor();
        // Drop controls from the end when narrow, like the browser panel.
        final shown = <String>{
          for (final name in [
            'mute',
            if (widget.onFullscreen != null) 'fullscreen',
            if (widget.onOpen != null) 'open',
            if (widget.onDownload != null) 'download',
          ].take(fit < 0 ? 0 : fit))
            name,
        };
        final showMute = shown.contains('mute');
        final showFullscreen = shown.contains('fullscreen');
        final showOpen = shown.contains('open');
        final showDownload = shown.contains('download');
        return SizedBox(
          height: 112,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // Sampled from the browser panel's fade (112 px tall).
                        colors: [
                          for (final a in _videoFade)
                            Colors.black.withValues(alpha: a),
                        ],
                        stops: _videoFadeStops,
                      ),
                    ),
                  ),
                ),
              ),
              // The browser panel: 48 px controls whose centres sit 50 px above
              // the bottom edge, the seek rail 24 px above it.
              Positioned(
                left: 3,
                right: 3,
                bottom: 26,
                height: box,
                child: Row(
                  children: [
                    button(
                      key: const Key('inline-video-toggle'),
                      glyph: widget.playing ? RaftGlyph.pause : RaftGlyph.play,
                      label: widget.playLabel,
                      onTap: widget.onTogglePlay,
                      filled: true,
                    ),
                    // Give the time the remaining width. A loose Flexible
                    // plus Spacer leaves unused time allocation after the actions
                    // with proportional fonts (especially short clips).
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          timeLabel,
                          key: const Key('inline-video-time'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            fontWeight: FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: Colors.white,
                            decoration: TextDecoration.none,
                            fontFamily: t.bodyFont,
                          ),
                        ),
                      ),
                    ),
                    if (showMute)
                      RaftHoverRegion(
                        onEnter: volumeEnter,
                        onExit: volumeExit,
                        child: button(
                          key: const Key('inline-video-mute'),
                          glyph: muted ? RaftGlyph.volumeX : RaftGlyph.volume2,
                          label: raftFormat(
                            context,
                            muted
                                ? 'Unmute video {filename}'
                                : 'Mute video {filename}',
                            {'filename': widget.filename},
                          ),
                          onTap: widget.onMute,
                        ),
                      ),
                    if (showFullscreen)
                      button(
                        key: const Key('inline-video-fullscreen'),
                        glyph: widget.fullscreen
                            ? RaftGlyph.minimize
                            : RaftGlyph.maximize,
                        label: raftFormat(
                          context,
                          widget.fullscreen
                              ? 'Exit full screen {filename}'
                              : 'Full screen {filename}',
                          {'filename': widget.filename},
                        ),
                        onTap: widget.onFullscreen,
                      ),
                    if (showOpen)
                      button(
                        key: const Key('inline-video-open'),
                        glyph: RaftGlyph.maximize,
                        label: openLabel,
                        onTap: widget.onOpen,
                      ),
                    if (showDownload)
                      button(
                        key: const Key('inline-video-download-action'),
                        glyph: RaftGlyph.download,
                        label: raftFormat(context, 'Download {filename}', {
                          'filename': widget.filename,
                        }),
                        onTap: widget.onDownload,
                      ),
                  ],
                ),
              ),
              if (!widget.touch && showMute)
                Positioned(
                  right:
                      3 +
                      box *
                          (1 +
                              ((showFullscreen ? 1 : 0) +
                                  (showOpen ? 1 : 0) +
                                  (showDownload ? 1 : 0))),
                  bottom: 26,
                  width: 64,
                  height: box,
                  child: RaftHoverRegion(
                    onEnter: volumeEnter,
                    onExit: volumeExit,
                    child: IgnorePointer(
                      ignoring: !volumeHovered,
                      // Kept in the semantics tree while hidden: a screen
                      // reader adjusts the volume without a pointer.
                      child: Opacity(
                        opacity: volumeHovered ? 1 : 0,
                        alwaysIncludeSemantics: true,
                        child: _VideoRail(
                          key: const Key('inline-video-volume'),
                          semanticLabel: raftFormat(
                            context,
                            'Video volume {filename}',
                            {'filename': widget.filename},
                          ),
                          semanticValue: '${widget.volume.round()}%',
                          value: (widget.volume / 100).clamp(0.0, 1.0),
                          step: .1,
                          enabled: widget.onVolume != null,
                          height: box,
                          thumb: true,
                          onDragChanged: widget.onDragChanged,
                          onChanged: (v) => widget.onVolume?.call(v * 100),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                height: 16,
                child: _VideoRail(
                  key: const Key('inline-video-seek'),
                  hoverLabel: known
                      ? (f) => raftAudioTimestamp(
                          Duration(
                            milliseconds: (f * widget.duration.inMilliseconds)
                                .round(),
                          ),
                        )
                      : null,
                  semanticLabel: raftFormat(context, 'Seek video {filename}', {
                    'filename': widget.filename,
                  }),
                  semanticValue: raftFormat(
                    context,
                    '{position} of {duration}',
                    {
                      'position': raftAudioTimestamp(bounded),
                      'duration': raftAudioTimestamp(widget.duration),
                    },
                  ),
                  value: progress,
                  step: known
                      ? (5000 / widget.duration.inMilliseconds).clamp(0.0, 1.0)
                      : 0,
                  enabled: known,
                  height: 16,
                  thumb: widget.hovered || widget.touch,
                  onDragChanged: widget.onDragChanged,
                  onChanged: (v) {
                    widget.onInteract?.call();
                    widget.onSeek?.call(
                      Duration(
                        milliseconds: (v * widget.duration.inMilliseconds)
                            .round(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.box = 48,
    this.onInteract,
  });
  final RaftGlyph glyph;
  final String label;
  final VoidCallback? onTap, onInteract;
  final bool filled;
  final double box;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: RaftHoverRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onInteract?.call();
          onTap?.call();
        },
        child: SizedBox(
          width: box,
          height: box,
          child: Center(
            child: RaftIcon(
              glyph,
              size: 16,
              color: Colors.white,
              filled: filled,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A thin light rail with a round thumb, for the dark video bar.
class _VideoRail extends StatefulWidget {
  const _VideoRail({
    super.key,
    required this.value,
    required this.enabled,
    required this.height,
    required this.onChanged,
    required this.semanticLabel,
    required this.semanticValue,
    this.thumb = true,
    this.step = .05,
    this.hoverLabel,
    this.onDragChanged,
  });
  final double value, height, step;
  final ValueChanged<bool>? onDragChanged;
  final bool enabled, thumb;
  final ValueChanged<double> onChanged;
  final String semanticLabel, semanticValue;

  /// Text for the pill that follows the pointer over the rail (the time at
  /// that position); null shows none.
  final String Function(double fraction)? hoverLabel;

  @override
  State<_VideoRail> createState() => _VideoRailState();
}

class _VideoRailState extends State<_VideoRail> {
  double? hoverX;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      enabled: widget.enabled,
      // Screen readers adjust with the platform's increase / decrease.
      increasedValue: widget.semanticValue,
      decreasedValue: widget.semanticValue,
      onIncrease: widget.enabled && widget.step > 0
          ? () => widget.onChanged((widget.value + widget.step).clamp(0.0, 1.0))
          : null,
      onDecrease: widget.enabled && widget.step > 0
          ? () => widget.onChanged((widget.value - widget.step).clamp(0.0, 1.0))
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final value = widget.value;
          void update(double dx) {
            if (!widget.enabled || w <= 0) return;
            widget.onChanged((dx / w).clamp(0.0, 1.0));
          }

          final hover = hoverX;
          return RaftHoverRegion(
            cursor: SystemMouseCursors.click,
            onHover: widget.hoverLabel == null
                ? null
                : (e) => setState(() => hoverX = e.localPosition.dx),
            onExit: (_) => setState(() => hoverX = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => update(d.localPosition.dx),
              onHorizontalDragStart: (d) {
                widget.onDragChanged?.call(true);
                update(d.localPosition.dx);
              },
              onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
              onHorizontalDragEnd: (_) => widget.onDragChanged?.call(false),
              onHorizontalDragCancel: () => widget.onDragChanged?.call(false),
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xADFFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    if (widget.thumb || hover != null)
                      Positioned(
                        left: (w * value - 6).clamp(-6.0, w - 6),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (hover != null && widget.hoverLabel != null)
                      Positioned(
                        left: hover.clamp(0.0, w),
                        bottom: widget.height / 2 + 10,
                        child: IgnorePointer(
                          child: FractionalTranslation(
                            translation: const Offset(-.5, 0),
                            child: Container(
                              key: const Key('inline-video-hover-time'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .88),
                                borderRadius: t.brutal
                                    ? null
                                    : BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: t.brutal ? .9 : .25,
                                  ),
                                  width: t.brutal ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                widget.hoverLabel!(
                                  w <= 0 ? 0 : (hover / w).clamp(0.0, 1.0),
                                ),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily: t.monoFont,
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
