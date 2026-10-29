import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// CSS focus-visible is keyboard modality, not Flutter's mouse/traditional
/// focus mode. This process-local tracker stores no account or product state.
class RaftFocusVisible extends ChangeNotifier {
  static final shared = RaftFocusVisible();
  bool keyboard = true;
  int users = 0;
  int keyEpoch = 0;
  void acquire() {
    if (users++ == 0) {
      HardwareKeyboard.instance.addHandler(key);
      GestureBinding.instance.pointerRouter.addGlobalRoute(pointer);
    }
  }

  void release() {
    if (--users == 0) {
      HardwareKeyboard.instance.removeHandler(key);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(pointer);
      keyboard = true;
    }
  }

  void update(bool value) {
    if (keyboard == value) return;
    keyboard = value;
    notifyListeners();
  }

  bool key(KeyEvent event) {
    if (event is KeyDownEvent) {
      keyEpoch++;
      update(true);
    }
    return false;
  }

  void pointer(PointerEvent event) {
    if (event is PointerDownEvent) update(false);
  }
}
