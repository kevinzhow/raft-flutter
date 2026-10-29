import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/server_error_code.dart';
import 'private_route_guard.dart';

/// The default community server (utils/communityServers.ts).
const communityServerSlug = 'community';

/// `/s/<slug>` of a community server the app joins on arrival (Web
/// ServerResolver: `community`; `community-cn` opens a separate page there).
bool isAutoJoinCommunitySlug(String? slug) => slug == communityServerSlug;

/// What `POST /servers/join-community` answered.
sealed class CommunityJoinOutcome {
  const CommunityJoinOutcome();
}

class CommunityJoined extends CommunityJoinOutcome {
  const CommunityJoined();
}

/// `agreement_required` / `agreement_changed`: the agreement to accept first.
class CommunityAgreementRequired extends CommunityJoinOutcome {
  const CommunityAgreementRequired(this.agreement);
  final Map<String, dynamic> agreement;
  String get id => '${agreement['id']}';
  String get title => '${agreement['title'] ?? ''}';
  String get bodyMarkdown => '${agreement['bodyMarkdown'] ?? ''}';
  int get version => (agreement['version'] as num?)?.toInt() ?? 1;
}

class CommunityJoinFailed extends CommunityJoinOutcome {
  const CommunityJoinFailed(this.error);

  /// The failure as caught; display it through `userErrorText` (Web:
  /// `response.data.error || "Failed to join community server"`).
  final Object error;
}

/// useJoinCommunityFlow.joinCommunity / the agreement dialog's join: one
/// request, classified.
Future<CommunityJoinOutcome> requestCommunityJoin(
  RaftClient client,
  String slug, {
  String? agreementId,
}) async {
  try {
    await client.post(
      '/servers/join-community',
      data: {'slug': slug, 'agreementId': ?agreementId},
    );
    return const CommunityJoined();
  } on RaftApiException catch (error) {
    final agreement = error.details['agreement'];
    if ((serverErrorIs(error, 'agreement_required') ||
            serverErrorIs(error, 'agreement_changed')) &&
        agreement is Map) {
      return CommunityAgreementRequired(Map<String, dynamic>.from(agreement));
    }
    return CommunityJoinFailed(error);
  }
}

/// The dialog's error line: a changed agreement asks the member to reopen
/// the join action, anything else is the generic failure.
String communityAgreementError(BuildContext context, Object error) =>
    serverErrorIs(error, 'agreement_changed')
    ? raftText(
        context,
        'The agreement was updated. Open the join action again to review the latest version.',
      )
    : raftText(context, 'Failed to join community server');

/// Shows the community agreement over [context]'s navigator. Resolves true
/// after [onAgree] succeeded, false when the member cancelled or closed it.
Future<bool> showCommunityAgreementDialog(
  BuildContext context, {
  required CommunityAgreementRequired agreement,
  required Future<void> Function(String agreementId) onAgree,
}) async {
  final joined = await showRaftDialog<bool>(
    context: context,
    barrierDismissible: false,
    routeSettings: const RouteSettings(name: PrivateRouteGuard.rootOwnedRoute),
    builder: (dialogContext) => RaftCommunityAgreementDialog(
      title: agreement.title,
      version: agreement.version,
      bodyMarkdown: agreement.bodyMarkdown,
      errorMessage: communityAgreementError,
      onClose: () => Navigator.of(dialogContext).pop(false),
      onAgree: () async {
        await onAgree(agreement.id);
        if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
      },
    ),
  );
  return joined == true;
}

/// Joins [slug]. An agreement that must be accepted first is shown in the
/// dialog ([beforeDialog] runs just before it opens). Resolves true once
/// joined, false when the member declined the agreement; a failed request
/// rethrows the [RaftApiException] (show it with `userErrorText`).
Future<bool> joinCommunity(
  BuildContext Function() dialogContext,
  RaftClient client,
  String slug, {
  VoidCallback? beforeDialog,
}) async {
  final first = await requestCommunityJoin(client, slug);
  switch (first) {
    case CommunityJoined():
      return true;
    case CommunityJoinFailed(:final error):
      throw error;
    case CommunityAgreementRequired():
      beforeDialog?.call();
      final context = dialogContext();
      if (!context.mounted) return false;
      return showCommunityAgreementDialog(
        context,
        agreement: first,
        onAgree: (agreementId) async {
          final result = await requestCommunityJoin(
            client,
            slug,
            agreementId: agreementId,
          );
          switch (result) {
            case CommunityJoined():
              return;
            case CommunityAgreementRequired():
              throw const RaftApiException('agreement_changed');
            case CommunityJoinFailed(:final error):
              throw error;
          }
        },
      );
  }
}
