// The layout of the sections right of the conversation (Web v1.24
// `shared/src/channelSideLayout.ts`): Thread, Tasks, Files, the Artifact, the
// profile, the context view and the channel details, in one or more columns
// right of the conversation, each column a vertical stack. One per person per
// server, saved in the server sidebar order as `channelSideLayout`.
//
// Only the shape is checked here: a stored value that is not one (an unknown
// section, too many columns, a width out of range) reads as "never saved" and
// the default applies. Fitting the columns into a window is the area's, at
// render time; it never rewrites what is saved. Pure Dart, no I/O.
import 'package:flutter/foundation.dart';

/// Below this width the Tasks and Files headers compact their controls.
const channelSideCompactHeaderWidth = 240.0;

enum ChannelSideSection {
  thread,
  tasks,
  files,
  artifact,
  profile,
  context,
  details;

  static final _byName = ChannelSideSection.values.asNameMap();

  /// The section a saved name means; null for one this build doesn't know.
  static ChannelSideSection? fromName(Object? name) =>
      name is String ? _byName[name] : null;
}

/// At most four side columns, besides one of the thread's own (the thread is a
/// layer of the conversation).
const channelSideMaxColumns = 4;

/// A column may be dragged as narrow as 160; its sections keep their own
/// minimum, clipped.
const channelSideMinSavedWidth = 160;
const channelSideMaxSavedWidth = 4000;

/// A section's narrowest readable width; a column's is its widest section's
/// ([channelSideColumnMinWidth]).
const channelSideSectionMinWidth = <ChannelSideSection, int>{
  ChannelSideSection.thread: 360,
  ChannelSideSection.tasks: 280,
  ChannelSideSection.files: 280,
  ChannelSideSection.artifact: 480,
  ChannelSideSection.profile: 320,
  ChannelSideSection.context: 320,
  ChannelSideSection.details: 320,
};

/// A column's narrowest readable width: its widest section's minimum.
int channelSideColumnMinWidth(Iterable<ChannelSideSection> sections) {
  var widest = 0;
  for (final section in sections) {
    final min = channelSideSectionMinWidth[section]!;
    if (min > widest) widest = min;
  }
  return widest;
}

/// The sections that follow the profile (the context behind an agent's message
/// and the channel details): placed under it, carried with it, never left
/// alone in a column, so a closed one never takes one of the four side columns.
const _profileFollowers = [
  ChannelSideSection.context,
  ChannelSideSection.details,
];
bool _followsProfile(ChannelSideSection s) => _profileFollowers.contains(s);

/// A section's column of its own where it has none to keep (a new one, or out
/// of a stack): the default layout's width.
int channelSideSectionWidth(ChannelSideSection section) {
  for (final column in ChannelSideLayout.defaults.columns) {
    if (column.sections.contains(section)) return column.width;
  }
  return 360;
}

@immutable
class ChannelSideColumn {
  /// Top to bottom; every section is in exactly one column.
  const ChannelSideColumn(this.sections, this.width);
  final List<ChannelSideSection> sections;

  /// The column's width in px when there is room for it.
  final int width;

  @override
  bool operator ==(Object other) =>
      other is ChannelSideColumn &&
      other.width == width &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(width, Object.hashAll(sections));

  @override
  String toString() => '${sections.map((s) => s.name).join('+')}@$width';
}

/// A column with open sections, for the area to lay out.
class VisibleChannelSideColumn {
  const VisibleChannelSideColumn({
    required this.column,
    required this.sections,
    required this.width,
    required this.minWidth,
  });

  /// The column's index in the layout.
  final int column;

  /// Its open sections, top to bottom.
  final List<ChannelSideSection> sections;
  final int width;
  final int minWidth;
}

/// Where a dragged section lands.
sealed class ChannelSideDrop {
  const ChannelSideDrop();
}

