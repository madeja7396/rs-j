#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/publish_release.sh --tag X.Y.Z [options]

Options:
  --tag X.Y.Z             Release tag (required, must match X.Y.Z)
  --notes FILE            Release notes file (default: docs/release-notes.md)
  --title TITLE           Release title (default: "X.Y.Z Release")
  --publish               Create as non-draft release (default: draft)
  --skip-tag-push         Do not push tag to origin
  -h, --help              Show this help

Environment:
  GITHUB_TOKEN            If set, create/update release via GitHub API.

Notes:
  - If local tag is missing, this script creates an annotated tag.
  - If GITHUB_TOKEN is not set, the script only prepares and pushes the tag,
    then prints manual release steps.
USAGE
}

TAG=""
NOTES_FILE="docs/release-notes.md"
TITLE=""
DRAFT=1
SKIP_TAG_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --publish)
      DRAFT=0
      shift
      ;;
    --skip-tag-push)
      SKIP_TAG_PUSH=1
      shift
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

api_request() {
  local method="$1"
  local url="$2"
  local payload_file="${3:-}"
  local response_file
  local http_code

  response_file="$(mktemp)"
  if [[ -n "$payload_file" ]]; then
    http_code="$(curl -sS -L -o "$response_file" -w '%{http_code}' \
      -X "$method" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      --data-binary "@$payload_file" \
      "$url")"
  else
    http_code="$(curl -sS -L -o "$response_file" -w '%{http_code}' \
      -X "$method" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$url")"
  fi

  echo "$http_code $response_file"
}

require_cmd git
require_cmd curl
require_cmd jq

if [[ -z "$TAG" ]]; then
  echo "--tag is required." >&2
  usage
  exit 1
fi

if [[ ! "$TAG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid --tag '$TAG'. Expected X.Y.Z format (e.g. 0.12.13)." >&2
  exit 1
fi

if [[ ! -f "$NOTES_FILE" ]]; then
  echo "Release notes file not found: $NOTES_FILE" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "Current branch is '$BRANCH'. Switch to 'main' before publishing release." >&2
  exit 1
fi

if [[ -z "$TITLE" ]]; then
  TITLE="${TAG} Release"
fi

REPO="$(infer_repo)"
API_BASE="https://api.github.com/repos/${REPO}"

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "Tag already exists locally: ${TAG}"
else
  echo "Creating local tag: ${TAG}"
  git tag -a "$TAG" -m "rs-j ${TAG} release"
fi

if [[ "$SKIP_TAG_PUSH" -eq 0 ]]; then
  if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q "refs/tags/${TAG}$"; then
    echo "Tag already exists on origin: ${TAG}"
  else
    echo "Pushing tag to origin: ${TAG}"
    git push origin "$TAG"
  fi
else
  echo "Skipping tag push (--skip-tag-push)."
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo
  echo "GITHUB_TOKEN is not set. Tag is prepared/pushed, but release was not created automatically."
  echo "Create the release manually: https://github.com/${REPO}/releases/new?tag=${TAG}"
  exit 0
fi

payload_file="$(mktemp)"
jq -n \
  --arg tag "$TAG" \
  --arg name "$TITLE" \
  --arg body "$(cat "$NOTES_FILE")" \
  --argjson draft "$DRAFT" \
  '{tag_name: $tag, name: $name, body: $body, draft: $draft, prerelease: false, generate_release_notes: false}' \
  > "$payload_file"

read -r get_code get_body < <(api_request GET "${API_BASE}/releases/tags/${TAG}")

if [[ "$get_code" == "200" ]]; then
  release_id="$(jq -r '.id' "$get_body")"
  echo "Updating existing release for tag ${TAG} (id=${release_id})"
  read -r patch_code patch_body < <(api_request PATCH "${API_BASE}/releases/${release_id}" "$payload_file")
  if [[ "$patch_code" != "200" ]]; then
    echo "Failed to update release (HTTP ${patch_code})." >&2
    jq -r '.message // . | tostring' "$patch_body" >&2 || true
    rm -f "$payload_file" "$get_body" "$patch_body"
    exit 1
  fi
  html_url="$(jq -r '.html_url' "$patch_body")"
  rm -f "$payload_file" "$get_body" "$patch_body"
  echo "Release updated: ${html_url}"
  exit 0
fi

if [[ "$get_code" != "404" ]]; then
  echo "Failed to query existing release (HTTP ${get_code})." >&2
  jq -r '.message // . | tostring' "$get_body" >&2 || true
  rm -f "$payload_file" "$get_body"
  exit 1
fi

rm -f "$get_body"

echo "Creating new release for tag ${TAG}"
read -r post_code post_body < <(api_request POST "${API_BASE}/releases" "$payload_file")
if [[ "$post_code" != "201" ]]; then
  echo "Failed to create release (HTTP ${post_code})." >&2
  jq -r '.message // . | tostring' "$post_body" >&2 || true
  rm -f "$payload_file" "$post_body"
  exit 1
fi

html_url="$(jq -r '.html_url' "$post_body")"
rm -f "$payload_file" "$post_body"
echo "Release created: ${html_url}"
