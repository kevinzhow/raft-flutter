import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_client/raft_client.dart';

final _diagramFence = RegExp(
  r'(^|\n) {0,3}(?:`{3,}|~{3,})\s*mermaid\b',
  caseSensitive: false,
);
// Quoted-message previews ignore URLs immediately after "(" (Markdown links).
// Keep this conservative: even unrelated bare URLs retire normally.
final _bareUrl = RegExp(r'(?<!\()https?://');

/// Retain only bounded text: decoded media, players, previews and large code
/// trees must still retire as soon as they leave the viewport cache.
bool retainTimelineProse(RaftMessage message) {
  final text = message.content;
  return text.length <= 4096 &&
      (message.json['attachments'] as List? ?? const []).isEmpty &&
      message.json['actionMetadata'] == null &&
      !_diagramFence.hasMatch(text) &&
      !text.contains('![') &&
      !_bareUrl.hasMatch(text);
}

/// Bounded ownership of recently mounted, lightweight timeline rows.
class TimelineRowRetention with WidgetsBindingObserver {
  TimelineRowRetention({this.capacity = 24}) : assert(capacity >= 0) {
    WidgetsBinding.instance.addObserver(this);
  }
  final int capacity;
  final _rows = <_TimelineReusableRowState>{};

  void _add(_TimelineReusableRowState row) {
    _rows.remove(row);
    _rows.add(row);
    while (_rows.length > capacity) {
      final oldest = _rows.first;
      _rows.remove(oldest);
      oldest.release();
    }
  }

  void _remove(_TimelineReusableRowState row) => _rows.remove(row);

  @override
  void didHaveMemoryPressure() {
    for (final row in _rows.toList()) {
      row.release();
    }
    _rows.clear();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rows.clear();
  }
}

class TimelineMountedRows {
  final _rows = <String, _TimelineReusableRowState>{};

  TimelineReusableRow row({
    required chat.Message message,
    required chat.Message? before,
    required chat.Message? after,
    required Object? revision,
    required WidgetBuilder builder,
    required TimelineRowRetention? retention,
  }) {
    final mounted = _rows[message.id]?.widget;
    if (mounted != null &&
        mounted.matches(message, before, after, revision) &&
        identical(mounted.retention, retention)) {
      mounted._builder.build = builder;
      return mounted;
    }
    return TimelineReusableRow._(
      owner: this,
      message: message,
      before: before,
      after: after,
      revision: revision,
      builder: _TimelineRowBuilder(builder),
      retention: retention,
    );
  }

  void _attach(_TimelineReusableRowState row) =>
      _rows[row.widget.message.id] = row;

  void _detach(_TimelineReusableRowState row) {
    final id = row.widget.message.id;
    if (identical(_rows[id], row)) _rows.remove(id);
  }
}

class _TimelineRowBuilder {
  _TimelineRowBuilder(this.build);
  WidgetBuilder build;
}

/// A row cache owned by its lazy element, so retirement releases its subtree.
/// The caller includes non-message inputs in [revision]; message grouping also
/// depends on the neighbouring immutable message versions.
class TimelineReusableRow extends StatefulWidget {
  const TimelineReusableRow._({
    required this._owner,
    required this.message,
    required this.before,
    required this.after,
    required this.revision,
    required this._builder,
    required this.retention,
  });
  final TimelineMountedRows _owner;
  final _TimelineRowBuilder _builder;
  final chat.Message message;
  final chat.Message? before, after;
  final Object? revision;
  final TimelineRowRetention? retention;

  bool matches(
    chat.Message message,
    chat.Message? before,
    chat.Message? after,
    Object? revision,
  ) =>
      identical(this.message, message) &&
      identical(this.before, before) &&
      identical(this.after, after) &&
      this.revision == revision;

  @override
  State<TimelineReusableRow> createState() => _TimelineReusableRowState();
}

class _TimelineReusableRowState extends State<TimelineReusableRow>
    with AutomaticKeepAliveClientMixin {
  Widget? _child;
  Widget? _layout;
  bool _retained = false;

  @override
  bool get wantKeepAlive => _retained;

  @override
  void initState() {
    super.initState();
    widget._owner._attach(this);
    _retained = widget.retention != null;
    widget.retention?._add(this);
  }

  void release() {
    if (!_retained) return;
    _retained = false;
    // Rows are mounted during sliver layout. Release the old keep-alive only
    // after layout, rather than changing a sibling's parent data mid-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) updateKeepAlive();
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- one frame per bounded eviction batch, including memory pressure while idle; never self-reschedules
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _invalidate();
  }

  void _invalidate() {
    _child = null;
    _layout = null;
  }

  @override
  void didUpdateWidget(TimelineReusableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.retention, widget.retention)) {
      oldWidget.retention?._remove(this);
      _retained = widget.retention != null;
      widget.retention?._add(this);
      updateKeepAlive();
    }
    if (!oldWidget.matches(
      widget.message,
      widget.before,
      widget.after,
      widget.revision,
    )) {
      _invalidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // A kept-alive sliver child can rebuild without being laid out. Updating
    // its rich text then lets selection registrars sort unlaid-out fragments
    // and lose existing entries. Reconcile the cached row during real layout.
    Widget body(BuildContext context) =>
        _child ??= widget._builder.build(context);
    if (widget.retention == null) return body(context);
    return _layout ??= LayoutBuilder(
      builder: (context, constraints) => body(context),
    );
  }

  @override
  void dispose() {
    widget._owner._detach(this);
    widget.retention?._remove(this);
    super.dispose();
  }
}
