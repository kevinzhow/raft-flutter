import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/previews.dart';

import '../data/workspace_controller.dart';
import 'account_connections_view.dart';

@RaftPreviews('Page Account provider-managed sign-in', size: Size(390, 844))
Widget accountProviderManagedPreview() => const _SignInPreview(password: false);
@RaftPreviews('Page Account local password inline', size: Size(390, 844))
Widget accountLocalPasswordPreview() => const _SignInPreview(password: true);

class _SignInPreview extends StatefulWidget {
  const _SignInPreview({required this.password});
  final bool password;
  @override
  State<_SignInPreview> createState() => _SignInPreviewState();
}

class _SignInPreviewState extends State<_SignInPreview> {
  late final client = _PublicSignInClient(
    widget.password,
  )..user = RaftRecord({'id': 'visual-user', 'email': 'artin@example.invalid'});
  late final w = WorkspaceController(client);
  @override
  void dispose() {
    w.dispose();
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    primary: false,
    child: AccountConnectionsView(controller: w, inline: true),
  );
}

class _PublicSignInClient extends RaftClient {
  _PublicSignInClient(this.password)
    : super(
        origin: 'https://public-visual-fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  final bool password;
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'GET' && path == '/auth/identities') {
      return {
        'passwordConfigured': password,
        'identities': [
          {'provider': 'google', 'providerEmail': 'artin@example.invalid'},
        ],
      };
    }
    if (method == 'GET' && path == '/auth/providers') {
      return {
        'providers': [
          {'id': 'google', 'label': 'Google', 'enabled': false},
        ],
      };
    }
    throw const RaftApiException(
      'This public fixture does not execute account mutations or external sign-in.',
    );
  }
}
