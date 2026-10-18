import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'icons.dart';
import 'preview_route.dart';
import 'large_content_viewer.dart';
import 'localization.dart';
import 'text_scaling.dart';
import 'dialog_card.dart' show RaftShadowSet;
import 'theme.dart';
import 'tokens/media_motion.g.dart';
import 'video_controls.dart' show raftMediaChromeFade;

// Unified media browser visuals (phone immersive stage, strip, drag-to-dismiss,
// Hero route). Pure presentation: the host owns items, loading, sessions and
// sharing (docs/media-playback.md "Media browser").

/// Command-key helper of the media browser's keyboard map: Cmd on Apple
/// platforms, Ctrl elsewhere (Esc, Ctrl+W and Cmd+W stay bound on both, Web).
abstract final class RaftPlatformKeys {
  static bool get apple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// `Cmd+key` on macOS / iOS, `Ctrl+key` on every other platform.
  static SingleActivator command(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: apple, control: !apple);
}

/// Distance the stage follows the finger for a full scrim fade / 0.82 scale.
const raftMediaDismissDistance = 260.0;

/// Release past this offset (dp) or velocity (dp/s) closes the browser.
const raftMediaDismissOffset = 120.0;
const raftMediaDismissVelocity = 700.0;

/// Final scale of the stage at [raftMediaDismissDistance].
const raftMediaDismissScale = 0.82;

/// Height of the phone top bar below the status bar, and its touch targets.
const raftMediaTopBarRow = 56.0;
const raftMediaChromeTarget = 44.0;

/// Phone strip: 44 dp thumbnails in a [raftMediaStripBand] tall band.
const raftMediaPhoneThumb = 44.0;
const raftMediaStripBand = 56.0;

/// Desktop strip (`size-12` thumbnails, `bottom-4`, room above): the band the
/// stage keeps free above and below its centre line.
const raftMediaDesktopThumb = 48.0;
const raftMediaDesktopStripBand = 48.0 + 16 + 8;

/// Two caption lines (13 / 1.35) plus the shell's padding.
const raftMediaCaptionHeight = 62.0;

/// The collapsed caption band: two lines at the current text size (capped at
/// a third of the screen so the picture keeps most of it).
double _captionHeight(BuildContext context) => math.min(
  RaftScaled.extent(context, raftMediaCaptionHeight - 12, fontSize: 13) + 12,
  math.max(raftMediaCaptionHeight, MediaQuery.sizeOf(context).height / 3),
);

