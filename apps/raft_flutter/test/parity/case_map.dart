// Explicit coverage map: official case id → Flutter builder. Every
// non-skipped, non-pending case in sharedCases.json that is not in
// [parityCases] counts as NOT COVERED in the parity percentage; cases listed
// in [parityUncovered] carry the reason, everything else defaults to
// "harnessTodo".
import 'cases/ext_computers.dart';
import 'cases/ext_live_activity.dart';
import 'cases/home_tasks.dart';
import 'cases/members_settings.dart';
import 'cases/screens.dart';
import 'cases/thread_composer.dart';
import 'cases/thread_messages.dart';
import 'cases/ui_primitives.dart';
import 'parity_harness.dart';

final Map<String, ParityCase> parityCases = {
  ...uiPrimitiveCases,
  ...threadMessageCases,
  ...threadComposerCases,
  ...homeTaskCases,
  ...membersSettingsCases,
  ...screenCases,
  // Extension suite (tool/parity-ext/cases.json), not official cases.
  ...extComputerCases,
  ...extLiveActivityCases,
};

final Map<String, ParityUncovered> parityUncovered = {
  ...uiPrimitiveUncovered,
  ...threadMessageUncovered,
  ...threadComposerUncovered,
  ...homeTaskUncovered,
  ...membersSettingsUncovered,
  ...screenUncovered,
};
