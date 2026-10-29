/// Synchronous layout ownership for one workspace receiver. Source forwarding
/// and read admission stay in the controller; this state has no side effects.
class ConversationPresentationState {
  Object? _owner, _tabOwner;
  bool _main = true, _thread = true, _chat = true;

  bool get main => _main;
  bool get thread => _thread;
  bool get chat => _chat;

  void setTab(Object owner, bool visible) {
    _tabOwner = owner;
    _chat = visible;
  }

  void releaseTab(Object owner) {
    if (!identical(owner, _tabOwner)) return;
    _tabOwner = null;
    _chat = true;
  }

  void setConversation(
    Object owner, {
    required bool main,
    required bool thread,
  }) {
    _owner = owner;
    _main = main;
    _thread = thread;
  }

  void releaseConversation(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _main = _thread = true;
  }
}
