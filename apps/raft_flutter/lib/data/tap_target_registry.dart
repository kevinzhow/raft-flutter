/// Registry of every container that renders a message (or a message list) and
/// every element Web makes interactive inside it.
///
/// Why it exists: a tap on a message element never navigates by itself. It
/// writes the location (`?thread=`, `?profile=`, `?task=`) or runs a callback,
/// and the CONTAINER must render the result. `NavigationRegistry` audits that
/// targets exist; it cannot see a container that writes a target nobody
/// renders (Activity preview + reply card: location got `?thread=`, no column
/// showed it). This registry lists the containers and cells, and
/// `test/tap_target_matrix_test.dart` taps each cell on the real widgets and
/// fails when the tap changes nothing visible. `test/tap_target_registry_test.dart`
/// fails when `lib/` builds a message container that is not listed here, and
/// keeps `docs/tap-targets.md` in step with this file.
library;

/// A mounted shape of the workspace in which message rows are tappable.
enum TapSurface {
  /// Main conversation of the Chat route (phone page or desktop column).
  chat,

  /// Chat route with a reply thread open beside / over the conversation.
  chatThreadPanel,

  /// Activity master-detail preview of a channel / DM row (column 3).
  activityChannel,

  /// Activity master-detail preview of a thread row (the thread IS column 3).
  activityThread,

  /// Search master-detail preview of a channel / DM hit (column 3).
  searchChannel,
}

class TapHost {
  const TapHost(
    this.id,
    this.surface,
    this.width,
    this.label, {
    this.touch = false,
  });
  final String id;
  final TapSurface surface;
  final double width;
  final String label;

  /// Touch device (phone, foldable): no hover toolbar, a tap on the row body
  /// opens the thread (Web `handleMobileTap`, `(hover: hover)` false).
  final bool touch;

  /// The thread is the detail itself (no reply cards, thread rows).
  bool get threadDetail =>
      surface == TapSurface.activityThread ||
      surface == TapSurface.chatThreadPanel;
}

/// An element of a message row that Web makes interactive.
enum TapElement {
  inlineThreadCard('Inline thread card ("N replies")'),
  repliesBadge('Thread replies badge'),
  toolbarReply('Hover toolbar: Reply in thread (pointer)'),
  rowTap('Row body tap (touch)'),
  avatar('Sender avatar'),
  mention('@mention link'),
  channelLink('#channel link'),
  taskRef('Inline #N task reference'),
  taskChip('Linked task chip'),
  reaction('Reaction chip'),
  attachment('Attachment chip');

  const TapElement(this.label);
  final String label;
}

/// What a tap must visibly do.
enum TapEffect {
  /// The reply thread is on screen and the location carries `?thread=`.
  threadPanel,

  /// A profile panel is on screen and the location carries `?profile=`.
  profilePanel,

  /// The location changed (navigation to another conversation).
  location,

  /// The task slot (`?task=`) opened.
  taskSlot,

  /// A server request was sent (in-place mutation).
  request,

  /// A dialog / page route was pushed.
  route,

  /// Web does nothing either; the cell asserts nothing changed.
  documentedNoop,

  /// Web does something and Flutter does not yet (a recorded gap, see
  /// docs/tap-targets.md "Left unfixed"). The cell asserts nothing changed, so
  /// fixing the gap fails the cell and forces the registry and docs to follow.
  knownGap,

  /// The element does not exist in this host.
  absent,
}

class TapExpectation {
  const TapExpectation(this.kind, [this.web = '']);
  final TapEffect kind;

  /// Web behaviour in plain words, for docs/tap-targets.md.
  final String web;
}

class TapContainer {
  const TapContainer(this.id, this.file, this.constructs, this.coverage);
  final String id;

  /// Path under `lib/` of the file that builds the container.
  final String file;

  /// Message widgets this file is allowed to construct.
  final List<String> constructs;

  /// Where its taps are asserted.
  final String coverage;
}

abstract final class TapTargetRegistry {
  static const hosts = <TapHost>[
    TapHost('chat-1280', TapSurface.chat, 1280, 'Chat, desktop 1280'),
    TapHost('chat-390', TapSurface.chat, 390, 'Chat, phone 390', touch: true),
    TapHost(
      'chat-thread-1280',
      TapSurface.chatThreadPanel,
      1280,
      'Chat thread panel, desktop 1280',
    ),
    TapHost(
      'activity-1280',
      TapSurface.activityChannel,
      1280,
      'Activity channel preview, desktop 1280',
    ),
    TapHost(
      'activity-816',
      TapSurface.activityChannel,
      816,
      'Activity channel preview, foldable 816 (touch)',
      touch: true,
    ),
    TapHost(
      'activity-thread-1280',
      TapSurface.activityThread,
      1280,
      'Activity thread preview, desktop 1280',
    ),
    TapHost(
      'activity-thread-816',
      TapSurface.activityThread,
      816,
      'Activity thread preview, foldable 816 (touch)',
      touch: true,
    ),
    TapHost(
      'search-1280',
      TapSurface.searchChannel,
      1280,
      'Search channel preview, desktop 1280',
    ),
    TapHost(
      'search-816',
      TapSurface.searchChannel,
      816,
      'Search channel preview, foldable 816 (touch)',
      touch: true,
    ),
  ];

  static const _absent = TapExpectation(TapEffect.absent);

  /// Web column 4 beside a channel detail; `ThreadPanel` replaces the
  /// conversation below `lg`.
  static const _thread = TapExpectation(
    TapEffect.threadPanel,
    'Opens the thread panel (column 4 on content routes, right panel on chat)',
  );
  static const _profile = TapExpectation(
    TapEffect.profilePanel,
    'Opens the profile panel (ProfilePanelWrapper) on every route',
  );

