import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Activity pending results', size: Size(440, 600))
Widget activityLoadingPreview() => const RaftActivityLoadingList();
