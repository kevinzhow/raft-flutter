// Web inline audio / video attachment cards (MessageItem.tsx
// InlineVideoAttachmentCard, InlineAudioAttachmentCard, InlineAudioPlayer).
// The app owns the media: URL, download, decoding, play state.
import 'dart:math' as math;

import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'card.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'media_browser.dart' show RaftMediaHero, raftMediaDuration;
import 'message_embed_frame.dart';
import 'panel_layout.dart' show RaftCssText;
import 'raft/button.dart';
import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/message_video_preview.g.dart';
import 'space.dart';
import 'text_scaling.dart';
import 'token_geometry.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'video_controls.dart';
import 'theme.dart';
import 'tooltip.dart';

enum RaftInlineMediaState { idle, loading, failed, ready }

/// The video card (Web InlineVideoAttachmentCard): a black 16:9 box whose
/// video is letterboxed (`object-contain`), so a portrait clip keeps its
/// aspect between black bars. The poster is the first decoded frame (the
/// paused video surface) or [poster] (a server thumbnail) beneath it.
///
/// Controls follow the native `<video controls>` Web renders: a centred Play
/// button while paused (on hover with a mouse, always on touch), a bottom bar
/// (play / pause, time, seek, volume) on hover, while paused after the first
/// play, or for a few seconds after a tap on touch; clicking the picture
/// toggles playback. The corner action opens the full preview. While loading
/// a spinner shows, and a failure reads as the codec warning with a download
/// action.
class RaftInlineVideo extends StatefulWidget {
  const RaftInlineVideo({
    super.key,
    required this.state,
    required this.filename,
    this.video,
    this.poster,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.touch,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
    this.onOpenPreview,
    this.onDownload,
    this.failureMessage,
    this.onRetry,
    this.onNetworkSettings,
  });
  final RaftInlineMediaState state;
  final String filename;

  /// The failed state's message, already localized and specific to the cause
  /// (proxy unreachable, expired link, ...). Null reads as Web's codec
  /// warning.
  final String? failureMessage;

  /// Failed state actions beside Download: reopen the media (signs the link
  /// again) and open Settings > Network. A null callback hides the action.
  final VoidCallback? onRetry, onNetworkSettings;

  /// The decoded video surface (state ready).
  final Widget? video;

  /// Server thumbnail shown until the video surface has a frame.
  final Widget? poster;
  final bool playing, buffering;
  final Duration position, duration;

  /// 0..100 like the native player.
  final double volume;

  /// Touch input (controls without hover). Defaults to the mobile platforms.
  final bool? touch;
  final VoidCallback? onTogglePlay, onOpenPreview, onDownload;
  final ValueChanged<Duration>? onSeek;

  /// 0..100.
  final ValueChanged<double>? onVolume;

  @override
  State<RaftInlineVideo> createState() => _RaftInlineVideoState();
}

class _RaftInlineVideoState extends State<RaftInlineVideo> {
  bool actionHovered = false;

  bool get ready =>
      widget.state == RaftInlineMediaState.ready && widget.video != null;

