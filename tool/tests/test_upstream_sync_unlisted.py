"""Report in-place source changes that lack an existing review row."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from test_upstream_sync import git, make_release, make_repo, us, write_tree


class UnlistedModificationsTests(unittest.TestCase):
    def test_report_lists_shared_logic_and_unmapped_web_modifications(self):
        shared = "packages/shared/src/namePicker.ts"
        web = "packages/web/src/utils/menuFilter.ts"
        mapped = "packages/web/src/components/foo/FooPanel.tsx"
        new = "packages/shared/src/newPicker.ts"
        deleted = "packages/web/src/utils/deletedPicker.ts"
        moved = "packages/shared/src/movedPicker.ts"
        docs = "packages/web/src/assets/fonts/README.md"
        styles = "packages/web/src/index.css"
        wire = "packages/shared/src/fooWire.ts"
        large = "packages/web/src/utils/largeUnmapped.ts"
        dart = "apps/raft_flutter/lib/features/name_picker.dart"
        dart_test = "apps/raft_flutter/test/name_picker_test.dart"
        unrelated = "apps/raft_flutter/lib/features/unrelated.dart"
        before = 'export const selectName = () => "swift-otter";\n'
        after = 'export const selectName = () => "Ada";\n'
        old_large = "".join(f"const value{idx} = {idx};\n" for idx in range(80))
        new_large = old_large.replace("const value", "const change")

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            upstream = root / "upstream"
            upstream.mkdir()
            git(upstream, "init", "-q")
            make_release(upstream, "v1.0.0-source.1", {
                shared: before,
                web: before,
                mapped: before,
                deleted: "export const deletedPicker = () => false;\n",
                moved: before + "const unrelatedValue = true;\n",
                docs: "Old font attribution\n",
                styles: ":root { --size: 1px; }\n",
                wire: "export interface FooWire {\n  oldWireField: string;\n}\n",
                large: old_large,
            })
            make_release(upstream, "v1.1.0-source.1", {
                shared: after + 'export const namePrefix = "Classic";\n',
                web: after,
                mapped: after,
                new: after,
                "packages/shared/src/renamedPicker.ts": before + "const unrelatedValue = true;\n",
                docs: "Updated font attribution\n",
                styles: ":root { --size: 2px; }\n",
                wire: "export interface FooWire {\n  newWireField: string;\n}\n",
                large: new_large,
            }, remove=(deleted, moved))
            repo = make_repo("v1.0.0-source.1")
            self.addCleanup(shutil.rmtree, repo)
            write_tree(repo, {
                dart: "// Source: packages/shared/src/namePicker.ts\n",
                dart_test: "// Cases from namePicker.ts.\n",
                unrelated: "// Source: packages/web/src/namePicker.ts\n",
            })

            report = us.generate_report(
                upstream / ".git", repo, "v1.0.0-source.1", "v1.1.0-source.1", root / "trees",
            )
            markdown, json_path = us.write_report(report, root / "out")
            self.assertEqual(
                json.loads(json_path.read_text())["unlisted_modifications"],
                [
                    {"path": shared, "added": 2, "removed": 1, "dart_refs": [dart, dart_test]},
                    {"path": docs, "added": 1, "removed": 1, "dart_refs": []},
                    {"path": web, "added": 1, "removed": 1, "dart_refs": []},
                ],
            )
            section = markdown.read_text().split("## Unlisted in-place modifications (3)", 1)[1].split("\n## ", 1)[0]
            self.assertIn(f"`{shared}` | +2/-1 | `{dart}`, `{dart_test}`", section)
            self.assertIn(f"`{web}` | +1/-1 |", section)
            self.assertNotIn(mapped, section)


if __name__ == "__main__":
    unittest.main()
