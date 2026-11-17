// Settings > Account > Danger zone: Delete Account (Web features/settings/
// account/DeleteAccountSection.tsx), the last thing on the page. Its button
// opens the Delete Account page (/s/<slug>/settings/account/delete).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

class AccountDeleteSection extends StatelessWidget {
  const AccountDeleteSection({super.key, required this.onOpen});

  /// Opens the Delete Account page, keeping the query.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    String tr(String s) => raftText(context, s);
    return Column(
      key: const ValueKey('account-deletion-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSettingsSectionHeader(
          label: tr('Danger zone'),
          glyph: RaftGlyph.triangleAlert,
        ),
        RaftSettingsActionCard(
          key: const ValueKey('account-deletion-card'),
          stacked: true,
          title: tr('Delete account'),
          description: tr(
            "Sign out everywhere and schedule your account for deletion. You can cancel until the date it's deleted.",
          ),
          action: RaftSettingsRecipeButton(
            key: const ValueKey('account-deletion-open'),
            label: tr('Delete account'),
            glyph: RaftGlyph.trash2,
            glyphSize: 14,
            variant: RaftButtonRecipeVariant.danger,
            onPressed: onOpen,
          ),
        ),
        const SizedBox(height: RaftSpace.x6),
      ],
    );
  }
}
