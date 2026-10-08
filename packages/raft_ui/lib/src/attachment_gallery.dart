import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'attachment_tokens.dart';
import 'theme.dart';

/// Pure row allocation ported from raft-ui 0.5.27 message-image-gallery-rows.
/// Media bytes, capabilities and preview operations belong to the app adapter.
List<List<int>> raftImageGalleryRows(List<({double? width, double? height})> images) {
  if (images.length == 1) return [[0]];
  final rows = <List<int>>[], buffered = <int>[];
  void flush() {
    final chunk = buffered.length == 4 ? 2 : 3;
    for (var i = 0; i < buffered.length; i += chunk) {
      rows.add(buffered.sublist(i, math.min(i + chunk, buffered.length)));
    }
    buffered.clear();
  }
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    if (image.width != null && image.height != null && image.width! > 0 && image.height! > 0 && image.width! / image.height! >= AttachmentPrimitive.wideAspect) {
      flush(); rows.add([i]);
    } else { buffered.add(i); }
  }
  flush(); return rows;
}

class RaftAttachmentGallery extends StatelessWidget {
  const RaftAttachmentGallery({super.key, required this.dimensions, required this.itemBuilder});
  final List<({double? width, double? height})> dimensions;
  final Widget Function(int index, Size extent, BoxFit fit) itemBuilder;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    if (dimensions.isEmpty) return const SizedBox.shrink();
    final viewport = MediaQuery.sizeOf(context).width;
    final recipe = AttachmentComponentRecipe(RaftTokens.of(context));
    final available = constraints.maxWidth.isFinite ? constraints.maxWidth : viewport;
    if (dimensions.length == 1) {
      final d = dimensions.single;
      final size = recipe.imageSize(viewportWidth: viewport, availableWidth: available, width: d.width, height: d.height);
      return itemBuilder(0, size, BoxFit.contain);
    }
    final width = math.max(1.0, math.min(available, viewport >= AttachmentPrimitive.columnsBreakpoint ? AttachmentPrimitive.desktopGalleryMaxWidth : math.min(AttachmentPrimitive.mobileGalleryMaxWidth, viewport - AttachmentPrimitive.mobileGalleryReserve))).toDouble();
    final rows = raftImageGalleryRows(dimensions);
    return SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var row = 0; row < rows.length; row++) ...[
        if (row > 0) const SizedBox(height: AttachmentPrimitive.galleryGap),
        Wrap(spacing: AttachmentPrimitive.galleryGap, runSpacing: AttachmentPrimitive.galleryGap, children: [
          for (final index in rows[row]) Builder(builder: (context) {
            final count = rows[row].length;
            final columns = count == 3 && viewport < AttachmentPrimitive.columnsBreakpoint ? 2 : count;
            final extent = Size((width - (columns - 1) * AttachmentPrimitive.galleryGap) / columns,
                count == 3 ? (viewport >= AttachmentPrimitive.rowBreakpoint ? AttachmentPrimitive.regularThreeRowHeight : AttachmentPrimitive.compactThreeRowHeight) : (viewport >= AttachmentPrimitive.rowBreakpoint ? AttachmentPrimitive.regularRowHeight : AttachmentPrimitive.compactRowHeight));
            final d = dimensions[index];
            final ratio = d.width != null && d.height != null && d.width! > 0 && d.height! > 0 ? d.width! / d.height! : 1.0;
            return itemBuilder(index, extent, ratio >= AttachmentPrimitive.wideAspect || ratio <= AttachmentPrimitive.tallAspect ? BoxFit.contain : BoxFit.cover);
          }),
        ]),
      ],
    ]));
  });
}
