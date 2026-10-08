// Public canonical source fixtures at 26f77ef; no sessions or live workspace data.
import 'dart:convert';

final Map<String, dynamic> pageTasksFixture = jsonDecode(r'''{
  "tasks": [
    {
      "id": "msg-task-visual-214",
      "messageId": "msg-task-visual-214",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "taskNumber": 214,
      "title": "Align the tabbar capture crops between React and Android",
      "description": "Both providers must wrap exactly the tabbar at width 390.",
      "status": "todo",
      "claimedByType": null,
      "claimedById": null,
      "claimedByName": null,
      "claimedAt": null,
      "completedAt": null,
      "createdById": "visual-user",
      "createdByType": "user",
      "createdByName": "artin",
      "createdAt": "2026-06-19T12:24:00.000Z",
      "updatedAt": "2026-06-19T12:24:00.000Z"
    },
    {
      "id": "msg-task-visual-212",
      "messageId": "msg-task-visual-212",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "taskNumber": 212,
      "title": "Fill the React fixture gaps before the Android diff",
      "description": null,
      "status": "in_progress",
      "claimedByType": "agent",
      "claimedById": "agent-cindy",
      "claimedByName": "Cindy",
      "claimedAt": "2026-06-22T02:30:00.000Z",
      "completedAt": null,
      "createdById": "visual-user",
      "createdByType": "user",
      "createdByName": "artin",
      "createdAt": "2026-06-18T00:00:00.000Z",
      "updatedAt": "2026-06-22T02:30:00.000Z"
    },
    {
      "id": "msg-task-visual-210",
      "messageId": "msg-task-visual-210",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "taskNumber": 210,
      "title": "Review the thread header strip baselines",
      "description": null,
      "status": "in_review",
      "claimedByType": "agent",
      "claimedById": "agent-product-ux",
      "claimedByName": "Product UX Designer",
      "claimedAt": "2026-06-19T12:24:00.000Z",
      "completedAt": null,
      "createdById": "agent-cindy",
      "createdByType": "agent",
      "createdByName": "Cindy",
      "createdAt": "2026-06-18T00:00:00.000Z",
      "updatedAt": "2026-06-22T02:35:00.000Z"
    },
    {
      "id": "msg-task-visual-208",
      "messageId": "msg-task-visual-208",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "taskNumber": 208,
      "title": "Publish the visual parity report",
      "description": null,
      "status": "done",
      "claimedByType": "agent",
      "claimedById": "agent-cindy",
      "claimedByName": "Cindy",
      "claimedAt": "2026-06-19T12:24:00.000Z",
      "completedAt": "2026-06-22T02:35:00.000Z",
      "createdById": "visual-user",
      "createdByType": "user",
      "createdByName": "artin",
      "createdAt": "2026-06-18T00:00:00.000Z",
      "updatedAt": "2026-06-22T02:35:00.000Z"
    }
  ]
}''') as Map<String, dynamic>;

final Map<String, dynamic> pageSavedFixture = jsonDecode(r'''{
  "hasMore": true,
  "total": 5,
  "saved": [
    {
      "messageId": "msg-saved-visual-1",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "content": "Captured the Android visual artifact for #product:f8e569cb and queued React parity.",
      "senderType": "agent",
      "senderId": "agent-cindy",
      "senderName": "Cindy",
      "createdAt": "2026-06-22T02:30:00.000Z",
      "savedAt": "2026-06-22T03:00:00.000Z",
      "parentChannelId": null,
      "parentChannelName": null,
      "parentChannelType": null,
      "parentMessageId": null
    },
    {
      "messageId": "msg-saved-visual-2",
      "channelId": "thread-visual",
      "channelName": "design",
      "channelType": "thread",
      "content": "Rename old visual cases under components.* before rerunning baseline.",
      "senderType": "user",
      "senderId": "visual-user",
      "senderName": "artin",
      "createdAt": "2026-06-22T01:40:00.000Z",
      "savedAt": "2026-06-22T02:10:00.000Z",
      "parentChannelId": "channel-design",
      "parentChannelName": "design",
      "parentChannelType": "channel",
      "parentMessageId": "msg-parent-visual"
    },
    {
      "messageId": "msg-saved-visual-3",
      "channelId": "channel-design",
      "channelName": "design",
      "channelType": "channel",
      "content": "Publish preflight is green — report goes live after the next full run.",
      "senderType": "agent",
      "senderId": "agent-product-ux",
      "senderName": "Product UX Designer",
      "createdAt": "2026-06-21T09:12:00.000Z",
      "savedAt": "2026-06-21T10:00:00.000Z",
      "parentChannelId": null,
      "parentChannelName": null,
      "parentChannelType": null,
      "parentMessageId": null
    }
  ]
}''') as Map<String, dynamic>;

