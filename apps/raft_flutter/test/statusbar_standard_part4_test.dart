// Part 4 of 4 of the status bar standard audit; the suite is declared in `statusbar_standard_test.dart`.
// matrix: nightly-full -- the matrix is cut on the gate in the first part's file.
import 'statusbar_standard_test.dart' show registerStatusbarStandardTests;
import 'support/test_parts.dart';

void main() => registerStatusbarStandardTests(TestPart(3, 4));
