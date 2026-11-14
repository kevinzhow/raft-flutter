// The viewer's side panels: its files and its versions.
//
// Source: packages/web/src/apps/artifacts/{ArtifactFilesPanel,
// ArtifactVersionHistory}.tsx at v1.24.0-source.1. Web shows the version
// list as a submenu on wide windows and a sheet on a phone, and Files as a
// panel beside (or, on a phone, over) the content; the app shows both as a
// panel beside the content on wide windows and over it on a phone.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../icu_message.dart';
import 'artifact_models.dart';
import 'artifact_text.dart';

/// Opens [version] pinned, or the latest for the latest (Web `pinnedFor`).
int? artifactPinnedFor(int version, int latest) =>
    version >= latest ? null : version;

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    this.meta,
    required this.closeLabel,
    required this.closeKey,
    required this.onClose,
    this.actions = const [],
  });

  final String title;
  final String? meta;
  final String closeLabel;
  final Key closeKey;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RaftSpace.x4,
        RaftSpace.x3,
        RaftSpace.x2,
        RaftSpace.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: RaftTypography.heading(t, size: 15, line: 20),
                  ),
                ),
                if (meta != null)
                  Text(
                    meta!,
                    key: const ValueKey('artifact-files-summary'),
                    style: RaftTypography.body(
                      t,
                      size: 12,
                      line: 16,
                    ).copyWith(color: t.ui.foregroundMuted),
                  ),
              ],
            ),
          ),
          ...actions,
          RaftButton(
            key: closeKey,
            glyph: RaftGlyph.x,
            tooltip: closeLabel,
            semanticLabel: closeLabel,
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.iconMd,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// The version's files, its entry first, each with its size and a download
/// (Web `ArtifactFilesPanel`). A row opens the file in the viewer.
class ArtifactFilesPanel extends StatelessWidget {
  const ArtifactFilesPanel({
    super.key,
    required this.data,
    required this.shownPath,
    required this.onShow,
    required this.onClose,
    this.onDownload,
    this.onDownloadAll,
  });

  final ArtifactViewerData data;

  /// The file shown now (null: the entry).
  final String? shownPath;
  final ValueChanged<String?> onShow;
  final VoidCallback onClose;
  final ValueChanged<ArtifactFile>? onDownload;
  final VoidCallback? onDownloadAll;

  @override
  Widget build(BuildContext context) {
    final files = data.files;
    final rows = [...files.where((f) => f.entry), ...files.where((f) => !f.entry)];
    final total = files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final summary = icuText(
      context,
      '{count, plural, one {# file} other {# files}} · {size}',
      {'count': files.length, 'size': artifactBytes(context, total)},
    );
    final downloadAll = raftText(context, 'Download all');
    return Column(
      key: const ValueKey('artifact-files-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: raftText(context, 'Files'),
          meta: summary,
          closeLabel: raftText(context, 'Close files'),
          closeKey: const ValueKey('artifact-files-close'),
          onClose: onClose,
          actions: [
            if (onDownloadAll != null)
              RaftButton(
                key: const ValueKey('artifact-files-download-all'),
                glyph: RaftGlyph.download,
                tooltip: downloadAll,
                semanticLabel: downloadAll,
                tone: RaftButtonRecipeVariant.ghost,
                size: RaftButtonRecipeSize.iconMd,
                onPressed: onDownloadAll,
              ),
          ],
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('artifact-files-list'),
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            children: [
              for (final file in rows)
                _FileRow(
                  file: file,
                  current: (shownPath ?? data.entry?.path) == file.path,
                  onOpen: () => onShow(file.entry ? null : file.path),
                  onDownload: onDownload == null
                      ? null
                      : () => onDownload!(file),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.current,
    required this.onOpen,
    required this.onDownload,
  });

  final ArtifactFile file;
  final bool current;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final download = raftFormat(context, 'Download {name}', {'name': file.name});
    return RaftListRow(
      key: ValueKey('artifact-files-row-${file.path}'),
      variant: RaftListRowVariant.plain,
      selected: current,
      onPressed: onOpen,
      semanticLabel: file.entry
          ? '${file.path}, ${raftText(context, 'Entry')}'
          : file.path,
      children: [
        RaftListRowIcon(
          file.entry ? RaftGlyph.home : artifactKindGlyph(file.kind),
        ),
        RaftListRowBody(children: [RaftListRowTitle(file.path)]),
        RaftListRowValue(artifactBytes(context, file.sizeBytes)),
        if (onDownload != null)
          RaftButton(
            key: ValueKey('artifact-files-download-${file.path}'),
            glyph: RaftGlyph.download,
            tooltip: raftText(context, 'Download file'),
            semanticLabel: download,
            tone: RaftButtonRecipeVariant.ghost,
            size: RaftButtonRecipeSize.iconSm,
            onPressed: onDownload,
          ),
      ],
    );
  }
}

/// Every version, newest first: its number, Latest, who published it when,
/// its note or changed files (Web `ArtifactVersionHistorySheet`).
class ArtifactVersionsPanel extends StatelessWidget {
  const ArtifactVersionsPanel({
    super.key,
    required this.data,
    required this.onPick,
    required this.onClose,
  });

  final ArtifactViewerData data;

  /// The version to show: null for the latest.
  final ValueChanged<int?> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final card = data.card;
    return Column(
      key: const ValueKey('artifact-version-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: raftText(context, 'Version history'),
          closeLabel: raftText(context, 'Close'),
          closeKey: const ValueKey('artifact-versions-close'),
          onClose: onClose,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            children: [
              for (final version in data.versions)
                RaftListRow(
                  key: ValueKey('artifact-version-row-${version.number}'),
                  variant: RaftListRowVariant.plain,
                  selected: version.number == card.version,
                  onPressed: () {
                    onClose();
                    if (version.number != card.version) {
                      onPick(
                        artifactPinnedFor(version.number, card.latestVersion),
                      );
                    }
                  },
                  children: [
                    RaftListRowBody(
                      children: [
                        RaftListRowTitle(
                          version.number == card.latestVersion
                              ? '${artifactVersionLabel(context, version.number)} · ${raftText(context, 'Latest')}'
                              : artifactVersionLabel(context, version.number),
                        ),
                        RaftListRowDescription(
                          raftFormat(context, '{name} · {time}', {
                            'name': artifactActorName(
                              context,
                              version.publisher,
                            ),
                            'time': artifactRelativeTime(
                              context,
                              version.createdAt,
                            ),
                          }),
                        ),
                        if (_noteOf(context, version) case final String note)
                          RaftListRowDescription(note, wrap: true),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The version's note, else its changed files (Web `useVersionNote`).
String? _noteOf(BuildContext context, ArtifactVersion version) {
  final note = version.note?.trim();
  if (note != null && note.isNotEmpty) return note;
  return artifactChangedFiles(context, version);
}
