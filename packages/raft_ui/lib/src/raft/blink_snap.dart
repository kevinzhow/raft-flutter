// Blink paints a box at a whole pixel. On a real device that is a device pixel; in the parity reference (an emulated
// device scale factor, see RaftBorderSnap) layout is not zoomed, so a half-pixel centring offset snaps to a whole CSS
// pixel. Wrap a small box or glyph that is centred on a fractional offset (a 9px status pixel in a 22px chip, a 22px
// glyph in a 51px tile).
import 'package:flutter/widgets.dart';

import '../css_pixel_snap.dart';
import 'css_box.dart';

class RaftBlinkSnap extends StatelessWidget {
  const RaftBlinkSnap({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!RaftBorderSnap.emulatedDeviceScaleFactor) {
      return RaftCssPixelSnap(child: child);
    }
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(devicePixelRatio: 1),
      child: RaftCssPixelSnap(child: child),
    );
  }
}
