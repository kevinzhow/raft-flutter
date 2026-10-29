import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Source `isApplePlatform` (`/mac|iphone|ipad|ipod/`): macOS and iOS use Cmd
/// for app shortcuts, every other platform uses Ctrl.
bool usesCommandShortcuts([TargetPlatform? platform]) {
  final target = platform ?? defaultTargetPlatform;
  return target == TargetPlatform.macOS || target == TargetPlatform.iOS;
}

/// Source `isGlobalSearchShortcut` / `isThreadSearchShortcut` modifier rule:
/// the platform's primary modifier alone. Cmd without Ctrl on macOS and iOS,
/// Ctrl without Cmd/Super elsewhere. On macOS Ctrl+K is the text field's
/// "delete to end of line", so Ctrl must never stand in for Cmd there.
bool primaryShortcutModifierDown([
  HardwareKeyboard? keyboard,
  TargetPlatform? platform,
]) {
  final state = keyboard ?? HardwareKeyboard.instance;
  return usesCommandShortcuts(platform)
      ? state.isMetaPressed && !state.isControlPressed
      : state.isControlPressed && !state.isMetaPressed;
}

/// `SingleActivator` modifier flags for the platform's primary shortcut.
({bool control, bool meta}) primaryShortcutFlags([TargetPlatform? platform]) {
  final command = usesCommandShortcuts(platform);
  return (control: !command, meta: command);
}

/// Source `getGlobalSearchShortcutLabel`: "⌘K" on Apple platforms, "Ctrl+K"
/// elsewhere (`common.shortcut.ctrlK`).
String globalSearchShortcutLabel([TargetPlatform? platform]) =>
    usesCommandShortcuts(platform) ? '⌘K' : 'Ctrl+K';