/// Into column [column] before its section [before] (null: at the bottom).
/// Indices are the layout's; [before] names a section, so closed sections in
/// between do not shift it.
class ChannelSideDropInto extends ChannelSideDrop {
  const ChannelSideDropInto(this.column, this.before);
  final int column;
  final ChannelSideSection? before;
}

/// As a new column before the column [at] (the layout's index;
/// `columns.length` for a new last column).
class ChannelSideDropNewColumn extends ChannelSideDrop {
  const ChannelSideDropNewColumn(this.at);
  final int at;
}

@immutable
class ChannelSideLayout {
  /// Left to right, right of the conversation.
  const ChannelSideLayout(this.columns);
  final List<ChannelSideColumn> columns;

  /// Before anyone drags: the thread in a column of its own, Tasks over Files
  /// right of it, then the Artifact, then the profile with the context view and
  /// the channel details under it.
  static const defaults = ChannelSideLayout([
    ChannelSideColumn([ChannelSideSection.thread], 400),
    ChannelSideColumn([
      ChannelSideSection.tasks,
      ChannelSideSection.files,
    ], 360),
    ChannelSideColumn([ChannelSideSection.artifact], 480),
    ChannelSideColumn([
      ChannelSideSection.profile,
      ChannelSideSection.context,
      ChannelSideSection.details,
    ], 400),
  ]);

  static bool _isThreadAlone(ChannelSideColumn column) =>
      column.sections.length == 1 &&
      column.sections.single == ChannelSideSection.thread;

  /// The thread's column of its own doesn't count among the side columns.
  static int _sideCount(List<ChannelSideColumn> columns) =>
      columns.where((column) => !_isThreadAlone(column)).length;

  /// The layout [raw] is, or null when it is not one: `v` 1; 1 to 4 side
  /// columns (and the thread's own); each with at least one section, no
  /// section twice in the whole layout; an integer width from 160 to 4000. A
  /// section this build doesn't know is dropped, and a column left with none
  /// goes too, so an older reader keeps the person's layout. Sections missing
  /// are allowed ([complete] places them). Returns a fresh copy without any
  /// other keys.
  static ChannelSideLayout? parse(Object? raw) {
    if (raw is! Map) return null;
    final v = raw['v'], columns = raw['columns'];
    if (v is! num || v != 1) return null;
    if (columns is! List ||
        columns.isEmpty ||
        columns.length > channelSideMaxColumns + 1) {
      return null;
    }
    final seen = <ChannelSideSection>{};
    final parsed = <ChannelSideColumn>[];
    for (final column in columns) {
      if (column is! Map) return null;
      final sections = column['sections'], width = column['width'];
      if (sections is! List || sections.isEmpty) return null;
      if (width is! num ||
          !width.isFinite ||
          width != width.truncateToDouble() ||
          width < channelSideMinSavedWidth ||
          width > channelSideMaxSavedWidth) {
        return null;
      }
      final own = <ChannelSideSection>[];
      for (final name in sections) {
        // A section this build doesn't know (a newer client's): dropped.
        final section = ChannelSideSection.fromName(name);
        if (section == null) continue;
        if (!seen.add(section)) return null;
        own.add(section);
      }
      // A column of only unknown sections goes with them.
      if (own.isNotEmpty) parsed.add(ChannelSideColumn(own, width.toInt()));
    }
    if (parsed.isEmpty || _sideCount(parsed) > channelSideMaxColumns) {
      return null;
    }
    return ChannelSideLayout(parsed);
  }

