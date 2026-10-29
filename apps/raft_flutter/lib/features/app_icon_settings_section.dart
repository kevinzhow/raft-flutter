import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../platform/app_icon.dart';

class AppIconSettingsSection extends StatefulWidget {
  const AppIconSettingsSection({super.key, this.service});
  final NativeAppIcon? service;
  @override
  State<AppIconSettingsSection> createState() => _AppIconSettingsSectionState();
}

class _AppIconSettingsSectionState extends State<AppIconSettingsSection>
    with WidgetsBindingObserver {
  late NativeAppIcon service;
  @override
  void initState() {
    super.initState();
    service = widget.service ?? NativeAppIcon.instance;
    WidgetsBinding.instance.addObserver(this);
    unawaited(service.refresh());
  }

  @override
  void didUpdateWidget(AppIconSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.service ?? NativeAppIcon.instance;
    if (next != service) {
      service = next;
      unawaited(service.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(service.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftAppIconChoices(
          selected: service.selected,
          busy: service.busy || !service.loaded,
          error: service.error,
          onChanged: service.supported ? service.select : null,
        ),
        if (!service.supported && service.loaded && service.error == null)
          Text(
            raftText(context, 'Icon changes are unavailable on this device.'),
          ),
        if (service.error != null)
          RaftSettingsRecipeButton(
            label: raftText(context, 'Retry'),
            onPressed: service.busy ? null : service.refresh,
          ),
      ],
    ),
  );
}
