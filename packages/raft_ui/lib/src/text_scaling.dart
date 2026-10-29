// Central text scaling policy (Apple's Dynamic Type model).
//
// Content text (messages, documents, lists, inputs, dialogs) follows the system
// text size without a cap, and larger styles grow less than small ones: iOS
// body 17pt reaches 53pt at the largest accessibility size (3.1x) while a 34pt
// large title reaches 60pt (1.8x). Fixed chrome (tab bars, channel tabs,
// badges) is bounded at [RaftTextScaling.chromeMaxScale] and offers the Large
// Content Viewer instead (long-press shows the item large, see
// large_content_viewer.dart).
//
// Everything reads `MediaQuery.textScalerOf(context).scale(fontSize)`; this file
// is the only place that decides what that returns.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// Dynamic Type sizes in points. Rows are the style's size at the default
/// "Large" category (the key of [_appleSizes]); columns are xSmall, Small,
/// Medium, Large, xLarge, xxLarge, xxxLarge and Accessibility 1 to 5 (Apple
/// Human Interface Guidelines, iOS Dynamic Type sizes).
const _appleSizes = <int, List<int>>{
  11: [11, 11, 11, 11, 12, 14, 15, 19, 23, 27, 32, 37],
  12: [11, 11, 11, 12, 14, 15, 17, 21, 25, 30, 35, 40],
  13: [12, 12, 12, 13, 15, 17, 19, 23, 27, 33, 38, 44],
  15: [12, 13, 14, 15, 17, 19, 21, 25, 30, 36, 42, 49],
  16: [13, 14, 15, 16, 18, 20, 22, 26, 32, 38, 44, 51],
  17: [14, 15, 16, 17, 19, 21, 23, 28, 33, 40, 47, 53],
  20: [17, 18, 19, 20, 22, 24, 26, 31, 37, 43, 49, 55],
  22: [19, 20, 21, 22, 24, 26, 28, 34, 39, 44, 50, 56],
  28: [25, 26, 27, 28, 30, 32, 34, 38, 43, 48, 53, 58],
  34: [31, 32, 33, 34, 36, 38, 40, 44, 48, 52, 56, 60],
};

/// The system (body) scale factor of each Dynamic Type category: the body row
/// of [_appleSizes] over 17.
final _bodyFactors = [for (final s in _appleSizes[17]!) s / 17];
final _anchors = _appleSizes.keys.toList();

/// First category that is an accessibility size (Accessibility 1).
const _firstAccessibilityCategory = 7;

/// A `TextScaler` that applies Apple's per-size curve to a linear platform
/// scaler and passes a nonlinear platform scaler (Android 14+) through.
///
/// [scale] is monotonic in the font size, 1.0 at the default text size, and
/// never smaller than the platform scale for the body size.
@immutable
final class RaftTextScaler extends TextScaler {
  /// The content scaler for [platform], the scaler Flutter got from the OS.
  RaftTextScaler(this.platform) : _linearFactor = _linearFactorOf(platform);

  /// The scaler the operating system provided.
  final TextScaler platform;

  /// The OS factor when [platform] is linear, otherwise null.
  final double? _linearFactor;

  /// Whether the Apple curve is applied (the platform scaler is linear).
  bool get appliesCurve => _linearFactor != null;

  static double? _linearFactorOf(TextScaler s) {
    final small = s.scale(10) / 10;
    final large = s.scale(34) / 34;
    if ((small - large).abs() > 1e-3) return null;
    return s.scale(17) / 17;
  }

  /// Scale of a [fontSize] at OS factor [factor] on the Apple curve.
  static double scaleLinearFactor(double factor, double fontSize) {
    if (factor <= 1.0 || fontSize <= 0) return fontSize * factor;
    final overshoot = factor > _bodyFactors.last
        ? factor / _bodyFactors.last
        : 1.0;
    return _scaled(fontSize, _category(factor)) * overshoot;
  }