String raftMediaDuration(Duration value) {
  final seconds = value.inSeconds;
  final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

// ---------------------------------------------------------------- route

/// Route of the media browser: transparent (the shell paints its own scrim,
/// the Hero flies the picture), so the page below shows through while the
/// scrim is not yet black and while a drag-to-dismiss fades it. Once the open
/// transition ends it turns opaque (the page below stops painting); a drag
/// makes it see-through again ([setTranslucent]).
///
/// Timing comes from [RaftMediaMotionTokens]: [transitionDuration] open,
/// [reverseTransitionDuration] close. [scrim] is the picture's own progress
/// (the Hero flies on exactly this curve), so scrim and picture stay in step.
/// A [staged] route (the phone shell) paints nothing itself: the shell reads
/// [scrim] and [stage] and brings the chrome in after the flight. Otherwise
/// the whole page fades with [scrim].
class RaftMediaBrowserRoute<T> extends PageRoute<T>
    implements RaftPreviewRoute {
  RaftMediaBrowserRoute({
    required this.builder,
    this.reducedMotion = false,
    this.staged = false,
    super.settings,
  });
  final WidgetBuilder builder;

  /// Reduced motion: an 80 ms cross-fade, no Hero (the host leaves it out).
  final bool reducedMotion;

  /// The shell stages the transition (scrim, stage and chrome) itself.
  final bool staged;

  /// Whether the shell stages this route's transition.
  bool get stagedTransition => staged && !reducedMotion;

  /// The browser route enclosing [context], if there is one.
  static RaftMediaBrowserRoute<dynamic>? maybeOf(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is RaftMediaBrowserRoute ? route : null;
  }

  CurvedAnimation? _scrim, _stage;

  /// 0 at the card, 1 at the stage: the picture's progress. The Hero of the
  /// route flies on the same curves (see [RaftMediaHero]).
  Animation<double> get scrim => _scrim ??= CurvedAnimation(
    parent: animation!,
    curve: RaftMediaMotionTokens.openCurve,
    reverseCurve: RaftMediaMotionTokens.closeCurve.flipped,
  );

  /// The stage's own fade, over the first [RaftMediaMotionTokens.stageFadeUntil]
  /// of the open and the last of the close. The picture flies over it; it shows
  /// when there is no card to fly from.
  Animation<double> get stage => _stage ??= CurvedAnimation(
    parent: animation!,
    curve: const Interval(0, RaftMediaMotionTokens.stageFadeUntil),
    reverseCurve: const Interval(1 - RaftMediaMotionTokens.stageFadeUntil, 1),
  );

  @override
  void dispose() {
    _scrim?.dispose();
    _stage?.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => reducedMotion
      ? RaftMediaMotionTokens.reducedDuration
      : RaftMediaMotionTokens.openDuration;

  @override
  Duration get reverseTransitionDuration => reducedMotion
      ? RaftMediaMotionTokens.reducedDuration
      : RaftMediaMotionTokens.closeDuration;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  /// While true the page below is built and painted even at rest (the scrim
  /// of a drag-to-dismiss fades over it).
  void setTranslucent(bool value) {
    final entries = overlayEntries;
    if (entries.isEmpty) return;
    entries.first.opaque = !value && (animation?.isCompleted ?? false);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    // Text outside a Material falls back to the debug underline style.
    child: Material(type: MaterialType.transparency, child: builder(context)),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (stagedTransition) return child;
    return FadeTransition(
      opacity: reducedMotion ? animation : scrim,
      child: child,
    );
  }
}

// ----------------------------------------------------------------- hero

/// A straight-line rect tween (Flutter's default under a `MaterialApp` is an
/// arc) whose end follows the destination's live bounds: whatever the layout
/// does during the flight (a bar measured after the first frame, the decoded
/// size, a list that scrolls), the picture lands on the box that is there.
class _StraightRectTween extends RectTween {
  _StraightRectTween({super.begin, super.end, this.live});
  final Rect? Function()? live;

  @override
  Rect? transform(double t) {
    final from = begin;
    final to = live?.call() ?? end;
    if (from == null || to == null) return super.transform(t);
    return Rect.fromLTRB(
      _lerp(from.left, to.left, t),
      _lerp(from.top, to.top, t),
      _lerp(from.right, to.right, t),
      _lerp(from.bottom, to.bottom, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// The picture that flies between a message card and the browser stage.
///
/// The flight is a straight line on the curves of [RaftMediaMotionTokens]. The
/// shuttle shows [image] in the interpolated rect and animates the CROP, not
/// the picture's shape: it starts as exactly what the card paints (the card's
/// [fit], bitmap size from the resolved image, never server metadata), ends
/// as exactly what the stage paints, and the corners round from [radius] to
/// square on the same progress. Telegram's clip animation, not a stretch.
///
/// Put it on both ends of the flight. The card end stays mounted and is
/// switched on with [enabled] (a [HeroMode], so the card's picture is never
/// rebuilt for the flight); the stage end is ONE element from the thumbnail
/// stand-in to the loaded original.
class RaftMediaHero extends StatefulWidget {
  const RaftMediaHero({
    super.key,
    required this.tag,
    required this.child,
    this.image,
    this.radius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.enabled = true,
  });
  final Object tag;
  final Widget child;

  /// The bitmap of the shuttle; without it the hero child is used as is.
  final ImageProvider? image;

  /// The corner radius of this end of the flight (the card's; the stage is
  /// square).
  final BorderRadius radius;

  /// How this end paints [image] in its box: the card's fit (cover for a tile,
  /// contain for a lone picture), contain on the stage.
  final BoxFit fit;

  /// Whether this end takes part in flights.
  final bool enabled;

  @override
  State<RaftMediaHero> createState() => _RaftMediaHeroState();
}

class _RaftMediaHeroState extends State<RaftMediaHero> {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  /// This end's bounds as Flutter measures a hero (in the route's space).
  Rect? _liveBounds() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(_route?.subtreeContext?.findRenderObject()),
      Offset.zero & box.size,
    );
    return rect.isFinite ? rect : null;
  }

  RectTween _rectTween(Rect? begin, Rect? end) =>
      _StraightRectTween(begin: begin, end: end, live: _liveBounds);

  Widget _shuttle(
    BuildContext flight,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext from,
    BuildContext to,
  ) {
    final push = direction == HeroFlightDirection.push;
    return _MediaHeroShuttle(
      image: widget.image!,
      animation: animation,
      card: push ? from : to,
      stage: push ? to : from,
    );
  }

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: widget.enabled,
    child: Hero(
      tag: widget.tag,
      createRectTween: _rectTween,
      curve: RaftMediaMotionTokens.openCurve,
      // Closing runs `closeCurve` forward in time: Flutter plays the reverse
      // of a route animation through the flipped curve.
      reverseCurve: RaftMediaMotionTokens.closeCurve.flipped,
      flightShuttleBuilder: widget.image == null ? null : _shuttle,
      child: widget.child,
    ),
  );
}

/// The flying picture. [animation] is 0 at the card and 1 at the stage in
/// both directions.
class _MediaHeroShuttle extends StatefulWidget {
  const _MediaHeroShuttle({
    required this.image,
    required this.animation,
    required this.card,
    required this.stage,
  });
  final ImageProvider image;
  final Animation<double> animation;

  /// The hero contexts of the card end and of the stage end.
  final BuildContext card, stage;

  @override
  State<_MediaHeroShuttle> createState() => _MediaHeroShuttleState();
}

class _MediaHeroShuttleState extends State<_MediaHeroShuttle> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _bitmap;

  /// The card's end settings, read once: the card can be rebuilt meanwhile.
  late final RaftMediaHero? _cardEnd = widget.card.mounted
      ? widget.card.findAncestorWidgetOfExactType<RaftMediaHero>()
      : null;
  late final RaftMediaHero? _stageEnd = widget.stage.mounted
      ? widget.stage.findAncestorWidgetOfExactType<RaftMediaHero>()
      : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _unwatch();
    final listener = ImageStreamListener((info, synchronous) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      // The stream hands every listener its own clone; only the size is kept.
      info.dispose();
      if (_bitmap == size) return;
      _bitmap = size;
      if (!synchronous && mounted) setState(() {});
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _unwatch() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unwatch();
    super.dispose();
  }

  /// What an end paints its bitmap at inside [box].
  static double _scale(Size bitmap, Size box, BoxFit fit) {
    final w = box.width / bitmap.width, h = box.height / bitmap.height;
    return fit == BoxFit.contain || fit == BoxFit.scaleDown
        ? math.min(w, h)
        : math.max(w, h);
  }

  /// The end's box as it looks on screen (the stage end may be zoomed or
  /// dragged: its layout size is not what the finger sees).
  static Size? _visibleSize(BuildContext hero) {
    if (!hero.mounted) return null;
    final box = hero.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final ancestor = Navigator.maybeOf(hero)?.context.findRenderObject();
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
    return rect.isFinite ? rect.size : null;
  }

  Size? _cardBox, _stageBox;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.animation,
    builder: (context, _) {
      final t = widget.animation.value;
      // The card never changes size during a flight; the stage end can.
      _cardBox ??= _visibleSize(widget.card);
      _stageBox = _visibleSize(widget.stage) ?? _stageBox;
      final cardBox = _cardBox, stageBox = _stageBox, bitmap = _bitmap;
      final radius = _cardEnd?.radius ?? BorderRadius.zero;
      return ClipRRect(
        key: const ValueKey('media-hero-shuttle'),
        borderRadius: BorderRadius.lerp(radius, BorderRadius.zero, t)!,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (bitmap == null ||
                bitmap.isEmpty ||
                cardBox == null ||
                stageBox == null) {
              // The bitmap or a box is not known yet: fill the flight rect.
              return _picture(null, constraints.biggest);
            }
            final fromCard = _scale(
              bitmap,
              cardBox,
              _cardEnd?.fit ?? BoxFit.cover,
            );
            final toStage = _scale(
              bitmap,
              stageBox,
              _stageEnd?.fit ?? BoxFit.contain,
            );
            final scale = fromCard + (toStage - fromCard) * t;
            return _picture(
              Size(bitmap.width * scale, bitmap.height * scale),
              constraints.biggest,
            );
          },
        ),
      );
    },
  );

  /// The picture at [size] centred in the clip ([clip] when null: cover).
  Widget _picture(Size? size, Size clip) {
    // ignore: raft_lints/avoid_raw_image_decode -- The shuttle paints the host's already decoded card / stage bitmap.
    final image = Image(
      key: const ValueKey('media-hero-shuttle-picture'),
      image: widget.image,
      width: size?.width,
      height: size?.height,
      fit: size == null ? BoxFit.cover : BoxFit.fill,
      gaplessPlayback: true,
    );
    if (size == null) return image;
    return OverflowBox(
      minWidth: 0,
      minHeight: 0,
      maxWidth: size.width,
      maxHeight: size.height,
      child: image,
    );
  }
}

