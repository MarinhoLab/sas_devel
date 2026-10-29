#!/usr/bin/env bash
# SmartArmStack lint driver: clang-tidy for C++, ruff + pyright for Python.
#
# Configs live at the repository root: .clang-tidy, ruff.toml,
# pyrightconfig.json. This script only wires the tools together.
#
# Usage:
#   scripts/lint.sh [MODE]
#     MODE: all (default) | cpp | py | types | ros2
#       cpp   clang-tidy over the C++ sources in the compile database
#       py    ruff (style + bugbear; import-resolution independent)
#       types pyright. Full results need the compiled pybind11 bindings and
#             rclpy/dqrobotics on the search path, i.e. run it in the ROS
#             docker image after `colcon build` and `source install/setup.bash`
#             (outside that environment missing imports degrade to warnings
#             and unknown extension symbols to errors).
#       ros2  tools/murilos_ros2_linter.py over src/ (spin/shutdown template,
#             ROS naming, package.xml vs imports/entry-points). Quietest in
#             the ROS container with the workspace sourced: installed
#             packages then count as declared dependencies.
#
# C++ linting needs a colcon compile database. Generate one with:
#   colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
# The script uses <ROOT>/build/compile_commands.json and, when that is
# missing, merges the per-package databases under <ROOT>/build/*/ first.
# The database must have been generated in the same environment the lint
# runs in (e.g. generate and lint inside the same docker container).
#
# Environment overrides:
#   CLANG_TIDY   clang-tidy binary          (default: clang-tidy, brew llvm fallback)
#   RUFF         ruff command               (default: ruff, falls back to "uvx ruff")
#   PYRIGHT      pyright command            (default: pyright, falls back to "uvx pyright")
#   COMPILE_DB   directory holding compile_commands.json (default: <ROOT>/build)
#   PARALLEL     clang-tidy job count       (default: number of CPUs)
#   ROS2_LINTER  murilos_ros2_linter.py path (default: <ROOT>/tools/)
#
# Exit codes:
#   0  no findings
#   1  at least one linter reported findings or failed
#   2  usage/environment error (missing database, missing tool)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
MODE="${1:-all}"
FAIL=0

die() { echo "ERROR: $*" >&2; exit 2; }

case "$MODE" in all|cpp|py|types|ros2) ;; *) die "unknown MODE '$MODE' (use: all|cpp|py|types|ros2)";; esac

nproc_or() {
    command -v nproc >/dev/null 2>&1 && { nproc; return; }
    sysctl -n hw.ncpu 2>/dev/null || echo 4
}

# Find clang-tidy: env override, PATH, then Homebrew LLVM (macOS).
find_clang_tidy() {
    [ -n "${CLANG_TIDY:-}" ] && { echo "$CLANG_TIDY"; return; }
    command -v clang-tidy >/dev/null 2>&1 && { command -v clang-tidy; return; }
    for c in /opt/homebrew/opt/llvm/bin/clang-tidy \
             /usr/local/opt/llvm/bin/clang-tidy \
             /usr/bin/clang-tidy-18 /usr/bin/clang-tidy-17; do
        [ -x "$c" ] && { echo "$c"; return; }
    done
    return 1
}

# Prefer a direct binary, fall back to "uvx <tool>" (no global install).
find_py_tool() {
    local tool="$1" var="${2:-}"
    [ -n "$var" ] && { echo "$var"; return; }
    command -v "$tool" >/dev/null 2>&1 && { echo "$tool"; return; }
    command -v uvx >/dev/null 2>&1 && { echo "uvx $tool"; return; }
    return 1
}

merge_compile_dbs() {
    # Merge colcon per-package compile_commands.json into one at build/.
    local build="$1"
    python3 - "$build" <<'PY'
import json, pathlib, sys
build = pathlib.Path(sys.argv[1])
merged, seen = [], set()
for f in sorted(build.glob('*/compile_commands.json')):
    try:
        entries = json.loads(f.read_text())
    except Exception as e:
        print(f'warning: skipping {f}: {e}', file=sys.stderr)
        continue
    for e in entries:
        key = (e.get('file'), e.get('directory'),
               e.get('command') or ' '.join(e.get('arguments', [])))
        if key in seen:
            continue
        seen.add(key)
        merged.append(e)
if not merged:
    sys.exit(1)
(build / 'compile_commands.json').write_text(json.dumps(merged))
print(f'merged {len(merged)} compile-database entries into {build}/compile_commands.json')
PY
}