  /// Every section placed exactly once: a section the layout lacks goes where
  /// the default puts it, after the sections it follows there (the thread into
  /// a new first column; Tasks or Files under the other one, or into a new last
  /// column; the Artifact and the profile into a new last column, or at the
  /// bottom of the last one where there is none to make; the context view and
  /// the channel details under the profile, else the same way). A column
  /// holding only those is not kept: it goes under the profile.
  ChannelSideLayout complete() {
    final columns = [
      for (final column in this.columns)
        ChannelSideColumn([...column.sections], column.width),
    ];
    final placed = {for (final column in columns) ...column.sections};
    for (final section in ChannelSideSection.values) {
      if (placed.contains(section)) continue;
      ChannelSideColumn? profileColumn;
      if (_followsProfile(section)) {
        for (final column in columns) {
          if (column.sections.contains(ChannelSideSection.profile)) {
            profileColumn = column;
            break;
          }
        }
      }
      if (section == ChannelSideSection.thread) {
        columns.insert(
          0,
          ChannelSideColumn([
            ChannelSideSection.thread,
          ], defaults.columns[0].width),
        );
      } else if (profileColumn != null) {
        profileColumn.sections.add(section);
      } else if (section == ChannelSideSection.artifact ||
          section == ChannelSideSection.profile ||
          _followsProfile(section)) {
        if (_sideCount(columns) < channelSideMaxColumns) {
          columns.add(
            ChannelSideColumn([section], channelSideSectionWidth(section)),
          );
        } else {
          columns.last.sections.add(section);
        }
      } else {
        ChannelSideColumn? sibling;
        for (final column in columns) {
          if (column.sections.any(
            (s) =>
                s == ChannelSideSection.tasks || s == ChannelSideSection.files,
          )) {
            sibling = column;
          }
        }
        if (sibling != null) {
          sibling.sections.add(section);
        } else if (_sideCount(columns) < channelSideMaxColumns) {
          columns.add(ChannelSideColumn([section], defaults.columns[1].width));
        } else {
          columns.last.sections.add(section);
        }
      }
      placed.add(section);
    }
    return _foldFollowerOnlyColumns(columns);
  }

  /// The columns with an open section, left to right; a column with none shows
  /// nothing.
  List<VisibleChannelSideColumn> visible(Set<ChannelSideSection> open) {
    final result = <VisibleChannelSideColumn>[];
    for (var index = 0; index < columns.length; index++) {
      final column = columns[index];
      final sections = column.sections.where(open.contains).toList();
      if (sections.isEmpty) continue;
      result.add(
        VisibleChannelSideColumn(
          column: index,
          sections: sections,
          width: column.width,
          minWidth: channelSideColumnMinWidth(sections),
        ),
      );
    }
    return result;
  }

  /// The layout with [section] moved to [drop]. A column left with no section
  /// at all disappears; one left with only closed sections stays. A section
  /// moved out alone keeps its column's width; out of a stack it takes its own
  /// default width. Returns this layout (the same object) when the drop is where
  /// the section already is, or would make a fifth side column. The profile
  /// carries the context view and details right under it, and no column is left
  /// holding only those (they go under the profile).
  ChannelSideLayout move(ChannelSideSection section, ChannelSideDrop drop) {
    final from = columns.indexWhere((c) => c.sections.contains(section));
    if (from < 0) return this;
    final moving = _movingSections(columns[from].sections, section);
    ChannelSideColumn without(ChannelSideColumn column) => ChannelSideColumn(
      column.sections.where((s) => !moving.contains(s)).toList(),
      column.width,
    );
    switch (drop) {
      case ChannelSideDropInto(:final column, :final before):
        if (column < 0 ||
            column >= columns.length ||
            (before != null && moving.contains(before))) {
          return this;
        }
        if (before != null && !columns[column].sections.contains(before)) {
          return this;
        }
        final next = columns.map(without).toList();
        final into = next[column].sections;
        into.insertAll(
          before == null ? into.length : into.indexOf(before),
          moving,
        );
        final folded = _foldFollowerOnlyColumns(
          next.where((c) => c.sections.isNotEmpty).toList(),
        );
        return folded.same(this) ? this : folded;
      case ChannelSideDropNewColumn(:final at):
        if (at < 0 || at > columns.length) return this;
        final alone = columns[from].sections.every(moving.contains);
        // Dropping a section that is alone in its column at either of its own
        // edges changes nothing.
        if (alone && (at == from || at == from + 1)) return this;
        // Its saved width goes with it: alone, its column's; out of a stack,
        // its own default.
        final width = alone
            ? columns[from].width
            : channelSideSectionWidth(section);
        final next = columns.map(without).toList()
          ..insert(at, ChannelSideColumn([...moving], width));
        final folded = _foldFollowerOnlyColumns(
          next.where((c) => c.sections.isNotEmpty).toList(),
        );
        if (folded.same(this)) return this;
        return _sideCount(folded.columns) > channelSideMaxColumns
            ? this
            : folded;
    }
  }

