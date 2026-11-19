import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'interaction.dart';
import 'localization.dart';

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

String? raftComposerSendKeyHint(
  BuildContext context, {
  required bool hasDraft,
}) {
  if (!hasDraft ||
      !RaftInteraction.of(context).pointer ||
      RaftComposerSendKeyScope.of(context) !=
          RaftComposerSendKey.modifiedEnter) {
    return null;
  }
  final shortcut = Theme.of(context).platform == TargetPlatform.macOS
      ? '⌘Enter'
      : 'Ctrl+Enter';
  return raftFormat(context, '{shortcut} to send', {'shortcut': shortcut});
}
