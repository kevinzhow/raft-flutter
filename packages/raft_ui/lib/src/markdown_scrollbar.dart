import 'package:flutter/cupertino.dart' show CupertinoScrollbar;
import 'package:flutter/material.dart';

import 'interaction.dart';

/// Decorates the renderer's existing horizontal viewport without replacing
/// its controller, child, padding, table layout or selection descendants.
Widget buildMarkdownScrollbar(
  BuildContext context,
  ScrollController controller,
  Widget child,
  bool? thumbVisibility,
) {
  final touch = RaftInteraction.of(context).touch;
  // Material Scrollbar does not forward interactive to its iOS adaptive
  // CupertinoScrollbar, so that platform needs an indicator-only painter.
  final cupertinoTouch =
      touch && Theme.of(context).platform == TargetPlatform.iOS;
  // Only the scrollbar painter consumes the local inset correction. Content
  // and selection descendants keep the caller's original MediaQuery.
  final scrollChild = MediaQuery(data: MediaQuery.of(context), child: child);
  // An embedded table/pre already sits inside the page's safe area. Applying
  // the window inset to its painter again places the thumb over its content.
  return MediaQuery.removePadding(
    context: context,
    removeLeft: true,
    removeTop: true,
    removeRight: true,
    removeBottom: true,
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: cupertinoTouch
          // ds-allow: platform scrollbar chrome, using Cupertino idle paint
          // defaults. It indicates horizontal position on touch; a thumb's
          // zero-slop drag recognizer must not steal vertical finger pans.
          ? RawScrollbar(
              controller: controller,
              interactive: false,
              thumbVisibility: thumbVisibility ?? false,
              padding: EdgeInsets.zero,
              crossAxisMargin: 0,
              mainAxisMargin: 3,
              thickness: CupertinoScrollbar.defaultThickness,
              radius: CupertinoScrollbar.defaultRadius,
              minThumbLength: 36,
              minOverscrollLength: 8,
              fadeDuration: const Duration(milliseconds: 250),
              timeToFade: const Duration(milliseconds: 1200),
              thumbColor: Theme.of(context).brightness == Brightness.dark
                  // ds-allow: Flutter 3.47.8 Cupertino scrollbar's native idle dark color.
                  ? const Color(0x80ffffff)
                  // ds-allow: Flutter 3.47.8 Cupertino scrollbar's native idle light color.
                  : const Color(0x59000000),
              child: scrollChild,
            )
          : Scrollbar(
              controller: controller,
              interactive: !touch,
              thumbVisibility: thumbVisibility,
              child: scrollChild,
            ),
    ),
  );
}
