import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class DependencyHost {
  static const channel = MethodChannel('app.raft/linux_dependencies');
  final calls = <MethodCall>[];
  final installed = <String>{};
  final known = <String>{};
  final registered = <String>{};
  String distro = 'ubuntu', idLike = 'debian';
  bool restart = false;
  Completer<void>? wait;

  Map<String, Object?> response() => {
    'protocol': 1,
    'distro': {'id': distro, 'idLike': idLike, 'versionId': '24.04'},
    'features': {
      for (final name in ['webkit', 'mpv', 'poppler'])
        name: {
          'status': !known.contains(name)
              ? 'unchecked'
              : installed.contains(name)
              ? 'available'
              : 'missing',
          'available': known.contains(name) && installed.contains(name),
          'registered': registered.contains(name),
          'requiresRestart': restart,
          'reason': 'dependency_unavailable',
          'detail': '/private/loader/path must not become a user error',
        },
    },
  };

  void bind() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          await wait?.future;
          final args = call.arguments;
          final name = args is Map ? args['feature'] : null;
          if (name is String) {
            known.add(name);
            if (call.method == 'ensure' &&
                name != 'poppler' &&
                installed.contains(name)) {
              registered.add(name);
            }
          }
          return response();
        });
  }

  void unbind() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}
