import 'package:flutter/foundation.dart';

/// A [Listenable] that is not a `ChangeNotifier`: process-lifetime notifiers
/// (kept per workspace controller in an `Expando`, or as a singleton) have no
/// owner to dispose them, and a `ChangeNotifier` that is never disposed is a
/// leak report in every test that touches one.
class PlainListenable implements Listenable {
  final _listeners = <VoidCallback>[];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Calls every listener (a listener may remove itself meanwhile).
  void notify() {
    for (final listener in [..._listeners]) {
      listener();
    }
  }
}
