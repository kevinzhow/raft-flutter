import 'package:flutter/material.dart';
import 'package:raft_ui/previews.dart';
import 'package:raft_ui/notification_previews.dart' as notification;

@RaftPreviews('Source notification center empty', size: Size(640, 480))
Widget notificationCenterEmptyPreview() =>
    notification.notificationCenterEmptyPreview();
@RaftPreviews('Source notification center actions', size: Size(640, 480))
Widget notificationCenterActionsPreview() =>
    notification.notificationCenterActionsPreview();
@RaftPreviews(
  'Source notification center Computer fixture',
  size: Size(412, 480),
)
Widget notificationCenterComputerPreview() =>
    notification.notificationCenterComputerPreview();
@RaftPreviews('Source notification center touch', size: Size(412, 480))
Widget notificationCenterTouchPreview() =>
    notification.notificationCenterTouchPreview();
@RaftPreviews('Source notification center long text', size: Size(412, 640))
Widget notificationCenterLongPreview() =>
    notification.notificationCenterLongPreview();
@RaftPreviews('Source notification attention', size: Size(640, 480))
Widget notificationAttentionPreview() =>
    notification.notificationAttentionPreview();
