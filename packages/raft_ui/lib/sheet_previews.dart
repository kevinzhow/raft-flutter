import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// A form long enough to scroll: the handle and the title row stay put at the
/// top, the actions at the bottom, one body scrolls between them.
@RaftPreviews('Sheet with a scrolling body', size: Size(412, 760))
Widget sheetScrollingPreview() => const _SheetPreview(rows: 24);

/// A short form: the sheet is only as tall as its detent.
@RaftPreviews('Sheet at its medium detent', size: Size(412, 520))
Widget sheetShortPreview() => const _SheetPreview(rows: 3, height: 300);

class _SheetPreview extends StatelessWidget {
  const _SheetPreview({required this.rows, this.height = 700});
  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftSheetSurface(
      height: height,
      child: RaftSheet(
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Create Channel',
              style: RaftTypography.heading(
                t,
                size: 18,
                line: 28,
                color: t.ink,
              ),
            ),
          ),
        ),
        headerExtent: 48,
        padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 1; i <= rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
                child: Text(
                  'Option $i',
                  style: RaftTypography.body(t, size: 14, line: 20),
                ),
              ),
          ],
        ),
        footer: Padding(
          padding: const EdgeInsets.all(RaftSpace.x4),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Create',
              style: RaftTypography.body(
                t,
                size: 14,
                line: 20,
                weight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
