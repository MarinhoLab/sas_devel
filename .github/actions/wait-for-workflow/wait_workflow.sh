#!/usr/bin/env bash
# Block until the latest run of TARGET_WORKFLOW for commit TARGET_SHA in the
# current repository completes with conclusion success.
# Env: TARGET_WORKFLOW, TARGET_SHA, GH_TOKEN (via gh auth).
set -euo pipefail

api="repos/${GITHUB_REPOSITORY}/actions/workflows/${TARGET_WORKFLOW}/runs?head_sha=${TARGET_SHA}"

run_id=""
for _ in $(seq 1 60); do
    run_id="$(gh api "$api" --jq '.workflow_runs[0].databaseId // ""')"
    [ -n "$run_id" ] && break
    sleep 10
done
if [ -z "$run_id" ]; then
    echo "::error::no ${TARGET_WORKFLOW} run found for ${TARGET_SHA} within 10 minutes — push or dispatch it first"
    exit 1
fi
echo "waiting on https://github.com/${GITHUB_REPOSITORY}/actions/runs/${run_id} (${TARGET_WORKFLOW} @ ${TARGET_SHA:0:10})"

while :; do
    status="$(gh run view "$run_id" -R "$GITHUB_REPOSITORY" --json status --jq .status)"
    [ "$status" = "completed" ] && break
    sleep 30
done
conclusion="$(gh run view "$run_id" -R "$GITHUB_REPOSITORY" --json conclusion --jq .conclusion)"
if [ "$conclusion" != "success" ]; then
    echo "::error::${TARGET_WORKFLOW} run ${run_id} for ${TARGET_SHA:0:10} concluded ${conclusion} — refusing to publish"
    exit 1
fi
echo "${TARGET_WORKFLOW} run ${run_id} for ${TARGET_SHA:0:10} succeeded"
