import 'package:flutter/foundation.dart';

import 'message_history.dart';

/// The unverified interval ends immediately before this newer saved row.
class HistoryGap {
  const HistoryGap(this.newerId, this.before, {this.older});
  final String newerId;
  final BigInt before;
  final BigInt? older;
}

abstract class HistoryGapQueries extends ChangeNotifier {
  /// Destructive coverage changes retire all in-memory acceptance proofs.
  int get retirement;
  Object revision(MessageHistoryScope scope);
  Future<List<HistoryGap>> readSaved(MessageHistoryScope scope);
  Future<List<HistoryGap>> read(
    MessageHistoryScope scope,
    List<(String, BigInt)> visible,
  );
}
