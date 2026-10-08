/// Route-level mobile navigation, following MainLayout.tsx's root/detail cuts.
/// This is independent of the selected channel retained for draft restoration.
String? mobileWorkspaceRootTab(
  String section, {
  required bool threadOpen,
  required bool settingsDetail,
}) {
  if (threadOpen) return null;
  return switch (section) {
    'home' => 'chat',
    'tasks' => 'tasks',
    'members' => 'members',
    'settings' when !settingsDetail => 'settings',
    _ => null,
  };
}

String mobileWorkspaceBackSection(String section) => switch (section) {
  'computers' ||
  'workspace-settings' ||
  'sidebar-settings' ||
  'providers' ||
  'integrations' ||
  'im-bridges' ||
  'administration' ||
  'billing' => 'settings',
  _ => 'home',
};