  /// Warning icon, the cause and the actions the user can take. With only the
  /// Download action this is Web's failed card; a card with more actions
  /// drops the icon so a phone-width card (140 px tall) still fits.
  Widget _failedBody(BuildContext context, RaftTokens t) {
    TextStyle style(double alpha, FontWeight weight) => TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      fontWeight: weight,
      color: Colors.white.withValues(alpha: alpha),
    );
    Widget link(
      Key key,
      RaftGlyph glyph,
      String label,
      VoidCallback? onTap,
    ) => GestureDetector(
      key: key,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          RaftIcon(glyph, size: 13, color: Colors.white.withValues(alpha: .75)),
          Text(raftText(context, label), style: style(.75, FontWeight.w400)),
        ],
      ),
    );
    final extra = widget.onRetry != null || widget.onNetworkSettings != null;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: (extra ? 8 : 12),
      children: [
        if (!extra)
          const RaftIcon(
            RaftGlyph.alertTriangle,
            size: 24,
            color: Colors.white,
          ),
        Text(
          widget.failureMessage ??
              raftText(
                context,
                'This video may use a codec this browser cannot preview.',
              ),
          textAlign: TextAlign.center,
          style: style(1, FontWeight.w500),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (widget.onRetry != null)
              link(
                const Key('inline-video-retry'),
                RaftGlyph.refreshCw,
                'Retry',
                widget.onRetry,
              ),
            if (widget.onNetworkSettings != null)
              link(
                const Key('inline-video-network-settings'),
                RaftGlyph.network,
                'Network Settings',
                widget.onNetworkSettings,
              ),
            link(
              const Key('inline-video-download'),
              RaftGlyph.download,
              'Download to View',
              widget.onDownload,
            ),
          ],
        ),
      ],
    );
    if (!extra) return body;
    // A phone-width card is 140 px tall: a long cause and three actions shrink
    // to fit rather than overflow.
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(width: constraints.maxWidth, child: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final s = RaftMessageVideoPreviewRecipe.resolve(
      states: t.recipeStates(),
      tokens: rt,
    );
    final action = RaftMessageVideoPreviewRecipe.resolve(
      states: t.recipeStates(hovered: actionHovered),
      tokens: rt,
    ).action;
    final width = MediaQuery.sizeOf(context).width;
    final openLabel = raftFormat(context, 'Open {filename} in Preview', {
      'filename': widget.filename,
    });
    final Widget fallback = switch (widget.state) {
      RaftInlineMediaState.ready when widget.video != null => widget.video!,
      RaftInlineMediaState.loading => const Center(
        child: RaftSpinner(size: 24, inverse: true),
      ),
      RaftInlineMediaState.failed => Center(
        // `max-w-[256px] px-4`: the padding is inside the 256 px box.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _failedBody(context, t),
          ),
        ),
      ),
      _ => Center(
        child: RaftIcon(
          RaftGlyph.play,
          size: 32,
          color: Colors.white.withValues(alpha: .8),
        ),
      ),
    };
    // A tap while the player is still being prepared is kept (the card queues
    // the play), so the picture reacts in every state but failed.
    final interactive = widget.state != RaftInlineMediaState.failed;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (width - 112).clamp(0, 448).toDouble(),
        ),
        child: _CardBox(
          child: RaftRecipeBox(
            key: const Key('inline-video'),
            style: s.root,
            tokens: rt,
            clip: true,
            child: RaftVideoOverlay(
              filename: widget.filename,
              interactive: interactive,
              ready: ready,
              buffering: widget.buffering,
              playing: widget.playing,
              position: widget.position,
              duration: widget.duration,
              volume: widget.volume,
              touch: widget.touch,
              onTogglePlay: widget.onTogglePlay,
              onSeek: widget.onSeek,
              onVolume: widget.onVolume,
              onOpen: widget.onOpenPreview,
              onDownload: widget.onDownload,
              extra: [
                if (widget.onOpenPreview != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: RaftTooltip(
                      message: openLabel,
                      excludeFromSemantics: true,
                      child: Semantics(
                        button: true,
                        label: openLabel,
                        child: RaftHoverRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => actionHovered = true),
                          onExit: (_) => setState(() => actionHovered = false),
                          child: GestureDetector(
                            key: const Key('inline-video-expand'),
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onOpenPreview,
                            child: RaftRecipeBox(
                              style: action,
                              tokens: rt,
                              width: 24,
                              height: 24,
                              child: const Center(
                                child: RaftIcon(RaftGlyph.eye, size: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.poster != null &&
                        widget.state != RaftInlineMediaState.failed)
                      widget.poster!,
                    fallback,
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

/// `aspect-video` as the browser lays it out: 16:9 with the height snapped to
/// a whole pixel (a 440 px card is 248 px tall, not 247.5).
class _CardBox extends StatelessWidget {
  const _CardBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 448.0;
      return SizedBox(
        width: width,
        height: (width * 9 / 16).roundToDouble(),
        child: child,
      );
    },
  );
}

/// The video card on a phone (no inline player): the poster at the video's own
/// shape with a play button in the middle and the length in a corner. A tap
/// anywhere on it opens the media viewer, which plays the video.
///
/// The box takes [aspectRatio] (width over height of the displayed picture;
/// 16:9 while the shape is unknown) at the card's width, capped at
/// [maxHeightFraction] of the screen height; a taller picture is cropped to
/// fill (cover), never squeezed. Without a [poster] (none yet, or it could not
/// be read) the box is a neutral placeholder, not black, and keeps the play
/// button.
///
/// [heroTag] / [heroEnabled] put the picture on the card-to-viewer flight (see
/// [RaftMediaHero]); the flight shows [poster] only, never a player.
/// Why a video card shows no preview (Web `useRefreshingMediaUrl`'s
/// `InlineMediaFailure`): the link or network failed (Retry helps), or the
/// platform cannot decode the file (only Download does).
enum RaftVideoPreviewFailure { unavailable, unsupported }

class RaftVideoPosterCard extends StatelessWidget {
  const RaftVideoPosterCard({
    super.key,
    required this.filename,
    this.poster,
    this.aspectRatio,
    this.duration,
    this.loading = false,
    this.onOpen,
    this.heroTag,
    this.heroEnabled = false,
    this.maxHeightFraction = .6,
    this.failure,
    this.onRetry,
    this.onDownload,
  });
  final String filename;
  final ImageProvider? poster;

  /// The preview could not be made: the card says so and offers Retry (when
  /// the failure is [RaftVideoPreviewFailure.unavailable]) and Download.
  final RaftVideoPreviewFailure? failure;
  final VoidCallback? onRetry, onDownload;

  /// Width over height of the displayed picture, when known.
  final double? aspectRatio;
  final Duration? duration;

  /// The upload is still running: a spinner instead of the play button.
  final bool loading;
  final VoidCallback? onOpen;
  final Object? heroTag;
  final bool heroEnabled;
  final double maxHeightFraction;

  /// The shape used while the real one is unknown.
  static const defaultAspect = 16 / 9;

  /// The card never grows wider than this (Web `max-w-[448px]`).
  static const maxCardWidth = 448.0;

  /// The box for a card [width] wide: the picture's shape, capped in height.
  static Size boxFor(
    double width,
    double? aspectRatio, {
    required double screenHeight,
    double maxHeightFraction = .6,
  }) {
    final aspect =
        aspectRatio != null && aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : defaultAspect;
    final height = (width / aspect).roundToDouble();
    return Size(width, height.clamp(1.0, screenHeight * maxHeightFraction));
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final s = RaftMessageVideoPreviewRecipe.resolve(
      states: t.recipeStates(),
      tokens: rt,
    );
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = (screen.width - 112).clamp(0, maxCardWidth).toDouble();
    final label = raftFormat(context, 'Play Video {filename}', {
      'filename': filename,
    });
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : maxCardWidth;
            final box = boxFor(
              width,
              aspectRatio,
              screenHeight: screen.height,
              maxHeightFraction: maxHeightFraction,
            );
            return SizedBox(
              width: box.width,
              height: box.height,
              child: RaftInteractive(
                key: const Key('inline-video-poster-card'),
                onPressed: onOpen,
                semanticLabel: label,
                builder: (_, _) => RaftRecipeBox(
                  key: const Key('inline-video'),
                  style: s.root,
                  tokens: rt,
                  clip: true,
                  child: _picture(context, t, s),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _picture(
    BuildContext context,
    RaftTokens t,
    RaftMessageVideoPreviewRecipeStyle s,
  ) {
    final image = poster;
    final Widget picture = image == null
        ? ColoredBox(
            key: const Key('inline-video-placeholder'),
            color: t.colors['layer-canvas-muted']!,
          )
        // ignore: raft_lints/avoid_raw_image_decode -- The provider comes from an AttachmentImageRepository lease: already decoded at the card's size and owned by the repository.
        : Image(
            image: image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: t.colors['layer-canvas-muted']!),
          );
    final Widget stage = heroTag == null
        ? picture
        : RaftMediaHero(
            tag: heroTag!,
            image: image,
            radius: RaftShapes.attachment(t),
            fit: BoxFit.cover,
            enabled: heroEnabled && image != null,
            child: picture,
          );
    final length = duration;
    if (failure != null) return _failed(context, t, s);
    return Stack(
      fit: StackFit.expand,
      children: [
        stage,
        Center(
          child: loading
              ? const RaftSpinner(size: 24, inverse: true)
              : const _PlayDisc(),
        ),
        if (length != null && length > Duration.zero)
          Positioned(
            right: 6,
            bottom: 6,
            child: RaftChrome(
              child: DecoratedBox(
                key: const Key('inline-video-duration'),
                // ds-allow: a scrim over the video picture, white on black like the player's own chrome
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .62),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    raftMediaDuration(length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Web `MessageVideoPreviewFallback` with the failure content: a warning, what
  /// went wrong, then Retry and Download to view.
  Widget _failed(
    BuildContext context,
    RaftTokens t,
    RaftMessageVideoPreviewRecipeStyle s,
  ) {
    final rt = t.recipeTokens;
    final unsupported = failure == RaftVideoPreviewFailure.unsupported;
    Widget action(
      String label,
      RaftGlyph glyph,
      VoidCallback? onTap,
      String semantic,
    ) => RaftInteractive(
      onPressed: onTap,
      semanticLabel: semantic,
      builder: (_, _) => RaftRecipeBox(
        style: s.failureAction,
        tokens: rt,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftIcon(glyph, size: 13),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
    final download = action(
      raftText(context, 'Download to view'),
      RaftGlyph.download,
      onDownload,
      raftFormat(context, 'Download {filename}', {'filename': filename}),
    );
    return RaftRecipeBox(
      key: const Key('inline-video-failure'),
      style: s.fallback,
      tokens: rt,
      child: Center(
        child: RaftRecipeBox(
          style: s.failureContent,
          tokens: rt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RaftRecipeBox(
                style: s.failureIcon,
                tokens: rt,
                child: const RaftIcon(RaftGlyph.alertTriangle, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                unsupported
                    ? raftText(
                        context,
                        'This video may use a codec this browser cannot preview.',
                      )
                    : raftText(context, "Couldn't load this video preview."),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (unsupported)
                download
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    action(
                      raftText(context, 'Retry'),
                      RaftGlyph.rotateCcw,
                      onRetry,
                      raftFormat(context, 'Retry loading {filename}', {
                        'filename': filename,
                      }),
                    ),
                    download,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round play button over a poster.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('inline-video-play'),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .55),
      shape: BoxShape.circle,
    ),
    child: const SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: RaftIcon(
          RaftGlyph.play,
          size: 22,
          color: Colors.white,
          filled: true,
        ),
      ),
    ),
  );
}

String raftAudioTimestamp(Duration value) {
  final seconds = value.inMilliseconds / 1000;
  if (!seconds.isFinite || seconds <= 0) return '0:00';
  final total = seconds.floor();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// The audio card: icon + filename + download over the player (or its loading
/// / failed placeholder).
class RaftInlineAudio extends StatelessWidget {
  const RaftInlineAudio({
    super.key,
    required this.filename,
    required this.state,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1,
    this.onDownload,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
    this.failureMessage,
    this.onRetry,
    this.onNetworkSettings,
  });
  final String filename;
  final RaftInlineMediaState state;
  final bool playing;
  final Duration position, duration;

  /// The failed state's message, already localized and specific to the cause.
  /// Null keeps the one-line "Download to view" placeholder.
  final String? failureMessage;

  /// 0..1.
  final double volume;
  final VoidCallback? onDownload, onTogglePlay, onRetry, onNetworkSettings;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final downloadLabel = raftFormat(context, 'Download {filename}', {
      'filename': filename,
    });
    final headerIcon = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ui.fillMuted,
        borderRadius: t.corner('radius.chip', fallback: 6),
      ),
      child: RaftIcon(RaftGlyph.music, size: 18, color: ui.foregroundMuted),
    );
    final download = state == RaftInlineMediaState.failed || onDownload == null
        ? null
        : RaftButton(
            key: const Key('audio-download'),
            label: '',
            glyph: RaftGlyph.download,
            uiVariant: RaftButtonVariant.ghost,
            uiSize: RaftButtonSize.iconMd,
            tooltip: downloadLabel,
            semanticLabel: downloadLabel,
            onPressed: onDownload,
          );
    final header = Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              spacing: RaftSpace.x2,
              children: [
                headerIcon,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RaftTooltip(
                        message: filename,
                        child: RaftCssText(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t
                              .scale(
                                RaftTypeScale.callout,
                                weight: FontWeight.w600,
                                color: ui.foreground,
                              )
                              .copyWith(
                                fontVariations: const [
                                  FontVariation.weight(600),
                                ],
                              ),
                        ),
                      ),
                      RaftCssText(
                        raftText(context, 'Audio file'),
                        style: t.scale(
                          RaftTypeScale.monoMeta,
                          mono: true,
                          color: ui.foregroundHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (download != null) ...[
            const SizedBox(width: RaftSpace.x2),
            download,
          ],
        ],
      ),
    );
    final loadingLabel = raftFormat(context, 'Loading {filename}', {
      'filename': filename,
    });
    final controlRadius = t.corner('radius.control', fallback: 8);
    final wellTextStyle = t
        .scale(
          RaftTypeScale.control,
          weight: FontWeight.w600,
          color: ui.foregroundMuted,
        )
        .copyWith(fontVariations: const [FontVariation.weight(600)]);
    Widget failedAction(
      Key key,
      RaftGlyph glyph,
      String label,
      VoidCallback? onTap,
    ) => GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: RaftSpace.x1_5,
        children: [
          RaftIcon(glyph, size: 14, color: ui.foregroundMuted),
          RaftCssText(raftText(context, label), style: wellTextStyle),
        ],
      ),
    );
    final Widget body = state == RaftInlineMediaState.ready
        ? _AudioPlayer(
            filename: filename,
            playing: playing,
            position: position,
            duration: duration,
            volume: volume,
            onTogglePlay: onTogglePlay,
            onSeek: onSeek,
            onVolume: onVolume,
          )
        : state == RaftInlineMediaState.failed && failureMessage != null
        ? Container(
            key: const Key('audio-failed'),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: RaftSpace.x3,
              vertical: RaftSpace.x2,
            ),
            decoration: BoxDecoration(
              color: ui.fillMuted,
              borderRadius: controlRadius,
            ),
            child: DefaultTextStyle.merge(
              style: wellTextStyle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: RaftSpace.x1_5,
                children: [
                  Text(failureMessage!, textAlign: TextAlign.center),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: RaftSpace.x3,
                    runSpacing: RaftSpace.x1,
                    children: [
                      if (onRetry != null)
                        failedAction(
                          const Key('audio-retry'),
                          RaftGlyph.refreshCw,
                          'Retry',
                          onRetry,
                        ),
                      if (onNetworkSettings != null)
                        failedAction(
                          const Key('audio-network-settings'),
                          RaftGlyph.network,
                          'Network Settings',
                          onNetworkSettings,
                        ),
                      failedAction(
                        const Key('audio-placeholder'),
                        RaftGlyph.download,
                        'Download to View',
                        onDownload,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        : GestureDetector(
            key: const Key('audio-placeholder'),
            behavior: HitTestBehavior.opaque,
            // Idle: the player was released (or not prepared yet); a tap prepares
            // it and plays.
            onTap: state == RaftInlineMediaState.failed
                ? onDownload
                : state == RaftInlineMediaState.idle
                ? onTogglePlay
                : null,
            child: Container(
              constraints: BoxConstraints(minHeight: t.desktop ? 34 : 32),
              padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ui.fillMuted,
                borderRadius: controlRadius,
              ),
              child: DefaultTextStyle.merge(
                style: wellTextStyle,
                child: state == RaftInlineMediaState.loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: RaftSpace.x2,
                        children: [
                          const RaftSpinner(size: 14),
                          Flexible(
                            child: Text(
                              loadingLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : state == RaftInlineMediaState.failed
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: RaftSpace.x2,
                        children: [
                          RaftIcon(
                            RaftGlyph.download,
                            size: 16,
                            color: ui.foregroundMuted,
                          ),
                          Flexible(
                            child: Text(
                              raftText(context, 'Download to View'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        loadingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          );
    final width = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (width - 112).clamp(0, 448).toDouble(),
        ),
        child: RaftMessageEmbedFrame(
          key: const Key('inline-audio'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, body],
            ),
          ),
        ),
      ),
    );
  }
}

/// Web `AudioPreviewBody` (modal variant): `<Card className="w-full max-w-xl p-4">`
/// with the 36px rounded-chip music badge, name and "Audio file" over the audio rails.
class RaftAudioPreview extends StatelessWidget {
  const RaftAudioPreview({
    super.key,
    required this.filename,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
  });
  final String filename;
  final bool playing;
  final Duration position, duration;

  /// 0..1.
  final double volume;
  final VoidCallback? onTogglePlay;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    // Centred when the card fits; scrolls when it does not (landscape, large
    // text, a short window).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? math.max(0.0, constraints.maxHeight - 32)
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 576),
              child: RaftCard(
                key: const Key('audio-preview'),
                padding: const EdgeInsets.all(RaftSpace.x4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: RaftSpace.x3),
                      child: Row(
                        spacing: RaftSpace.x3,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ui.fillMuted,
                              borderRadius: t.corner(
                                'radius.chip',
                                fallback: 6,
                              ),
                            ),
                            child: RaftIcon(
                              RaftGlyph.music,
                              size: 20,
                              color: ui.foregroundMuted,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RaftCssText(
                                  filename,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t
                                      .scale(
                                        RaftTypeScale.callout,
                                        weight: FontWeight.w600,
                                        color: ui.foreground,
                                      )
                                      .copyWith(
                                        fontVariations: const [
                                          FontVariation.weight(600),
                                        ],
                                      ),
                                ),
                                RaftCssText(
                                  raftText(context, 'Audio file'),
                                  style: t.scale(
                                    RaftTypeScale.monoMeta,
                                    mono: true,
                                    color: ui.foregroundHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AudioPlayer(
                      filename: filename,
                      playing: playing,
                      position: position,
                      duration: duration,
                      volume: volume,
                      onTogglePlay: onTogglePlay,
                      onSeek: onSeek,
                      onVolume: onVolume,
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

class _AudioPlayer extends StatelessWidget {
  const _AudioPlayer({
    required this.filename,
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
  });
  final String filename;
  final bool playing;
  final Duration position, duration;
  final double volume;
  final VoidCallback? onTogglePlay;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    final known = duration > Duration.zero;
    final bounded = known && position > duration ? duration : position;
    final progress = known
        ? (bounded.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final timeLabel =
        '${raftAudioTimestamp(bounded)} / ${raftAudioTimestamp(duration)}';
    final playLabel = raftFormat(
      context,
      playing ? 'Pause Audio {filename}' : 'Play Audio {filename}',
      {'filename': filename},
    );
    return Container(
      key: const Key('inline-audio-player'),
      padding: const EdgeInsets.all(RaftSpace.x2),
      decoration: BoxDecoration(
        color: ui.fillMuted,
        borderRadius: t.corner('radius.control', fallback: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: RaftSpace.x2,
            children: [
              RaftButton(
                key: const Key('audio-play-toggle'),
                uiVariant: RaftButtonVariant.standard,
                uiSize: RaftButtonSize.iconMd,
                semanticLabel: playLabel,
                onPressed: onTogglePlay,
                iconBuilder: (size, color) => RaftIcon(
                  playing ? RaftGlyph.pause : RaftGlyph.play,
                  size: size,
                  color: color,
                  filled: true,
                ),
              ),
              Expanded(
                child: _RailSlider(
                  key: const Key('audio-seek'),
                  semanticLabel: raftFormat(context, 'Seek audio {filename}', {
                    'filename': filename,
                  }),
                  semanticValue: timeLabel,
                  value: progress,
                  enabled: known,
                  height: 32,
                  rail: 8,
                  railRadius: 4,
                  thumb: 14,
                  fill: ui.info,
                  onChanged: (v) => onSeek?.call(
                    Duration(
                      milliseconds: (v * duration.inMilliseconds).round(),
                    ),
                  ),
                ),
              ),
              SizedBox(
                // `w-[4.75rem]` (76px), scaling cleanly with Dynamic Type.
                width: RaftScaled.extent(context, 76, fontSize: 12),
                child: RaftCssText(
                  timeLabel,
                  key: const Key('audio-time'),
                  textAlign: TextAlign.right,
                  style: t
                      .scale(
                        RaftTypeScale.monoMeta,
                        mono: true,
                        color: ui.foregroundHint,
                      )
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RaftSpace.x1_5),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              spacing: RaftSpace.x2,
              children: [
                RaftIcon(
                  RaftGlyph.volume2,
                  size: 16,
                  color: ui.foregroundMuted,
                ),
                Expanded(
                  child: _RailSlider(
                    key: const Key('audio-volume'),
                    semanticLabel: raftFormat(
                      context,
                      'Audio volume {filename}',
                      {'filename': filename},
                    ),
                    semanticValue: '${(volume * 100).round()}%',
                    value: volume.clamp(0.0, 1.0),
                    enabled: true,
                    height: 24,
                    rail: 6,
                    railRadius: 3,
                    thumb: 12,
                    fill: ui.foregroundMuted,
                    onChanged: (v) => onVolume?.call(v),
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

/// Web v1.24 audio rails: rounded hairline-bordered `layer-card` track with
/// clipped progress fill and `rounded-[2px] border-[1.5px] border-line-strong`
/// `layer-card` thumb.
class _RailSlider extends StatelessWidget {
  const _RailSlider({
    super.key,
    required this.value,
    required this.enabled,
    required this.height,
    required this.rail,
    required this.railRadius,
    required this.thumb,
    required this.fill,
    required this.onChanged,
    required this.semanticLabel,
    required this.semanticValue,
  });
  final double value, height, rail, railRadius, thumb;
  final bool enabled;
  final Color fill;
  final ValueChanged<double> onChanged;
  final String semanticLabel, semanticValue;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: semanticValue,
      enabled: enabled,
      increasedValue: semanticValue,
      decreasedValue: semanticValue,
      onIncrease: enabled
          ? () => onChanged((value + .05).clamp(0.0, 1.0))
          : null,
      onDecrease: enabled
          ? () => onChanged((value - .05).clamp(0.0, 1.0))
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          void update(double dx) {
            if (!enabled || w <= 0) return;
            onChanged((dx / w).clamp(0.0, 1.0));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => update(d.localPosition.dx),
            onHorizontalDragStart: (d) => update(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: rail,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: ui.layerCard,
                      borderRadius: BorderRadius.circular(railRadius),
                      border: Border.all(
                        color: raftChromeBlend(ui.lineHairline, ui.layerCard),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: ColoredBox(color: fill),
                    ),
                  ),
                  Positioned(
                    left: w * value - thumb / 2,
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: ui.layerCard,
                        borderRadius: t.corner(
                          'radius.audioThumb',
                          fallback: 2,
                        ),
                        border: Border.all(color: ui.lineStrong, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Web MessageItem attachment area: the image gallery, then the inline videos
/// and the inline audio cards (each `space-y-2`), then every other attachment
/// as a wrapping group of cards; 8px between groups.
class RaftAttachmentStack extends StatelessWidget {
  const RaftAttachmentStack({
    super.key,
    this.gallery,
    this.videos = const [],
    this.audios = const [],
    this.others = const [],
  });
  final Widget? gallery;
  final List<Widget> videos, audios, others;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      ?gallery,
      if (videos.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: videos,
        ),
      if (audios.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: audios,
        ),
      if (others.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: others),
    ],
  );
}