// ---------------------------------------------------------------- strip

/// One thumbnail of [RaftMediaStrip]. Videos carry a play badge with their
/// duration so they are recognisable at 44 dp.
@immutable
class RaftMediaStripItem {
  const RaftMediaStripItem({
    required this.label,
    this.thumbnail,
    this.video = false,
    this.duration,
  });

  /// Semantics label, already localized ("Image 3 of 9").
  final String label;
  final ImageProvider? thumbnail;
  final bool video;
  final Duration? duration;
}

/// The scrollable thumbnail strip: drag or wheel scrolls it, the active item
/// is centred and ringed, a few items stay centred as a group. Thumbnails are
/// built lazily.
class RaftMediaStrip extends StatefulWidget {
  const RaftMediaStrip({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    this.compact = false,
  });
  final List<RaftMediaStripItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  /// Phone strip: 44 dp thumbnails filling a [raftMediaStripBand] band.
  /// Otherwise the Web strip: `size-12` thumbnails, 16 dp above the bottom.
  final bool compact;

  @override
  State<RaftMediaStrip> createState() => _RaftMediaStripState();
}

class _RaftMediaStripState extends State<RaftMediaStrip> {
  static const _gap = 6.0;
  ScrollController? _scroll;
  double _viewport = 0;

  double get _thumb =>
      widget.compact ? raftMediaPhoneThumb : raftMediaDesktopThumb;