  /// Position in the category table (fractional index) of OS factor [factor].
  static double _category(double factor) {
    final last = _bodyFactors.length - 1;
    if (factor >= _bodyFactors[last]) return last.toDouble();
    for (var i = 0; i < last; i++) {
      final a = _bodyFactors[i], b = _bodyFactors[i + 1];
      if (factor <= b) {
        return i + (factor - a) / (b - a);
      }
    }
    return last.toDouble();
  }

  /// Size in points of the style whose default-size is [anchor] at the
  /// fractional [category].
  static double _anchorSize(int anchor, double category) {
    final row = _appleSizes[anchor]!;
    final i = category.floor().clamp(0, row.length - 1);
    final j = math.min(i + 1, row.length - 1);
    return row[i] + (row[j] - row[i]) * (category - i);
  }

  /// Interpolates between the nearest styles of the table by their scaled
  /// sizes, which keeps the result monotonic in [fontSize].
  static double _scaled(double fontSize, double category) {
    final first = _anchors.first, last = _anchors.last;
    if (fontSize <= first) {
      return fontSize * _anchorSize(first, category) / first;
    }
    if (fontSize >= last) {
      return fontSize * _anchorSize(last, category) / last;
    }
    for (var i = 0; i < _anchors.length - 1; i++) {
      final a = _anchors[i], b = _anchors[i + 1];
      if (fontSize <= b) {
        final t = (fontSize - a) / (b - a);
        final sa = _anchorSize(a, category), sb = _anchorSize(b, category);
        return sa + (sb - sa) * t;
      }
    }
    return fontSize;
  }

  @override
  double scale(double fontSize) {
    final factor = _linearFactor;
    if (factor == null) return platform.scale(fontSize);
    return scaleLinearFactor(factor, fontSize);
  }

  // The estimate the framework documents; use [scale] instead.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(17) / 17;

  @override
  bool operator ==(Object other) =>
      other is RaftTextScaler && other.platform == platform;

  @override
  int get hashCode => Object.hash(RaftTextScaler, platform);

  @override
  String toString() => 'RaftTextScaler($platform)';
}

/// Which text size accessibility category the OS is in (Accessibility 1 and up
/// is "accessibility sizes").
bool raftIsAccessibilityTextSize(TextScaler content) {
  final s = content is RaftTextScaler ? content : RaftTextScaler(content);
  final f = s._linearFactor ?? (s.platform.scale(17) / 17);
  return f >= _bodyFactors[_firstAccessibilityCategory] - 1e-6;
}

/// Installs the content text scaler for everything below it and publishes the
/// chrome scaler and the clamping state. Place once above the app content
/// (MaterialApp `builder`).
///
/// It also keeps `MediaQueryData.displayFeatures` the same list object while
/// its content is unchanged. The engine decodes a new list on every window
/// metrics update, and `MediaQuery.displayFeaturesOf` (also used by
/// `DisplayFeatureSubScreen` of every dialog and sheet) compares by identity,
/// so each frame of a keyboard animation would otherwise rebuild every widget
/// that reads it.
class RaftTextScaling extends StatefulWidget {
  const RaftTextScaling({super.key, required this.child});

  final Widget child;

  /// Fixed chrome grows at most to this factor.
  static const double chromeMaxScale = 1.35;

  /// The text scaler of the surrounding content (already on the Apple curve).
  static TextScaler contentOf(BuildContext context) =>
      MediaQuery.textScalerOf(context);

  @override
  State<RaftTextScaling> createState() => _RaftTextScalingState();
}

class _RaftTextScalingState extends State<RaftTextScaling> {
  List<ui.DisplayFeature>? _features;

