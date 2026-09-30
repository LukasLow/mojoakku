"""Discover and run library checks, using full-tested release tags as a baseline.

No success cache or dependency registry. Native/Python files belong to their
library; only Mojo imports create edges between libraries.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import subprocess
import sys


class PlanError(Exception):
    """Cannot establish a safe selection or execute the requested command."""


@dataclass
class Plan:
    libraries: tuple[str, ...]
    selected: dict[str, str]
    baseline: str | None = None
    fallback: str | None = None


def git(root, *args, input=None):
    result = subprocess.run(
        ["git", *args], cwd=root, input=input, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode:
        raise PlanError(result.stderr.decode(errors="replace").strip())
    return result.stdout


def paths(output):
    return {os.fsdecode(name) for name in output.split(b"\0") if name}


def discover(root):
    folder = root / "akku"
    libraries = {}
    for directory in sorted(folder.iterdir()) if folder.is_dir() else []:
        if not directory.is_dir():
            continue
        taskfile = directory / "Taskfile.yml"
        has_sources = any("_dev" not in path.parts for path in directory.rglob("*.mojo"))
        if not taskfile.exists() and not has_sources:
            continue
        if not re.fullmatch(r"[a-z][a-z0-9_]*", directory.name):
            raise PlanError(f"Invalid library identifier: {directory.name}")
        if directory.is_symlink() or taskfile.is_symlink():
            raise PlanError(f"Library paths must be owned directories: {directory.name}")
        if not taskfile.is_file():
            raise PlanError(f"Library {directory.name} has sources but no Taskfile.yml")
        libraries[directory.name] = taskfile
    if not libraries:
        raise PlanError("No library Taskfiles found under akku/")
    return libraries


def is_shallow(root):
    return git(root, "rev-parse", "--is-shallow-repository").strip() == b"true"


def eligible_tag(root, base_ref):
    if not base_ref:
        for candidate in ("origin/main", "main"):
            try:
                git(root, "rev-parse", "--verify", candidate + "^{commit}")
                base_ref = candidate
                break
            except PlanError:
                pass
    if not base_ref:
        raise PlanError("No main/PR target reference is available")
    # Resolve first so user-provided reference names cannot be interpreted as flags.
    target = git(root, "rev-parse", "--verify", "--end-of-options", base_ref + "^{commit}")
    target = target.decode().strip()
    tags = git(root, "tag", "--list", "v*", "--sort=-version:refname").decode().splitlines()
    for tag in tags:
        if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
            continue
        try:
            git(root, "merge-base", "--is-ancestor", tag, "HEAD")
            git(root, "merge-base", "--is-ancestor", tag, target)
        except PlanError:
            continue
        subject = git(root, "log", "-1", "--format=%s", tag).decode().strip()
        if subject == f"release: {tag} [skip ci]":
            return tag
    raise PlanError("No full-check release tag exists on the shared main ancestry")


def changed_paths(root, baseline):
    # Include both index and actual checkout. --no-renames exposes both owners.
    changed = paths(git(root, "diff", "--name-only", "-z", "--no-renames", baseline, "--"))
    changed |= paths(git(root, "diff", "--cached", "--name-only", "-z", "--no-renames", baseline, "--"))
    changed |= paths(git(root, "ls-files", "--others", "--exclude-standard", "-z"))
    return changed


def owner(path):
    parts = PurePosixPath(path).parts
    return parts[1] if len(parts) >= 3 and parts[0] == "akku" else None


def developer_note(path):
    parts = PurePosixPath(path).parts
    return len(parts) >= 4 and parts[0] == "akku" and parts[2] == "_dev"


def documentation(path):
    return (
        path in {"README.md", "AGENTS.md", "TODO.md", "CHANGELOG.md", "LICENSE", ".repo/TESTING.md"}
        or path.startswith(("docs/", ".changes/", ".repo/todo/"))
        or (path.startswith(".agents/") and path.endswith(".md"))
    )


def source_tokens(source):
    """Small Mojo lexer: remove comments/quoted literals before reading imports.

    Python's tokenize is intentionally not used: its contract requires Python
    syntax, whereas Mojo adds escaped identifiers and other syntax.
    """
    tokens = []
    position = 0
    while position < len(source):
        char = source[position]
        if char == "#":
            end = source.find("\n", position)
            position = len(source) if end < 0 else end
        elif char in "\"'":
            quote = char * 3 if source.startswith(char * 3, position) else char
            position += len(quote)
            while position < len(source) and not source.startswith(quote, position):
                if source[position] == "\\":
                    position += 2
                elif source[position] == "\n" and len(quote) == 1:
                    raise PlanError("Unterminated quoted literal during import scan")
                else:
                    position += 1
            if position >= len(source):
                raise PlanError("Unterminated quoted literal during import scan")
            position += len(quote)
            tokens.append("<literal>")
        elif char == "`":
            end = source.find("`", position + 1)
            if end < 0:
                raise PlanError("Unterminated escaped identifier during import scan")
            tokens.append(source[position + 1:end])
            position = end + 1
        elif char == "\n":
            tokens.append("\n")
            position += 1
        elif char.isspace():
            position += 1
        elif char.isalpha() or char == "_":
            end = position + 1
            while end < len(source) and (source[end].isalnum() or source[end] == "_"):
                end += 1
            tokens.append(source[position:end])
            position = end
        else:
            tokens.append(char)
            position += 1
    return tokens


def import_statement(tokens, start):
    end, depth = start, 0
    while end < len(tokens):
        token = tokens[end]
        if token in {"\n", ";"} and depth == 0:
            break
        depth += (token == "(") - (token == ")")
        if depth < 0:
            raise PlanError("Unbalanced import statement")
        end += 1
    if depth:
        raise PlanError("Unbalanced import statement")
    return [token for token in tokens[start:end] if token != "\n"], end


def import_dependencies(source, path, libraries):
    tokens = source_tokens(source)
    if "import_module" in tokens or "__import__" in tokens:
        raise PlanError(f"Dynamic import cannot be resolved in {path}")
    dependencies = set()
    source_owner = owner(path)
    package = list(PurePosixPath(path).parent.parts)

    def resolve(module):
        if not re.fullmatch(r"\.*(?:[\w]+(?:\.[\w]+)*)?", module) or not module:
            raise PlanError(f"Unsupported import path in {path}: {module}")
        level = len(module) - len(module.lstrip("."))
        if level:
            if level > len(package):
                raise PlanError(f"Relative import leaves the project in {path}")
            prefix = package[:len(package) - level + 1]
            suffix = module[level:].split(".") if module[level:] else []
            return prefix + suffix
        return module.split(".")

    def add(parts):
        if parts[0] != "akku":
            if parts[0] in libraries:
                raise PlanError(f"Unqualified project import in {path}")
            return
        if len(parts) < 2 or parts[1] not in libraries:
            raise PlanError(f"Unresolved project import in {path}: {'.'.join(parts)}")
        if parts[1] != source_owner:
            dependencies.add(parts[1])

    position = 0
    while position < len(tokens):
        keyword = tokens[position]
        if keyword not in {"from", "import"}:
            position += 1
            continue
        statement, position = import_statement(tokens, position)
        if keyword == "from":
            try:
                split = statement.index("import")
            except ValueError as error:
                raise PlanError(f"Unsupported from-import in {path}") from error
            module = resolve("".join(statement[1:split]))
            if module == ["akku"]:
                names = [token for token in statement[split + 1:] if token not in {"(", ")"}]
                for group in split_imports(names):
                    add(module + resolve(group))
            else:
                add(module)
        else:
            for module in split_imports(statement[1:]):
                add(resolve(module))
    return dependencies


def split_imports(tokens):
    """Module list with optional aliases; reject shapes we cannot resolve."""
    groups, group = [], []
    for token in [*tokens, ","]:
        if token == ",":
            if group:
                if "as" in group:
                    split = group.index("as")
                    if len(group[split + 1:]) != 1:
                        raise PlanError("Unsupported import alias")
                    group = group[:split]
                groups.append("".join(group))
            group = []
        else:
            group.append(token)
    if not groups:
        raise PlanError("Empty import list")
    return groups


def tagged_sources(root, tag):
    """Read baseline blobs in one batch; never extract Git paths to disk."""
    entries = {}
    for entry in git(root, "ls-tree", "-r", "-z", tag, "--", "akku").split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, sha = metadata.split()
        path = os.fsdecode(name)
        if path.endswith("/Taskfile.yml") or (path.endswith(".mojo") and not developer_note(path)):
            if mode == b"120000" or kind != b"blob":
                raise PlanError(f"Cannot resolve linked baseline source: {path}")
            entries[path] = sha
    hashes = sorted(set(entries.values()))
    output = git(root, "cat-file", "--batch", input=b"\n".join(hashes) + b"\n") if hashes else b""
    blobs, offset = {}, 0
    for sha in hashes:
        end = output.index(b"\n", offset)
        actual, kind, length = output[offset:end].split()
        if actual != sha or kind != b"blob":
            raise PlanError("Unexpected baseline blob response")
        start = end + 1
        offset = start + int(length)
        blobs[sha] = output[start:offset]
        offset += 1
    return {path: blobs[sha].decode("utf-8-sig") for path, sha in entries.items()}


def current_sources(root):
    inventory = paths(git(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "akku"))
    sources = {}
    for path in sorted(inventory):
        if not path.endswith(".mojo") or developer_note(path):
            continue
        file = root / path
        if file.is_symlink():
            raise PlanError(f"Cannot resolve linked source: {path}")
        if file.is_file():
            sources[path] = file.read_text(encoding="utf-8-sig")
    return sources


def dependency_graph(sources, libraries):
    graph = {name: set() for name in libraries}
    for path, source in sorted(sources.items()):
        name = owner(path)
        if path.endswith(".mojo") and name in graph:
            graph[name].update(import_dependencies(source, path, libraries))
    return graph


def environment_issue(root, tag):
    # Current main CI runs Ubuntu x86-64. A Linux tag does not certify macOS/ARM.
    if platform.system() != "Linux" or platform.machine() not in {"x86_64", "AMD64"}:
        return "release tags certify Linux x86-64 CI, not this platform"
    try:
        lock = git(root, "show", f"{tag}:pixi.lock").decode()
        versions = set(re.findall(r"/linux-64/mojo-([0-9]+\.[0-9]+\.[0-9]+)-", lock))
        version = subprocess.run(["mojo", "--version"], capture_output=True, text=True, check=True)
        actual = re.search(r"[0-9]+\.[0-9]+\.[0-9]+", version.stdout + version.stderr)
        if len(versions) != 1 or actual is None or actual.group() not in versions:
            return "installed Mojo does not match the release tag's locked compiler"
    except (PlanError, OSError, subprocess.CalledProcessError):
        return "cannot verify the release tag's toolchain"
    return None


def make_plan(root, smart, base_ref=None):
    libraries = tuple(discover(root))

    def full(reason, baseline=None):
        return Plan(libraries, {name: reason for name in libraries}, baseline, reason)

    if not smart:
        return full("explicit full run")
    baseline = None
    try:
        if is_shallow(root):
            raise PlanError("Shallow Git history; cannot verify a full-check release tag")
        baseline = eligible_tag(root, base_ref)
        issue = environment_issue(root, baseline)
        if issue:
            return full(issue, baseline)
        changed = changed_paths(root, baseline)
        relevant = {path for path in changed if not developer_note(path) and not documentation(path)}
        shared = sorted(path for path in relevant if owner(path) is None)
        if shared:
            return full(f"shared or unclassified input changed: {shared[0]}", baseline)
        old_sources = tagged_sources(root, baseline)
        old_libraries = {owner(path) for path in old_sources if path.endswith("/Taskfile.yml")}
        known = set(libraries) | old_libraries
        graph = dependency_graph(old_sources, known)
        for name, dependencies in dependency_graph(current_sources(root), known).items():
            graph.setdefault(name, set()).update(dependencies)
        reasons = {owner(path): f"changed: {path}" for path in sorted(relevant)}
        queue = list(reasons)
        for dependency in queue:
            for consumer in sorted(graph):
                if dependency in graph[consumer] and consumer not in reasons:
                    reasons[consumer] = f"depends on {dependency} ({reasons[dependency]})"
                    queue.append(consumer)
        selected = {name: reasons[name] for name in libraries if name in reasons}
        return Plan(libraries, selected, baseline)
    except (PlanError, UnicodeError, OSError, ValueError) as error:
        return full(f"safe full fallback: {error}", baseline)


def print_plan(plan):
    print(f"Baseline: {plan.baseline or 'none'}; selected {len(plan.selected)}/{len(plan.libraries)} libraries", flush=True)
    if plan.fallback:
        print(f"Full: {plan.fallback}", flush=True)
    for name in plan.libraries:
        if name in plan.selected:
            print(f"RUN {name}: {plan.selected[name]}", flush=True)
        else:
            print(f"UNCHANGED {name}", flush=True)


def execute_library(root, name, mode):
    taskfile = root / "akku" / name / "Taskfile.yml"
    available = subprocess.run(
        ["task", "-t", str(taskfile), "--list-all", "--json"],
        cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    if available.returncode:
        return available.returncode, available.stderr
    try:
        tasks = {item["name"] for item in json.loads(available.stdout)["tasks"]}
    except (ValueError, KeyError, TypeError) as error:
        return 1, f"Cannot inspect tasks for {name}: {error}\n"
    command = "test" if mode == "ci" and "ci" not in tasks else mode
    if command not in tasks:
        return 1, f"Library {name} does not provide task {command}\n"
    result = subprocess.run(
        ["task", "-t", str(taskfile), command], cwd=root,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    return result.returncode, result.stdout


def run_pool(root, names, mode, jobs):
    if jobs < 1:
        raise PlanError("JOBS must be a positive integer")
    libraries = discover(root)
    for name in names:
        if name not in libraries:
            raise PlanError(f"Unknown library: {name}")
    failed = []
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = {pool.submit(execute_library, root, name, mode): name for name in names}
        for future in as_completed(futures):
            name = futures[future]
            try:
                status, output = future.result()
            except OSError as error:
                status, output = 1, str(error)
            print(f"== {name}::{mode}", flush=True)
            if output:
                print(output, end="" if output.endswith("\n") else "\n", flush=True)
            print(f"{'FAIL' if status else 'PASS'} {name}", flush=True)
            if status:
                failed.append(name)
    if failed:
        print(f"FAILED: {', '.join(sorted(failed))}", flush=True)
        return 1
    return 0


def release_guard(root, checked):
    checked = git(root, "rev-parse", "--verify", "--end-of-options", checked + "^{commit}").decode().strip()
    changed = changed_paths(root, checked)
    unexpected = sorted(path for path in changed if path != "CHANGELOG.md" and not path.startswith(".changes/"))
    if unexpected:
        raise PlanError("Files changed after full CI outside release metadata: " + ", ".join(unexpected))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("plan", help="Explain smart selection without running checks")
    run = commands.add_parser("run")
    run.add_argument("mode", choices=("test", "ci"))
    run.add_argument("selection", choices=("smart", "full"))
    single = commands.add_parser("single")
    single.add_argument("library")
    single.add_argument("mode", choices=("test", "compile", "ci"))
    guard = commands.add_parser("release-guard")
    guard.add_argument("checked_commit")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    try:
        if args.command == "release-guard":
            release_guard(root, args.checked_commit)
            print("Release inputs unchanged; only release metadata may be committed.")
            return 0
        if args.command == "single":
            return run_pool(root, [args.library], args.mode, 1)
        plan = make_plan(root, args.command == "plan" or args.selection == "smart", os.getenv("REPO_BASE_REF"))
        print_plan(plan)
        if args.command == "plan":
            return 0
        try:
            jobs = int(os.getenv("REPO_TEST_JOBS", "2"))
        except ValueError as error:
            raise PlanError("JOBS must be a positive integer") from error
        return run_pool(root, list(plan.selected), args.mode, jobs)
    except (PlanError, OSError) as error:
        print(f"testing: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
