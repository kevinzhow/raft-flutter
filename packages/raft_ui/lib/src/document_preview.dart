import 'package:flutter/material.dart';

import 'localization.dart';
import 'message_body.dart';
import 'design_primitives.dart';
import 'message_content_tokens.dart';
import 'theme.dart';

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
    final recipe = DocumentAttachmentRecipe(RaftTokens.of(context));
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
                Padding(padding: const EdgeInsets.only(right: 4), child: RaftControl(
                  kind: RaftControlKind.tab, selected: sheet == i, shadow: false,
                  semanticLabel: '${sheets[i]['name'] ?? ''}',
                  onPressed: () => setState(() => sheet = i),
                  child: Text('${sheets[i]['name'] ?? ''}'),
                )),
            ],
          ),
        if (tabular)
          Text(
            '${selected['rowCount'] ?? rows.length} × ${selected['columnCount'] ?? headers.length}',
            style: recipe.heading,
          ),
        Expanded(
          child: ColoredBox(color: data['kind'] == 'markdown' ? recipe.paper : recipe.background, child: Padding(padding: data['kind'] == 'markdown' ? recipe.markdownInset(MediaQuery.sizeOf(context).width) : recipe.inset, child: LayoutBuilder(builder: (context, bounds) => SingleChildScrollView(
            child: data['kind'] == 'markdown'
                ? RaftMessageBody(
                    content: '${data['markdown'] ?? ''}',
                    fontSize: 16,
                    documentMode: true,
                  )
                : tabular
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(constraints: BoxConstraints(minWidth: bounds.maxWidth), child: Table(
                      defaultColumnWidth: const IntrinsicColumnWidth(),
                      border: TableBorder.all(color: recipe.border.color, width: recipe.border.width),
                      children: [
                        if (headers.isNotEmpty)
                          TableRow(
                            decoration: BoxDecoration(color: recipe.tableHeader),
                            children: [
                              for (final h in headers)
                                Padding(
                                  padding: recipe.cellInset,
                                  child: ConstrainedBox(constraints: BoxConstraints(maxWidth: recipe.maxColumnWidth), child: Text(
                                    h,
                                    style: recipe.tableText.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  )),
                                ),
                            ],
                          ),
                        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                          if (headers.isNotEmpty)
                            TableRow(
                              decoration: BoxDecoration(color: rowIndex.isEven ? recipe.rowStripe : recipe.paper),
                              children: [
                                for (var i = 0; i < headers.length; i++)
                                  Padding(
                                    padding: recipe.cellInset,
                                    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: recipe.maxColumnWidth), child: Semantics(
                                      label: i < rows[rowIndex].length ? '${rows[rowIndex][i]}' : '',
                                      excludeSemantics: true,
                                      child: SelectableText(
                                        i < rows[rowIndex].length ? '${rows[rowIndex][i]}' : '',
                                        style: recipe.tableText,
                                        maxLines: 1,
                                      ),
                                    )),
                                  ),
                              ],
                            ),
                      ],
                    )),
                  )
                : DecoratedBox(decoration: BoxDecoration(color: recipe.paper, border: Border.fromBorderSide(recipe.border)), child: Padding(padding: recipe.textInset, child: SelectableText(
                    '${data['text'] ?? ''}',
                    style: recipe.text,
                  ))),
          )))),
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
