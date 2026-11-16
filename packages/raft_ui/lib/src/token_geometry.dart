import 'package:flutter/painting.dart';

import 'theme.dart';

/// Corner radii read from the theme's numeric tokens (`radius.*`), so a pack
/// that squares the corners reaches every surface that uses one. [fallback] is
/// the Raft value, used when a pack does not set the token.
extension RaftTokenGeometry on RaftTokens {
  BorderRadius corner(String token, {required double fallback}) =>
      BorderRadius.circular(size(token, fallback: fallback));
}
