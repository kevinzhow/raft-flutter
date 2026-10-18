// GENERATED from the @RaftPreviews functions in packages/raft_ui/lib/*_previews.dart
// (see text_scale_audit_surfaces_test.dart, which fails when this list drifts).
// `representative` marks the surfaces of the gated audit; the rest run only with
// RAFT_TEXT_SCALE_SWEEP=1.
import 'package:flutter/widgets.dart';

import 'package:raft_ui/activity_scope_previews.dart';
import 'package:raft_ui/activity_selected_previews.dart';
import 'package:raft_ui/agent_avatar_picker_previews.dart';
import 'package:raft_ui/agent_menu_previews.dart';
import 'package:raft_ui/agent_surface_previews.dart';
import 'package:raft_ui/announcement_previews.dart';
import 'package:raft_ui/app_icon_previews.dart';
import 'package:raft_ui/attachment_comments_previews.dart';
import 'package:raft_ui/attachment_previews.dart';
import 'package:raft_ui/banner_previews.dart';
import 'package:raft_ui/basic_component_previews.dart';
import 'package:raft_ui/channel_header_previews.dart';
import 'package:raft_ui/channel_management_previews.dart';
import 'package:raft_ui/channel_resolution_previews.dart';
import 'package:raft_ui/chat_composition_previews.dart';
import 'package:raft_ui/combobox_previews.dart';
import 'package:raft_ui/collapsible_section_previews.dart';
import 'package:raft_ui/composer_expand_previews.dart';
import 'package:raft_ui/conversation_card_previews.dart';
import 'package:raft_ui/css_recipe_radius_previews.dart';
import 'package:raft_ui/desktop_title_bar_previews.dart';
import 'package:raft_ui/dialog_previews.dart';
import 'package:raft_ui/directory_navigation_previews.dart';
import 'package:raft_ui/document_previews.dart';
import 'package:raft_ui/dropdown_viewport_previews.dart';
import 'package:raft_ui/elegant_navigation_previews.dart';
import 'package:raft_ui/hover_card_previews.dart';
import 'package:raft_ui/html_previews.dart';
import 'package:raft_ui/inline_badge_previews.dart';
import 'package:raft_ui/inline_thread_surface_previews.dart';
import 'package:raft_ui/legacy_input_previews.dart';
import 'package:raft_ui/media_browser_previews.dart';
import 'package:raft_ui/video_poster_card_previews.dart';
import 'package:raft_ui/member_profile_previews.dart';
import 'package:raft_ui/message_affordance_previews.dart';
import 'package:raft_ui/message_row_previews.dart';
import 'package:raft_ui/message_translation_previews.dart';
import 'package:raft_ui/mobile_computer_previews.dart';
import 'package:raft_ui/mobile_detail_previews.dart';
import 'package:raft_ui/mobile_navigation_previews.dart';
import 'package:raft_ui/mobile_page_header_previews.dart';
import 'package:raft_ui/mobile_tabbar_config_previews.dart';
import 'package:raft_ui/mounted_avatar_previews.dart';
import 'package:raft_ui/notification_previews.dart';
import 'package:raft_ui/notification_settings_previews.dart';
import 'package:raft_ui/popover_surface_previews.dart';
import 'package:raft_ui/popup_collision_previews.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/pull_to_refresh_previews.dart';
import 'package:raft_ui/quick_reaction_picker_previews.dart';
import 'package:raft_ui/quick_switcher_previews.dart';
import 'package:raft_ui/search_surface_previews.dart';
import 'package:raft_ui/section_pager_previews.dart';
import 'package:raft_ui/sheet_previews.dart';
import 'package:raft_ui/selection_popover_previews.dart';
import 'package:raft_ui/selection_toolbar_previews.dart';
import 'package:raft_ui/settings_administration_previews.dart';
import 'package:raft_ui/settings_catalog_previews.dart';
import 'package:raft_ui/settings_control_previews.dart';
import 'package:raft_ui/surface_progress_previews.dart';
import 'package:raft_ui/switch_previews.dart';
import 'package:raft_ui/task_section_previews.dart';
import 'package:raft_ui/task_surface_previews.dart';
import 'package:raft_ui/text_selection_toolbar_previews.dart';
import 'package:raft_ui/thread_composition_previews.dart';
import 'package:raft_ui/thread_reply_previews.dart';
import 'package:raft_ui/timeline_composition_previews.dart';
import 'package:raft_ui/toast_previews.dart';
import 'package:raft_ui/typography_locale_previews.dart';
import 'package:raft_ui/workspace_previews.dart';
import 'package:raft_ui/workspace_shell_previews.dart';

