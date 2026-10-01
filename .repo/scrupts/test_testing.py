"""Regression tests for selection, Git history and the library process pool."""

import contextlib
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import testing


class RepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "tests@example.invalid")
        self.git("config", "user.name", "Testing")
        for name in ("net_ip", "net_socket", "web_http", "codec_base64"):
            self.library(name)
        self.write("akku/net_socket/client.mojo", "from akku.net_ip import Address\n")
        self.write("akku/web_http/client.mojo", "from akku.net_socket import Socket\n")
        self.write(".gitignore", "*.log\n.tmp/\n")
        self.commit("Initial libraries")
        self.write("CHANGELOG.md", "First release\n")
        self.commit("release: v0.1.0 [skip ci]")
        self.git("tag", "v0.1.0")
        self.env = patch.object(testing, "environment_issue", return_value=None)
        self.env.start()
        self.addCleanup(self.env.stop)

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True).strip()

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def library(self, name, ci=False, failing=False):
        command = "exit 7" if failing else "echo test >> ../../calls.log"
        taskfile = (
            "version: '3'\nsilent: true\ntasks:\n"
            f"  test:\n    cmds:\n      - '{command}'\n"
        )
        if ci:
            taskfile += "  ci:\n    cmds:\n      - 'echo ci >> ../../calls.log'\n"
        self.write(f"akku/{name}/Taskfile.yml", taskfile)
        self.write(f"akku/{name}/__init__.mojo", "# library entry\n")

    def commit(self, message):
        self.git("add", "-A")
        self.git("commit", "-qm", message)

    def plan(self):
        return testing.make_plan(self.root, smart=True, base_ref="main")

    def test_unchanged_tag_selects_nothing(self):
        plan = self.plan()
        self.assertEqual(plan.baseline, "v0.1.0")
        self.assertEqual(set(plan.selected), set())

    def test_native_change_selects_reverse_transitive_chain(self):
        self.write("akku/net_ip/_internal/clib/ip.c", "int ip = 1;\n")
        self.assertEqual(set(self.plan().selected), {"net_ip", "net_socket", "web_http"})

    def test_committed_red_change_is_selected_on_every_invocation(self):
        self.write("akku/net_ip/__init__.mojo", "# broken phase commit\n")
        self.commit("A deliberately red phase")
        first = self.plan()
        self.assertEqual(set(first.selected), {"net_ip", "net_socket", "web_http"})
        self.assertEqual(first.selected, self.plan().selected)

    def test_staged_unstaged_and_untracked_changes_are_combined(self):
        self.write("akku/net_ip/__init__.mojo", "# staged\n")
        self.git("add", "akku/net_ip/__init__.mojo")
        self.write("akku/codec_base64/__init__.mojo", "# unstaged\n")
        self.write("akku/net_socket/new fixture.txt", "untracked fixture\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_staged_change_is_seen_even_when_worktree_is_restored(self):
        self.write("akku/net_ip/__init__.mojo", "# staged edit\n")
        self.git("add", "akku/net_ip/__init__.mojo")
        self.write("akku/net_ip/__init__.mojo", "# library entry\n")
        self.assertIn("net_ip", self.plan().selected)

    def test_ignored_untracked_and_developer_notes_do_not_select_suites(self):
        self.write("run.log", "ignored\n")
        self.write("akku/net_ip/_dev/TODO.md", "Later API\n")
        self.write(".repo/todo/net_ip.yml", "summary: catalogue only\n")
        self.assertEqual(self.plan().selected, {})

    def test_markdown_anywhere_is_excluded_but_other_library_files_are_relevant(self):
        for path in ("akku/net_ip/README.md", "akku/net_ip/_tests/notes.md", "new-guide.md"):
            self.write(path, "documentation only\n")
        self.assertEqual(self.plan().selected, {})
        self.write("akku/net_ip/_internal/native.c", "int changed = 1;\n")
        self.assertEqual(set(self.plan().selected), {"net_ip", "net_socket", "web_http"})
        self.write("akku/codec_base64/_tests/input.bin", "fixture\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_new_library_is_discovered_without_a_registration(self):
        self.library("crypto_new")
        self.assertEqual(set(self.plan().selected), {"crypto_new"})

    def test_sources_without_a_taskfile_are_an_error(self):
        self.write("akku/new_lib/__init__.mojo", "# new\n")
        with self.assertRaises(testing.PlanError):
            testing.discover(self.root)

    def test_deleted_dependency_keeps_old_consumers_in_selection(self):
        for path in (self.root / "akku/net_ip").iterdir():
            path.unlink()
        self.write("akku/net_socket/client.mojo", "# removed its import\n")
        plan = self.plan()
        self.assertEqual(set(plan.selected), {"net_socket", "web_http"})

    def test_renamed_file_selects_both_owners(self):
        self.git("mv", "akku/net_ip/__init__.mojo", "akku/codec_base64/moved.mojo")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_removed_import_still_uses_tag_graph(self):
        self.write("akku/net_socket/client.mojo", "# no import now\n")
        self.write("akku/net_ip/__init__.mojo", "# changed\n")
        self.assertEqual(set(self.plan().selected), {"net_ip", "net_socket", "web_http"})

    def test_test_only_dependency_is_included(self):
        self.write("akku/codec_base64/_tests/test_ip.mojo", "from akku.net_ip import Address\n")
        self.commit("Cross-library test")
        self.write("akku/net_ip/__init__.mojo", "# changed\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_cycle_does_not_hang_selection(self):
        self.write("akku/net_ip/cycle.mojo", "from akku.web_http import Client\n")
        self.assertEqual(set(self.plan().selected), {"net_ip", "net_socket", "web_http"})

    def test_shared_runner_change_selects_everything(self):
        self.write(".repo/scrupts/helper.sh", "echo changed\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_unknown_root_file_is_conservative(self):
        self.write("unexpected.config", "something\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_unknown_import_falls_back_to_full(self):
        self.write("akku/net_socket/client.mojo", "import akku.not_present\n")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))
        self.assertIn("import", self.plan().fallback)

    def test_missing_tag_means_full(self):
        self.git("tag", "-d", "v0.1.0")
        self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))
        self.assertIsNone(self.plan().baseline)

    def test_unrelated_high_version_tag_is_not_selected(self):
        self.git("switch", "-qc", "other")
        self.write("CHANGELOG.md", "Unrelated release\n")
        self.commit("release: v9.0.0 [skip ci]")
        self.git("tag", "v9.0.0")
        self.git("switch", "-q", "main")
        self.assertEqual(self.plan().baseline, "v0.1.0")

    def test_feature_branch_tag_is_not_a_main_baseline(self):
        self.git("switch", "-qc", "feature")
        self.write("CHANGELOG.md", "Feature tag\n")
        self.commit("release: v2.0.0 [skip ci]")
        self.git("tag", "v2.0.0")
        self.assertEqual(self.plan().baseline, "v0.1.0")

    def test_unverified_version_tag_is_not_a_baseline(self):
        self.write("CHANGELOG.md", "Manual tag\n")
        self.commit("Not a full-check release")
        self.git("tag", "v3.0.0")
        self.assertEqual(self.plan().baseline, "v0.1.0")

    def test_environment_mismatch_means_full(self):
        with patch.object(testing, "environment_issue", return_value="different platform"):
            self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))
            self.assertIn("platform", self.plan().fallback)

    def test_full_is_full_even_without_changes(self):
        plan = testing.make_plan(self.root, smart=False)
        self.assertEqual(set(plan.selected), set(testing.discover(self.root)))

    def test_shallow_history_means_full(self):
        with patch.object(testing, "is_shallow", return_value=True):
            self.assertEqual(set(self.plan().selected), set(testing.discover(self.root)))

    def test_stash_is_not_active_but_applied_stash_is_seen(self):
        self.write("akku/net_ip/__init__.mojo", "# stashed\n")
        self.git("stash", "push", "-qm", "inactive")
        self.assertEqual(self.plan().selected, {})
        self.git("stash", "apply", "-q")
        self.assertIn("net_ip", self.plan().selected)

    def test_release_guard_allows_metadata_only(self):
        checked = self.git("rev-parse", "HEAD")
        self.write("CHANGELOG.md", "New release\n")
        self.write(".changes/archive/v0.2.0/new.md", "NEW: next\n")
        testing.release_guard(self.root, checked)

    def test_release_guard_rejects_code_changed_after_full(self):
        checked = self.git("rev-parse", "HEAD")
        self.write("akku/net_ip/__init__.mojo", "# changed after full\n")
        with self.assertRaises(testing.PlanError):
            testing.release_guard(self.root, checked)

    def test_single_library_ci_falls_back_to_test(self):
        with contextlib.redirect_stdout(io.StringIO()):
            result = testing.run_pool(self.root, ["net_ip"], "ci", 1)
        self.assertEqual(result, 0)
        self.assertEqual((self.root / "calls.log").read_text(), "test\n")

    def test_ci_task_is_called_once_without_an_extra_test(self):
        self.library("net_ip", ci=True)
        with contextlib.redirect_stdout(io.StringIO()):
            result = testing.run_pool(self.root, ["net_ip"], "ci", 1)
        self.assertEqual(result, 0)
        self.assertEqual((self.root / "calls.log").read_text(), "ci\n")

    def test_one_failure_makes_the_pool_fail_and_other_suites_still_run(self):
        self.library("net_ip", failing=True)
        with contextlib.redirect_stdout(io.StringIO()):
            result = testing.run_pool(self.root, ["net_ip", "codec_base64"], "test", 2)
        self.assertNotEqual(result, 0)
        self.assertEqual((self.root / "calls.log").read_text(), "test\n")

    def test_unknown_library_and_missing_task_fail(self):
        with self.assertRaises(testing.PlanError):
            testing.run_pool(self.root, ["../net_ip"], "test", 1)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertNotEqual(testing.run_pool(self.root, ["net_ip"], "compile", 1), 0)

    def root_task(self, command):
        project = Path(__file__).resolve().parents[2]
        self.write("Taskfile.yml", (project / "Taskfile.yml").read_text())
        self.write(".repo/scrupts/testing.py", (project / ".repo/scrupts/testing.py").read_text())
        return subprocess.run(["task", command], cwd=self.root, capture_output=True, text=True)

    def test_root_wildcard_discovers_new_library_without_registration(self):
        self.library("crypto_example")
        result = self.root_task("crypto_example::test")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / "calls.log").read_text(), "test\n")
        self.assertFalse((self.root / ".task").exists())

    def test_root_wildcard_unknown_library_fails(self):
        result = self.root_task("missing_example::test")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown library", result.stderr)

    def test_pool_concurrency_is_bounded(self):
        active = peak = 0
        lock = threading.Lock()

        def execute(root, name, mode):
            nonlocal active, peak
            with lock:
                active += 1
                peak = max(peak, active)
            time.sleep(0.03)
            with lock:
                active -= 1
            return 0, "passed\n"

        with patch.object(testing, "execute_library", side_effect=execute):
            with contextlib.redirect_stdout(io.StringIO()):
                testing.run_pool(self.root, list(testing.discover(self.root)), "test", 2)
        self.assertEqual(peak, 2)


