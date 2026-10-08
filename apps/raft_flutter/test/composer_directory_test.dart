import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/composer_directory.dart';

import 'message_presentation_test.dart' show fixture;

Future<void> settled() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('private roster is lazy, member-scoped, and false flag never requests resource directories', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    w.channel = RaftChannel({'id': 'c1', 'type': 'private', 'joined': true});
    a.routes['GET /channels/c1/members'] = (_) => {
      'humans': [
        {'id': 'human', 'name': 'same'},
      ],
      'agents': [
        {'id': 'agent', 'name': 'same'},
      ],
    };
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'composer_resource_references_v0', 'enabled': false},
      ],
    };
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    expect(a.calls.where((r) => r.path.contains('/members')), isEmpty);
    directory.request('#');
    await settled();
    expect(directory.people, isEmpty);
    directory.request('@');
    await settled();
    expect(directory.people.map((p) => '${p.type}:${p.id}'), [
      'user:human',
      'agent:agent',
    ]);
    expect(
      a.calls.any(
        (r) => r.path == '/servers/s1/members' || r.path == '/agents',
      ),
      isFalse,
    );
    expect(
      a.calls.any(
        (r) => r.path.endsWith('/machines') || r.path.endsWith('/apps'),
      ),
      isFalse,
    );
  });
  test('late roster cannot restore identities after role loss', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    final response = Completer<Map<String, dynamic>>();
    a.routes['GET /channels/c1/members'] = (_) => response.future;
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    directory.request('@');
    await settled();
    w.server = RaftRecord({'id': 's1', 'role': 'guest'});
    w.setError(null);
    response.complete({
      'humans': [
        {'id': 'secret', 'name': 'hidden'},
      ],
      'agents': [],
    });
    await settled();
    expect(directory.people, isEmpty);
    expect(a.calls.any((r) => r.path == '/servers/s1/members'), isFalse);
  });
  test('enabled resource references insert canonical targets without notifying a person', () async {
    final (w, a) = await fixture('owner');
    addTearDown(w.dispose);
    a.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'composer_resource_references_v0', 'enabled': true},
      ],
    };
    a.routes['GET /servers/s1/machines'] = (_) => [
      {'id': 'machine-id', 'isComputer': true, 'name': 'Computer [A]'},
    ];
    a.routes['GET /servers/s1/apps'] = (_) => {
      'apps': [
        {'appId': 'system.test', 'displayName': 'Test app'},
      ],
    };
    final directory = ComposerDirectory(w);
    addTearDown(directory.dispose);
    directory.request('@');
    await settled();
    expect(
      directory.people.where((p) => p.type == 'computer').single.insertion,
      r'[@Computer \[A\]](<computer:machine-id>)',
    );
    expect(
      directory.people.where((p) => p.type == 'app').single.insertion,
      '[@Test app](<app:system.test>)',
    );
    expect(directory.people.every((p) => !p.isMention), isTrue);
  });
}