  List<ui.DisplayFeature> _stable(List<ui.DisplayFeature> next) {
    final previous = _features;
    if (previous != null && listEquals(previous, next)) return previous;
    return _features = next;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final platform = media.textScaler;
    final content = platform is RaftTextScaler
        ? platform
        : RaftTextScaler(platform);
    return MediaQuery(
      data: media.copyWith(
        textScaler: content,
        displayFeatures: _stable(media.displayFeatures),
      ),
      child: widget.child,
    );
  }
}

/// Bounds the text scale of fixed chrome (bottom tab bar, channel tabs,
/// badges, counters, icon buttons) at [RaftTextScaling.chromeMaxScale]. Inside,
/// `scale()` never exceeds 1.35x of the font size; [RaftChrome.engagedOf] tells
/// the Large Content Viewer whether the bound is currently hiding any growth.
///
/// While the bound hides nothing (normal text sizes) this widget is
/// transparent: it adds no widget and depends only on the text scaler.
class RaftChrome extends StatelessWidget {
  const RaftChrome({super.key, required this.child});

  final Widget child;

  /// Font sizes the bound is evaluated at (caption, tab label, body).
  static const _probeSizes = [11.0, 13.0, 17.0];

  static bool _hides(TextScaler content, TextScaler bounded) {
    for (final size in _probeSizes) {
      if (content.scale(size) > bounded.scale(size) + 1e-6) return true;
    }
    return false;
  }

  /// The content scaler outside the nearest [RaftChrome] (or the ambient one).
  static TextScaler contentScalerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RaftChromeScope>();
    return scope?.content ?? MediaQuery.textScalerOf(context);
  }

  /// The ambient text scaler bounded for chrome. For a single `Text` in chrome
  /// that is not worth a [RaftChrome] of its own: pass this as `textScaler`.
  static TextScaler boundedScalerOf(BuildContext context) =>
      contentScalerOf(context)
          .clamp(maxScaleFactor: RaftTextScaling.chromeMaxScale);

  /// Whether the chrome bound is reducing the text scale here.
  static bool engagedOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_RaftChromeScope>();
    return scope?.engaged ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Nested chrome keeps the outermost content scaler.
    final outer = context.getInheritedWidgetOfExactType<_RaftChromeScope>();
    final content = outer?.content ?? MediaQuery.textScalerOf(context);
    final bounded = content.clamp(
      maxScaleFactor: RaftTextScaling.chromeMaxScale,
    );
    if (!_hides(content, bounded)) return child;
    return _RaftChromeScope(
      content: content,
      engaged: true,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: bounded),
        child: child,
      ),
    );
  }
}

class _RaftChromeScope extends InheritedWidget {
  const _RaftChromeScope({
    required this.content,
    required this.engaged,
    required super.child,
  });

  final TextScaler content;
  final bool engaged;

  @override
  bool updateShouldNotify(_RaftChromeScope old) =>
      old.content != content || old.engaged != engaged;
}

/// Sizes that must follow the text size.
///
/// A box that holds text is a minimum at 1.0x (pixel parity with Web) and
/// grows with the text above it: build it with `height: null` and a
/// `minHeight` of [extent], or use [grows] to choose between the two.
abstract final class RaftScaled {
  /// Whether text is currently larger than at the default size.
  static bool grows(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 14.0 + 1e-6;

  /// A box that holds a line of text [height] tall: exactly [height] at the
  /// default text size (the CSS line box, pixel parity with Web) and a minimum
  /// above it, so the line grows instead of being clipped.
  static Widget lineBox(
    BuildContext context, {
    required double height,
    required Widget child,
  }) => grows(context)
      ? ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: child,
        )
      : SizedBox(height: height, child: child);

  /// [px] (a size designed for text of [fontSize] at the default text size)
  /// grown by the scale of that font size; never below [px].
  static double extent(
    BuildContext context,
    double px, {
    double fontSize = 14,
  }) {
    final scaled = MediaQuery.textScalerOf(context).scale(fontSize);
    return scaled <= fontSize ? px : px * scaled / fontSize;
  }
}
