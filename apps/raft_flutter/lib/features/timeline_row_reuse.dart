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

/// A row cache owned by its lazy element, so retirement releases its subtree.
/// The caller includes non-message inputs in [revision]; message grouping also
/// depends on the neighbouring immutable message versions.
class TimelineReusableRow extends StatefulWidget {
  const TimelineReusableRow({
    super.key,
    required this.message,
    required this.before,
    required this.after,
    required this.revision,
    required this.builder,
    this.retention,
  });
  final chat.Message message;
  final chat.Message? before, after;
  final Object? revision;
  final WidgetBuilder builder;
  final TimelineRowRetention? retention;

  @override
  State<TimelineReusableRow> createState() => _TimelineReusableRowState();
}

class _TimelineReusableRowState extends State<TimelineReusableRow>
    with AutomaticKeepAliveClientMixin {
  Widget? _child;
  bool _retained = false;

  @override
  bool get wantKeepAlive => _retained;

  @override
  void initState() {
    super.initState();
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
    _child = null;
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
    if (!identical(oldWidget.message, widget.message) ||
        !identical(oldWidget.before, widget.before) ||
        !identical(oldWidget.after, widget.after) ||
        oldWidget.revision != widget.revision) {
      _child = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // A kept-alive sliver child can rebuild without being laid out. Updating
    // its rich text then lets selection registrars sort unlaid-out fragments
    // and lose existing entries. Reconcile the cached row during real layout.
    if (widget.retention == null) return _child ??= widget.builder(context);
    return LayoutBuilder(
      builder: (context, constraints) => _child ??= widget.builder(context),
    );
  }

  @override
  void dispose() {
    widget.retention?._remove(this);
    super.dispose();
  }
}
