// Receiver-local visits; leaving clears delivery warnings through one callback.
class ComposerVisitState {
  ComposerVisitState(this._leftScope);

  final void Function(String) _leftScope;
  final Map<String, int> _visits = {};
  String? _channelScope, _threadScope;

  int visitOf(String scope) => _visits[scope] ?? 0;

  void synchronize(String? channelScope, String? threadScope) {
    if (channelScope != _channelScope) {
      _leave(_channelScope);
      _channelScope = channelScope;
    }
    if (threadScope != _threadScope) {
      _leave(_threadScope);
      _threadScope = threadScope;
    }
  }

  void _leave(String? scope) {
    if (scope == null) return;
    _visits[scope] = (_visits[scope] ?? 0) + 1;
    _leftScope(scope);
  }
}
