import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chinese_community.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_community.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  final harness = <String, OpenSurface>{
    'chinese-community-page': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showChineseCommunityPage(context, 'https://api.raft.build'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () => find.byType(ChineseCommunityPage).evaluate().isNotEmpty,
        back: find.byKey(const ValueKey('chinese-community-back')),
      );
    },
  };
  registerCloseTests(communitySurfaces, harness);
}
