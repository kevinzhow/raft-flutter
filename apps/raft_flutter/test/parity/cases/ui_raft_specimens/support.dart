// Layout vocabulary of tool/parity-ui/host/src/specimens.tsx, shared by the specimen builders.
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// A specimen body: the content of `<div data-specimen>` (inside its 16px padding).
typedef RaftSpecimenBuilder = Widget Function(
  BuildContext context,
  RaftTokens t,
);

/// `flex flex-col gap-4` (the `Stack` of specimens.tsx).
Widget specimenStack(List<Widget> children, {double gap = 16}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

/// `flex flex-wrap items-center gap-3` (the `Row` of specimens.tsx).
Widget specimenRow(List<Widget> children, {double gap = 12}) => Wrap(
  spacing: gap,
  runSpacing: gap,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: children,
);

/// A block that takes the full 358px (`w-full`).
Widget specimenFull(Widget child) =>
    SizedBox(width: double.infinity, child: child);