final Map<String, dynamic> pageActivityFixture = jsonDecode(r'''{
  "hasMore": false,
  "totalCount": 3,
  "totalUnreadCount": 3,
  "items": [
    {
      "kind": "thread",
      "threadChannelId": "thread-msg-agent-reply",
      "parentMessageId": "msg-agent-reply",
      "parentChannelId": "channel-design",
      "parentChannelName": "design",
      "parentChannelType": "channel",
      "parentMessagePreview": "Captured the Android visual artifact for #product:f8e569cb and queued React parity.",
      "parentMessageSenderType": "agent",
      "parentMessageSenderId": "agent-cindy",
      "latestActivityPreview": "Review the Android composer crop before release.",
      "latestActivitySenderType": "user",
      "latestActivitySenderId": "visual-user",
      "latestActivityMessageId": "msg-visual-activity-reply",
      "firstUnreadMessageId": "msg-visual-activity-reply",
      "firstMentionMessageId": "msg-visual-activity-reply",
      "replyCount": 5,
      "lastActivityAt": "2026-06-22T02:35:00.000Z",
      "lastReplyAt": "2026-06-22T02:35:00.000Z",
      "unreadCount": 2,
      "hasMention": true,
      "taskNumber": null,
      "taskStatus": null,
      "taskClaimedByName": null
    },
    {
      "kind": "channel",
      "channelId": "channel-android",
      "channelName": "android-artifacts",
      "channelType": "channel",
      "lastMessageId": "msg-visual-activity-android",
      "firstUnreadMessageId": "msg-visual-activity-android",
      "firstMentionMessageId": null,
      "lastMessageAt": "2026-06-19T12:24:00.000Z",
      "lastMessagePreview": "Captured the previous visual baseline before leaving the workspace.",
      "lastMessageSenderType": "agent",
      "lastMessageSenderId": "agent-cindy",
      "lastMessageSenderName": "Cindy",
      "unreadCount": 1,
      "hasMention": false
    },
    {
      "kind": "dm",
      "channelId": "dm-agent-cindy-artin",
      "channelName": "Cindy",
      "channelType": "dm",
      "lastMessageId": "msg-visual-activity-dm",
      "firstUnreadMessageId": null,
      "firstMentionMessageId": null,
      "lastMessageAt": "2026-06-19T12:24:00.000Z",
      "lastMessagePreview": "201继续推进",
      "lastMessageSenderType": "agent",
      "lastMessageSenderId": "agent-cindy",
      "lastMessageSenderName": "Cindy",
      "unreadCount": 0,
      "hasMention": false
    }
  ]
}''') as Map<String, dynamic>;

final Map<String, dynamic> pageSearchFixture = jsonDecode(r'''{
  "comment": "Canonical /messages/search rows for components.home.search.results (manifest variant filtered-results: query 'android'). Entities and timestamps come from fixtureData.json (channels.design, agents.cindy, humans.owner, times) so React and Android render the same rows. Consumed by the playwright /messages/search route stub (packages/visual-testing/tests/react-provider.spec.ts); the render host does not prime a search store — MessageSearchPage fetches these rows after the capture interaction fills the query (task #351).",
  "hasMore": false,
  "results": [
    {
      "id": "msg-visual-search-1",
      "channelId": "channel-design",
      "threadId": null,
      "parentMessageId": null,
      "parentMessageContent": null,
      "parentChannelId": "channel-design",
      "parentChannelName": "design",
      "parentChannelType": "channel",
      "parentChannelArchivedAt": null,
      "senderId": "agent-cindy",
      "senderType": "agent",
      "senderName": "Cindy",
      "channelName": "design",
      "channelType": "channel",
      "channelArchivedAt": null,
      "content": "Captured the Android visual artifact for #product:f8e569cb and queued React parity.",
      "snippet": "Captured the Android visual artifact for #product:f8e569cb and queued React parity.",
      "createdAt": "2026-06-22T02:30:00.000Z"
    },
    {
      "id": "msg-visual-search-2",
      "channelId": "thread-msg-agent-reply",
      "threadId": null,
      "parentMessageId": "msg-agent-reply",
      "parentMessageContent": "Captured the Android visual artifact for #product:f8e569cb and queued React parity.",
      "parentChannelId": "channel-design",
      "parentChannelName": "design",
      "parentChannelType": "channel",
      "parentChannelArchivedAt": null,
      "senderId": "visual-user",
      "senderType": "user",
      "senderName": "artin",
      "channelName": "design",
      "channelType": "thread",
      "channelArchivedAt": null,
      "content": "Review the Android composer crop before release.",
      "snippet": "Review the Android composer crop before release.",
      "createdAt": "2026-06-22T02:35:00.000Z"
    }
  ]
}
''') as Map<String, dynamic>;
