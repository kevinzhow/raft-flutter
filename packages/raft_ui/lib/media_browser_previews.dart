import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Media browser phone', size: Size(390, 844))
Widget mediaBrowserPhonePreview() => const _MediaBrowserPreview();

@RaftPreviews('Media browser phone, chrome hidden', size: Size(390, 844))
Widget mediaBrowserPhoneHiddenPreview() =>
    const _MediaBrowserPreview(chrome: false);

@RaftPreviews('Media browser phone landscape', size: Size(844, 390))
Widget mediaBrowserPhoneLandscapePreview() => const _MediaBrowserPreview();

@RaftPreviews('Media browser phone without caption', size: Size(390, 844))
Widget mediaBrowserPhoneNoCaptionPreview() =>
    const _MediaBrowserPreview(caption: false);

@RaftPreviews('Media browser desktop', size: Size(1280, 800))
Widget mediaBrowserDesktopPreview() => const _MediaBrowserDesktopPreview();

// Mount the real player so these previews exercise the controls and shell together.
@RaftPreviews('Video browser compact phone', size: Size(320, 640))
Widget videoBrowserCompactPhonePreview() =>
    const _MediaBrowserPreview(video: true);

@RaftPreviews('Video browser phone', size: Size(390, 844))
Widget videoBrowserPhonePreview() => const _MediaBrowserPreview(video: true);

@RaftPreviews('Video browser phone landscape', size: Size(844, 390))
Widget videoBrowserLandscapePreview() =>
    const _MediaBrowserPreview(video: true);

@RaftPreviews('Video browser tablet', size: Size(768, 1024))
Widget videoBrowserTabletPreview() =>
    const _MediaBrowserDesktopPreview(video: true);

@RaftPreviews('Video browser desktop', size: Size(1280, 800))
Widget videoBrowserDesktopPreview() =>
    const _MediaBrowserDesktopPreview(video: true);

@RaftPreviews('Video browser desktop single attachment', size: Size(1280, 800))
Widget videoBrowserSingleDesktopPreview() =>
    const _MediaBrowserDesktopPreview(video: true, gallery: false);

@RaftPreviews('Video inline card', size: Size(320, 240))
Widget videoInlineControlsPreview() => const Center(
  child: SizedBox(width: 288, height: 180, child: _VideoScene(inline: true)),
);

const _items = [
  RaftMediaStripItem(label: 'Image 1 of 8'),
  RaftMediaStripItem(
    label: 'Video 2 of 8',
    video: true,
    duration: Duration(seconds: 19),
  ),
  RaftMediaStripItem(label: 'Image 3 of 8'),
  RaftMediaStripItem(label: 'Image 4 of 8'),
  RaftMediaStripItem(
    label: 'Video 5 of 8',
    video: true,
    duration: Duration(minutes: 1, seconds: 3),
  ),
  RaftMediaStripItem(label: 'Image 6 of 8'),
  RaftMediaStripItem(label: 'Image 7 of 8'),
  RaftMediaStripItem(label: 'Image 8 of 8'),
];

class _Scene extends StatelessWidget {
  const _Scene();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF2C14E), Color(0xFF4F9D9D), Color(0xFF2B4570)],
      ),
    ),
    child: SizedBox.expand(),
  );
}

class _MediaBrowserPreview extends StatefulWidget {
  const _MediaBrowserPreview({
    this.chrome = true,
    this.caption = true,
    this.video = false,
  });
  final bool chrome, caption, video;
  @override
  State<_MediaBrowserPreview> createState() => _MediaBrowserPreviewState();
}

class _MediaBrowserPreviewState extends State<_MediaBrowserPreview> {
  late final ValueNotifier<bool> chrome = ValueNotifier(widget.chrome);
  late int index = widget.video ? 1 : 2;
  bool closed = false;

