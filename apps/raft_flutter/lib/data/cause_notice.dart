/// Transient notices that are bound to their cause (Kevin 2026-10-13: the
/// "wait for uploads" banner stayed after the upload finished and the message
/// was sent).
///
/// A banner, error row or inline warning is a *consequence* of something: an
/// upload still running, a failed request, a rejected file. Storing it as a
/// free-floating string means every place that ends the cause has to remember
/// to clear it, and the one that forgets leaves a stale message on screen.
///
/// A [CauseNotice] instead carries its own end conditions and checks them on
/// every read, so a stale message cannot be shown:
///
///  * [raise]`(whileTrue:)` - the cause predicate. The notice reads as null the
///    moment it is false (uploads finished, the attachment was removed, the
///    retry succeeded). Prefer this: it is derived state, nothing to clear.
///  * `scope` - an identity (channel, thread, dialog, account) captured when
///    the notice is raised. The notice reads as null once the scope's current
///    value differs, so navigating away and back does not resurrect it.
///  * [clear] - for causes that cannot be expressed as a predicate (the user
///    retried, submitted, or changed the input).
///
/// Reads never notify: whatever changes the cause already rebuilds the reader.
/// The only mutation a read performs is dropping an expired message.
class CauseNotice {
  CauseNotice({this._scope});

  final Object? Function()? _scope;
  String? _message;
  Object? _raisedIn;
  bool Function()? _holds;

  /// The message while its cause and scope still hold, else null.
  String? get message {
    final text = _message;
    if (text == null) return null;
    final scope = _scope;
    if ((scope != null && scope() != _raisedIn) ||
        (_holds != null && !_holds!())) {
      _message = null;
      _holds = null;
      return null;
    }
    return text;
  }

  bool get isActive => message != null;

  /// Shows [message] until [whileTrue] turns false, the scope changes or
  /// [clear] is called. A null [message] clears.
  void raise(String? message, {bool Function()? whileTrue}) {
    if (message == null || message.isEmpty) {
      clear();
      return;
    }
    _message = message;
    _raisedIn = _scope?.call();
    _holds = whileTrue;
  }

  void clear() {
    _message = null;
    _holds = null;
  }
}

/// [CauseNotice]s keyed by scope (a composer's draft scope, a row id), for
/// state that outlives the widget showing it. Each entry carries its own
/// end conditions, so a key never shows a message whose cause has ended.
class CauseNotices<K extends Object> {
  final Map<K, CauseNotice> _byKey = {};

  String? messageFor(K key) {
    final notice = _byKey[key];
    final text = notice?.message;
    if (notice != null && text == null) _byKey.remove(key);
    return text;
  }

  /// Raises [message] for [key]; returns whether what is shown changed.
  bool raise(K key, String? message, {bool Function()? whileTrue}) {
    final before = messageFor(key);
    if (message == null || message.isEmpty) {
      _byKey.remove(key);
      return before != null;
    }
    (_byKey[key] = CauseNotice()).raise(message, whileTrue: whileTrue);
    return before != message;
  }

  /// Returns whether a message was showing.
  bool clear(K key) => _byKey.remove(key)?.message != null;

  void clearAll() => _byKey.clear();
}
