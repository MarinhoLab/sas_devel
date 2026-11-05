#!/usr/bin/env bash
# Trigger a workflow_dispatch run in TARGET_REPO/TARGET_WORKFLOW and block
# until it completes successfully. Identifies "our" run by polling for a
# run id newer than the last one seen before the trigger.
# Env: TARGET_REPO, TARGET_WORKFLOW, DRY_RUN, GH_TOKEN (via gh auth).
set -euo pipefail

echo "::group::verify ${TARGET_REPO} / ${TARGET_WORKFLOW}"
wf_id="$(gh api "repos/${TARGET_REPO}/actions/workflows/${TARGET_WORKFLOW}" -q .id)" \
    || { echo "::error::workflow ${TARGET_WORKFLOW} not found in ${TARGET_REPO} (bad name or token lacks access)"; exit 1; }
echo "workflow id ${wf_id}; latest run:"
gh run list -R "$TARGET_REPO" --workflow "$TARGET_WORKFLOW" --limit 1 \
    --json databaseId,status,conclusion,createdAt,event \
    --jq '.[0] | "  \(.createdAt) run \(.databaseId) \(.status)/\(.conclusion) [\(.event)]"' \
    || echo "  (no runs yet)"
echo "::endgroup::"

if [ "$DRY_RUN" = "true" ]; then
    echo "dry run: not triggering ${TARGET_WORKFLOW} in ${TARGET_REPO}"
    exit 0
fi

before="$(gh run list -R "$TARGET_REPO" --workflow "$TARGET_WORKFLOW" --limit 1 \
    --json databaseId --jq '.[0].databaseId // 0')"

gh workflow run "$TARGET_WORKFLOW" -R "$TARGET_REPO"
echo "dispatched ${TARGET_WORKFLOW} in ${TARGET_REPO} (previous latest run ${before})"

run_id=""
for _ in $(seq 1 60); do
    candidate="$(gh run list -R "$TARGET_REPO" --workflow "$TARGET_WORKFLOW" --limit 1 \
        --json databaseId --jq '.[0].databaseId // 0')"
    if [ "${candidate:-0}" -gt "${before:-0}" ]; then
        run_id="$candidate"
        break
    fi
    sleep 5
done
if [ -z "$run_id" ]; then
    echo "::error::${TARGET_WORKFLOW} did not start in ${TARGET_REPO} within 5 minutes"
    exit 1
fi
echo "watching https://github.com/${TARGET_REPO}/actions/runs/${run_id}"

# gh run watch can drop the connection; poll to a terminal state regardless.
while :; do
    status="$(gh run view "$run_id" -R "$TARGET_REPO" --json status --jq .status)"
    [ "$status" = "completed" ] && break
    sleep 30
done
conclusion="$(gh run view "$run_id" -R "$TARGET_REPO" --json conclusion --jq .conclusion)"
if [ "$conclusion" != "success" ]; then
    echo "::error::${TARGET_WORKFLOW} run ${run_id} in ${TARGET_REPO} concluded ${conclusion}"
    exit 1
fi
echo "${TARGET_WORKFLOW} run ${run_id} in ${TARGET_REPO} succeeded"
