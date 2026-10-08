import 'package:raft_ui/rich_surface_visual_previews.dart' as surface;
import 'package:flutter/material.dart';

import 'package:raft_ui/previews.dart' show RaftPreviews, RaftWorkspacePreviews;
import 'package:raft_ui/rich_visual_previews.dart' show RichVisualPreviews;
import 'package:raft_ui/previews.dart' as base;
import 'package:raft_ui/basic_component_previews.dart' as basic;
import 'package:raft_ui/rich_visual_previews.dart' as rich;
import 'package:raft_ui/attachment_previews.dart' as attachment;
import 'package:raft_ui/document_previews.dart' as document;
import 'package:raft_ui/html_previews.dart' as html;
import 'package:raft_ui/thread_reply_previews.dart' as thread;

// The SDK scans application-local annotations. Keep the entry points here,
// while all widgets, fixtures and theme wrappers remain in the pure UI package.
// These forwarders do not introduce application dependencies into raft_ui.

@RaftPreviews('Buttons')
Widget appButtonsPreview() => base.buttonsPreview();

@RaftPreviews('Avatar')
Widget appAvatarPreview() => base.avatarPreview();

@RaftPreviews('Navigation')
Widget appNavigationPreview() => base.navigationPreview();

@RaftPreviews('Panel')
Widget appPanelPreview() => base.panelPreview();

@RaftPreviews('Message')
Widget appMessagePreview() => base.messagePreview();

@RaftPreviews('Composer')
Widget appComposerPreview() => base.composerPreview();

@RaftPreviews('Empty state')
Widget appEmptyPreview() => base.emptyPreview();

@RaftPreviews('Upload')
Widget appUploadPreview() => base.uploadPreview();

@RaftPreviews('Form')
Widget appFormPreview() => base.formPreview();

@RaftPreviews('Task')
Widget appTaskPreview() => base.taskPreview();

@RaftPreviews('Long message')
Widget appLongMessagePreview() => base.longMessagePreview();

@RaftPreviews('Credential')
Widget appCredentialPreview() => base.credentialPreview();

@RaftWorkspacePreviews()
Widget appAdaptiveWorkspacePreview() => base.adaptiveWorkspacePreview();

@RaftPreviews('Workspace rail')
Widget appWorkspaceRailPreview() => base.workspaceRailPreview();

@RaftPreviews('Rich message', size: Size(640, 580))
Widget appRichMessagePreview() => base.richMessagePreview();

@RaftPreviews('Action card', size: Size(640, 620))
Widget appActionCardPreview() => base.actionCardPreview();

@RaftPreviews('Message export', size: Size(640, 680))
Widget appMessageExportPreview() => base.messageExportPreview();

@RaftPreviews('Forwarded bundle', size: Size(640, 680))
Widget appForwardedBundlePreview() => base.forwardedBundlePreview();

@RaftPreviews('Composer suggestions', size: Size(640, 520))
Widget appComposerSuggestionsPreview() => base.composerSuggestionsPreview();

@RaftPreviews('Design controls', size: Size(640, 440))
Widget appDesignControlsPreview() => basic.designControlsPreview();

@RaftPreviews('Design fields', size: Size(640, 440))
Widget appDesignFieldsPreview() => basic.designFieldsPreview();

@RaftPreviews('Design typography', size: Size(640, 440))
Widget appDesignTypographyPreview() => basic.designTypographyPreview();

@RaftPreviews('Design icons', size: Size(640, 440))
Widget appDesignIconsPreview() => basic.designIconsPreview();

@RaftPreviews('Source buttons', size: Size(640, 440))
Widget appSourceButtonsPreview() => basic.sourceButtonsPreview();

@RaftPreviews('Source inputs', size: Size(640, 440))
Widget appSourceInputsPreview() => basic.sourceInputsPreview();

@RaftPreviews('Source avatars', size: Size(640, 440))
Widget appSourceAvatarsPreview() => basic.sourceAvatarsPreview();

@RichVisualPreviews('Flowchart')
Widget appVisualFlowchart() => rich.visualFlowchart();

@RichVisualPreviews('Sequence')
Widget appVisualSequence() => rich.visualSequence();

@RichVisualPreviews('Pie')
Widget appVisualPie() => rich.visualPie();

@RichVisualPreviews('Code')
Widget appVisualCode() => rich.visualCode();

@RichVisualPreviews('Markdown')
Widget appVisualMarkdown() => rich.visualMarkdown();

@RichVisualPreviews('File chip')
Widget appVisualFileChip() => rich.visualFileChip();

@RaftPreviews('Attachment')
Widget appAttachmentPreview() => attachment.attachmentPreview();

@RaftPreviews('Document and media preview')
Widget appDocumentMediaPreview() => document.documentMediaPreview();

@RaftPreviews('HTML preview')
Widget appHtmlPreview() => html.htmlPreview();

@RaftPreviews('Inline thread replies')
Widget appInlineRepliesPreview() => thread.inlineRepliesPreview();

@RaftPreviews('Source menus', size: Size(640, 440))
Widget appSourceMenusPreview() => basic.sourceMenusPreview();
@RaftPreviews('Source text headings', size: Size(640, 440))
Widget appSourceTextHeadingsPreview() => basic.sourceTextHeadingsPreview();
@RaftPreviews('Source text sans', size: Size(640, 440))
Widget appSourceTextSansPreview() => basic.sourceTextSansPreview();

@RichVisualPreviews('visualForwardedSnapshot')
Widget appVisualForwardedSnapshot() => surface.visualForwardedSnapshot();

@RichVisualPreviews('visualActionCard')
Widget appVisualActionCard() => surface.visualActionCard();

@RichVisualPreviews('visualCollapsedProse')
Widget appVisualCollapsedProse() => surface.visualCollapsedProse();

@RichVisualPreviews('visualImageGallery')
Widget appVisualImageGallery() => surface.visualImageGallery();

@RichVisualPreviews('visualAttachmentLightbox')
Widget appVisualAttachmentLightbox() => surface.visualAttachmentLightbox();

@RichVisualPreviews('visualDocumentSheet')
Widget appVisualDocumentSheet() => surface.visualDocumentSheet();
