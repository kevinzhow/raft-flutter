/// Native smoke host. Its Windows identity, COM class and receipt are isolated
/// from the product; it never opens a session, workspace or network connection.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/windows_notifications.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final lab = _Lab(
    arguments.any(
      (argument) => argument.startsWith('raft-notification-lab://'),
    ),
  );
  await lab.service.initialize();
  for (final argument in arguments) {
    final uri = Uri.tryParse(argument);
    if (uri != null) lab.service.receiveWindowsActivation(uri);
  }
  if (arguments.contains('--send-test')) await lab.send();
  await lab.record();
  runApp(MaterialApp(home: _LabPage(lab)));
}

class _Lab extends ChangeNotifier {
  _Lab(this.cold) {
    service.onTap = (payload) {
      if (payload != 'raft-notification-test') return;
      taps++;
      unawaited(service.presentWindow());
      unawaited(record());
      notifyListeners();
    };
  }
  final bool cold;
  final service = NativeNotificationService(
    platform: TargetPlatform.windows,
    windows: WindowsNotifications(lab: true),
  );
  int taps = 0;
  int active = 0;
  bool posted = false;
  Future<void> _writes = Future.value();
  Future<void> record() {
    final receipt = jsonEncode({
      'cold': cold,
      'available': service.available,
      'permitted': service.permitted,
      'posted': posted,
      'taps': taps,
      'active': active,
      'error': service.error,
    });
    return _writes = _writes.then((_) async {
      await File(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          'notification-lab-receipt.json',
        ),
      ).writeAsString(receipt);
    });
  }

  Future<void> send() async {
    posted = await service.test(
      title: 'Raft 通知测试',
      body: 'Windows notification lab — 点击返回测试窗口。',
    );
    active =
        await const MethodChannel('app.raft/windows-notifications')
            .invokeMethod<int>('labHistory') ??
        0;
    await record();
    notifyListeners();
  }
}

class _LabPage extends StatelessWidget {
  const _LabPage(this.lab);
  final _Lab lab;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Raft notification lab')),
    body: ListenableBuilder(
      listenable: lab,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: ${lab.service.available}'),
            Text('OS permission: ${lab.service.permitted}'),
            Text('Posted: ${lab.posted}'),
            Text('Notification clicks: ${lab.taps}'),
            Text('Notifications in OS history: ${lab.active}'),
            Text('Cold activation: ${lab.cold}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: lab.send,
              child: const Text('Send Test Notification'),
            ),
            ElevatedButton(
              onPressed: lab.service.openSettings,
              child: const Text('Open Notification Settings'),
            ),
          ],
        ),
      ),
    ),
  );
}
