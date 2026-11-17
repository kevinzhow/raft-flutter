// Web v1.24.0 Settings › Account › Session (features/settings/account/
// AccountSignOutSection.tsx): a settings row in a ListRowGroup with the
// warning Sign out button at its end (under the text where the row is under
// 32rem wide), and a heading that script can focus (`tabIndex -1`) for focus
// that has nowhere nearer to go: revoking the last App login lands here.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

class AccountSignOutSection extends StatelessWidget {
  const AccountSignOutSection({
    super.key,
    required this.headingFocus,
    required this.onLogout,
  });

  /// The section's heading: focusable from script, never by Tab.
  final FocusNode headingFocus;

  /// The host owns the session teardown; null while there is none to end.
  final Future<void> Function()? onLogout;

  Future<void> confirm(BuildContext context) async {
    final ok = await RaftConfirmDialog.show(
      context,
      const RaftConfirmDialog(
        title: 'Sign out',
        message: 'Sign out of this browser? Your account and data are kept; you can sign back in any time.',
        confirmLabel: 'Sign out',
        cancelLabel: 'Cancel',
        surfaceKey: ValueKey('account-logout-dialog'),
        // confirmVariant="warning".
        confirmVariant: RaftButtonRecipeVariant.warning,
        confirmKey: Key('account-logout-confirm-button'),
      ),
    );
    if (ok == true) await onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: RaftSpace.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: RaftSpace.x3),
            child: Semantics(
              header: true,
              child: Focus(
                focusNode: headingFocus,
                skipTraversal: true,
                child: ListenableBuilder(
                  listenable: headingFocus,
                  builder: (context, child) => DecoratedBox(
                    key: const ValueKey('account-session-heading'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(t.radius),
                      // `focus-visible:shadow-focus`: only for keyboard focus.
                      boxShadow:
                          headingFocus.hasFocus &&
                              FocusManager.instance.highlightMode ==
                                  FocusHighlightMode.traditional
                          ? t.focusShadows
                          : null,
                    ),
                    child: child,
                  ),
                  child: const RaftSettingsSectionHeader(
                    label: 'Session',
                    glyph: RaftGlyph.logOut,
                    bottom: 0,
                  ),
                ),
              ),
            ),
          ),
          RaftSettingsRowGroup(
            rows: [
              RaftSettingsRowSpec(
                title: 'Sign out',
                description: 'Sign out of this browser. Your account and data stay; you can sign back in any time.',
                control: RaftSettingsRecipeButton(
                  key: const Key('account-logout'),
                  label: 'Sign out',
                  variant: RaftButtonRecipeVariant.warning,
                  onPressed: onLogout == null ? null : () => confirm(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
