import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/mobile_navigation_previews.dart' as mobile;

@RaftPreviews('Source mobile navigation', size: Size(390, 844))
Widget sourceMobileNavigationPreview() =>
    mobile.sourceMobileNavigationPreview();
@RaftPreviews('Source mobile navigation compact', size: Size(390, 560))
Widget sourceMobileNavigationCompactPreview() =>
    mobile.sourceMobileNavigationCompactPreview();

@RaftPreviews('Source mobile navigation touch', size: Size(390, 844))
Widget sourceMobileNavigationTouchPreview() =>
    mobile.sourceMobileNavigationTouchPreview();