lint_cpp() {
    local tidy dbdir sources tmp findings
    tidy="$(find_clang_tidy)" || die "clang-tidy not found (set CLANG_TIDY=<path>)"
    dbdir="${COMPILE_DB:-$ROOT/build}"
    if [ ! -f "$dbdir/compile_commands.json" ]; then
        echo "no compile_commands.json in $dbdir, merging per-package databases..."
        merge_compile_dbs "$dbdir" || die "no compile database found in $dbdir — run:
  colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
(or point COMPILE_DB at a directory containing compile_commands.json)"
    fi

    # Our sources only: prune vendored/embedded trees and build artifacts.
    sources="$(find "$ROOT/src" "$ROOT/sas_cpp" \
        \( -name .git -o -name pybind11 -o -name Universal_Robots_Client_Library \
           -o -name third_party -o -name vendor -o -name .devcontainer \
           -o -name build -o -name install -o -name log \) -prune -o \
        \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' \) -print 2>/dev/null)"

    # Keep only files covered by the database (i.e. actually built). Matches
    # both absolute paths and ROOT-relative path tails, so a database
    # generated inside docker (different prefix) still selects the files;
    # clang-tidy itself still requires a same-environment database.
    tmp="$(mktemp)"
    srcs="$(mktemp)"
    printf '%s\n' "$sources" > "$srcs"
    python3 - "$dbdir/compile_commands.json" "$ROOT" "$srcs" > "$tmp" <<'PY'
import json, pathlib, sys
db = pathlib.Path(sys.argv[1]); root = pathlib.Path(sys.argv[2]).resolve()
entries = json.loads(db.read_text())
dbfiles = {str(pathlib.Path(e['file']).resolve()) for e in entries}
dbtails = {pathlib.Path(e['file']).as_posix() for e in entries}
for line in open(sys.argv[3]):
    f = line.strip()
    if not f:
        continue
    rp = pathlib.Path(f).resolve()
    try:
        rel = rp.relative_to(root).as_posix()
    except ValueError:
        continue
    if str(rp) in dbfiles or any(t.endswith('/' + rel) or t == rel for t in dbtails):
        print(f)
PY

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp" "$srcs"
        die "no lintable C++ files matched the compile database in $dbdir — was the workspace built?"
    fi

    echo "=== clang-tidy: $(wc -l < "$tmp" | tr -d ' ') translation units ($dbdir) ==="
    if ! xargs -n 1 -P "$(nproc_or)" "$tidy" -p "$dbdir" -quiet < "$tmp" > "$tmp.out" 2>&1; then
        FAIL=1
    fi
    cat "$tmp.out"
    findings="$(grep -c ': warning:\|: error:' "$tmp.out" || true)"
    rm -f "$tmp" "$tmp.out"
    echo "=== clang-tidy: $findings finding(s) ==="
    [ "${findings:-0}" -eq 0 ] || FAIL=1
}

lint_py() {
    local ruff
    cd "$ROOT" || die "cannot cd to $ROOT"
    ruff="$(find_py_tool ruff "${RUFF:-}")" || die "ruff not found (pip install ruff or set RUFF=)"
    echo "=== ruff check ==="
    $ruff check . || FAIL=1
}

lint_types() {
    local pyright
    cd "$ROOT" || die "cannot cd to $ROOT"
    pyright="$(find_py_tool pyright "${PYRIGHT:-}")" || die "pyright not found (npm/pip install pyright or set PYRIGHT=)"
    echo "=== pyright ==="
    # reportMissingImports is 'warning' in pyrightconfig.json so runs outside
    # a ROS/pip environment degrade gracefully; see the header on sourcing
    # install/setup.bash for a fully resolved check.
    $pyright || FAIL=1
}

lint_ros2() {
    local linter="${ROS2_LINTER:-$ROOT/tools/murilos_ros2_linter.py}"
    [ -f "$linter" ] || die "murilos_ros2_linter.py not found at $linter (set ROS2_LINTER=)"
    echo "=== murilos_ros2_linter (ROS 2 conventions over src/) ==="
    python3 "$linter" "$ROOT/src" || FAIL=1
}

cd "$ROOT" || die "repository root $ROOT does not exist"
case "$MODE" in
    cpp)   lint_cpp ;;
    py)    lint_py ;;
    types) lint_types ;;
    ros2)  lint_ros2 ;;
    all)   lint_cpp; lint_py; lint_types; lint_ros2 ;;
esac
exit "$FAIL"