  /// Room around the thumbnails for the active one's shadow.
  double get _pad => widget.compact ? 6 : 8;
  double get _pitch => _thumb + _gap;
  double get _total => widget.items.length * _pitch - _gap;

  /// Offset that centres item [i] in a [viewport] wide strip.
  double _offsetFor(int i, double viewport) {
    final target = _pad + i * _pitch + _thumb / 2 - viewport / 2;
    final max = math.max(0.0, _total + 2 * _pad - viewport);
    return target.clamp(0.0, max);
  }

  @override
  void didUpdateWidget(RaftMediaStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _reveal();
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _reveal() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = _scroll;
      if (!mounted || scroll == null || !scroll.hasClients) return;
      final offset = _offsetFor(widget.index, _viewport);
      if (reduce) {
        scroll.jumpTo(offset);
      } else {
        unawaited(
          scroll.animateTo(
            offset,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  /// Mouse wheel over the strip scrolls it sideways (a plain vertical wheel
  /// included) instead of reaching the stage underneath.
  void _wheel(PointerSignalEvent event) {
    final scroll = _scroll;
    if (event is! PointerScrollEvent || scroll == null || !scroll.hasClients) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final delta = (e as PointerScrollEvent).scrollDelta;
      final position = scroll.position;
      scroll.jumpTo(
        (position.pixels + (delta.dx != 0 ? delta.dx : delta.dy)).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // Fixed-size thumbnails are chrome: their labels stay within the bound.
    return RaftChrome(child: _strip(context, t));
  }

  Widget _strip(BuildContext context, RaftTokens t) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.compact ? 0 : 16 - _pad),
        child: Listener(
          onPointerSignal: _wheel,
          child: SizedBox(
            key: const ValueKey('lightbox-thumbnails'),
            height: _thumb + 2 * _pad,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewport = constraints.maxWidth;
                final scrolls = _total + 2 * _pad > _viewport;
                final side = scrolls ? _pad : (_viewport - _total) / 2;
                _scroll ??= ScrollController(
                  initialScrollOffset: _offsetFor(widget.index, _viewport),
                );
                final list = ListView.separated(
                  key: const ValueKey('lightbox-thumbnail-scroll'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: side,
                    vertical: _pad,
                  ),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) => _thumbAt(context, t, i),
                );
                if (!scrolls) return list;
                // The edge fade says "there is more".
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: [
                      Color(0x00000000),
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0x00000000),
                    ],
                    stops: [0, .05, .95, 1],
                  ).createShader(r),
                  child: list,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbAt(BuildContext context, RaftTokens t, int i) {
    final item = widget.items[i];
    final active = i == widget.index;
    final border = active
        ? (t.brutal ? t.product.softSignal : t.colors['accent-strong']!)
        : Colors.white.withValues(alpha: .3);
    final image = item.thumbnail;
    final thumb = _thumb;
    Widget box = Container(
      width: thumb,
      height: thumb,
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 2),
        boxShadow: !active
            ? null
            : t.brutal
            ? RaftShadowSet.brutalSm
            : t.themeShadows.sm.outer,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            // ignore: raft_lints/avoid_raw_image_decode -- Thumbnail strip reuses the already-decoded bitmaps of the message attachments (OneFrame bitmap providers, nothing left to resize).
            Image(image: image, fit: BoxFit.cover)
          else
            ColoredBox(
              color: Colors.white.withValues(alpha: .2),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: t.headingFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .5),
                  ),
                ),
              ),
            ),
          if (item.video)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 15,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .62),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const RaftIcon(
                        RaftGlyph.play,
                        size: 8,
                        color: Colors.white,
                        filled: true,
                      ),
                      if (item.duration != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          raftMediaDuration(item.duration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!active) box = Opacity(opacity: widget.compact ? .72 : .6, child: box);
    return RaftInteractive(
      key: ValueKey('lightbox-thumbnail-$i'),
      onPressed: () => widget.onSelect(i),
      semanticLabel: item.label,
      selected: active,
      builder: (_, _) => ExcludeSemantics(child: box),
    );
  }
}

