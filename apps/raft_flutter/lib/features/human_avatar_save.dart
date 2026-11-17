import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart'
    show RaftHumanAvatarField, RaftHumanAvatarRecipe;

/// Sets your avatar to a built pixel avatar (Web `saveHumanAvatarRecipe`,
/// `PUT /auth/me/avatar-recipe`): it replaces any avatar, an uploaded photo
/// too, and the server answers with the updated user, which becomes the
/// signed-in user (no second `/auth/me` read). Throws when not saved; an
/// answer for an account that is no longer the signed-in one is dropped.
Future<void> saveHumanAvatarRecipe(
  RaftClient client,
  RaftHumanAvatarRecipe recipe,
) async {
  final account = client.authenticationGeneration, id = client.user?.id;
  final answer = await client.request(
    'PUT',
    '/auth/me/avatar-recipe',
    data: {
      'recipe': {
        for (final field in RaftHumanAvatarField.values)
          field.name: recipe[field],
      },
    },
  );
  if (client.authenticationGeneration != account || client.user?.id != id) {
    throw const RaftApiException.staleScope();
  }
  if (answer is! Map) {
    throw const RaftApiException('The avatar was not saved.');
  }
  await client.replaceUser(Map<String, dynamic>.from(answer));
}
