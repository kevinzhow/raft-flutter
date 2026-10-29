// Text-scale audit with tall font metrics: every design family is replaced by
// Noto Sans CJK, so all text, Latin included, gets the line metrics of the
// taller CJK system fonts (ascent 1.16, descent 0.288 against ~1.2 for the
// design fonts). 1.0x must stay clean; 1.3x and 2.0x combine both stressors.
// budget: per-surface (one case per registered surface; grows with every new preview)
import 'package:flutter/material.dart';

import '../../../tool/testing/text_scale_audit.dart';
import 'text_scale_audit_runner.dart';

void main() {
  defineSurfaceAudits(
    AuditFonts.tall,
    modes: const [
      AuditMode.base,
      AuditMode.x13,
      AuditMode('zh-1.0x', locale: Locale('zh', 'CN')),
      AuditMode('zh-2.0x', textScale: 2.0, locale: Locale('zh', 'CN')),
    ],
  );
}
