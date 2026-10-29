// Native iOS notification-startup fixture. Build only into a fresh simulator
// with an app.raft.notification-startup.qa.* bundle ID. Never uses an account.
// RunnerTests verifies preparation before the first opt-in; the visible button
// exercises the production permission service and scheduler. Relaunch the same
// installed app to exercise restored permission/preferences without clearing it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_flutter/platform/attachment_files.dart';
import 'package:raft_flutter/platform/file_selection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/background_notifications.dart';

const _scope =
    'https://fixture.invalid\nnotification-test\nnotification-server';
const _optedInKey = 'notification-startup-fixture.opted-in';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final info = await PackageInfo.fromPlatform();
  if (!Platform.isIOS ||
      !info.packageName.startsWith('app.raft.notification-startup.qa.')) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Text('Isolated iOS QA identity required')),
      ),
    );
    return;
  }
  runApp(const MaterialApp(home: _Fixture()));
}

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> with WidgetsBindingObserver {
  final service = NativeNotificationService();
  final background = BackgroundNotificationScheduler();
  String phase = 'Before first notification opt-in';
  bool busy = false;
  bool restored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore().then((_) => restored = true);
  }

  Future<void> _record(String value) async {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/notification-startup.json').writeAsString(
      jsonEncode({
        'phase': value,
        'permitted': service.permitted,
        'enabled': service.enabled,
        'error': service.error,
        'pid': pid,
      }),
      flush: true,
    );
    if (mounted) setState(() => phase = value);
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_optedInKey) != true) {
      await _record('Before first notification opt-in');
      return;
    }
    await service.bindAuthenticatedWorkspace(_scope);
    await background.bind(_scope, service.enabled);
    await _record('Restored after cold launch');
  }

  Future<void> _enable() async {
    setState(() => busy = true);
    try {
      await service.bindAuthenticatedWorkspace(_scope);
      await _record('Requesting notification permission');
      await service.requestEnable(true);
      await (await SharedPreferences.getInstance()).setBool(_optedInKey, true);
      await _record('Permission answered; binding background refresh');
      await background.bind(_scope, service.enabled);
      await _record('Permission and background binding completed');
    } catch (error) {
      await _record('Failed: ${error.runtimeType}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && restored && !busy) _refresh();
  }

  Future<void> _refresh() async {
    await service.refreshPermission();
    if ((await SharedPreferences.getInstance()).getBool(_optedInKey) == true) {
      await background.bind(_scope, service.enabled);
    }
    await _record(phase);
  }

  Future<void> _savePhoto() async {
    setState(() => busy = true);
    try {
      // A synthetic one-pixel PNG; no account, network or personal photos.
      await AttachmentFiles().saveToGallery(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMwTpv5HwAENAIyWy0K4AAAAABJRU5ErkJggg==',
        ),
        filename: 'notification-permission-fixture.png',
        mimeType: 'image/png',
        authorized: () => true,
      );
      await _record('Photo saved');
    } on PlatformException catch (error) {
      await _record('Photo result: ${error.code}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickPhotos() async {
    setState(() => busy = true);
    try {
      final selected = await selectUploads(mediaOnly: true);
      await _record('Photos selected: ${selected.length}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification startup QA')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(phase),
          Text(
            service.permitted ? 'Permission: allowed' : 'Permission: denied',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: busy ? null : _enable,
            child: const Text('Enable notifications'),
          ),
          ElevatedButton(
            onPressed: busy ? null : service.openSettings,
            child: const Text('Open app settings'),
          ),
          ElevatedButton(
            onPressed: busy ? null : _savePhoto,
            child: const Text('Save synthetic photo'),
          ),
          ElevatedButton(
            onPressed: busy ? null : _pickPhotos,
            child: const Text('Pick photos'),
          ),
        ],
      ),
    ),
  );
}
