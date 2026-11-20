import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// CSS focus-visible is keyboard modality, not Flutter's mouse/traditional
/// focus mode. This process-local tracker stores no account or product state.
class RaftFocusVisible extends ChangeNotifier {
  static final shared = RaftFocusVisible();
  bool keyboard = true;
  int users = 0;
  int keyEpoch = 0;
  late Stopwatch _clock;
  Duration? _lastInput;
  _RingModality? _ringModality;
  bool get ringVisible => _ringModality?.visible ?? true;

  void addRingListener(VoidCallback listener) {
    acquire();
    // A pointer can open a view before its first Composer mounts.
    (_ringModality ??= _RingModality(
      _clock,
      _lastInput,
      keyboard,
    )).addListener(listener);
  }

  void removeRingListener(VoidCallback listener) {
    if (_ringModality!.detach(listener)) _ringModality = null;
    release();
  }

  void acquire() {
    if (users++ == 0) {
      _clock = GestureBinding.instance.samplingClock.stopwatch()..start();
      HardwareKeyboard.instance.addHandler(key);
      GestureBinding.instance.pointerRouter.addGlobalRoute(pointer);
    }
  }

  void release() {
    if (--users == 0) {
      HardwareKeyboard.instance.removeHandler(key);
      GestureBinding.instance.pointerRouter.removeGlobalRoute(pointer);
      _clock.stop();
      _lastInput = null;
      keyboard = true;
    }
  }

  void update(bool value) {
    if (keyboard == value) return;
    keyboard = value;
    notifyListeners();
  }

  bool key(KeyEvent event) {
    _ringModality?._key(event);
    if (event is KeyDownEvent) {
      _lastInput = _clock.elapsed;
      keyEpoch++;
      update(true);
    }
    return false;
  }

  void pointer(PointerEvent event) {
    _ringModality?._pointer(event);
    if (event is PointerDownEvent) {
      _lastInput = _clock.elapsed;
      update(false);
    }
  }
}

enum _InputModality { virtual, pointer, keyboard }

/// raft-ui 0.95.3's focus-ring gate. Editing keys leave pointer modality
/// in place while the editor keeps focus, even when the field is focus-visible.
class _RingModality extends ChangeNotifier {
  _RingModality(this._clock, this._lastInput, bool keyboard) {
    if (_lastInput != null) {
      _mode = keyboard ? _InputModality.keyboard : _InputModality.pointer;
    }
    _focusManager.addListener(_focusChanged);
  }

  static const _causeWindow = Duration(seconds: 1);
  static const _navigationKeys = [
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.f6,
  ];
  static const _widgetKeys = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.escape,
  ];
  static const _modifiers = [
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  ];

  final _focusManager = FocusManager.instance;
  final Stopwatch _clock;
  Duration? _lastInput;
  ({FocusNode field, Duration at})? _editing;
  var _mode = _InputModality.virtual;

  bool get visible => _mode != _InputModality.pointer;

  void _setMode(_InputModality mode) {
    final wasVisible = visible;
    _mode = mode;
    if (wasVisible != visible) notifyListeners();
  }

  void _pointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _lastInput = _clock.elapsed;
      _editing = null;
      _setMode(_InputModality.pointer);
    } else if (_mode == _InputModality.virtual &&
        event is PointerHoverEvent &&
        event.kind == PointerDeviceKind.mouse) {
      _setMode(_InputModality.pointer);
    }
  }

  void _key(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    if (_modifiers.contains(key)) return;
    final now = _clock.elapsed;
    _lastInput = now;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed || keyboard.isControlPressed) return;
    final navigates = _navigationKeys.contains(key);
    if (!navigates && !_widgetKeys.contains(key)) return;
    final focus = _focusManager.primaryFocus;
    if (!navigates &&
        focus != null &&
        focus.context?.findAncestorStateOfType<EditableTextState>() != null) {
      _editing = (field: focus, at: now);
    } else {
      _editing = null;
      _setMode(_InputModality.keyboard);
    }
  }

  void _focusChanged() {
    final focus = _focusManager.primaryFocus;
    if (focus == null || focus is FocusScopeNode) return;
    final now = _clock.elapsed;
    final editing = _editing;
    if (editing != null && now - editing.at < _causeWindow) {
      if (focus != editing.field) {
        _editing = null;
        _setMode(_InputModality.keyboard);
      }
    } else if (_lastInput == null || now - _lastInput! > _causeWindow) {
      // Focus without a recent input includes assistive technology and
      // programmatic focus. Keep the indicator available in both cases.
      _setMode(_InputModality.virtual);
    }
  }

  bool detach(VoidCallback listener) {
    removeListener(listener);
    if (hasListeners) return false;
    dispose();
    return true;
  }

  @override
  void dispose() {
    _focusManager.removeListener(_focusChanged);
    super.dispose();
  }
}
