#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check_workflow_runs.sh [options]

Options:
  --sha SHA               Commit SHA to inspect (default: HEAD)
  --repo owner/repo       GitHub repository (default: inferred from origin)
  --required a,b,c        Required workflow names (default: ci,codecov,docs)
  --wait-secs N           Wait up to N seconds for completion (default: 0)
  --poll-interval N       Poll interval seconds when waiting (default: 10)
  -h, --help              Show this help

Notes:
  - Uses GitHub REST API: /repos/{owner}/{repo}/actions/runs
  - Set GITHUB_TOKEN for higher API rate limits.
EOF
}

SHA=""
REPO=""
REQUIRED="ci,codecov,docs"
WAIT_SECS=0
POLL_INTERVAL=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sha)
      SHA="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --required)
      REQUIRED="${2:-}"
      shift 2
      ;;
    --wait-secs)
      WAIT_SECS="${2:-}"
      shift 2
      ;;
    --poll-interval)
      POLL_INTERVAL="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 2
  fi
}

require_cmd git
require_cmd curl
require_cmd jq

if [[ ! "$WAIT_SECS" =~ ^[0-9]+$ ]]; then
  echo "Invalid --wait-secs '$WAIT_SECS' (must be non-negative integer)." >&2
  exit 1
fi

if [[ ! "$POLL_INTERVAL" =~ ^[0-9]+$ ]] || [[ "$POLL_INTERVAL" -eq 0 ]]; then
  echo "Invalid --poll-interval '$POLL_INTERVAL' (must be integer >= 1)." >&2
  exit 1
fi

if [[ -z "$SHA" ]]; then
  SHA="$(git rev-parse HEAD)"
fi

infer_repo() {
  local remote_url
  remote_url="$(git remote get-url origin)"
  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local name="${BASH_REMATCH[2]}"
    echo "${owner}/${name%.git}"
    return 0
  fi

  echo "Could not infer GitHub repo from origin URL: $remote_url" >&2
  return 1
}

if [[ -z "$REPO" ]]; then
  REPO="$(infer_repo)"
fi

if [[ "$REQUIRED" == *" "* ]]; then
  echo "Warning: spaces in --required are ignored." >&2
fi

declare -a REQUIRED_WORKFLOWS=()
IFS=',' read -r -a RAW_REQUIRED <<<"$REQUIRED"
for raw in "${RAW_REQUIRED[@]}"; do
  name="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [[ -n "$name" ]]; then
    REQUIRED_WORKFLOWS+=("$name")
  fi
done

if [[ "${#REQUIRED_WORKFLOWS[@]}" -eq 0 ]]; then
  echo "No required workflows provided." >&2
  exit 1
fi

fetch_runs_json() {
  local url="https://api.github.com/repos/${REPO}/actions/runs?per_page=100&head_sha=${SHA}"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "$url"
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "$url"
  fi
}

evaluate_runs() {
  local json="$1"
  local pending=0
  local failed=0

  declare -A STATUS_BY_NAME=()
  declare -A CONCLUSION_BY_NAME=()
  declare -A URL_BY_NAME=()

  while IFS=$'\t' read -r wf_name wf_status wf_conclusion wf_url; do
    local key
    key="$(printf '%s' "$wf_name" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "${STATUS_BY_NAME[$key]+x}" ]]; then
      STATUS_BY_NAME["$key"]="$wf_status"
      CONCLUSION_BY_NAME["$key"]="$wf_conclusion"
      URL_BY_NAME["$key"]="$wf_url"
    fi
  done < <(
    jq -r '.workflow_runs[] | [.name, .status, (.conclusion // "-"), .html_url] | @tsv' <<<"$json"
  )

  echo "Repository: ${REPO}"
  echo "SHA: ${SHA}"

  for required_name in "${REQUIRED_WORKFLOWS[@]}"; do
    if [[ -z "${STATUS_BY_NAME[$required_name]+x}" ]]; then
      echo "- ${required_name}: missing"
      pending=$((pending + 1))
      continue
    fi

    status="${STATUS_BY_NAME[$required_name]}"
    conclusion="${CONCLUSION_BY_NAME[$required_name]}"
    url="${URL_BY_NAME[$required_name]}"
    echo "- ${required_name}: ${status}/${conclusion} (${url})"

    if [[ "$status" != "completed" ]]; then
      pending=$((pending + 1))
    elif [[ "$conclusion" != "success" ]]; then
      failed=$((failed + 1))
    fi
  done

  if [[ "$failed" -gt 0 ]]; then
    return 10
  fi
  if [[ "$pending" -gt 0 ]]; then
    return 11
  fi
  return 0
}

start_epoch="$(date +%s)"
while true; do
  echo
  echo "Checking workflow runs..."
  runs_json="$(fetch_runs_json)" || {
    echo "Failed to fetch workflow runs from GitHub API." >&2
    exit 2
  }

  if evaluate_runs "$runs_json"; then
    echo
    echo "All required workflows completed successfully."
    exit 0
  fi

  rc=$?
  if [[ "$rc" -eq 10 ]]; then
    echo
    echo "One or more required workflows failed."
    exit 1
  fi

  now_epoch="$(date +%s)"
  elapsed=$((now_epoch - start_epoch))
  if [[ "$WAIT_SECS" -eq 0 ]] || [[ "$elapsed" -ge "$WAIT_SECS" ]]; then
    echo
    echo "Required workflows are still pending or missing."
    exit 1
  fi

  remaining=$((WAIT_SECS - elapsed))
  sleep_for="$POLL_INTERVAL"
  if [[ "$remaining" -lt "$sleep_for" ]]; then
    sleep_for="$remaining"
  fi

  echo
  echo "Waiting ${sleep_for}s for completion (${remaining}s remaining)..."
  sleep "$sleep_for"
done
