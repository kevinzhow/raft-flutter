# Behavior checklist

Canonical `data/nav.json`, `data/loading.json` and `data/performance.json` describe the current parent items (the original 47 plus separately recorded discoveries),
their independently required checks and Source references. They do not contain
completion states. `data/baseline-audit.json` retains Cindy's initial human audit
as historical evidence. It cannot verify the current code.

Tests carry labels such as `[N24a]`. The collector preserves Flutter's machine
results, failures, skips, source hash, immutable log hash and declared evidence
layer. Declare `mounted` only for labeled tests that actually mount the page or
component; controller/model tests stay at those layers. For mixed suites, use
the weaker layer unless every labeled check is a mounted test. N24's accepted
identity API tests are collected as `controller`; its actual Activity handler
proof comes from `workspace_activity_activation_test.dart`, the independently held
uncached-parent cases in `workspace_activity_canonical_cold_test.dart`, and real
focus expiry in `mounted_thread_focus_expiry_test.dart`.

```sh
python3 tool/checklist/run.py --root . --out .local/checklist-<new-attempt> \
  --suite mounted:test/workspace_activity_activation_test.dart \
  --suite controller:test/known_thread_identity_test.dart
python3 tool/checklist/build.py --source-hash "$(tool/source-hash)" \
  --commit "$(git rev-parse HEAD)" \
  --receipt .local/checklist-<new-attempt>/receipt.json \
  --out .local/checklist-<new-page>
python3 -m unittest discover -s tool/checklist -p 'test_*.py' -v
```

Use a new run directory each time. All required children must pass on unchanged
current input before the parent is verified. Source-mismatched receipts are
ignored; changed logs fail the build. Model/controller proof cannot verify a
page contract. Missing checks, aborts, failures and skips remain visible. Multiple
copies of one passing test cannot satisfy missing theme coverage.

The generated page has one current progress number; historical audit counts are
collapsed. Only current parent items contribute to the denominator; the frozen historical audit retains its original 47. Child checks
provide coverage detail without inflating progress. The four user-facing states distinguish verified, partial, missing test evidence
and not started. Without current proof, historical partial/not-started review
can describe implementation progress; historical verified or implemented items
become missing evidence. Historical review cannot verify the current snapshot.
Connect old tests progressively instead of importing handwritten completion.
The page records a separate checksum of the checklist rules, collector and data;
these tool files are outside the product `source-hash` input set.

Visual results are separate frozen evidence. To display them, pass a JSON
`--visual-receipt` containing `title`, `flutterCommit`, `sourceHash`, `casesPath`
(relative to that receipt) and `casesSha`. The builder verifies exact bytes and
prints that capture's version separately; it never calls old pixels current.
The existing parity acceptance and baseline images are unchanged.

After validated direct pushes to `cindy/integration`, publish the generated
`index.html`, `progress.json` and copied evidence to the existing report hub's
`raft_flutter_checklist/` directory. Keep prior generated pages in a timestamped
history directory and browser-check the fixed URL and proof links.

P01 is a separate performance contract. Its three children require native profile evidence in each actual theme for channel scroll, post-context scroll and native window resize. Mounted-row boundedness tests are supplementary and cannot verify a native frame-time contract. Original visual and historical audit thresholds remain unchanged.
