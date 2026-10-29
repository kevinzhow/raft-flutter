import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/popover_surface.dart';

@RaftPreviews('Source Popover surface: LG Brutal / XL Elegant')
Widget popoverSurfacePreview() => const Center(
  child: RaftPopoverSurface(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      // A minimum height: larger text grows the surface instead of clipping.
      child: _PopoverBody(),
    ),
  ),
);

class _PopoverBody extends StatelessWidget {
  const _PopoverBody();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 208,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: const Center(
        heightFactor: 1,
        child: Text('Controlled public surface'),
      ),
    ),
  );
}
