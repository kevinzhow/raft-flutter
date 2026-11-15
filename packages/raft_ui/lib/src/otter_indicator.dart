import 'package:flutter/material.dart';

import 'sized_image.dart';

/// Which pose Ottie takes (raft-ui `OtterIndicator` `status`).
enum RaftOtterStatus { wait, process, error }

/// raft-ui `OtterIndicator` (0.95.3): Ottie resting, quietly typing or tilting
/// its head with a question mark. Decorative: the nearby status text says what
/// it means. This is the still pose the Web shows under reduced motion (the
/// loop frames are not animated here, so it never wakes an idle app).
///
/// The art is one 3x2 sprite sheet per pose (`wait` is a single frame); the
/// first frame is the resting / typing pose, the last the tilted one.
class RaftOtterIndicator extends StatelessWidget {
  const RaftOtterIndicator({super.key, required this.status, this.size = 40});
  final RaftOtterStatus status;

  /// The square box, 40 or larger.
  final double size;

  static const _package = 'raft_ui';

  /// The art, decoded no larger than the box it fills.
  static Widget _art(String asset, double width, double height, BoxFit fit) =>
      RaftSizedImage(
        // ignore: raft_lints/avoid_raw_image_decode -- Bundled brand art handed straight to RaftSizedImage, so it decodes at the display size.
        image: AssetImage(asset, package: _package),
        width: width,
        height: height,
        fit: fit,
        excludeFromSemantics: true,
      );

  Widget _frame(String asset, int column, int row) => ClipRect(
    child: OverflowBox(
      alignment: Alignment(
        column == 0 ? -1 : (column == 1 ? 0 : 1),
        row == 0 ? -1 : 1,
      ),
      minWidth: size * 3,
      maxWidth: size * 3,
      minHeight: size * 2,
      maxHeight: size * 2,
      child: _art(asset, size * 3, size * 2, BoxFit.fill),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final child = switch (status) {
      RaftOtterStatus.wait => _art(
        'assets/otter/wait.webp',
        size,
        size,
        BoxFit.contain,
      ),
      RaftOtterStatus.process => _frame('assets/otter/process.webp', 0, 0),
      // The tilted frame replaces the top of the resting one; the question mark
      // is drawn on top (`r-otter-indicator__question`).
      RaftOtterStatus.error => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          _frame('assets/otter/error.webp', 0, 0),
          ClipRect(
            clipper: _TopClipper(.58),
            child: _frame('assets/otter/error.webp', 2, 1),
          ),
          Positioned(
            left: size * 40.3 / 48 - size * .09,
            top: size * 11.4 / 48 - size * .24,
            child: Transform.rotate(
              angle: 10 * 3.14159265 / 180,
              child: Text(
                '?',
                // Part of the drawing: it scales with Ottie, not with the text.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  // ds-allow: raft-ui `r-otter-indicator__question`: 11.4 of the 48 viewBox
                  fontSize: size * 11.4 / 48,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  // ds-allow: raft-ui `r-otter-indicator__question` fill oklch(0.57 0.09 75)
                  color: const Color(0xFF9B7424),
                ),
              ),
            ),
          ),
        ],
      ),
    };
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('raft-otter-indicator'),
        width: size,
        height: size,
        child: child,
      ),
    );
  }
}

class _TopClipper extends CustomClipper<Rect> {
  const _TopClipper(this.fraction);
  final double fraction;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);
  @override
  bool shouldReclip(_TopClipper oldClipper) => oldClipper.fraction != fraction;
}
