import 'package:flutter/material.dart';

import 'previews.dart';
import 'src/popover_surface.dart';

@RaftPreviews('Source Popover surface: LG Brutal / XL Elegant')
Widget popoverSurfacePreview() => const Center(
  child: RaftPopoverSurface(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SizedBox(
        width: 208,
        height: 28,
        child: Center(child: Text('Controlled public surface')),
      ),
    ),
  ),
);
