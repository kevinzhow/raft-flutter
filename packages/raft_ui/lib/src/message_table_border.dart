import 'package:flutter/material.dart';

/// CSS collapsed borders straddle the outside grid lines, while Flutter's
/// default TableBorder paints the outer border entirely inside its rectangle.
/// Caller allocates half-stroke cell and outer padding for uniform CSS grids.
class MessageCollapsedTableBorder extends TableBorder {
  MessageCollapsedTableBorder({required Color color, required double width}) : super(
    top: BorderSide(color: color, width: width),
    right: BorderSide(color: color, width: width),
    bottom: BorderSide(color: color, width: width),
    left: BorderSide(color: color, width: width),
    horizontalInside: BorderSide(color: color, width: width),
    verticalInside: BorderSide(color: color, width: width),
  );

  @override
  void paint(Canvas canvas, Rect rect, {required Iterable<double> rows, required Iterable<double> columns}) {
    final halfStroke = top.width / 2;
    // Expanding the outer paint rect changes its origin. Offset the supplied
    // relative grid positions equally so internal borders stay on their cells.
    super.paint(canvas, rect.inflate(halfStroke),
      rows: rows.map((position) => position + halfStroke),
      columns: columns.map((position) => position + halfStroke));
  }
}
