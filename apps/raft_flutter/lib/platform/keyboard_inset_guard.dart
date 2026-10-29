import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the platform reports the soft keyboard as visible right now.
/// `null` means unknown; callers must then trust the engine value.
typedef ImeVisibility = Future<bool?> Function();

/// Quiet period after the last engine inset change before it is checked against
/// the platform (a real keyboard animation changes it every frame).
const keyboardInsetSettleDelay = Duration(milliseconds: 250);

const _channel = MethodChannel('app.raft/ime');

/// Android: asks the activity's root window insets whether the IME is shown.
Future<bool?> nativeImeVisible() async {
  try {
    return await _channel.invokeMethod<bool>('visible');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

/// Reconciles a stale keyboard inset after resume (flutter#118761).
///
/// With the keyboard open, backgrounding the app closes the IME. Back in the
/// foreground the engine first reports 0, then, when the system's no-op IME
/// animation ends, Flutter's `ImeSyncDeferringInsetsCallback` re-dispatches the
/// `WindowInsets` it cached at the last keyboard show and the engine reports the
/// old `viewInsets.bottom` again (device log: 883 px, 0, 883 px with
/// `ime.isVisible == false` throughout). Every keyboard-aware surface then
/// reserves a keyboard-sized blank gap. `MainActivity` re-dispatches the real
/// insets at the end of each IME animation; this guard is the Dart-side net.
/// When the engine has reported a non-zero inset, with no further change for
/// [keyboardInsetSettleDelay] or on resume, while the platform says the IME is hidden, the
/// guard remembers that inset as stale and reports it as 0 (and gives the
/// system bar back to `padding`) until the engine reports a different value or
/// focus changes, so a keyboard that really reopens, even at the same height,
/// is never hidden.
///
/// Placed once above the app content (inside the `MaterialApp` builder) so all
/// consumers, including overlays, see the reconciled metrics.
class KeyboardInsetGuard extends StatefulWidget {
  const KeyboardInsetGuard({super.key, this.imeVisible, required this.child});

  /// Platform IME probe. `null` disables the guard (web, desktop, iOS).
  final ImeVisibility? imeVisible;
  final Widget child;

  @override
  State<KeyboardInsetGuard> createState() => _KeyboardInsetGuardState();
}

class _KeyboardInsetGuardState extends State<KeyboardInsetGuard>
    with WidgetsBindingObserver {
  /// Raw engine `viewInsets.bottom` (physical px) known to be stale, or null.
  double? _staleInset;
  int _checks = 0;
  Timer? _settle;

  double _rawInset() => View.of(context).viewInsets.bottom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _settle?.cancel();
    FocusManager.instance.removeListener(_focusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reconcile());
  }

  @override
  void didChangeMetrics() {
    // Any new engine value ends the stale episode.
    if (_staleInset != null && _rawInset() != _staleInset) _clear();
    _settle?.cancel();
    if (_staleInset == null && _rawInset() > 0 && widget.imeVisible != null) {
      _settle = Timer(keyboardInsetSettleDelay, () => unawaited(_reconcile()));
    }
  }

  void _focusChanged() {
    // A focus change may reopen the IME with the same height as the stale one.
    if (_staleInset != null) _clear();
  }

  void _clear() {
    if (_staleInset == null) return;
    setState(() => _staleInset = null);
  }

  Future<void> _reconcile() async {
    final probe = widget.imeVisible;
    final raw = _rawInset();
    if (probe == null || raw <= 0) return;
    final check = ++_checks;
    final visible = await probe();
    if (!mounted || check != _checks || visible != false) return;
    // The inset may have changed while the platform answered.
    if (_rawInset() != raw) return;
    setState(() => _staleInset = raw);
  }

  @override
  Widget build(BuildContext context) {
    final stale = _staleInset;
    final media = MediaQuery.of(context);
    if (stale == null || View.of(context).viewInsets.bottom != stale) {
      return widget.child;
    }
    return MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(bottom: 0),
        // The engine derives padding as max(0, viewPadding - viewInsets): with
        // no keyboard it is the full system bar again.
        padding: media.padding.copyWith(bottom: media.viewPadding.bottom),
      ),
      child: widget.child,
    );
  }
}

/// The guard for the running platform (Android only).
ImeVisibility? get platformImeVisibility =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? nativeImeVisible
    : null;
