#!/usr/bin/env bash
# Guardrail against namespace pollution.
#
# Forbids 'using namespace Eigen;' and 'using namespace rclcpp;' in HEADER
# files across the whole workspace: a using-directive in a header leaks into
# every translation unit that includes it. A using-directive in a .c/.cpp/.cc
# source is translation-unit-local and is reported as a warning only.
# 'using namespace DQ_robotics;' is intentionally NOT banned.
#
# Usage:
#   scripts/check_using_namespace.sh [ROOT]
#   ROOT defaults to the repository root (the parent directory of this script).
#
# Exit codes:
#   0  no banned using-directive in any header
#   1  at least one banned using-directive found in a header
#   2  internal error (ROOT not a directory)

set -u

if [ -n "${1:-}" ]; then
    ROOT="$1"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="$(dirname "$SCRIPT_DIR")"
fi
if [ ! -d "$ROOT" ]; then
    echo "ERROR: '$ROOT' is not a directory" >&2
    exit 2
fi

# Match 'using namespace Eigen;' / 'using namespace rclcpp;' with optional
# whitespace before ';'. Does NOT match narrower directives such as
# 'using namespace Eigen::RowMajor;'. Uses [ \t] (not [[:space:]]) so the
# pattern behaves identically on BSD and GNU grep.
BANNED_RE='using[ 	]+namespace[ 	]+(Eigen|rclcpp)[ 	]*;'

# Vendored / third-party trees and build artifacts are out of scope.
# 'submodules/' holds nested git checkouts pinned to their own commits
# (e.g. sas_py/submodules/sas_cpp) and is not part of this workspace's state.
skip_path() {
    case "$1" in
        */pybind11/*|\
        */Universal_Robots_Client_Library/*|\
        */sas_robot_driver_kuka/src/kuka/*|\
        */submodules/*|\
        */.git/*|*/build/*|*/install/*|*/log/*)
            return 0 ;;
    esac
    return 1
}

header_hits=0
src_hits=0

for pkg in "$ROOT"/src/*/ "$ROOT"/sas_cpp "$ROOT"/sas_py; do
    [ -d "$pkg" ] || continue
    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        path="${hit%%:*}"
        rest="${hit#*:}"
        lineno="${rest%%:*}"
        content="${rest#*:}"
        # Trim leading whitespace.
        content="${content#"${content%%[![:space:]]*}"}"
        # Skip comment and preprocessor lines (heuristic: the line starts
        # with a comment marker or '#').
        case "$content" in
            '//'*|'*'*|'/*'*|'#'*)
                continue ;;
        esac
        if skip_path "$path"; then
            continue
        fi
        rel="${path#"$ROOT"/}"
        case "$path" in
            *.h|*.hpp|*.hxx|*.hh)
                echo "FAIL: $rel:$lineno -> $content"
                header_hits=$((header_hits + 1))
                ;;
            *.c|*.cpp|*.cc|*.cxx)
                echo "WARN: using-directive in translation unit $rel:$lineno -> $content"
                src_hits=$((src_hits + 1))
                ;;
        esac
    done < <(grep -rnE "$BANNED_RE" "$pkg" \
        --include='*.h' --include='*.hpp' --include='*.hxx' --include='*.hh' \
        --include='*.c' --include='*.cpp' --include='*.cc' --include='*.cxx' 2>/dev/null)
done

echo
echo "Headers with banned using-directive: $header_hits"
if [ "$src_hits" -gt 0 ]; then
    echo "Sources with banned using-directive (warning only): $src_hits"
fi

if [ "$header_hits" -gt 0 ]; then
    echo "ERROR: 'using namespace Eigen;' / 'using namespace rclcpp;' are forbidden in headers." >&2
    exit 1
fi
exit 0
