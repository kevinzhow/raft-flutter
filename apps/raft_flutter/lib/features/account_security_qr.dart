// Web v1.24.0 TwoStepVerificationSection `TotpQrCode`: the otpauth URI as a
// QR code (uqr `encode(uri, {border: 1})`, the module matrix drawn in
// `text-sticker-ink` on `bg-sticker-paper`, `size-40 rounded-sticker border
// border-line-hairline p-1`). The key under it is the way in without it.
import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';
import 'package:raft_ui/raft_ui.dart';

class TotpQrCode extends StatelessWidget {
  const TotpQrCode(this.uri, {super.key});
  final String uri;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    QrImage? image;
    try {
      image = QrImage(
        QrCode.fromData(data: uri, errorCorrectLevel: QrErrorCorrectLevel.L),
      );
    } on Object {
      // Too long to encode: the key under it is the way in.
      image = null;
    }
    return Center(
      child: Container(
        key: const ValueKey('two-step-totp-qr'),
        // ds-allow: the Web QR frame is a fixed 160px sticker with 4px padding
        width: 160,
        // ds-allow: the Web QR frame is a fixed 160px square
        height: 160,
        // ds-allow: the Web QR frame has 4px padding
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ui.stickerPaper,
          // ds-allow: the Web QR frame radius
          borderRadius: BorderRadius.circular(
            t.size('radius.sticker', fallback: 4),
          ),
          border: Border.all(color: ui.lineHairline),
        ),
        child: image == null
            ? null
            : ExcludeSemantics(
                child: CustomPaint(painter: _QrPainter(image, ui.stickerInk)),
              ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, this.ink);
  final QrImage image;
  final Color ink;

  /// uqr `border: 1`: one light module around the code.
  static const _border = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount + 2 * _border;
    final module = size.shortestSide / count;
    final paint = Paint()
      ..color = ink
      ..isAntiAlias = false;
    final path = Path();
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        if (!image.isDark(y, x)) continue;
        path.addRect(
          Rect.fromLTWH(
            (x + _border) * module,
            (y + _border) * module,
            module,
            module,
          ),
        );
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image || old.ink != ink;
}
