import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

@RaftPreviews('Unresolved real channel')
Widget channelResolutionPreview() =>
    const RaftChannelResolutionBody(label: 'Loading channel');
