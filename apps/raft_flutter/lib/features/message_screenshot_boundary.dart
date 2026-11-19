import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'screenshot_budget.dart';

class MessageScreenshotBoundary extends RepaintBoundary {
  const MessageScreenshotBoundary({super.key, required super.child});

  @override
  RenderMessageScreenshotBoundary createRenderObject(BuildContext context) =>
      RenderMessageScreenshotBoundary();
}

class RenderMessageScreenshotBoundary extends RenderRepaintBoundary {
  Future<ui.Image> captureBand(ScreenshotBand band) =>
      (layer! as OffsetLayer).toImage(
        Rect.fromLTWH(0, band.top, size.width, band.height),
        pixelRatio: band.pixelRatio,
      );
}
