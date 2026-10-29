import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Dialog surface and backdrop')
Widget dialogSurfacePreview() => const RaftDialogBackdrop(
  child: Center(
    child: RaftDialogSurface(
      child: Padding(
        padding: EdgeInsets.all(RaftSpace.x4),
        child: Text('Shared dialog surface'),
      ),
    ),
  ),
);
