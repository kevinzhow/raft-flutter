// GENERATED — do not edit. Regenerate with `tool/gen-tokens`.
// Source: media-motion.json (authored in-repo; Flutter-only policy, no Web CSS counterpart)
// dart format off

import 'package:flutter/animation.dart';

/// Motion of the media browser's open / close transition: the picture flies
/// from the card to the stage in [openDuration] (decelerating) and back in
/// [closeDuration]; the scrim follows the picture, the chrome waits for it.
abstract final class RaftMediaMotionTokens {
  /// `media.openMs`: the open flight.
  static const Duration openDuration = Duration(milliseconds: 300);
  /// `media.closeMs`: the close flight (never longer than the open).
  static const Duration closeDuration = Duration(milliseconds: 240);
  /// `media.reducedMs`: the cross-fade of reduced motion (no flight).
  static const Duration reducedDuration = Duration(milliseconds: 80);
  /// `media.openCurve`: the open flight and scrim (emphasized decelerate).
  static const Cubic openCurve = Cubic(0.05, 0.7, 0.1, 1.0);
  /// `media.closeCurve`: the close flight and scrim (standard).
  static const Cubic closeCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  /// `media.chromeRevealAt`: share of the open flight after which the bars fade in.
  static const double chromeRevealAt = 0.7;
  /// `media.chromeFadeInMs`: the bars fading in.
  static const Duration chromeFadeIn = Duration(milliseconds: 160);
  /// `media.chromeFadeOutMs`: the bars gone when a close starts.
  static const Duration chromeFadeOut = Duration(milliseconds: 80);
  /// `media.stageFadeUntil`: share of the flight in which the stage fades (no card to fly from).
  static const double stageFadeUntil = 0.4;
}
