import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/workspace_controller.dart';

/// Web v1.24: Members, Computers and Settings are pages the server tab pushes
/// (no bottom bar, Back at the top), not tab roots. Back of such a page, or
/// null on a tab root (with the left rail those pages stay roots).
VoidCallback? pushedServerPageBack(
  BuildContext context,
  WorkspaceController controller,
) => controller.navigation.mobileRootTab == null
    ? () => unawaited(Navigator.maybeOf(context)?.maybePop())
    : null;

/// Key of the Back button on a pushed server page.
const pushedServerPageBackKey = Key('server-page-mobile-back');
