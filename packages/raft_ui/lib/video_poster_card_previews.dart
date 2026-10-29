import 'dart:convert';

import 'package:flutter/material.dart';

import 'previews.dart';
import 'raft_ui.dart';

/// A one-pixel picture standing in for a poster.
// ignore: raft_lints/avoid_raw_image_decode -- A preview's one-pixel stand-in; nothing is decoded at size.
final _poster = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPQdi0AAAF/AOFhadZxAAAAAElFTkSuQmCC',
  ),
);

Widget _frame(Widget card) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [card],
  ),
);

@RaftPreviews('Video poster card, landscape', size: Size(390, 500))
Widget videoPosterCardLandscapePreview() => _frame(
  RaftVideoPosterCard(
    filename: 'walkthrough.mp4',
    poster: _poster,
    aspectRatio: 16 / 9,
    duration: const Duration(minutes: 1, seconds: 23),
    onOpen: () {},
  ),
);

@RaftPreviews('Video poster card, portrait', size: Size(390, 900))
Widget videoPosterCardPortraitPreview() => _frame(
  RaftVideoPosterCard(
    filename: 'phone-clip.mp4',
    poster: _poster,
    aspectRatio: 9 / 16,
    duration: const Duration(seconds: 19),
    onOpen: () {},
  ),
);

@RaftPreviews('Video poster card, very tall (capped)', size: Size(390, 700))
Widget videoPosterCardTallPreview() => _frame(
  RaftVideoPosterCard(
    filename: 'scroll.mp4',
    poster: _poster,
    aspectRatio: 9 / 32,
    duration: const Duration(hours: 1, minutes: 2, seconds: 3),
    onOpen: () {},
  ),
);

@RaftPreviews('Video poster card, no poster yet', size: Size(390, 400))
Widget videoPosterCardPlaceholderPreview() => _frame(
  RaftVideoPosterCard(filename: 'clip.mp4', onOpen: () {}),
);

@RaftPreviews('Video poster card, uploading', size: Size(390, 400))
Widget videoPosterCardUploadingPreview() =>
    _frame(const RaftVideoPosterCard(filename: 'clip.mp4', loading: true));
