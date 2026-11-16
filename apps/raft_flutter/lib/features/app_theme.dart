import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

/// The app's [ThemeData] for one brightness (the `theme:` / `darkTheme:` of
/// the root MaterialApp).
ThemeData raftAppTheme({
  required bool dark,
  required RaftAppearance appearance,
  required Locale locale,
  required Locale textLocale,
}) => raftTheme(
  dark: dark,
  pack: appearance.pack,
  locale: locale,
  textLocale: textLocale,
);
