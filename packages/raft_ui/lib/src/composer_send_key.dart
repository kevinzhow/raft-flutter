import 'package:flutter/widgets.dart';

enum RaftComposerSendKey { enter, modifiedEnter }

class RaftComposerSendKeyScope extends InheritedWidget {
  const RaftComposerSendKeyScope({
    super.key,
    required this.sendKey,
    required super.child,
  });

  final RaftComposerSendKey sendKey;

  static RaftComposerSendKey of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RaftComposerSendKeyScope>()
          ?.sendKey ??
      RaftComposerSendKey.enter;

  @override
  bool updateShouldNotify(RaftComposerSendKeyScope oldWidget) =>
      sendKey != oldWidget.sendKey;
}