  @override
  void dispose() {
    chrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => closed
      ? Center(
          child: RaftButton(
            label: 'Open Media',
            onPressed: () => setState(() => closed = false),
          ),
        )
      : RaftMediaImmersiveShell(
          title: widget.video ? 'short-clip.mp4' : 'IMG_2041.jpg',
          subtitle: 'Alice Chen · Oct 13, 2:02 PM',
          chrome: chrome,
          onClose: () => setState(() => closed = true),
          counter: RaftLightboxCounter(index: index, count: _items.length),
          actions: [
            RaftMediaAction(
              glyph: RaftGlyph.share2,
              label: 'Share',
              onPressed: (_) {},
            ),
            RaftMediaAction(
              glyph: RaftGlyph.ellipsis,
              label: 'More',
              onPressed: (_) {},
            ),
          ],
          caption: widget.caption
              ? 'Notes from the walkthrough: the new hall, the loading dock '
                    'and the second floor staircase, all before the handover.'
              : null,
          strip: RaftMediaStrip(
            compact: true,
            items: _items,
            index: index,
            onSelect: (i) => setState(() => index = i),
          ),
          child: widget.video
              ? ValueListenableBuilder<bool>(
                  valueListenable: chrome,
                  builder: (context, shown, _) => _VideoScene(
                    immersive: true,
                    controlsVisible: shown,
                    onSurfaceTap: () => chrome.value = !chrome.value,
                  ),
                )
              : GestureDetector(
                  onTap: () => chrome.value = !chrome.value,
                  child: const _Scene(),
                ),
        );
}

class _MediaBrowserDesktopPreview extends StatefulWidget {
  const _MediaBrowserDesktopPreview({this.video = false, this.gallery = true});
  final bool video, gallery;
  @override
  State<_MediaBrowserDesktopPreview> createState() =>
      _MediaBrowserDesktopPreviewState();
}

class _MediaBrowserDesktopPreviewState
    extends State<_MediaBrowserDesktopPreview> {
  int index = 1;
  @override
  Widget build(BuildContext context) => RaftAttachmentLightbox(
    title: 'hall-walkthrough.mp4',
    subtitle: 'Alice Chen · Oct 13, 2:02 PM · 1920x1080 · 12.4 MB',
    leading: const RaftIcon(RaftGlyph.video, size: 16),
    titleBold: true,
    onClose: () {},
    meta: widget.gallery
        ? RaftLightboxCounter(index: index, count: _items.length)
        : null,
    actions: [
      RaftLightboxIconAction(
        glyph: RaftGlyph.download,
        label: 'Download',
        onPressed: () {},
      ),
    ],
    overlayInset: widget.gallery ? raftMediaDesktopStripBand : 0,
    overlay: !widget.gallery
        ? null
        : RaftMediaStrip(
            items: _items,
            index: index,
            onSelect: (i) => setState(() => index = i),
          ),
    child: widget.video ? const _VideoScene() : const _Scene(),
  );
}

// Only the picture is synthetic; controls, visibility and action state are real.
class _VideoScene extends StatefulWidget {
  const _VideoScene({
    this.immersive = false,
    this.inline = false,
    this.controlsVisible,
    this.onSurfaceTap,
  });
  final bool immersive, inline;
  final bool? controlsVisible;
  final VoidCallback? onSurfaceTap;
  @override
  State<_VideoScene> createState() => _VideoSceneState();
}

class _VideoSceneState extends State<_VideoScene> {
  bool playing = false;
  double volume = 100;
  Duration position = const Duration(seconds: 1);
  @override
  Widget build(BuildContext context) {
    final duration = widget.inline
        ? const Duration(hours: 2, minutes: 3, seconds: 4)
        : const Duration(seconds: 2);
    final insets = RaftMediaChromeInsets.maybeOf(context);
    void toggle() => setState(() => playing = !playing);
    void seek(Duration value) => setState(() => position = value);
    void setVolume(double value) => setState(() => volume = value);
    if (widget.inline) {
      return RaftVideoOverlay(
        filename: 'long-clip.mp4',
        playing: playing,
        position: position,
        duration: duration,
        volume: volume,
        touch: true,
        onTogglePlay: toggle,
        onSeek: seek,
        onVolume: setVolume,
        onOpen: () {},
        onDownload: () {},
        child: const _Scene(),
      );
    }
    return RaftVideoViewer(
      filename: 'short-clip.mp4',
      video: const _Scene(),
      immersive: widget.immersive,
      touch: widget.immersive,
      videoSize: const Size(1920, 1080),
      playing: playing,
      position: position,
      duration: duration,
      volume: volume,
      controlsVisible: widget.controlsVisible,
      controlsInset: widget.immersive ? (insets?.bottom ?? 0) : 0,
      onSurfaceTap: widget.onSurfaceTap,
      onTogglePlay: toggle,
      onSeek: seek,
      onVolume: setVolume,
      onDownload: widget.immersive ? null : () {},
    );
  }
}
