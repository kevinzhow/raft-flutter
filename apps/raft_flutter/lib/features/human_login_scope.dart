import 'package:flutter/widgets.dart';

import 'human_login.dart';

/// The signed-in app's side of Login with Raft, for links opened from
/// anywhere below it (a message, a panel). Installed above the Navigator, so
/// the in-app browser and its sheets see it. Null while signed out. Read at
/// the moment a link is opened; nothing subscribes to it.
class HumanLoginScope extends InheritedWidget {
  const HumanLoginScope({super.key, required this.api, required super.child});
  final HumanLoginApi? api;

  static HumanLoginApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HumanLoginScope>()?.api;

  @override
  bool updateShouldNotify(HumanLoginScope oldWidget) => false;
}
