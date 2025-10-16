#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Checking for manual CI runs on commit: $COMMIT_SHA"

# Get workflow runs for the specific commit
WORKFLOW_RUNS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/actions/runs?head_sha=$COMMIT_SHA")

# Check if API call was successful
if [[ $(echo "$WORKFLOW_RUNS" | jq -r '.message // empty') == "Not Found" ]]; then
    echo "❌ Repository not found or no access"
    exit 1
fi

# Get the most recent manual run
LATEST_MANUAL_RUN=$(echo "$WORKFLOW_RUNS" | jq -r '
    [.workflow_runs[] | select(.event == "workflow_dispatch")] |
    sort_by(.created_at) | reverse | 
    .[0] // empty |
    "\(.name)|\(.status)|\(.conclusion)|\(.created_at)|\(.html_url)"
')

if [[ -z "$LATEST_MANUAL_RUN" ]]; then
    echo "❌ No manual workflow runs found for commit $COMMIT_SHA"
    exit 1
fi

# Parse the latest run details
IFS='|' read -r name status conclusion created_at url <<< "$LATEST_MANUAL_RUN"

if [[ "$status" == "completed" && "$conclusion" == "success" ]]; then
    echo "✅ Latest manual CI run was successful: $url"
    exit 0
else
    echo "❌ Latest manual CI run did not succeed (conclusion: $conclusion, url: $url)"
    exit 1
fi