  /// What a move of [section] takes along: the profile carries the context
  /// view and details sitting right under it, so a closed one never stays
  /// behind alone.
  static List<ChannelSideSection> _movingSections(
    List<ChannelSideSection> sections,
    ChannelSideSection section,
  ) {
    if (section != ChannelSideSection.profile) return [section];
    final moving = [ChannelSideSection.profile];
    for (
      var at = sections.indexOf(ChannelSideSection.profile) + 1;
      at < sections.length && _followsProfile(sections[at]);
      at++
    ) {
      moving.add(sections[at]);
    }
    return moving;
  }

  /// A column holding only the context view or the details is not kept: it goes
  /// under the profile instead, among what already follows it. Such a column,
  /// its sections closed, would show nothing and still count among the four
  /// side columns.
  static ChannelSideLayout _foldFollowerOnlyColumns(
    List<ChannelSideColumn> columns,
  ) {
    final unchanged = ChannelSideLayout(columns);
    final withProfile = columns.indexWhere(
      (c) => c.sections.contains(ChannelSideSection.profile),
    );
    final lone = columns
        .where((c) => c.sections.every(_followsProfile))
        .toList();
    if (lone.isEmpty || withProfile < 0) return unchanged;
    final kept = [
      for (final column in columns)
        if (!lone.contains(column))
          ChannelSideColumn([...column.sections], column.width),
    ];
    final profile = kept
        .firstWhere((c) => c.sections.contains(ChannelSideSection.profile))
        .sections;
    final start = profile.indexOf(ChannelSideSection.profile) + 1;
    var end = start;
    while (end < profile.length && _followsProfile(profile[end])) {
      end++;
    }
    // The run under the profile, in the default's order.
    final run =
        [
          ...profile.sublist(start, end),
          for (final column in lone) ...column.sections,
        ]..sort(
          (x, y) => _profileFollowers.indexOf(x) - _profileFollowers.indexOf(y),
        );
    profile.replaceRange(start, end, run);
    return ChannelSideLayout(kept);
  }

  /// The layout with column [column] [width] px wide (rounded, within the saved
  /// range); this layout when nothing changes.
  ChannelSideLayout resize(int column, num width) {
    if (column < 0 || column >= columns.length || width.isNaN) return this;
    final clamped = width
        .clamp(channelSideMinSavedWidth, channelSideMaxSavedWidth)
        .round();
    if (columns[column].width == clamped) return this;
    return ChannelSideLayout([
      for (var i = 0; i < columns.length; i++)
        i == column
            ? ChannelSideColumn([...columns[i].sections], clamped)
            : columns[i],
    ]);
  }

  /// The saved shape: `{"v":1,"columns":[{"sections":[...],"width":n}]}`.
  Map<String, Object?> toJson() => {
    'v': 1,
    'columns': [
      for (final column in columns)
        {
          'sections': [for (final s in column.sections) s.name],
          'width': column.width,
        },
    ],
  };

  bool same(ChannelSideLayout other) => listEquals(columns, other.columns);

  @override
  bool operator ==(Object other) => other is ChannelSideLayout && same(other);

  @override
  int get hashCode => Object.hashAll(columns);

  @override
  String toString() => columns.join(' | ');
}
