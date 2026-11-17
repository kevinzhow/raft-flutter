// Port of the Web v1.24 shared channelSideLayout.test.ts: the right-hand
// sections' layout (what a saved value may be, how missing sections are
// placed, what shows, where a dragged section lands).
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';

typedef S = ChannelSideSection;

// A column spec with the default width of 360 (the Web helper's default).
(List<S>, int) c(List<S> sections, [int width = 360]) => (sections, width);

ChannelSideLayout lay(List<(List<S>, int)> columns) => ChannelSideLayout([
  for (final (sections, width) in columns) ChannelSideColumn(sections, width),
]);

// The channel details (added after these cases were written) are left out of
// a shape: their own test checks where they go.
String shape(ChannelSideLayout l) => l.columns
    .map(
      (c) =>
          c.sections.where((s) => s != S.details).map((s) => s.name).join('+'),
    )
    .where((s) => s.isNotEmpty)
    .join(' | ');
String fullShape(ChannelSideLayout l) =>
    l.columns.map((c) => c.sections.map((s) => s.name).join('+')).join(' | ');

Map<String, Object?> raw(List<Object?> sections, Object? width) => {
  'sections': sections,
  'width': width,
};

void main() {
  test(
    'a saved layout is v 1, one to four side columns (and the thread\'s own) of '
    'known sections, none twice, widths 160 to 4000; anything else is not one',
    () {
      expect(
        ChannelSideLayout.parse(ChannelSideLayout.defaults.toJson()),
        ChannelSideLayout.defaults,
      );
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['tasks'], 160),
          ],
        }),
        lay([
          c([S.tasks], 160),
        ]),
        reason: 'as narrow as 160 (#189, rule 2)',
      );
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            {
              ...raw(['tasks'], 300),
              'extra': true,
            },
          ],
          'also': 1,
        }),
        lay([
          c([S.tasks], 300),
        ]),
        reason: 'other keys dropped',
      );
      final five = lay([
        c([S.thread]),
        c([S.tasks]),
        c([S.files]),
        c([S.artifact]),
        c([S.profile]),
      ]);
      expect(
        ChannelSideLayout.parse(five.toJson()),
        five,
        reason: 'four side columns and the thread\'s own',
      );
      expect(
        ChannelSideLayout.parse(
          lay([
            c([S.thread, S.tasks]),
            c([S.files]),
            c([S.artifact]),
            c([S.profile]),
            c([S.thread]),
          ]).toJson(),
        ),
        isNull,
        reason: 'a section twice',
      );
      for (final bad in <Object?>[
        null,
        <Object?>[],
        'x',
        {
          'v': 2,
          'columns': [
            raw(['tasks'], 300),
          ],
        },
        {'v': 1, 'columns': <Object?>[]},
        {
          'v': 1,
          'columns': List.generate(5, (_) => raw(['tasks'], 300)),
        },
        {
          'v': 1,
          'columns': [
            for (final s in [
              ['thread'],
              ['tasks'],
              ['files'],
              ['artifact'],
              ['profile'],
              ['thread'],
            ])
              raw(s, 300),
          ],
        },
        {
          'v': 1,
          'columns': [raw([], 300)],
        },
        {
          'v': 1,
          'columns': [
            raw(['board'], 300),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], 300),
            raw(['tasks'], 300),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], 159),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], 4001),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], 300.5),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], double.nan),
          ],
        },
        {
          'v': 1,
          'columns': [
            raw(['tasks'], '300'),
          ],
        },
        {
          'v': 1,
          'columns': [
            {'sections': 'tasks', 'width': 300},
          ],
        },
        {
          'v': 1,
          'columns': [
            ['tasks'],
          ],
        },
      ]) {
        expect(ChannelSideLayout.parse(bad), isNull, reason: '$bad');
      }
    },
  );

  test(
    'a whole-number width decoded as a double is still an integer width',
    () {
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['tasks'], 300.0),
          ],
        }),
        lay([
          c([S.tasks], 300),
        ]),
      );
    },
  );

  test(
    'a section this build doesn\'t know (a newer client\'s) is dropped, not the '
    'whole layout; a column of only those goes too',
    () {
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['profile', 'futureSection'], 400),
          ],
        }),
        lay([
          c([S.profile], 400),
        ]),
      );
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['tasks'], 300),
            raw(['futureSection'], 360),
            raw(['artifact', 7], 480),
          ],
        }),
        lay([
          c([S.tasks], 300),
          c([S.artifact], 480),
        ]),
      );
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['futureSection'], 360),
          ],
        }),
        isNull,
        reason: 'nothing known left',
      );
    },
  );

  test(
    'a layout saved with the retired execution record ("record") reads without it',
    () {
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['thread'], 400),
            raw(['profile', 'record', 'context'], 400),
            raw(['record'], 360),
          ],
        }),
        lay([
          c([S.thread], 400),
          c([S.profile, S.context], 400),
        ]),
      );
    },
  );

  test('completing places each missing section where the default would: thread '
      'first, Tasks or Files under the other, the Artifact and the profile in '
      'columns of their own last', () {
    String done(ChannelSideLayout l) => shape(l.complete());
    expect(
      done(
        lay([
          c([S.tasks]),
        ]),
      ),
      'thread | tasks+files | artifact | profile+context',
    );
    expect(
      done(
        lay([
          c([S.thread, S.files]),
        ]),
      ),
      'thread+files+tasks | artifact | profile+context',
      reason: 'Tasks under Files, wherever that is',
    );
    expect(
      done(
        lay([
          c([S.files]),
          c([S.thread]),
        ]),
      ),
      'files+tasks | thread | artifact | profile+context',
    );
    expect(
      done(ChannelSideLayout.defaults),
      'thread | tasks+files | artifact | profile+context',
    );
    expect(
      ChannelSideLayout.defaults.complete(),
      ChannelSideLayout.defaults,
      reason: 'the default is complete',
    );
    // Tasks and Files apart (before the Artifact and the profile were
    // sections): four side columns and the thread's own; one already at four
    // side columns takes the others at the bottom of its last.
    expect(
      done(
        lay([
          c([S.thread]),
          c([S.tasks]),
          c([S.files]),
        ]),
      ),
      'thread | tasks | files | artifact | profile+context',
    );
    expect(
      done(
        lay([
          c([S.thread, S.tasks]),
          c([S.files]),
        ]),
      ),
      'thread+tasks | files | artifact | profile+context',
    );
    expect(
      done(
        lay([
          c([S.thread, S.tasks]),
          c([S.files]),
          c([S.artifact]),
        ]),
      ),
      'thread+tasks | files | artifact | profile+context',
    );
    expect(
      done(
        lay([
          c([S.thread, S.tasks]),
          c([S.files]),
          c([S.profile]),
          c([S.artifact]),
        ]),
      ),
      'thread+tasks | files | profile+context | artifact',
    );
    expect(
      lay([
        c([S.tasks]),
      ]).complete().columns[2].width,
      480,
      reason: 'the Artifact\'s own column: its 480',
    );
    expect(
      lay([
        c([S.tasks]),
      ]).complete().columns[3].width,
      400,
      reason: 'the profile\'s: 400',
    );
    // The context view, added after the others: under the profile wherever
    // it is, else a column of its own.
    expect(
      done(
        lay([
          c([S.thread]),
          c([S.profile]),
          c([S.tasks, S.files]),
          c([S.artifact]),
        ]),
      ),
      'thread | profile+context | tasks+files | artifact',
    );
    expect(
      done(
        lay([
          c([S.thread]),
          c([S.tasks, S.files, S.profile]),
          c([S.artifact]),
        ]),
      ),
      'thread | tasks+files+profile+context | artifact',
    );
  });

  test(
    'a column\'s minimum is its widest section\'s: the thread\'s 360, the Artifact\'s 480, the profile\'s 320, else 280',
    () {
      expect(channelSideColumnMinWidth([S.tasks, S.files]), 280);
      expect(channelSideColumnMinWidth([S.tasks, S.thread]), 360);
      expect(channelSideColumnMinWidth([S.artifact, S.tasks]), 480);
      expect(channelSideColumnMinWidth([S.profile]), 320);
      expect(channelSideColumnMinWidth([]), 0);
    },
  );

  test('only columns with an open section show, with only those sections', () {
    final l = lay([
      c([S.thread], 400),
      c([S.tasks, S.files], 360),
    ]);
    List<String> view(Set<S> open) => [
      for (final v in l.visible(open))
        '${v.column}:${v.sections.map((s) => s.name).join('+')}:${v.minWidth}',
    ];
    expect(view({S.tasks}), ['1:tasks:280']);
    expect(view({S.thread, S.files}), ['0:thread:360', '1:files:280']);
    expect(view({}), isEmpty);
    expect(l.visible({S.tasks}).single.width, 360);
  });

  group('into a column', () {
    final l = ChannelSideLayout.defaults.complete();
    ChannelSideLayout move(S s, int column, S? before) =>
        l.move(s, ChannelSideDropInto(column, before));

    test('before a section or at the bottom; a column left empty goes', () {
      expect(
        shape(move(S.files, 1, S.tasks)),
        'thread | files+tasks | artifact | profile+context',
      );
      expect(
        shape(move(S.tasks, 0, null)),
        'thread+tasks | files | artifact | profile+context',
      );
      expect(
        shape(move(S.thread, 1, S.files)),
        'tasks+thread+files | artifact | profile+context',
        reason: 'the thread\'s own column, now empty, goes',
      );
      expect(
        shape(move(S.profile, 2, null)),
        'thread | tasks+files | artifact+profile+context',
        reason:
            'the profile stacks under the Artifact, its context view with it',
      );
      expect(
        move(S.profile, 2, null).columns[2].width,
        480,
        reason: 'the column it joins keeps its width',
      );
    });

    test('where it already is, or nowhere: unchanged (the same object)', () {
      expect(identical(move(S.tasks, 1, S.files), l), isTrue);
      expect(identical(move(S.tasks, 1, S.tasks), l), isTrue);
      expect(
        identical(move(S.tasks, 7, null), l),
        isTrue,
        reason: 'no such column',
      );
      expect(identical(move(S.tasks, -1, null), l), isTrue);
      expect(
        identical(move(S.tasks, 0, S.files), l),
        isTrue,
        reason: 'before a section that is not in that column',
      );
    });

    test('a column left with closed sections stays', () {
      // The layout never knows what is open: only a column with no section at
      // all goes, so Files alone in a column of its own stays when Tasks move.
      final apart = lay([
        c([S.thread]),
        c([S.tasks]),
        c([S.files]),
        c([S.artifact]),
        c([S.profile, S.context, S.details]),
      ]);
      final moved = apart.move(S.tasks, const ChannelSideDropInto(0, null));
      expect(shape(moved), 'thread+tasks | files | artifact | profile+context');
    });
  });

  group('a new column', () {
    final l = ChannelSideLayout.defaults.complete();

    test(
      'at the edges; alone it keeps its column\'s width, out of a stack its own default',
      () {
        final split = l.move(S.files, const ChannelSideDropNewColumn(2));
        expect(
          shape(split),
          'thread | tasks | files | artifact | profile+context',
          reason: 'four side columns and the thread\'s own',
        );
        expect(
          split.columns[2].width,
          360,
          reason: 'out of a stack: Files\' own default',
        );
        expect(
          shape(l.move(S.tasks, const ChannelSideDropNewColumn(0))),
          'tasks | thread | files | artifact | profile+context',
        );
        expect(
          identical(l.move(S.thread, const ChannelSideDropNewColumn(0)), l),
          isTrue,
          reason: 'alone at its own left edge',
        );
        expect(
          identical(l.move(S.thread, const ChannelSideDropNewColumn(1)), l),
          isTrue,
          reason: 'alone at its own right edge',
        );
        expect(
          shape(l.move(S.thread, const ChannelSideDropNewColumn(2))),
          'tasks+files | thread | artifact | profile+context',
          reason: 'a lone section moving: same count',
        );
      },
    );

    test('the profile moved left of Tasks\' column keeps its saved width', () {
      final wide = l
          .move(S.context, const ChannelSideDropInto(2, null))
          .resize(3, 520);
      final moved = wide.move(S.profile, const ChannelSideDropNewColumn(1));
      expect(shape(moved), 'thread | profile | tasks+files | artifact+context');
      expect(moved.columns[1].width, 520);
    });

    test('at most four side columns; stacking is always a place', () {
      final split = l.move(S.files, const ChannelSideDropNewColumn(2));
      expect(
        identical(
          split.move(S.artifact, const ChannelSideDropInto(4, null)),
          split,
        ),
        isFalse,
      );
      final full = lay([
        c([S.thread, S.tasks]),
        c([S.files]),
        c([S.artifact]),
        c([S.profile]),
      ]);
      expect(
        shape(full.move(S.tasks, const ChannelSideDropNewColumn(4))),
        'thread | files | artifact | profile | tasks',
      );
      // The thread out of a stack into a column of its own doesn't count
      // among them.
      final stacked = lay([
        c([S.thread, S.tasks]),
        c([S.files]),
        c([S.artifact]),
        c([S.profile]),
      ]);
      expect(
        shape(stacked.move(S.thread, const ChannelSideDropNewColumn(0))),
        'thread | tasks | files | artifact | profile',
      );
    });
  });

  test('resizing rounds and keeps the width within the saved range', () {
    final l = ChannelSideLayout.defaults.complete();
    expect(l.resize(1, 410.6).columns[1].width, 411);
    expect(
      l.resize(1, 10).columns[1].width,
      160,
      reason: 'a column goes to 160 (#189); its sections clip',
    );
    expect(l.resize(1, 99999).columns[1].width, 4000);
    expect(identical(l.resize(1, 360), l), isTrue, reason: 'unchanged');
    expect(identical(l.resize(5, 400), l), isTrue);
    expect(identical(l.resize(-1, 400), l), isTrue);
    expect(identical(l.resize(1, double.nan), l), isTrue);
    expect(l.resize(1, 500).columns[0].width, 400, reason: 'only that column');
  });

  test('the context view (View Context) follows the profile, and never holds a '
      'column alone (a closed one would count among the four)', () {
    final l = ChannelSideLayout.defaults.complete();
    expect(shape(l), 'thread | tasks+files | artifact | profile+context');
    expect(channelSideColumnMinWidth([S.context]), 320);
    // The profile into the Artifact's column, Files split out; the Artifact
    // may still move out.
    final profileIn = l.move(S.profile, const ChannelSideDropInto(2, null));
    expect(shape(profileIn), 'thread | tasks+files | artifact+profile+context');
    final filesOut = profileIn.move(S.files, const ChannelSideDropNewColumn(2));
    expect(
      shape(filesOut),
      'thread | tasks | files | artifact+profile+context',
    );
    final artifactOut = filesOut.move(
      S.artifact,
      const ChannelSideDropNewColumn(4),
    );
    expect(
      artifactOut,
      isNot(filesOut),
      reason:
          'the Artifact moves to a column of its own: no hidden '
          'context column takes the fourth place',
    );
    expect(
      shape(artifactOut),
      'thread | tasks | files | profile+context | artifact',
    );

    // Moving the profile carries the context view, into a stack or into a
    // column of its own.
    expect(
      shape(l.move(S.profile, const ChannelSideDropInto(1, S.files))),
      'thread | tasks+profile+context+files | artifact',
    );
    final own = profileIn.move(S.profile, const ChannelSideDropNewColumn(1));
    expect(shape(own), 'thread | profile+context | tasks+files | artifact');
    expect(
      own.columns[1].width,
      channelSideSectionWidth(S.profile),
      reason: 'out of a stack: the profile\'s own width',
    );

    // Out of a stack shared with others, the context view goes with the
    // profile rather than staying in that stack.
    final stacked = lay([
      c([S.thread]),
      c([S.tasks, S.files, S.profile, S.context]),
      c([S.artifact]),
    ]);
    expect(
      shape(stacked.move(S.profile, const ChannelSideDropNewColumn(2))),
      'thread | tasks+files | profile+context | artifact',
    );
    // Moved by itself it stays where it is put; the profile then moves alone.
    final contextMoved = l.move(S.context, const ChannelSideDropInto(1, null));
    expect(
      shape(contextMoved),
      'thread | tasks+files+context | artifact | profile',
    );
    expect(
      shape(contextMoved.move(S.profile, const ChannelSideDropInto(2, null))),
      'thread | tasks+files+context | artifact+profile',
    );
    // Dropped into a column of its own, it goes back under the profile:
    // nothing changes.
    expect(l.move(S.context, const ChannelSideDropNewColumn(4)), l);
  });

  test(
    'a stored layout with a column holding only the context view normalises to it under the profile',
    () {
      String done(List<(List<S>, int)> columns) =>
          shape(lay(columns).complete());
      expect(
        done([
          c([S.thread]),
          c([S.tasks, S.files]),
          c([S.profile]),
          c([S.context]),
          c([S.artifact]),
        ]),
        'thread | tasks+files | profile+context | artifact',
      );
      expect(
        done([
          c([S.context]),
          c([S.thread]),
          c([S.tasks, S.files]),
          c([S.artifact, S.profile]),
        ]),
        'thread | tasks+files | artifact+profile+context',
      );
      expect(
        done([
          c([S.thread]),
          c([S.context]),
          c([S.tasks, S.files]),
          c([S.profile]),
        ]),
        'thread | tasks+files | profile+context | artifact',
      );
      // A layout saved before the context view existed gets it under the profile.
      expect(
        done([
          c([S.thread]),
          c([S.tasks, S.files]),
          c([S.artifact]),
          c([S.profile]),
        ]),
        'thread | tasks+files | artifact | profile+context',
      );
    },
  );

  test(
    'the channel details follow the profile: under it by default, carried with it, never a column alone',
    () {
      expect(
        fullShape(ChannelSideLayout.defaults),
        'thread | tasks+files | artifact | profile+context+details',
      );
      // A layout saved before the details existed gets them under the profile,
      // after the context view.
      expect(
        fullShape(
          lay([
            c([S.thread]),
            c([S.tasks, S.files]),
            c([S.profile, S.context]),
            c([S.artifact]),
          ]).complete(),
        ),
        'thread | tasks+files | profile+context+details | artifact',
      );
      final l = ChannelSideLayout.defaults.complete();
      // The profile carries them.
      expect(
        fullShape(l.move(S.profile, const ChannelSideDropInto(2, null))),
        'thread | tasks+files | artifact+profile+context+details',
      );
      // Moved by themselves into a stack they stay there; dropped into a column
      // of their own they go back under the profile.
      expect(
        fullShape(l.move(S.details, const ChannelSideDropInto(1, null))),
        'thread | tasks+files+details | artifact | profile+context',
      );
      expect(l.move(S.details, const ChannelSideDropNewColumn(4)), l);
      expect(
        fullShape(
          lay([
            c([S.thread]),
            c([S.details]),
            c([S.tasks, S.files]),
            c([S.profile]),
          ]).complete(),
        ),
        'thread | tasks+files | profile+context+details | artifact',
      );
      expect(channelSideColumnMinWidth([S.details]), 320);
      // A reader that knows them keeps them where they were saved.
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['thread'], 400),
            raw(['profile', 'details'], 400),
          ],
        }),
        lay([
          c([S.thread], 400),
          c([S.profile, S.details], 400),
        ]),
      );
      // A section a reader doesn't know is dropped and the rest kept.
      expect(
        ChannelSideLayout.parse({
          'v': 1,
          'columns': [
            raw(['thread'], 400),
            raw(['profile', 'not-yet-a-section'], 400),
          ],
        }),
        lay([
          c([S.thread], 400),
          c([S.profile], 400),
        ]),
      );
    },
  );

  test(
    'toJson is the saved shape: v 1 and each column\'s sections and width',
    () {
      expect(
        lay([
          c([S.thread], 400),
          c([S.tasks, S.files], 360),
        ]).toJson(),
        {
          'v': 1,
          'columns': [
            {
              'sections': ['thread'],
              'width': 400,
            },
            {
              'sections': ['tasks', 'files'],
              'width': 360,
            },
          ],
        },
      );
      expect(ChannelSideLayout.defaults.toJson()['columns'], hasLength(4));
    },
  );

  test('same compares columns, sections and widths', () {
    final a = lay([
      c([S.tasks, S.files], 360),
    ]);
    expect(
      a.same(
        lay([
          c([S.tasks, S.files], 360),
        ]),
      ),
      isTrue,
    );
    expect(
      a.same(
        lay([
          c([S.files, S.tasks], 360),
        ]),
      ),
      isFalse,
    );
    expect(
      a.same(
        lay([
          c([S.tasks, S.files], 361),
        ]),
      ),
      isFalse,
    );
    expect(
      a.same(
        lay([
          c([S.tasks, S.files]),
          c([S.thread]),
        ]),
      ),
      isFalse,
    );
  });

  test(
    'the Tasks, Files and thread sections are part of the layout\'s defaults',
    () {
      expect(channelSideSectionWidth(S.thread), 400);
      expect(channelSideSectionWidth(S.tasks), 360);
      expect(channelSideSectionWidth(S.artifact), 480);
      expect(channelSideSectionWidth(S.details), 400);
      expect(channelSideMaxColumns, 4);
      expect(channelSideMinSavedWidth, 160);
      expect(channelSideMaxSavedWidth, 4000);
      expect(channelSideSectionMinWidth[S.thread], 360);
    },
  );
}