class ImportTests(unittest.TestCase):
    names = {"net_ip", "net_socket", "web_http", "codec_base64"}

    def deps(self, source, path="akku/net_socket/client.mojo"):
        return testing.import_dependencies(source, path, self.names)

    def test_absolute_aliases_and_multiline_imports(self):
        source = """import akku.net_ip as ip
from akku.codec_base64 import (
    encode as enc,
    decode,
)
def inside():
    from akku.web_http.client import Client
"""
        self.assertEqual(self.deps(source), {"net_ip", "codec_base64", "web_http"})

    def test_relative_imports_and_root_import_list(self):
        self.assertEqual(self.deps("from ..net_ip import Address\n"), {"net_ip"})
        self.assertEqual(self.deps("from akku import net_ip as ip, web_http\n"), {"net_ip", "web_http"})
        self.assertEqual(self.deps("from .client import Client\n"), set())
        self.assertEqual(
            self.deps("from ...net_ip import Address\n", "akku/net_socket/_tests/test.mojo"),
            {"net_ip"},
        )

    def test_comments_strings_and_own_imports_are_not_edges(self):
        source = '''# from akku.web_http import Client
var example = "import akku.web_http"
var docs = """from akku.codec_base64 import encode
import akku.web_http
"""
from akku.net_socket._internal.core import helper
from std.collections import List
'''
        self.assertEqual(self.deps(source), set())

    def test_escaped_quotes_and_raw_strings_do_not_leak_imports(self):
        self.assertEqual(self.deps('var text = r"from akku.web_http import Client"\n'), set())
        self.assertEqual(self.deps('var text = "quote\\\" import akku.web_http"\n'), set())

    def test_ambiguous_root_and_unknown_local_imports_are_not_ignored(self):
        for source in ("import akku\n", "from akku import *\n", "import akku.missing\n"):
            with self.subTest(source=source), self.assertRaises(testing.PlanError):
                self.deps(source)

    def test_dynamic_imports_are_not_silently_ignored(self):
        with self.assertRaises(testing.PlanError):
            self.deps('var module = Python.import_module("something")\n')

    def test_unterminated_string_prevents_an_incomplete_graph(self):
        with self.assertRaises(testing.PlanError):
            self.deps('var example = "unterminated\nimport akku.net_ip\n')


if __name__ == "__main__":
    unittest.main()
