import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_details_host.dart';

import 'close_panels_test.dart' show mountAt;
import 'support/close_registry_channel_details.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  registerCloseTests(channelDetailsSurfaces, {
    'channel-details': (t, size) async {
      final phone = size.width < 768;
      final w = await mountAt(
        t,
        size,
        phone ? '/s/demo/channel/c1?channelPage=settings:c1' : null,
      );
      if (!phone) {
        ChannelDetailsStore.of(w).open(w.channels.first);
        await frames(t, 25);
      }
      final surface = find.byKey(const Key('channel-details'));
      return SurfaceProbe(
        isOpen: () => surface.evaluate().isNotEmpty,
        x: find.byKey(const Key('channel-details-close')),
        back: find.byKey(const Key('channel-overflow-back')),
      );
    },
  });
}