// ------------------------------------------------------------ chrome bits

/// A phone chrome action (Share, More, Download): glyph, semantics label and
/// a press handler that receives the button's global rect (menus anchor to it).
@immutable
class RaftMediaAction {
  const RaftMediaAction({
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.id,
  });
  final RaftGlyph glyph;
  final String label;
  final ValueChanged<Rect> onPressed;
  final Key? id;
}

/// Round (elegant) or boxed (brutal) icon button of the immersive chrome;
/// the touch target is 44 dp.
class RaftMediaChromeButton extends StatelessWidget {
  const RaftMediaChromeButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
  });
  final RaftGlyph glyph;
  final String label;
  final ValueChanged<Rect> onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    void press() {
      final box = context.findRenderObject();
      onPressed(
        box is RenderBox && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.zero,
      );
    }

    // Fixed chrome: at large text sizes a long press shows the action large.
    return RaftChrome(
      child: RaftLargeContentViewer(
        label: label,
        onActivate: press,
        iconBuilder: (context, size) =>
            RaftIcon(glyph, size: size, color: IconTheme.of(context).color),
        child: _button(t, press),
      ),
    );
  }

  Widget _button(RaftTokens t, VoidCallback press) {
    return RaftInteractive(
      semanticLabel: label,
      onPressed: press,
      builder: (_, state) => SizedBox.square(
        dimension: raftMediaChromeTarget,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: t.brutal
                ? BoxDecoration(
                    color: Colors.white,
                    border: Border.all(width: 2),
                    boxShadow: RaftShadowSet.brutalSm,
                  )
                : BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: state.pressed ? .62 : .42,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
            child: RaftIcon(
              glyph,
              size: 18,
              color: t.brutal ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- dismiss

/// Drag-down-to-dismiss of the stage (touch only): the stage follows the
/// finger and shrinks to 0.82 at 260 dp, [progress] (0..1) drives the scrim
/// and chrome fade. Released past 120 dp or 700 dp/s it calls [onDismiss],
/// otherwise it springs back in 200 ms. Disabled (zoomed, a video seek rail,
/// desktop) the stage is left alone.
class RaftMediaDismissible extends StatefulWidget {
  const RaftMediaDismissible({
    super.key,
    required this.enabled,
    required this.onDismiss,
    required this.progress,
    required this.child,
    this.onDragChanged,
  });
  final bool enabled;
  final VoidCallback onDismiss;
  final ValueNotifier<double> progress;

  /// A drag began (true) or ended, sprung back or was handed to [onDismiss]
  /// (false): a native video view gets out of the way while it runs.
  final ValueChanged<bool>? onDragChanged;
  final Widget child;

  @override
  State<RaftMediaDismissible> createState() => _RaftMediaDismissibleState();
}

class _RaftMediaDismissibleState extends State<RaftMediaDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  double _dy = 0;

  /// Fingers down: a second one is a pinch, which never moves the stage.
  int _pointers = 0;

  /// Offset the spring-back started from.
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _spring.addListener(
      () => _set(_from * (1 - Curves.easeOut.transform(_spring.value))),
    );
  }

  void _set(double value) {
    _dy = value;
    widget.progress.value = (value / raftMediaDismissDistance).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    _spring.stop();
    widget.onDragChanged?.call(true);
    RaftMediaBrowserRoute.maybeOf(context)?.setTranslucent(true);
  }

  void _update(DragUpdateDetails details) {
    if (_pointers > 1) return;
    _set(math.max(0, _dy + details.delta.dy));
  }

  void _end(DragEndDetails details) {
    if (_pointers <= 1 &&
        (_dy > raftMediaDismissOffset ||
            details.velocity.pixelsPerSecond.dy > raftMediaDismissVelocity)) {
      widget.onDismiss();
      return;
    }
    _release();
  }

  void _release() {
    _from = _dy;
    unawaited(
      _spring.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        _set(0);
        widget.onDragChanged?.call(false);
        RaftMediaBrowserRoute.maybeOf(context)?.setTranslucent(false);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _pointers++,
      onPointerUp: (_) => _pointers = math.max(0, _pointers - 1),
      onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
      child: RawGestureDetector(
        key: const ValueKey('media-dismiss'),
        behavior: HitTestBehavior.translucent,
        gestures: {
          if (widget.enabled)
            VerticalDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  VerticalDragGestureRecognizer
                >(
                  () => VerticalDragGestureRecognizer(
                    supportedDevices: const {PointerDeviceKind.touch},
                  ),
                  (recognizer) => recognizer
                    ..onStart = _start
                    ..onUpdate = _update
                    ..onEnd = _end
                    ..onCancel = _release,
                ),
        },
        child: ValueListenableBuilder<double>(
          valueListenable: widget.progress,
          builder: (context, progress, child) => Transform.translate(
            offset: Offset(0, _dy),
            child: Transform.scale(
              scale: reduced ? 1 : 1 - (1 - raftMediaDismissScale) * progress,
              child: child,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shell

/// Phone media browser (page route): a black stage edge to edge under the
/// system bars, with two chrome layers that fade together on a tap (the host
/// owns [chrome]): the top bar (back, title and sub-line, counter, actions)
/// and the bottom band (optional caption, then the strip). Landscape drops the
/// bottom band. The stage reports what the bars cover
/// ([RaftMediaChromeInsets]): an image fits between the top bar and the bottom
/// band while the chrome shows and fills the stage while it is hidden, gliding
/// between the two.
class RaftMediaImmersiveShell extends StatefulWidget {
  const RaftMediaImmersiveShell({
    super.key,
    required this.title,
    required this.chrome,
    required this.onClose,
    required this.child,
    this.subtitle,
    this.counter,
    this.actions = const [],
    this.strip,
    this.caption,
    this.shortcuts = const {},
    this.dismissEnabled = true,
    this.onDismissDrag,
    this.backLabel = 'Back',
  });
  final String title;
  final String? subtitle;

  /// Chrome visibility; a screen reader keeps it on regardless.
  final ValueListenable<bool> chrome;
  final VoidCallback onClose;
  final Widget? counter;
  final List<RaftMediaAction> actions;
  final Widget? strip;
  final String? caption;
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  /// Whether the drag-down gesture may start (off while zoomed).
  final bool dismissEnabled;

  /// A drag-to-dismiss began or ended (see [RaftMediaDismissible.onDragChanged]).
  final ValueChanged<bool>? onDismissDrag;
  final String backLabel;
  final Widget child;

  @override
  State<RaftMediaImmersiveShell> createState() =>
      _RaftMediaImmersiveShellState();
}

class _RaftMediaImmersiveShellState extends State<RaftMediaImmersiveShell> {
  /// Drag-to-dismiss progress (0..1): fades the scrim and the chrome.
  final progress = ValueNotifier<double>(0);

  /// Where the route's open / close transition is: the chrome waits for the
  /// picture to land and is gone when a close starts.
  late final phase = ValueNotifier<_Flight>(_Flight.settled);

  /// The route when it leaves the transition to this shell; null otherwise
  /// (a shell mounted without one, reduced motion, a wide layout).
  RaftMediaBrowserRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final found = RaftMediaBrowserRoute.maybeOf(context);
    final next = found?.stagedTransition == true ? found : null;
    if (!identical(next, _route)) {
      _unwatchRoute();
      _route = next;
      next?.animation?.addListener(_syncPhase);
      next?.animation?.addStatusListener(_syncPhaseStatus);
    }
    _syncPhase();
  }

  void _unwatchRoute() {
    _route?.animation?.removeListener(_syncPhase);
    _route?.animation?.removeStatusListener(_syncPhaseStatus);
  }

  void _syncPhaseStatus(AnimationStatus _) => _syncPhase();

  void _syncPhase() {
    final animation = _route?.animation;
    phase.value = animation == null
        ? _Flight.settled
        // The route's first frame is built off stage while the Hero measures,
        // and then reports a finished animation: that is the start, not the end.
        : _route!.offstage
        ? _Flight.entering
        : switch (animation.status) {
            AnimationStatus.reverse => _Flight.leaving,
            AnimationStatus.completed => _Flight.settled,
            AnimationStatus.forward =>
              animation.value >= RaftMediaMotionTokens.chromeRevealAt
                  ? _Flight.settled
                  : _Flight.entering,
            AnimationStatus.dismissed => _Flight.entering,
          };
  }

  /// The top bar's and the bottom band's rendered extents (the bar grows with
  /// wrapped text at large sizes); null until laid out.
  double? _barExtent, _contentExtent;

  void _measured({double? bar, double? content}) {
    if ((bar == null || bar == _barExtent) &&
        (content == null || content == _contentExtent)) {
      return;
    }
    // A layout change arrives during the frame: rebuild after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _barExtent = bar ?? _barExtent;
        _contentExtent = content ?? _contentExtent;
      });
    });
  }

  @override
  void dispose() {
    _unwatchRoute();
    progress.dispose();
    phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final safe = media.padding;
    final topBar = raftMediaTopBarRow + safe.top;
    final hasStrip = widget.strip != null && !landscape;
    final hasCaption = widget.caption != null && !landscape;
    // Where the visible part of the bottom band starts: the caption and the
    // strip stack above 8 dp and the system bar (the gradient above them is
    // only a fade, the picture may run under it). The caption is two lines at
    // the current text size; the rendered band replaces this estimate once laid
    // out (an expanded caption, a wrapped line).
    final bottomBand = hasCaption || hasStrip
        ? safe.bottom +
              8 +
              (hasCaption ? _captionHeight(context) : 0) +
              (hasStrip ? raftMediaStripBand : 0)
        : safe.bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
          ...widget.shortcuts,
        },
        child: Focus(
          autofocus: true,
          child: _stack(
            context,
            safe: safe,
            topBar: topBar,
            bottomBand: bottomBand,
            hasStrip: hasStrip,
            hasCaption: hasCaption,
          ),
        ),
      ),
    );
  }

  Widget _stack(
    BuildContext context, {
    required EdgeInsets safe,
    required double topBar,
    required double bottomBand,
    required bool hasStrip,
    required bool hasCaption,
  }) {
    final t = RaftTokens.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final alwaysShown = MediaQuery.accessibleNavigationOf(context);
    Widget layer(Widget Function(BuildContext) build) => _ChromeBuilder(
      chrome: widget.chrome,
      drag: progress,
      phase: phase,
      builder: (context, shown, drag, flight) {
        // The bars wait for the picture to land and are gone as a close starts.
        final visible = (shown || alwaysShown) && flight == _Flight.settled;
        final fade = reduced
            ? Duration.zero
            : flight == _Flight.leaving
            ? RaftMediaMotionTokens.chromeFadeOut
            : raftMediaChromeFade;
        // The chrome is gone within the first 40 dp of a drag.
        final dragFade = 1 - (drag * raftMediaDismissDistance / 40).clamp(0, 1);
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            duration: fade,
            opacity: visible ? dragFade.toDouble() : 0,
            child: ExcludeSemantics(excluding: !visible, child: build(context)),
          ),
        );
      },
    );

    final top = layer((context) {
      // The bar is fixed chrome (bounded text, Large Content Viewer); its
      // title and sender line wrap and the bar grows above the default size.
      final grows = RaftScaled.grows(context);
      final rule = t.brutal
          ? const Border(bottom: BorderSide(color: Colors.white, width: 2))
          : null;
      final barHeight = topBar + (t.brutal ? 2 : 0);
      final row = Container(
        height: grows ? null : barHeight,
        constraints: grows ? BoxConstraints(minHeight: barHeight) : null,
        padding: EdgeInsets.fromLTRB(
          4 + safe.left,
          safe.top,
          4 + safe.right,
          0,
        ),
        child: Row(
          children: [
            RaftMediaChromeButton(
              glyph: RaftGlyph.chevronLeft,
              label: raftText(context, widget.backLabel),
              onPressed: (_) => widget.onClose(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: grows ? null : 1,
                    overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.headingFont,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      maxLines: grows ? null : 1,
                      overflow: grows
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.bodyFont,
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.counter != null) ...[
              const SizedBox(width: 6),
              widget.counter!,
            ],
            for (final action in widget.actions)
              RaftMediaChromeButton(
                key: action.id,
                glyph: action.glyph,
                label: raftText(context, action.label),
                onPressed: action.onPressed,
              ),
          ],
        ),
      );
      // The backdrop never takes a tap (see the bottom band).
      final bar = Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: t.brutal
                    ? BoxDecoration(color: Colors.black, border: rule)
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: .8),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          row,
        ],
      );
      return _ReportSize(
        onSize: (size) => _measured(bar: size.height),
        child: RaftChrome(child: RaftLargeContentScope(child: bar)),
      );
    });

    final bottom = layer((context) {
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCaption) _MediaCaption(text: widget.caption!),
          if (hasStrip)
            SizedBox(height: raftMediaStripBand, child: widget.strip!),
        ],
      );
      // The band's backdrop (gradient / rule) never takes a tap: a tap on the
      // picture under it still toggles the chrome; only the caption and the
      // strip answer to their own taps.
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: t.brutal
                    ? const BoxDecoration(
                        color: Colors.black,
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 2),
                        ),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: .78),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              safe.left,
              t.brutal ? 6 : 12,
              safe.right,
              safe.bottom + 8,
            ),
            child: _ReportSize(
              onSize: (size) => _measured(content: size.height),
              child: content,
            ),
          ),
        ],
      );
    });

    // The scrim follows the picture (the route's own progress) and the finger.
    final scrim = _route?.scrim;
    final stageFade = _route?.stage;
    Widget stage(Widget child) => stageFade == null
        ? child
        : FadeTransition(opacity: stageFade, child: child);
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, drag, _) => scrim == null
              ? ColoredBox(
                  key: const ValueKey('media-scrim'),
                  color: Colors.black.withValues(alpha: 1 - drag),
                )
              : AnimatedBuilder(
                  animation: scrim,
                  builder: (_, _) => ColoredBox(
                    key: const ValueKey('media-scrim'),
                    color: Colors.black.withValues(
                      alpha: (1 - drag) * scrim.value,
                    ),
                  ),
                ),
        ),
        Positioned.fill(
          child: stage(
            RaftMediaDismissible(
              enabled: widget.dismissEnabled,
              progress: progress,
              onDismiss: widget.onClose,
              onDragChanged: widget.onDismissDrag,
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.chrome,
                builder: (context, shown, child) {
                  // A screen reader keeps the chrome on, and so the room for it.
                  final visible = shown || alwaysShown;
                  // Measured when it has been laid out, the estimate before.
                  final bar = _barExtent ?? topBar;
                  final band = _contentExtent == null
                      ? bottomBand
                      : (hasCaption || hasStrip)
                      ? safe.bottom + 8 + _contentExtent!
                      : safe.bottom;
                  return RaftMediaChromeInsets(
                    visible: visible,
                    top: visible ? bar : safe.top,
                    bottom: visible ? band : safe.bottom,
                    child: child!,
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, top: 0, child: top),
        Positioned(left: 0, right: 0, bottom: 0, child: bottom),
      ],
    );
  }
}

