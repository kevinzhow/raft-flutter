import 'package:flutter/widgets.dart';
import 'package:raft_ui/previews.dart';

import 'message_history_gaps.dart';

@RaftPreviews('Saved history gap', size: Size(360, 250))
Widget savedHistoryGapPreview() => Center(child: const HistoryGapNotice());
@RaftPreviews('Saved history gap loading', size: Size(360, 250))
Widget savedHistoryGapLoadingPreview() =>
    const Center(child: HistoryGapNotice());
@RaftPreviews('Saved history gap error', size: Size(360, 250))
Widget savedHistoryGapRetryPreview() =>
    Center(child: HistoryGapNotice(failed: true, onRetry: () {}));

@RaftPreviews('Saved history gap offline', size: Size(360, 250))
Widget savedHistoryGapOfflinePreview() =>
    const Center(child: HistoryGapNotice(offline: true));
