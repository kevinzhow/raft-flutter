part of 'message_body.dart';

/// Sendable inputs for the same parser and code spans used by a message row.
/// Task callbacks are resolved here; a worker never receives workspace state.
class RaftMessageBodyRequest {
  RaftMessageBodyRequest({
    required this.content,
    required RaftTokens tokens,
    List<RaftTextReference> references = const [],
    String Function(int)? taskHref,
    bool Function(int)? knownTaskNumber,
    double fontSize = 14,
  }) : _references = _ReferencesKey(
         content,
         references,
         taskHref,
         knownTaskNumber,
       ),
       _dark = tokens.dark,
       _codeStyle = RaftCodeRecipe(tokens).textStyle.copyWith(
         fontSize: fontSize,
         color: RaftCodeRecipe(tokens).foreground,
       );
  final String content;
  final _ReferencesKey _references;
  final bool _dark;
  final TextStyle _codeStyle;
  bool get _cached {
    final chunks = _bodyChunkCache.peek(content);
    if (chunks == null) return false;
    for (final chunk in chunks) {
      if (chunk.markdown &&
          !raftMarkdownAstCache.containsKey(
            _TreeKey(chunk.text, RaftMarkdownMode.message, _references),
          ))
        return false;
      if (!chunk.markdown &&
          !chunk.mermaid &&
          !raftCodeSpanCache.containsKey((
            chunk.text,
            chunk.language,
            _codeStyle,
            _dark,
          )))
        return false;
    }
    return true;
  }
}

class _PreparedMessageBody {
  const _PreparedMessageBody(this.request, this.chunks, this.trees, this.code);
  final RaftMessageBodyRequest request;
  final List<_BodyChunk> chunks;
  final List<List<md.Node>?> trees;
  final List<TextSpan?> code;
  void adopt() {
    _bodyChunkCache.putIfAbsent(request.content, () => chunks);
    for (var i = 0; i < chunks.length; i++) {
      final tree = trees[i], span = code[i], chunk = chunks[i];
      if (tree != null) {
        raftMarkdownAstCache.putIfAbsent(
          _TreeKey(chunk.text, RaftMarkdownMode.message, request._references),
          () => tree,
        );
      }
      if (span != null) {
        raftCodeSpanCache.putIfAbsent((
          chunk.text,
          chunk.language,
          request._codeStyle,
          request._dark,
        ), () => span);
      }
    }
  }
}

List<_PreparedMessageBody> _prepareMessageBodies(
  List<RaftMessageBodyRequest> requests,
) => [
  for (final request in requests)
    () {
      final key = request._references;
      final tasks = {
        for (final task in key.tasks ?? <(int, String, bool)>[])
          task.$1: (task.$2, task.$3),
      };
      final inputs = _TreeInputs(
        RaftMarkdownMode.message,
        RaftTokenContext(
          references: [
            for (final r in key.references)
              RaftTextReference(
                text: r.$1,
                href: r.$2,
                identityBacked: r.$3,
                label: r.$4,
              ),
          ],
          taskHref: key.tasks == null ? null : (n) => tasks[n]!.$1,
          knownTaskNumber: key.tasks == null
              ? null
              : (n) => tasks[n]?.$2 ?? false,
          message: true,
        ),
        key,
      );
      final chunks = _splitBody(request.content);
      return _PreparedMessageBody(
        request,
        chunks,
        [
          for (final chunk in chunks)
            if (chunk.markdown)
              () {
                final tree = _buildTree(chunk.text, inputs);
                return _hasEmptyListItem(tree) ? null : tree;
              }()
            else
              null,
        ],
        [
          for (final chunk in chunks)
            !chunk.markdown && !chunk.mermaid
                ? _highlightCode(
                    chunk.text,
                    chunk.language,
                    request._codeStyle,
                    dark: request._dark,
                  )
                : null,
        ],
      );
    }(),
];

/// One bounded worker batch, plus its newest replacement, per visible pane.
/// Parsing never delays message publication. Unprepared rows render normally.
/// Cancellation drops stale results without starting concurrent isolates.
class RaftMessageBodyWorker {
  List<RaftMessageBodyRequest? Function()> _pending = [];
  bool Function() _current = () => false;
  bool _running = false, _disposed = false;
  int _revision = 0;
  Future<void> _completion = Future.value();
  final _yieldTimer = RaftIdleTimer(yieldToAnimation: false);
  Completer<void>? _yielding;
  Future<void> get completion => _completion;

  void replace(
    Iterable<RaftMessageBodyRequest> requests, {
    required bool Function() current,
  }) => prepare(
    requests
        .take(64)
        .where((r) => !r._cached)
        .map(
          (r) =>
              () => r,
        ),
    current: current,
  );

  /// Resolves references in small steps after publication, including while
  /// scrolling. Only pure requests cross the isolate boundary.
  void prepare(
    Iterable<RaftMessageBodyRequest? Function()> requests, {
    required bool Function() current,
  }) {
    if (_disposed || kIsWeb) return;
    ++_revision;
    _pending = requests.take(64).toList();
    _current = current;
    if (!_running && _pending.isNotEmpty) _completion = _drain();
  }

  Future<void> _yield() {
    final done = _yielding = Completer<void>();
    _yieldTimer.start(const Duration(milliseconds: 8), () {
      _yielding = null;
      done.complete();
    });
    return done.future;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final jobs = _pending, revision = _revision, current = _current;
        _pending = [];
        bool valid() => !_disposed && revision == _revision && current();
        final batch = <RaftMessageBodyRequest>[];
        var bytes = 0;
        try {
          for (var i = 0; i < jobs.length; i++) {
            if (i % 4 == 0) await _yield();
            if (!valid()) break;
            final request = jobs[i]();
            if (request == null || request.content.length > 64 * 1024) continue;
            final size = request.content.length * 2;
            if (bytes + size > 512 * 1024 || request._cached) continue;
            bytes += size;
            batch.add(request);
          }
          if (!valid() || batch.isEmpty) continue;
          final result = await compute(
            _prepareMessageBodies,
            batch,
            debugLabel: 'Raft history bodies',
          );
          for (var i = 0; i < result.length; i++) {
            if (i % 4 == 0) await _yield();
            if (!valid()) break;
            result[i].adopt();
          }
        } catch (_) {
          // Optional cache warming: the mounted row remains the synchronous
          // source of truth, including on platforms without isolate support.
        }
      }
    } finally {
      _running = false;
    }
  }

  void cancel() {
    ++_revision;
    _pending = [];
    _yieldTimer.cancel();
    _yielding?.complete();
    _yielding = null;
  }

  void dispose() {
    cancel();
    _disposed = true;
  }
}