class AuditSurface {
  const AuditSurface(
    this.fn,
    this.name,
    this.build,
    this.size, {
    this.representative = false,
  });
  final String fn;
  final String name;
  final Widget Function() build;
  final Size size;
  final bool representative;
}

final auditSurfaces = <AuditSurface>[
  AuditSurface(
    'dropdownViewportPreview',
    'Long dropdowns at the window edge',
    dropdownViewportPreview,
    Size(390, 720),
    representative: true,
  ),
  AuditSurface(
    'activityCompactScopePreview',
    'Activity compact scope',
    activityCompactScopePreview,
    Size(440, 110),
  ),
  AuditSurface(
    'activityMobileScopePreview',
    'Activity mobile views',
    activityMobileScopePreview,
    Size(390, 70),
    representative: true,
  ),
  AuditSurface(
    'activityScopePickerPreview',
    'Activity scope picker',
    activityScopePickerPreview,
    Size(440, 590),
  ),
  AuditSurface(
    'activityDirectMessagesMobilePreview',
    'Activity DMs mobile',
    activityDirectMessagesMobilePreview,
    Size(390, 70),
    representative: true,
  ),
  AuditSurface(
    'activityDirectMessagesPickerPreview',
    'Activity DMs picker',
    activityDirectMessagesPickerPreview,
    Size(440, 590),
    representative: true,
  ),
  AuditSurface(
    'activityLoadingPreview',
    'Activity pending results',
    activityLoadingPreview,
    Size(440, 600),
  ),
  AuditSurface(
    'activityFinderPreview',
    'Activity scoped finder',
    activityFinderPreview,
    Size(440, 70),
  ),
  AuditSurface(
    'activitySelectedRowsPreview',
    'Activity selected row',
    activitySelectedRowsPreview,
    Size(520, 640),
  ),
  AuditSurface(
    'activitySelectedMasterDetailPreview',
    'Activity selected master-detail',
    activitySelectedMasterDetailPreview,
    Size(1180, 640),
  ),
  AuditSurface(
    'agentAvatarEditorPreview',
    'Agent avatar editor',
    agentAvatarEditorPreview,
    Size(390, 650),
  ),
  AuditSurface(
    'agentMenuPreview',
    'Agent menu',
    agentMenuPreview,
    Size(390, 360),
  ),
  AuditSurface(
    'agentSurfacePreview',
    'Agent form · recipe and caller chrome',
    agentSurfacePreview,
    Size(440, 560),
  ),
  AuditSurface(
    'announcementModalPreview',
    'Announcement modal',
    announcementModalPreview,
    Size(900, 640),
  ),
  AuditSurface(
    'appIconChoicesPreview',
    'App icon choices',
    appIconChoicesPreview,
    Size(412, 460),
  ),
  AuditSurface(
    'appIconFailurePreview',
    'App icon failure',
    appIconFailurePreview,
    Size(412, 520),
  ),
  AuditSurface(
    'attachmentCommentsPreview',
    'Attachment comments',
    attachmentCommentsPreview,
    Size(390, 420),
    representative: true,
  ),
  AuditSurface(
    'attachmentPreview',
    'Attachment',
    attachmentPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'attachmentTransferPreview',
    'Attachment transfer',
    attachmentTransferPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'bannerPreview',
    'Banner',
    bannerPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'designControlsPreview',
    'Design controls',
    designControlsPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'designFieldsPreview',
    'Design fields',
    designFieldsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'designTypographyPreview',
    'Design typography',
    designTypographyPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'designIconsPreview',
    'Design icons',
    designIconsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sourceButtonsPreview',
    'Source buttons',
    sourceButtonsPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'sourceInputsPreview',
    'Source inputs',
    sourceInputsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sourceAvatarsPreview',
    'Source avatars',
    sourceAvatarsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sourceMenusPreview',
    'Source menus',
    sourceMenusPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sourceTextHeadingsPreview',
    'Source text headings',
    sourceTextHeadingsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sourceTextSansPreview',
    'Source text sans',
    sourceTextSansPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'channelHeaderPreview',
    'Channel header',
    channelHeaderPreview,
    Size(390, 160),
    representative: true,
  ),
  AuditSurface(
    'desktopPanelHeaderPreview',
    'Desktop panel header flow',
    desktopPanelHeaderPreview,
    Size(960, 180),
    representative: true,
  ),
  AuditSurface('dmHeaderPreview', 'DM header', dmHeaderPreview, Size(960, 160)),
  AuditSurface(
    'channelSettingsPagePreview',
    'Mobile channel settings page',
    channelSettingsPagePreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'dmSettingsPagePreview',
    'Mobile DM current settings',
    dmSettingsPagePreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'channelMembersPagePreview',
    'Mobile channel members page',
    channelMembersPagePreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'channelMembersLoadingPreview',
    'Mobile channel members loading',
    channelMembersLoadingPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'channelSettingsErrorPreview',
    'Mobile channel settings error',
    channelSettingsErrorPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'channelResolutionPreview',
    'Unresolved real channel',
    channelResolutionPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'mountedChatSidebarGroupsPreview',
    'Mounted chat sidebar groups',
    mountedChatSidebarGroupsPreview,
    Size(320, 560),
    representative: true,
  ),
  AuditSurface(
    'conversationTabsDesktopPreview',
    'Conversation tabs desktop',
    conversationTabsDesktopPreview,
    Size(1024, 220),
    representative: true,
  ),
  AuditSurface(
    'conversationTabsTouchPreview',
    'Conversation tabs phone touch',
    conversationTabsTouchPreview,
    Size(390, 220),
    representative: true,
  ),
  AuditSurface(
    'composerTaskActionPreview',
    'Composer task action',
    composerTaskActionPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'recipeGroupOpacityPreview',
    'Recipe group opacity',
    recipeGroupOpacityPreview,
    Size(390, 180),
  ),
  AuditSurface(
    'composerEditableLineBoxPreview',
    'Composer editable CSS line boxes',
    composerEditableLineBoxPreview,
    Size(390, 240),
    representative: true,
  ),
  AuditSurface(
    'composerDropOverlayPreview',
    'Composer file drop overlay',
    composerDropOverlayPreview,
    Size(640, 240),
  ),
  AuditSurface(
    'longMountedChatSidebarPreview',
    'Long mounted chat sidebar',
    longMountedChatSidebarPreview,
    Size(320, 560),
    representative: true,
  ),
  AuditSurface(
    'collapsibleSectionPreview',
    'Collapsible section header',
    collapsibleSectionPreview,
    Size(420, 520),
    representative: true,
  ),
  AuditSurface(
    'comboboxPreview',
    'Combobox panel',
    comboboxPreview,
    Size(300, 320),
  ),
  AuditSurface(
    'composerExpandButtonPreview',
    'Composer expand button',
    composerExpandButtonPreview,
    Size(640, 260),
    representative: true,
  ),
  AuditSurface(
    'expandedComposerDesktopPreview',
    'Expanded composer desktop',
    expandedComposerDesktopPreview,
    Size(1100, 820),
    representative: true,
  ),
  AuditSurface(
    'expandedComposerPhonePreview',
    'Expanded composer phone',
    expandedComposerPhonePreview,
    Size(412, 860),
    representative: true,
  ),
  AuditSurface(
    'sheetScrollingPreview',
    'Sheet with a scrolling body',
    sheetScrollingPreview,
    Size(412, 760),
  ),
  AuditSurface(
    'sheetShortPreview',
    'Sheet at its medium detent',
    sheetShortPreview,
    Size(412, 520),
  ),
  AuditSurface(
    'conversationActivationPreview',
    'Conversation activation',
    conversationActivationPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'recipeRadiusPreview',
    'Recipe rounded-full at actual sizes',
    recipeRadiusPreview,
    Size(390, 220),
  ),
  AuditSurface(
    'desktopTitleStripPreview',
    'Desktop title strip',
    desktopTitleStripPreview,
    Size(640, 200),
  ),
  AuditSurface(
    'desktopTitleRulePreview',
    'Desktop native caption rule',
    desktopTitleRulePreview,
    Size(640, 200),
  ),
  AuditSurface(
    'desktopTitleFullscreenPreview',
    'Desktop title bar fullscreen',
    desktopTitleFullscreenPreview,
    Size(640, 200),
  ),
  AuditSurface(
    'sourceDialogPreview',
    'Source dialog',
    sourceDialogPreview,
    Size(390, 500),
    representative: true,
  ),
  AuditSurface(
    'sourceAlertDialogPreview',
    'Source alert dialog',
    sourceAlertDialogPreview,
    Size(390, 500),
    representative: true,
  ),
  AuditSurface(
    'sosConfirmPreview',
    'SOS stop all agents',
    sosConfirmPreview,
    Size(420, 360),
    representative: true,
  ),
  AuditSurface(
    'sosStoppedPreview',
    'SOS agents stopped guidance',
    sosStoppedPreview,
    Size(420, 460),
  ),
  AuditSurface(
    'directoryNavigationPreview',
    'Mounted directory rows: identity and selection',
    directoryNavigationPreview,
    Size(390, 260),
  ),
  AuditSurface(
    'mountedSidebarPreview',
    'Mounted sidebar: computer groups and human descriptions',
    mountedSidebarPreview,
    Size(390, 420),
  ),
  AuditSurface(
    'sidebarUnreadIndicatorsPreview',
    'Mounted channel unread, mute and draft states',
    sidebarUnreadIndicatorsPreview,
    Size(390, 240),
  ),
  AuditSurface(
    'documentMediaPreview',
    'Document and media preview',
    documentMediaPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'railIdentityRecipePreview',
    'Rail identity and numeric count recipes',
    railIdentityRecipePreview,
    Size(390, 240),
  ),
  AuditSurface(
    'railAttentionPreview',
    'Product rail attention',
    railAttentionPreview,
    Size(390, 260),
  ),
  AuditSurface(
    'agentProfileHoverCardPreview',
    'Hover card: agent profile (avatar / @mention)',
    agentProfileHoverCardPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'memberProfileHoverCardPreview',
    'Hover card: member profile and unavailable',
    memberProfileHoverCardPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'reactionReactorsPreview',
    'Hover popup: reaction reactor names',
    reactionReactorsPreview,
    Size(360, 160),
  ),
  AuditSurface(
    'runtimeUsageCardPreview',
    'Hover card: runtime account usage',
    runtimeUsageCardPreview,
    Size(900, 520),
  ),
  AuditSurface('htmlPreview', 'HTML preview', htmlPreview, Size(640, 440)),
  AuditSurface(
    'sourceInlineBadgeEditorPreview',
    'Source inline badge editor',
    sourceInlineBadgeEditorPreview,
    Size(390, 320),
  ),
  AuditSurface(
    'inlineThreadSurfacePreview',
    'Mounted inline replies: one parent thread action',
    inlineThreadSurfacePreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'legacyInputPreview',
    'Legacy Source input · focus and caller states',
    legacyInputPreview,
    Size(360, 300),
  ),
  AuditSurface(
    'profileTabsAndCardPreview',
    'Profile tabs and card',
    profileTabsAndCardPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'messageAffordancePreview',
    'Mounted message affordances: toolbar and count transition',
    messageAffordancePreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'messageRowPreview',
    'Mounted message row: grouping and pointer actions',
    messageRowPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'messageTranslationPreview',
    'Message translation: pending, translated, bilingual, failed',
    messageTranslationPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'computerDirectoryInsetPreview',
    'Computer directory · long list with bottom inset',
    computerDirectoryInsetPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileDmSettingsPreview',
    'Mobile DM settings page',
    mobileDmSettingsPreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'mobileAttachmentImagePreview',
    'Mobile attachment image page',
    mobileAttachmentImagePreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileAttachmentDocumentPreview',
    'Mobile attachment document page',
    mobileAttachmentDocumentPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileAttachmentLoadingPreview',
    'Mobile attachment loading page',
    mobileAttachmentLoadingPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileAttachmentErrorPreview',
    'Mobile attachment error page',
    mobileAttachmentErrorPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'sourceMobileNavigationPreview',
    'Source mobile navigation',
    sourceMobileNavigationPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'sourceMobileNavigationCompactPreview',
    'Source mobile navigation compact',
    sourceMobileNavigationCompactPreview,
    Size(390, 560),
  ),
  AuditSurface(
    'sourceMobileNavigationTouchPreview',
    'Source mobile navigation touch',
    sourceMobileNavigationTouchPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'sourceMobileNavigationSystemInsetPreview',
    'Source mobile navigation system inset',
    sourceMobileNavigationSystemInsetPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobilePageHeaderPreview',
    'Mobile page navigation',
    mobilePageHeaderPreview,
    Size(390, 600),
  ),
  AuditSurface(
    'mobileSettingsRootBottomBarPreview',
    'Mobile settings root with Bottom bar entry',
    mobileSettingsRootBottomBarPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileSettingsRootCurrentPreview',
    'Mobile settings root (current)',
    mobileSettingsRootCurrentPreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'mobileTabbarConfigDefaultPreview',
    'Mobile Bottom bar settings (default)',
    mobileTabbarConfigDefaultPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileTabbarConfigGesturePreview',
    'Mobile Bottom bar settings (gesture inset)',
    mobileTabbarConfigGesturePreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileTabbarConfigButtonsPreview',
    'Mobile Bottom bar settings (3-button inset)',
    mobileTabbarConfigButtonsPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileTabbarConfigFullPreview',
    'Mobile Bottom bar settings (limit reached)',
    mobileTabbarConfigFullPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileTabbarConfigMinimumPreview',
    'Mobile Bottom bar settings (minimum)',
    mobileTabbarConfigMinimumPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'mobileTabbarFiveItemsPreview',
    'Mobile bottom bar, 5 items at 360dp',
    mobileTabbarFiveItemsPreview,
    Size(360, 120),
    representative: true,
  ),
  AuditSurface(
    'mountedAvatarPreview',
    'Mounted avatar: panel and compact identity/status',
    mountedAvatarPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'withheldAvatarSlotPreview',
    'Withheld compact avatar slot',
    withheldAvatarSlotPreview,
    Size(80, 60),
  ),
  AuditSurface(
    'notificationCenterEmptyPreview',
    'Source notification center empty',
    notificationCenterEmptyPreview,
    Size(640, 480),
  ),
  AuditSurface(
    'notificationCenterActionsPreview',
    'Source notification center actions',
    notificationCenterActionsPreview,
    Size(640, 480),
  ),
  AuditSurface(
    'notificationCenterComputerPreview',
    'Source notification center Computer fixture',
    notificationCenterComputerPreview,
    Size(412, 480),
  ),
  AuditSurface(
    'notificationCenterTouchPreview',
    'Source notification center touch',
    notificationCenterTouchPreview,
    Size(412, 480),
  ),
  AuditSurface(
    'notificationCenterLongPreview',
    'Source notification center long text',
    notificationCenterLongPreview,
    Size(412, 640),
  ),
  AuditSurface(
    'notificationAttentionPreview',
    'Source notification attention',
    notificationAttentionPreview,
    Size(640, 480),
  ),
  AuditSurface(
    'sourceDesktopNotificationSettingsPreview',
    'Source notification settings (desktop)',
    sourceDesktopNotificationSettingsPreview,
    Size(390, 460),
  ),
  AuditSurface(
    'sourcePhoneNotificationSettingsPreview',
    'Source notification settings (phone)',
    sourcePhoneNotificationSettingsPreview,
    Size(390, 600),
  ),
  AuditSurface(
    'popoverSurfacePreview',
    'Source Popover surface: LG Brutal / XL Elegant',
    popoverSurfacePreview,
    Size(640, 440),
  ),
  AuditSurface(
    'popupCollisionPreview',
    'Bottom-edge status menu',
    popupCollisionPreview,
    Size(320, 400),
  ),
  AuditSurface(
    'shortRefreshPreview',
    'Pull to refresh · short list',
    shortRefreshPreview,
    Size(390, 600),
  ),
  AuditSurface(
    'emptyRefreshPreview',
    'Pull to refresh · empty',
    emptyRefreshPreview,
    Size(390, 600),
  ),
  AuditSurface(
    'quickReactionPickerPreview',
    'Controlled seven-reaction picker: source glyph slot pending',
    quickReactionPickerPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'quickSwitcherPreview',
    'Quick switcher',
    quickSwitcherPreview,
    Size(900, 640),
  ),
  AuditSurface(
    'quickSwitcherResultsPreview',
    'Quick switcher results',
    quickSwitcherResultsPreview,
    Size(720, 900),
    representative: true,
  ),
  AuditSurface(
    'searchSurfacesPreview',
    'Search results and task filters',
    searchSurfacesPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'searchHistoryTagsPreview',
    'Search history tags',
    searchHistoryTagsPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'searchInputPreview',
    'Search input focus and clear',
    searchInputPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'taskDocumentPreview',
    'Task document typography and inline status',
    taskDocumentPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'sectionPagerPreview',
    'Mobile section paging',
    sectionPagerPreview,
    Size(390, 600),
  ),
  AuditSurface(
    'selectionPopoverPreview',
    'Selection popover · default and explicit caller',
    selectionPopoverPreview,
    Size(410, 420),
  ),
  AuditSurface(
    'selectionToolbarPreview',
    'Source selection toolbar',
    selectionToolbarPreview,
    Size(390, 320),
  ),
  AuditSurface(
    'textSelectionToolbarPreview',
    'Android text selection',
    textSelectionToolbarPreview,
    Size(390, 520),
  ),
  AuditSurface(
    'largeTextSelectionToolbarPreview',
    'Android text selection · large text',
    largeTextSelectionToolbarPreview,
    Size(320, 520),
  ),
  AuditSurface(
    'administrationAdminsPreview',
    'Administration: Owners & Admins',
    administrationAdminsPreview,
    Size(760, 420),
    representative: true,
  ),
  AuditSurface(
    'administrationFormsPreview',
    'Administration: checkbox, switch and links',
    administrationFormsPreview,
    Size(760, 760),
  ),
  AuditSurface(
    'longApplicationCatalogPreview',
    'Settings: long application catalog',
    longApplicationCatalogPreview,
    Size(1000, 650),
    representative: true,
  ),
  AuditSurface(
    'longMcpCatalogPreview',
    'Settings: long MCP catalog',
    longMcpCatalogPreview,
    Size(1000, 650),
  ),
  AuditSurface(
    'settingsControlsPreview',
    'Settings buttons keyboard focus and disabled',
    settingsControlsPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'surfaceProgressPreview',
    'Product surfaces and progress',
    surfaceProgressPreview,
    Size(380, 320),
  ),
  AuditSurface(
    'sourceSwitchesPreview',
    'Source switches',
    sourceSwitchesPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'taskSectionPreview',
    'Lazy task sections',
    taskSectionPreview,
    Size(390, 720),
  ),
  AuditSurface(
    'taskModalPreview',
    'Task modal',
    taskModalPreview,
    Size(390, 844),
  ),
  AuditSurface(
    'taskPagePreview',
    'Mobile task page',
    taskPagePreview,
    Size(390, 844),
  ),
  AuditSurface(
    'legacyTaskPagePreview',
    'Mobile legacy task page',
    legacyTaskPagePreview,
    Size(390, 844),
  ),
  AuditSurface(
    'legacyTaskPreview',
    'Legacy task panel',
    legacyTaskPreview,
    Size(1280, 844),
  ),
  AuditSurface(
    'legacyDockedTaskPreview',
    'Legacy docked task panel',
    legacyDockedTaskPreview,
    Size(1280, 844),
  ),
  AuditSurface(
    'mountedThreadCompositionDesktopPreview',
    'Mounted Thread composition desktop',
    mountedThreadCompositionDesktopPreview,
    Size(1280, 560),
  ),
  AuditSurface(
    'mountedThreadCompositionTouchPreview',
    'Mounted Thread composition folded touch',
    mountedThreadCompositionTouchPreview,
    Size(390, 560),
    representative: true,
  ),
  AuditSurface(
    'inlineRepliesPreview',
    'Inline thread replies',
    inlineRepliesPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'timelineMainPreview',
    'Timeline Main centered composition',
    timelineMainPreview,
    Size(390, 560),
  ),
  AuditSurface(
    'timelineThreadPreview',
    'Timeline Thread centered composition',
    timelineThreadPreview,
    Size(390, 560),
  ),
  AuditSurface(
    'selectionCopyToastPreview',
    'Selection copy toast',
    selectionCopyToastPreview,
    Size(390, 240),
    representative: true,
  ),
  AuditSurface(
    'chineseGlyphsPreview',
    'English UI · Chinese glyphs',
    chineseGlyphsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'traditionalGlyphsPreview',
    'English UI · Traditional Chinese glyphs',
    traditionalGlyphsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'japaneseGlyphsPreview',
    'English UI · Japanese glyphs',
    japaneseGlyphsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'koreanGlyphsPreview',
    'English UI · Korean glyphs',
    koreanGlyphsPreview,
    Size(640, 440),
  ),
  AuditSurface(
    'workspaceModePreview',
    'Workspace mode',
    workspaceModePreview,
    Size(390, 160),
  ),
  AuditSurface(
    'workspaceEditorGroupsPreview',
    'Workspace editor groups',
    workspaceEditorGroupsPreview,
    Size(1080, 680),
  ),
  AuditSurface(
    'workspaceSidebarHeadingPreview',
    'Desktop sidebar heading',
    workspaceSidebarHeadingPreview,
    Size(280, 100),
    representative: true,
  ),
  AuditSurface(
    'workspaceRailFooterPreview',
    'Desktop rail footer',
    workspaceRailFooterPreview,
    Size(440, 320),
    representative: true,
  ),
  AuditSurface(
    'mediaBrowserPhonePreview',
    'Media browser phone',
    mediaBrowserPhonePreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'mediaBrowserPhoneHiddenPreview',
    'Media browser phone, chrome hidden',
    mediaBrowserPhoneHiddenPreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'mediaBrowserPhoneLandscapePreview',
    'Media browser phone landscape',
    mediaBrowserPhoneLandscapePreview,
    Size(844, 390),
    representative: true,
  ),
  AuditSurface(
    'mediaBrowserPhoneNoCaptionPreview',
    'Media browser phone without caption',
    mediaBrowserPhoneNoCaptionPreview,
    Size(390, 844),
    representative: true,
  ),
  AuditSurface(
    'videoPosterCardLandscapePreview',
    'Video poster card (phone message)',
    videoPosterCardLandscapePreview,
    Size(390, 500),
    representative: true,
  ),
  AuditSurface(
    'videoPosterCardPortraitPreview',
    'Video poster card, portrait',
    videoPosterCardPortraitPreview,
    Size(390, 900),
  ),
  AuditSurface(
    'videoPosterCardTallPreview',
    'Video poster card, very tall',
    videoPosterCardTallPreview,
    Size(390, 700),
  ),
  AuditSurface(
    'videoPosterCardPlaceholderPreview',
    'Video poster card, no poster',
    videoPosterCardPlaceholderPreview,
    Size(390, 400),
  ),
  AuditSurface(
    'videoPosterCardUploadingPreview',
    'Video poster card, uploading',
    videoPosterCardUploadingPreview,
    Size(390, 400),
  ),
  AuditSurface(
    'mediaBrowserDesktopPreview',
    'Media browser desktop',
    mediaBrowserDesktopPreview,
    Size(1280, 800),
    representative: true,
  ),
  // The core component catalog (previews.dart).
  AuditSurface(
    'buttonsPreview',
    'Buttons',
    buttonsPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'avatarPreview',
    'Avatar',
    avatarPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'navigationPreview',
    'Navigation',
    navigationPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'panelPreview',
    'Panel',
    panelPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'messagePreview',
    'Message',
    messagePreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'composerPreview',
    'Composer',
    composerPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'emptyPreview',
    'Empty state',
    emptyPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'uploadPreview',
    'Upload',
    uploadPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'formPreview',
    'Form',
    formPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'taskPreview',
    'Task',
    taskPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'longMessagePreview',
    'Long message',
    longMessagePreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'credentialPreview',
    'Credential',
    credentialPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'workspaceRailPreview',
    'Workspace rail',
    workspaceRailPreview,
    Size(640, 440),
    representative: true,
  ),
  AuditSurface(
    'richMessagePreview',
    'Rich message',
    richMessagePreview,
    Size(640, 580),
  ),
  AuditSurface(
    'actionCardPreview',
    'Action card',
    actionCardPreview,
    Size(640, 620),
    representative: true,
  ),
  AuditSurface(
    'messageExportPreview',
    'Message export',
    messageExportPreview,
    Size(640, 680),
    representative: true,
  ),
  AuditSurface(
    'forwardedBundlePreview',
    'Forwarded bundle',
    forwardedBundlePreview,
    Size(640, 680),
    representative: true,
  ),
  AuditSurface(
    'composerSuggestionsPreview',
    'Composer suggestions',
    composerSuggestionsPreview,
    Size(640, 520),
    representative: true,
  ),
  AuditSurface(
    'timelineBottomButtonPreview',
    'Timeline return to latest',
    timelineBottomButtonPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'newUpdatesButtonPreview',
    'Activity new updates',
    newUpdatesButtonPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'threadResolutionPreview',
    'Thread resolution loading',
    threadResolutionPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'threadResolutionRetryPreview',
    'Thread resolution retry',
    threadResolutionRetryPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'threadRepliesLoadingPreview',
    'Thread replies loading',
    threadRepliesLoadingPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'serverSwitcherPreview',
    'Server switcher',
    serverSwitcherPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'mobileServerSwitcherPreview',
    'Mobile Home server switcher',
    mobileServerSwitcherPreview,
    Size(390, 900),
    representative: true,
  ),
  AuditSurface(
    'serverResolutionPreview',
    'Server URI resolution',
    serverResolutionPreview,
    Size(390, 360),
    representative: true,
  ),
  AuditSurface(
    'rootErrorFallbackPreview',
    'Root error fallback',
    rootErrorFallbackPreview,
    Size(390, 700),
    representative: true,
  ),
  AuditSurface(
    'serverAccessDeniedPreview',
    'Server not found',
    serverAccessDeniedPreview,
    Size(390, 420),
    representative: true,
  ),
  AuditSurface(
    'archivedChannelsPreview',
    'Archived channels',
    archivedChannelsPreview,
    Size(640, 420),
    representative: true,
  ),
  AuditSurface(
    'setupResumeBarPreview',
    'Setup resume bar',
    setupResumeBarPreview,
    Size(390, 160),
    representative: true,
  ),
  AuditSurface(
    'setupResumeBarOpeningPreview',
    'Setup resume bar opening',
    setupResumeBarOpeningPreview,
    Size(390, 160),
    representative: true,
  ),
  AuditSurface(
    'communityAgreementPreview',
    'Community agreement',
    communityAgreementPreview,
    Size(560, 640),
    representative: true,
  ),
  AuditSurface(
    'inviteAcceptSignedOutPreview',
    'Invite accept signed out',
    inviteAcceptSignedOutPreview,
    Size(390, 700),
    representative: true,
  ),
  AuditSurface(
    'inviteAcceptSignedInPreview',
    'Invite accept signed in',
    inviteAcceptSignedInPreview,
    Size(390, 700),
    representative: true,
  ),
];
