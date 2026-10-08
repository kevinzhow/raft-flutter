import 'package:flutter/material.dart';

import 'localization.dart';
import 'message_body.dart';

/// Structured, server-bounded attachment content. Never executes document HTML.
class RaftDocumentPreview extends StatefulWidget {
  const RaftDocumentPreview({
    super.key,
    required this.data,
    this.truncated = false,
  });
  final Map<String, dynamic> data;
  final bool truncated;
  @override
  State<RaftDocumentPreview> createState() => _RaftDocumentPreviewState();
}

class _RaftDocumentPreviewState extends State<RaftDocumentPreview> {
  int sheet = 0;
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final sheets = (data['sheets'] as List? ?? []).whereType<Map>().toList();
    final selected = sheets.isEmpty
        ? data
        : sheets[sheet.clamp(0, sheets.length - 1)];
    final tabular = ['csv', 'xlsx'].contains(data['kind']);
    final headers = (selected['headers'] as List? ?? [])
        .map((v) => '$v')
        .toList();
    final rows = (selected['rows'] as List? ?? []).whereType<List>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.truncated ||
            data['truncated'] == true ||
            selected['truncated'] == true)
          Text(raftText(context, 'Preview truncated. Download the full file.')),
        if (data['kind'] == 'xlsx' && sheets.length > 1)
          Wrap(
            children: [
              for (var i = 0; i < sheets.length; i++)
                ChoiceChip(
                  label: Text('${sheets[i]['name'] ?? ''}'),
                  selected: sheet == i,
                  onSelected: (_) => setState(() => sheet = i),
                ),
            ],
          ),
        if (tabular)
          Text(
            '${selected['rowCount'] ?? rows.length} × ${selected['columnCount'] ?? headers.length}',
          ),
        Expanded(
          child: SingleChildScrollView(
            child: data['kind'] == 'markdown'
                ? RaftMessageBody(content: '${data['markdown'] ?? ''}')
                : tabular
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      border: TableBorder.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      children: [
                        if (headers.isNotEmpty)
                          TableRow(
                            children: [
                              for (final h in headers)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        for (final row in rows)
                          if (headers.isNotEmpty)
                            TableRow(
                              children: [
                                for (var i = 0; i < headers.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Semantics(
                                      label: i < row.length ? '${row[i]}' : '',
                                      excludeSemantics: true,
                                      child: SelectableText(
                                        i < row.length ? '${row[i]}' : '',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                      ],
                    ),
                  )
                : SelectableText(
                    '${data['text'] ?? ''}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
          ),
        ),
      ],
    );
  }
}

class RaftMediaControls extends StatelessWidget {
  const RaftMediaControls({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    this.volume = 100,
    this.onPlayPause,
    this.onSeek,
    this.onVolume,
  });
  final bool playing;
  final Duration position, duration;
  final double volume;
  final VoidCallback? onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;
  String clock(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          IconButton(
            tooltip: raftText(context, playing ? 'Pause' : 'Play'),
            onPressed: onPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          Expanded(
            child: Slider(
              semanticFormatterCallback: (v) =>
                  clock(Duration(milliseconds: v.round())),
              value: position.inMilliseconds.toDouble().clamp(
                0,
                duration.inMilliseconds.toDouble().clamp(1, double.infinity),
              ),
              max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: duration > Duration.zero && onSeek != null
                  ? (v) => onSeek!(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Text('${clock(position)} / ${clock(duration)}'),
        ],
      ),
      Row(
        children: [
          Icon(Icons.volume_up, semanticLabel: raftText(context, 'Volume')),
          Expanded(
            child: Slider(
              value: volume.clamp(0, 100),
              max: 100,
              onChanged: onVolume,
              semanticFormatterCallback: (v) => '${v.round()}%',
            ),
          ),
        ],
      ),
    ],
  );
}
