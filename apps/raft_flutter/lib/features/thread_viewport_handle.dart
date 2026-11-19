import 'package:flutter/foundation.dart';

/// Actions on the currently mounted thread timeline.
class ChatViewportHandle {
  Object? _owner;
  VoidCallback? _jump;
  ValueChanged<String>? _outline;

  void jumpToBeginning() => _jump?.call();
  void jumpToOutline(String id) => _outline?.call(id);

  void bind(Object owner, VoidCallback jump, ValueChanged<String> outline) {
    _owner = owner;
    _jump = jump;
    _outline = outline;
  }

  void release(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _jump = null;
      _outline = null;
    }
  }
}