/// Reports the laid-out size of [child] (after the frame) whenever it changes.
class _ReportSize extends StatefulWidget {
  const _ReportSize({required this.onSize, required this.child});
  final ValueChanged<Size> onSize;
  final Widget child;
  @override
  State<_ReportSize> createState() => _ReportSizeState();
}

class _ReportSizeState extends State<_ReportSize> {
  Size? _last;

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size == _last) return;
    _last = box.size;
    widget.onSize(box.size);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _report());
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

/// What the phone chrome covers at the stage's top and bottom edge right now:
/// the bars while they show ([visible]), the system insets while they do not.
/// An image page fits (and pans) in the room between them ([imageRoom]); a page
/// that fills the whole stage (a video) keeps its own controls clear of it.
class RaftMediaChromeInsets extends InheritedWidget {
  const RaftMediaChromeInsets({
    super.key,
    required this.top,
    required this.bottom,
    required this.visible,
    required super.child,
  });
  final double top, bottom;

  /// The top bar and the bottom band are on screen.
  final bool visible;

  /// The edges an image keeps clear of: the bars while they show, the system
  /// bars alone (the room between them) while the chrome is hidden.
  EdgeInsets get imageRoom => EdgeInsets.only(top: top, bottom: bottom);

  static RaftMediaChromeInsets? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftMediaChromeInsets>();

