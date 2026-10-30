#!/usr/bin/env python3
"""License-header gate for the SmartArmStack workspace.

Every first-party source file must carry a copyright notice near the top
(the LGPLv3 block used across the stack). This gate enforces presence --
the repo-level linters (ruff, pyright, clang-tidy) do not check headers,
and the per-package ament_copyright boilerplate was dropped as redundant.

Vendored and generated trees are exempt (see SKIP_* below): never edit a
vendor file to satisfy this gate, extend the skip list instead.

Usage:  tools/license_header_check.py [ROOT ...]   (default: standard dirs)
Exit:   0 all files carry a header, 1 at least one is missing.
"""

import os
import re
import sys

EXTS = {".py", ".cpp", ".hpp", ".c", ".h", ".cc", ".hh", ".cxx", ".hxx"}
SKIP_DIRS = {
    "build", "install", "log", "docs", ".devcontainer", ".git", "__pycache__",
    "node_modules", "debian", "resource", "third_party", "vendor", "pybind11",
    "Universal_Robots_Client_Library",
}
# Path components (any depth) whose whole subtree is exempt: vendored
# third-party code and generated protobuf bindings.
SKIP_PATH_PARTS = {"nanopb-0.2.8", "protobuf_gen", ".agents"}
# Individual exempt files (repo-root relative), e.g. vendored tools kept
# byte-faithful to upstream.
SKIP_FILES = {"tools/murilos_ros2_linter.py"}
DEFAULT_ROOTS = ["src", "sas_cpp", "sas_py", "scripts", "tools", "docker"]
HEADER_LINES = 20


def check_file(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            head = "".join(handle.readlines()[:HEADER_LINES])
    except OSError as exc:
        print(f"{path}:1: error: unreadable ({exc})")
        return False
    if not re.search(r"copyright", head, re.IGNORECASE):
        print(f"{path}:1: error: no Copyright notice in the first "
              f"{HEADER_LINES} lines")
        return False
    return True


def main(argv):
    roots = argv[1:] or DEFAULT_ROOTS
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    total = 0
    missing = 0
    for root in roots:
        if not os.path.isdir(root):
            print(f"warning: {root} not found, skipped")
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
            rel_dir = os.path.relpath(dirpath, repo_root)
            if any(part in SKIP_PATH_PARTS for part in rel_dir.split(os.sep)):
                continue
            for name in sorted(filenames):
                if os.path.splitext(name)[1] not in EXTS:
                    continue
                path = os.path.join(dirpath, name)
                if os.path.relpath(path, repo_root) in SKIP_FILES:
                    continue
                total += 1
                if not check_file(path):
                    missing += 1
    print(f"{total} file(s) checked, {missing} missing a license header")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
