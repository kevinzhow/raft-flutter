# Message scrolling performance

P01 measures the actual Linux profile engine, using a fixed 500-message channel
with long Chinese Markdown, code, images and reactions. Each of the three themes
has ten-second channel scroll, accepted message-context scroll, and native window
resize samples. The original failing samples remain separate from subsequent
attempts. Widget mount counts and unit tests do not establish native performance.

Run the reference and candidate sequentially on the same hardware, display,
Flutter 3.47.6 engine and CPU affinity, with the identical benchmark file. The
reference product commit is `e210562a80e403986d0fc44090245657906277a0`. Copy the
current integration test, driver and performance scripts into the reference
checkout; add `flutter_driver: {sdk: flutter}` to its development dependencies.
Keep the reference product implementation unchanged. Use separate fresh output
directories; the runner rejects overwriting earlier results.

```bash
python3 tool/performance/run.py --out .local/performance/reference
python3 tool/performance/run.py --out .local/performance/candidate \
  --reference .local/performance/reference
```

Run the first command inside the reference checkout. For the candidate, pass the
absolute path to that reference output if the directories differ. Repeat both
with `--semantics` and separate output directories to check accessibility costs.
`--only` and `--trace` produce diagnostics; they cannot verify P01.

The gate requires all nine real samples, approximately ten seconds of actual
action, at least nine seconds of engine frame timestamps, real content movement
and actual native view size changes. Build plus raster p95 must be below 16ms
(8ms on a display at 100Hz or above), missed display frames below 5%, and process
CPU below 80% of one core. The candidate's combined p95 must not exceed the
corresponding reference p95. CPU time covers the action, excluding the timing
collector's flush. GPU acceleration and matching hardware are checked before
comparison. Raw frames, Flutter Driver outcomes and hashed artifacts determine
the result; a manually edited green summary cannot verify the checklist.

The GitHub workflow runs measurement guards on pull requests. Its native job runs
for relevant pull requests from branches in this repository and through
`workflow_dispatch`, on a runner labeled `raft-performance`. Fork pull requests
run the guards; native execution requires a separately trusted checkout.
That runner needs an exclusive real X11 desktop (`DISPLAY`), hardware accelerated
GL, the pinned Flutter SDK, Linux build dependencies, `xdotool`, `glxinfo`, and
the host-matched media runtime. If local media libraries are used, configure
`PKG_CONFIG_PATH` and `LD_LIBRARY_PATH` in the runner environment before starting
it. The job executes semantics off and on sequentially. A workflow definition
does not establish that a matching runner exists or that the native CI job has
passed. Keep native CI as unrun until its actual job outcome is available.

The Activity reproduction uses the same mounted `RaftChatView` after the real
controller's `jumpToMessage` accepts context from the fixture API. It measures
the resulting list, rather than the Activity navigation UI. The short anchor
message ensures that target-center hit testing does not confuse empty space in
a tall row with a hidden page. First failures and target geometry are retained.
An AT-SPI bus setting alone cannot prove the semantics state of a previous
user session; record the actual engine setting for each sample.