  static TapExpectation expectation(TapHost host, TapElement element) {
    if (host.threadDetail) {
      // Web ThreadPanel hides thread actions inside a thread; the rows of the
      // reply fixture carry only a sender and an @mention.
      return switch (element) {
        TapElement.avatar => _profile,
        TapElement.mention => _profile,
        _ => _absent,
      };
    }
    return switch (element) {
      TapElement.inlineThreadCard || TapElement.repliesBadge => _thread,
      TapElement.toolbarReply => host.touch ? _absent : _thread,
      TapElement.rowTap =>
        host.touch
            ? const TapExpectation(
                TapEffect.knownGap,
                'Web touch: a tap on the row (not a link / button / image) '
                'opens its thread. Flutter: SelectionArea owns the tap on '
                'message text',
              )
            : _absent,
      TapElement.avatar || TapElement.mention => _profile,
      TapElement.channelLink => const TapExpectation(
        TapEffect.location,
        'MessageItem onNavigateChannel: opens the channel route',
      ),
      TapElement.taskRef => const TapExpectation(
        TapEffect.taskSlot,
        'onOpenTaskRef: opens the task slot (openThread intent task)',
      ),
      TapElement.taskChip => const TapExpectation(
        TapEffect.taskSlot,
        'Opens the task slot (?task=)',
      ),
      TapElement.reaction => const TapExpectation(
        TapEffect.request,
        'Toggles the viewer reaction',
      ),
      TapElement.attachment => const TapExpectation(
        TapEffect.route,
        'Opens the attachment preview / lightbox',
      ),
    };
  }

  /// Every file under `lib/` that constructs a message container widget. A new
  /// file that builds one of [guardedConstructs] fails
  /// `test/tap_target_registry_test.dart` until it is listed here with the
  /// test that taps it.
  static const containers = <TapContainer>[
    TapContainer('message-timeline', 'features/chat_view.dart', [
      'RaftMessageTile',
      'RaftInlineThreadSurface',
      'RaftThreadRepliesBadge',
    ], 'tap_target_matrix_test.dart (every host)'),
    TapContainer('workspace-hosts', 'features/workspace_view.dart', [
      'RaftChatView',
    ], 'tap_target_matrix_test.dart (thread panel, Activity / Search detail)'),
    TapContainer('channel-panel', 'features/conversation_panel.dart', [
      'RaftChatView',
    ], 'tap_target_matrix_test.dart (chat, Activity, Search hosts)'),
    TapContainer(
      'task-discussion',
      'features/task_surface.dart',
      ['RaftChatView'],
      'tap_target_matrix_test.dart (task discussion carries onTask / onViewBilling)',
    ),
    TapContainer('public-server', 'features/public_server_view.dart', [
      'RaftMessageTile',
      'RaftThreadRepliesBadge',
    ], 'public_server_view_test.dart (reply badge opens the thread)'),
    TapContainer(
      'activity-saved-rows',
      'features/resource_view.dart',
      ['RaftConversationCard'],
      'activity_row_interaction_test.dart; tap_target_matrix_test.dart (Saved rows)',
    ),
    TapContainer(
      'activity-card-rows',
      'features/activity_card_row.dart',
      ['RaftConversationCard'],
      'activity_row_interaction_test.dart; activity_conversation_list_test.dart (Activity card and list rows)',
    ),
    TapContainer('search-rows', 'features/resource_search.dart', [
      'RaftSearchResultSurface',
    ], 'desktop_preview_single_location_test.dart'),
    TapContainer('image-export', 'features/message_image_export.dart', [
      'RaftMessageTile',
    ], 'inert by design: off-screen render for the exported image'),
    TapContainer('appearance-sample', 'features/appearance_section.dart', [
      'RaftMessageTile',
    ], 'inert by design: static sample row in Appearance settings'),
  ];

  /// Widgets whose construction makes a file a message container.
  static const guardedConstructs = <String>[
    'RaftChatView(',
    'RaftMessageTile(',
    'RaftInlineThreadSurface(',
    'RaftThreadRepliesBadge(',
    'RaftConversationCard(',
    'RaftSearchResultSurface(',
  ];

  static String _cell(TapExpectation e) => switch (e.kind) {
    TapEffect.threadPanel => 'thread panel',
    TapEffect.profilePanel => 'profile panel',
    TapEffect.location => 'opens channel',
    TapEffect.taskSlot => 'task slot',
    TapEffect.request => 'request',
    TapEffect.route => 'dialog',
    TapEffect.documentedNoop => 'no-op (as Web)',
    TapEffect.knownGap => 'GAP: no-op',
    TapEffect.absent => '-',
  };

  /// The generated part of docs/tap-targets.md: the matrix the widget test
  /// walks, and the list of containers.
  static String matrixMarkdown() {
    final out = StringBuffer()
      ..writeln('| Element | ${hosts.map((h) => h.id).join(' | ')} |')
      ..writeln('|---|${hosts.map((_) => '---').join('|')}|');
    for (final element in TapElement.values) {
      out.writeln(
        '| ${element.label} | '
        '${hosts.map((h) => _cell(expectation(h, element))).join(' | ')} |',
      );
    }
    out
      ..writeln()
      ..writeln('| Host | Surface | Width |')
      ..writeln('|---|---|---|');
    for (final host in hosts) {
      out.writeln('| `${host.id}` | ${host.label} | ${host.width.toInt()} |');
    }
    out
      ..writeln()
      ..writeln('| Container | File | Builds | Taps asserted in |')
      ..writeln('|---|---|---|---|');
    for (final c in containers) {
      out.writeln(
        '| ${c.id} | `lib/${c.file}` | ${c.constructs.join(', ')} | ${c.coverage} |',
      );
    }
    return out.toString();
  }
}
