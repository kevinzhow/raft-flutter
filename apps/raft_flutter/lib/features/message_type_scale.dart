import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// Resolves the display size of the existing sm/md/lg preference mapping.
/// Persistence and profile fallback remain owned by personal_presentation.
double messagePreferenceDisplaySize(BuildContext context, double legacySize) =>
    RaftMessageSizeTier.of(legacySize).bodySizeFor(RaftTokens.of(context));
