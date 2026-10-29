// Text fit on the Android Chinese control profile (docs/android-cjk-control-typography.md):
// the line box of every control label is 1.3 with proportional leading, taller
// than the Web 1.0 line a recipe's fixed height was cut for. Every preview is
// pumped at 1.0x / 1.3x / 2.0x and checked for clipped ink, overflow, text that
// escapes a fixed-height box and (offCentre) single-line labels that sit off
// the centre of their pill / button / chip.
// budget: per-surface (one case per registered surface; grows with every new preview)
import 'package:flutter/material.dart';

import '../../../tool/testing/text_scale_audit.dart';
import 'text_scale_audit_runner.dart';

void main() {
  defineSurfaceAudits(
    AuditFonts.real,
    profile: 'android-zh',
    androidChinese: true,
    centring: true,
    allSurfaces: true,
    ignoreKinds: const {'error'},
    modes: const [
      AuditMode('zh-1.0x', locale: Locale('zh', 'CN')),
      AuditMode('zh-1.3x', textScale: 1.3, locale: Locale('zh', 'CN')),
      AuditMode('zh-2.0x', textScale: 2.0, locale: Locale('zh', 'CN')),
    ],
  );
}
