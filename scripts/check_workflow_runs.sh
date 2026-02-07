#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
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
  - If API is rate-limited/unavailable, falls back to parsing public Actions HTML.
  - Set GITHUB_TOKEN for higher API rate limits.
USAGE
}

SHA=""
REPO=""
REQUIRED="ci,codecov,docs"
WAIT_SECS=0
POLL_INTERVAL=10
RUN_SOURCE="api"
FETCHED_RUNS_TSV=""

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

normalize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

require_cmd git
require_cmd curl
require_cmd jq
require_cmd perl

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
SHORT_SHA="${SHA:0:7}"

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

declare -a REQUIRED_WORKFLOWS=()
IFS=',' read -r -a RAW_REQUIRED <<<"$REQUIRED"
for raw in "${RAW_REQUIRED[@]}"; do
  name="$(normalize_name "$raw")"
  if [[ -n "$name" ]]; then
    REQUIRED_WORKFLOWS+=("$name")
  fi
done

if [[ "${#REQUIRED_WORKFLOWS[@]}" -eq 0 ]]; then
  echo "No required workflows provided." >&2
  exit 1
fi

fetch_runs_tsv_api() {
  local url="https://api.github.com/repos/${REPO}/actions/runs?per_page=100&head_sha=${SHA}"
  local headers_file body_file http_code message
  headers_file="$(mktemp)"
  body_file="$(mktemp)"

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    http_code="$(curl -sS -L \
      -D "$headers_file" \
      -o "$body_file" \
      -w '%{http_code}' \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "$url")" || {
      rm -f "$headers_file" "$body_file"
      return 2
    }
  else
    http_code="$(curl -sS -L \
      -D "$headers_file" \
      -o "$body_file" \
      -w '%{http_code}' \
      -H "Accept: application/vnd.github+json" \
      "$url")" || {
      rm -f "$headers_file" "$body_file"
      return 2
    }
  fi

  if [[ "$http_code" == "200" ]]; then
    jq -r '.workflow_runs[] | [.name, .status, (.conclusion // "-"), .html_url] | @tsv' "$body_file"
    rm -f "$headers_file" "$body_file"
    return 0
  fi

  message="$(jq -r '.message // empty' "$body_file" 2>/dev/null || true)"
  rm -f "$headers_file" "$body_file"

  if [[ "$http_code" == "403" && "$message" == *"API rate limit exceeded"* ]]; then
    return 3
  fi

  if [[ -n "$message" ]]; then
    echo "GitHub API returned ${http_code}: ${message}" >&2
  else
    echo "GitHub API returned HTTP ${http_code}." >&2
  fi
  return 2
}

fetch_runs_tsv_html() {
  local url="https://github.com/${REPO}/actions?query=${SHORT_SHA}"
  local html

  html="$(curl -fsSL "$url")" || return 2

  TARGET_SHORT_SHA="$SHORT_SHA" perl -0777 -ne '
    my $target = lc($ENV{TARGET_SHORT_SHA} // "");
    my $html = $_;

    while ($html =~ m{<a href="/([^"]+/actions/runs/(\d+))"[^>]*aria-label="([^"]+)".*?Commit <a[^>]*>([0-9a-f]{7})</a>}sgi) {
      my ($run_path, $run_id, $label, $commit_short) = ($1, $2, $3, lc($4));
      next if $target eq "" || $commit_short ne $target;

      my $workflow = "";
      if ($label =~ /Run \d+ of (.+?)\.(?:\s|$)/i) {
        $workflow = $1;
      }
      next if $workflow eq "";

      my ($status, $conclusion) = ("in_progress", "-");
      if ($label =~ /^completed successfully:/i) {
        ($status, $conclusion) = ("completed", "success");
      } elsif ($label =~ /^failed:/i) {
        ($status, $conclusion) = ("completed", "failure");
      } elsif ($label =~ /^cancelled:/i) {
        ($status, $conclusion) = ("completed", "cancelled");
      } elsif ($label =~ /^queued:/i) {
        ($status, $conclusion) = ("queued", "-");
      } elsif ($label =~ /^currently running:/i) {
        ($status, $conclusion) = ("in_progress", "-");
      }

      print "$workflow\t$status\t$conclusion\thttps://github.com/$run_path\n";
    }
  ' <<<"$html"
}

fetch_runs_tsv() {
  local api_tsv html_tsv rc

  if api_tsv="$(fetch_runs_tsv_api)"; then
    if [[ -n "$api_tsv" ]]; then
      RUN_SOURCE="api"
      FETCHED_RUNS_TSV="$api_tsv"
      return 0
    fi

    echo "GitHub API returned no workflow runs for ${SHORT_SHA}; attempting Actions HTML scraping." >&2
    html_tsv="$(fetch_runs_tsv_html)" || return 2
    if [[ -z "$html_tsv" ]]; then
      echo "No matching workflow runs found via API or Actions HTML for commit ${SHORT_SHA}." >&2
      return 2
    fi

    RUN_SOURCE="html"
    FETCHED_RUNS_TSV="$html_tsv"
    return 0
  else
    rc=$?
  fi

  if [[ "$rc" -eq 3 ]]; then
    echo "GitHub API rate limit exceeded; falling back to Actions HTML scraping." >&2
  elif [[ "$rc" -eq 2 ]]; then
    echo "GitHub API fetch failed; attempting Actions HTML scraping." >&2
  else
    return "$rc"
  fi

  html_tsv="$(fetch_runs_tsv_html)" || return 2
  if [[ -z "$html_tsv" ]]; then
    echo "No matching workflow runs found via Actions HTML for commit ${SHORT_SHA}." >&2
    return 2
  fi

  RUN_SOURCE="html"
  FETCHED_RUNS_TSV="$html_tsv"
  return 0
}

evaluate_runs() {
  local runs_tsv="$1"
  local pending=0
  local failed=0

  declare -A STATUS_BY_NAME=()
  declare -A CONCLUSION_BY_NAME=()
  declare -A URL_BY_NAME=()

  while IFS=$'\t' read -r wf_name wf_status wf_conclusion wf_url; do
    [[ -z "$wf_name" ]] && continue
    local key
    key="$(normalize_name "$wf_name")"
    if [[ -z "${STATUS_BY_NAME[$key]+x}" ]]; then
      STATUS_BY_NAME["$key"]="$wf_status"
      CONCLUSION_BY_NAME["$key"]="$wf_conclusion"
      URL_BY_NAME["$key"]="$wf_url"
    fi
  done <<<"$runs_tsv"

  echo "Repository: ${REPO}"
  echo "SHA: ${SHA}"
  echo "Source: ${RUN_SOURCE}"

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
  fetch_runs_tsv || {
    echo "Failed to fetch workflow runs." >&2
    exit 2
  }
  runs_tsv="$FETCHED_RUNS_TSV"

  if evaluate_runs "$runs_tsv"; then
    echo
    echo "All required workflows completed successfully."
    exit 0
  else
    rc=$?
  fi

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
