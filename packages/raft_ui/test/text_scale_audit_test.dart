// Text-scale audit with the bundled design fonts (Noto Sans CJK as the CJK
// fallback): every representative surface at 1.0x, 1.3x and 2.0x, plus the
// Chinese UI locale at 1.0x. 3.1x is iOS Accessibility 5 (body 53pt). See text_scale_audit_runner.dart.
// budget: per-surface (one case per registered surface; grows with every new preview)
import 'package:flutter/material.dart';

import '../../../tool/testing/text_scale_audit.dart';
import 'text_scale_audit_runner.dart';

void main() {
  expectSurfaceListComplete();
  defineSurfaceAudits(
    AuditFonts.real,
    modes: const [
      AuditMode.base,
      AuditMode.x13,
      AuditMode.x2,
      AuditMode.x31,
      AuditMode('zh-1.0x', locale: Locale('zh', 'CN')),
    ],
  );
}
