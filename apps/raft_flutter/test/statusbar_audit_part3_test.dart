// Part 3 of 3 of the status bar audit; the suite is declared in `statusbar_audit_test.dart`.
// matrix: nightly-full -- the matrix is cut on the gate in the first part's file.
import 'statusbar_audit_test.dart' show registerStatusbarAuditTests;
import 'support/test_parts.dart';

void main() => registerStatusbarAuditTests(TestPart(2, 3));
