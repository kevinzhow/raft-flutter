import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'previews.dart';

@RaftPreviews('Banner', size: Size(390, 360))
Widget bannerPreview() => const Padding(
  padding: EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RaftBanner(
        description: 'Avatar upload failed. Try again.',
        size: RaftBannerRecipeSize.sm,
      ),
      SizedBox(height: 16),
      RaftBanner(
        title: 'Connection interrupted',
        description: 'Your draft is saved. Reconnect to send it.',
        status: RaftBannerRecipeStatus.info,
      ),
      SizedBox(height: 16),
      RaftBanner(
        description: 'Profile saved.',
        status: RaftBannerRecipeStatus.success,
        size: RaftBannerRecipeSize.lg,
      ),
    ],
  ),
);
