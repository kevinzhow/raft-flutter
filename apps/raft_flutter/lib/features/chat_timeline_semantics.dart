part of 'chat_view.dart';

extension _ChatTimelineSemantics on _RaftChatViewState {
  double get timelineMessageBodySize => messagePreferenceDisplaySize(
    context,
    PersonalPresentationScope.bodyFontSize(
      context,
      w.client.user?.string('preferredMessageBodyFontSize'),
    ),
  );

  List<RaftMessageSemanticsAction> messageSemanticsActions(
    RaftMessage message, {
    required bool parent,
    required bool pending,
  }) {
    if (pending) return const [];
    final saved = SavedCountStore.of(w).isSaved(message.id);
    return [
      if (!parent && !widget.thread && presentationActive)
        RaftMessageSemanticsAction(
          raftText(context, 'Reply in thread'),
          (_) => _messages.threads.openThread(message),
        ),
      if (canReact)
        RaftMessageSemanticsAction(
          raftText(context, 'Add reaction'),
          (row) => openReactionPicker(message, row),
        ),
      if (presentationActive && !w.client.restoredOffline)
        RaftMessageSemanticsAction(
          raftText(context, saved ? 'Remove from Saved' : 'Save'),
          (_) => saveMessage(message),
        ),
      RaftMessageSemanticsAction(
        raftText(context, 'Copy Markdown'),
        (_) => Clipboard.setData(ClipboardData(text: message.content)),
      ),
      ...translationSemanticsActions(message),
      RaftMessageSemanticsAction(raftText(context, 'Message Actions'), (row) {
        final box = row.findRenderObject();
        actions(
          message,
          anchor: box is RenderBox && box.hasSize
              ? box.localToGlobal(box.size.center(Offset.zero))
              : null,
          parentTile: parent,
        );
      }),
    ];
  }

  String? messageSemanticsContent(RaftMessage message) =>
      switch (message.json['actionMetadata']) {
        {'kind': 'action-card' || 'forwarded-bundle'} => '',
        _ => null,
      };

  List<Map<String, dynamic>> messageTileReactions(RaftMessage message) =>
      (message.json['reactions'] as List? ?? [])
          .whereType<Map>()
          .map((reaction) => Map<String, dynamic>.from(reaction))
          .toList();

  ValueChanged<String>? messageReactionAction(
    RaftMessage message, {
    required bool pending,
  }) => canReact
      ? (emoji) {
          if (!pending) react(message, emoji);
        }
      : null;

  MessagePresentation presentMessageProse(
    RaftMessage message,
    String? content, {
    double fontSize = 14,
    String? unavailablePermalink,
  }) => MessagePresentation(
    controller: w,
    navigation: ChatNavigationScope.maybeOf(context),
    message: message,
    unavailablePermalink: unavailablePermalink,
    content: content,
    taskByNumber: taskProjection.taskByNumber,
    onExternalLink: link,
    onOpenTask: openTaskRef,
    directoryReferences: referenceDirectory.references,
    fontSize: fontSize,
    searchHighlight: searchActive == message.id ? boundSearch?.query : null,
  );

  Widget? previewMessageTile(
    RaftMessage message,
    double width,
    TimelinePreviewExtent extent,
  ) {
    if (message.string('messageType') == 'system' ||
        message.retracted ||
        message.json['actionMetadata'] is Map) {
      return null;
    }
    final translations = w.services.translations.present(message);
    if (longMessagesCollapse(message.json, w.channel?.json)) {
      final fits = extent.measured
          ? extent.height < RaftCollapsible.heightLimit
          : !selection.active &&
                translations.translatedContent == null &&
                !translations.skeleton &&
                RaftMessageTile.plainBodyFits(
                  context,
                  message.content,
                  rowWidth: width,
                  rowContext: widget.thread
                      ? RaftMessageRowContext.thread
                      : RaftMessageRowContext.main,
                  fontSize: timelineMessageBodySize,
                );
      if (!fits) return null;
    }
    final prose = presentMessageProse(message, translations.translatedContent);
    final pending = WorkspaceMessages.isPendingSend(message);
    return TimelineRowPreview(
      height: extent.height,
      tile: RaftMessageTile(
        author: messageSenderName(context, message),
        timestamp: timeFormatter.messageTime(message.createdAt),
        content: prose.text,
        departureLabel: senderDepartureLabel(message),
        compactSemantics: true,
        coarsePointer: RaftDensityScope.of(context) == RaftDensity.touch,
        semanticsActions: messageSemanticsActions(
          message,
          parent: false,
          pending: pending,
        ),
        onAuthor: senderMention(message),
        onReaction: messageReactionAction(message, pending: pending),
        reactions: messageTileReactions(message),
        onActionsAt: (anchor) {
          if (!pending) actions(message, anchor: anchor);
        },
      ),
      linkGroups: translations.skeleton
          ? const []
          : [
              ...prose.proseSemanticsLinks,
              if (translations.bilingual)
                ...presentMessageProse(message, null).proseSemanticsLinks,
            ],
      onLink: (href) => unawaited(prose.open(context, href)),
    );
  }
}