  @override
  bool updateShouldNotify(RaftMediaChromeInsets old) =>
      top != old.top || bottom != old.bottom || visible != old.visible;
}

/// Where the route's open / close transition is, as far as the chrome cares.
enum _Flight {
  /// The picture is still leaving the card: the bars wait.
  entering,

  /// The picture has (almost) landed, or there is no transition: bars as the
  /// chrome flag says.
  settled,

  /// A close started: the bars are gone at once.
  leaving,
}

/// Rebuilds from the chrome flag, the drag progress and the flight phase.
class _ChromeBuilder extends StatelessWidget {
  const _ChromeBuilder({
    required this.chrome,
    required this.drag,
    required this.phase,
    required this.builder,
  });
  final ValueListenable<bool> chrome;
  final ValueListenable<double> drag;
  final ValueListenable<_Flight> phase;
  final Widget Function(BuildContext, bool, double, _Flight) builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([chrome, drag, phase]),
    builder: (context, _) =>
        builder(context, chrome.value, drag.value, phase.value),
  );
}

class _MediaCaption extends StatefulWidget {
  const _MediaCaption({required this.text});
  final String text;
  @override
  State<_MediaCaption> createState() => _MediaCaptionState();
}

class _MediaCaptionState extends State<_MediaCaption> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Semantics(
      container: true,
      label: widget.text,
      child: GestureDetector(
        key: const ValueKey('media-caption'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: SizedBox(
            height: expanded ? null : _captionHeight(context) - 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: expanded ? 200 : _captionHeight(context) - 12,
              ),
              child: SingleChildScrollView(
                physics: expanded
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Text(
                  widget.text,
                  maxLines: expanded ? null : 2,
                  // An ellipsis without a line limit lays out as ONE line
                  // (the engine's rule): expanded text only clips (scrolls).
                  overflow: expanded
                      ? TextOverflow.clip
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: t.bodyFont,
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
