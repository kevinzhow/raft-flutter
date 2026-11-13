import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/external_sender.dart';
import 'package:raft_flutter/features/profile_preview.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 external identities (externalIdentityPresentation.ts,
/// ExternalIdentityPreviewCard.tsx, MessageItem sender name): a Slack bot's
/// synthetic label gives way to its verified profile, an unresolved profile
/// reads "Slack user {id}", a bot is an "App", and its card names its App and
/// the name it posted under.
void main() {
  Map<String, dynamic> bot({
    String display = 'Slack bot · 9xyz',
    String? profile = 'Deploy Bot',
    String? fallback,
  }) => {
    'provider': 'slack',
    'actorKind': 'bot',
    'externalActorId': 'B0129xyz',
    'displayName': display,
    'avatarUrl': '/avatars/fallback.png',
    'profileDisplayName': profile,
    'profileAvatarUrl': '/avatars/deploy.png',
    'appName': 'Deployer',
    'profileFallback': ?fallback,
  };

  Future<BuildContext> contextOf(WidgetTester t) async {
    late BuildContext context;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  RaftMessage message(Map<String, dynamic> author) => RaftMessage({
    'senderType': 'external_projection',
    'senderName': author['displayName'],
    'externalAuthor': author,
  });

  testWidgets('the synthetic Slack bot label gives way to its profile', (
    t,
  ) async {
    final context = await contextOf(t);
    expect(messageSenderName(context, message(bot())), 'Deploy Bot');
    expect(externalSenderPresentation(bot()).avatarUrl, '/avatars/deploy.png');
    // A name the bot chose itself is kept.
    expect(
      messageSenderName(context, message(bot(display: 'Release Notes'))),
      'Release Notes',
    );
    expect(
      externalSenderPresentation(bot(display: 'Release Notes')).avatarUrl,
      '/avatars/fallback.png',
    );
    expect(
      messageSenderName(context, message(bot(fallback: 'unresolved'))),
      'Slack user B0129xyz',
    );
  });

  testWidgets('a bot\'s card: App, its App and the name it posted under', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => externalIdentityPreviewBody(
              context,
              displayName: 'Deploy Bot',
              avatar: const SizedBox.square(dimension: 32),
              provider: 'slack',
              workspaceName: 'Acme',
              actorKind: 'bot',
              appName: 'Deployer',
              postedAs: 'Slack bot · 9xyz',
            ),
          ),
        ),
      ),
    );
    expect(find.text('App'), findsOneWidget);
    expect(find.text('From Slack · Deployer'), findsOneWidget);
    expect(find.text('Posted as Slack bot · 9xyz'), findsOneWidget);
    expect(find.text('From Acme'), findsNothing);
  });
}
