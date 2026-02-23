#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT:-ai-nutrition-assistant-e2346}"
FUNCTIONS_TARGET="functions:searchFoods,functions:autocompleteFoods,functions:lookupFoodByBarcode"

SKIP_CI=0
SKIP_FETCH=0
ALLOW_DIRTY=0
ALLOW_MAIN=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Guarded FatSecret function deploy.

Usage:
  ./scripts/deploy_fatsecret_functions.sh [options]

Options:
  --project <id>    Firebase project id (default: ai-nutrition-assistant-e2346)
  --skip-ci         Skip GitHub check-run validation
  --skip-fetch      Skip `git fetch origin main`
  --allow-dirty     Allow deploy with uncommitted changes
  --allow-main      Allow running from main branch
  --dry-run         Print deploy command only
  -h, --help        Show this help
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

parse_repo_slug() {
  local remote_url
  remote_url="$(git config --get remote.origin.url || true)"
  [[ -n "$remote_url" ]] || die "remote.origin.url is not configured."

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return
  fi

  die "Could not parse GitHub repo slug from remote URL: $remote_url"
}

github_api_get() {
  local url="$1"
  local auth_header=()
  local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  local response_file
  local http_code
  local body
  local message

  response_file="$(mktemp)"

  if [[ -n "$token" ]]; then
    auth_header=(-H "Authorization: Bearer ${token}")
  fi

  http_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
    -H "Accept: application/vnd.github+json" \
    "${auth_header[@]}" \
    "$url" || true)"

  body="$(cat "$response_file")"
  rm -f "$response_file"

  if [[ "$http_code" != "200" ]]; then
    message="$(jq -r '.message // empty' <<<"$body" 2>/dev/null || true)"
    if [[ -n "$message" ]]; then
      die "GitHub API request failed (${http_code}): ${message}. Set GITHUB_TOKEN or rerun with --skip-ci."
    fi
    die "GitHub API request failed (${http_code}). Set GITHUB_TOKEN or rerun with --skip-ci."
  fi

  echo "$body"
}

check_ci_checks() {
  local repo_slug sha url checks_json total bad
  repo_slug="$(parse_repo_slug)"
  sha="$(git rev-parse HEAD)"
  url="https://api.github.com/repos/${repo_slug}/commits/${sha}/check-runs?per_page=100"

  info "Checking CI status for ${repo_slug}@${sha:0:7}"
  checks_json="$(github_api_get "$url")"

  total="$(jq -r '.total_count // 0' <<<"$checks_json")"
  (( total > 0 )) || die "No check runs found for this commit. Rerun after CI starts or use --skip-ci."

  bad="$(jq -r '[.check_runs[]
    | select(.status != "completed" or (((.conclusion // "") as $c | ["success","neutral","skipped"] | index($c)) == null))
  ] | length' <<<"$checks_json")"

  if (( bad > 0 )); then
    jq -r '.check_runs[]
      | select(.status != "completed" or (((.conclusion // "") as $c | ["success","neutral","skipped"] | index($c)) == null))
      | "- \(.name): status=\(.status), conclusion=\(.conclusion // "null")"' <<<"$checks_json" >&2
    die "One or more CI checks are not passing."
  fi

  info "CI checks are passing (${total} run(s))."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || die "--project requires a value."
      PROJECT_ID="$2"
      shift 2
      ;;
    --skip-ci)
      SKIP_CI=1
      shift
      ;;
    --skip-fetch)
      SKIP_FETCH=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --allow-main)
      ALLOW_MAIN=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Run this from inside the git repo."
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" != "HEAD" ]] || die "Detached HEAD is not allowed for deploy."

if [[ "$branch" == "main" && "$ALLOW_MAIN" -ne 1 ]]; then
  die "Deploy from a feature branch. Use --allow-main only if intentional."
fi

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree has uncommitted changes. Commit/stash first or rerun with --allow-dirty."
  fi
fi

if [[ "$SKIP_FETCH" -ne 1 ]]; then
  info "Fetching origin/main"
  git fetch origin main --quiet
fi

git show-ref --verify --quiet refs/remotes/origin/main || die "origin/main is not available locally."
read -r ahead behind < <(git rev-list --left-right --count HEAD...origin/main)
if (( behind > 0 )); then
  die "Branch is behind origin/main by ${behind} commit(s). Rebase/merge first."
fi
info "Branch divergence vs origin/main: ahead=${ahead}, behind=${behind}"

if [[ "$SKIP_CI" -ne 1 ]]; then
  check_ci_checks
else
  info "Skipping CI check (--skip-ci)."
fi

command -v firebase >/dev/null 2>&1 || die "firebase CLI not found in PATH."

deploy_cmd=(firebase deploy --project "$PROJECT_ID" --only "$FUNCTIONS_TARGET")
info "Ready to deploy: ${FUNCTIONS_TARGET}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run command:"
  printf '  %q ' "${deploy_cmd[@]}"
  echo
  exit 0
fi

"${deploy_cmd[@]}"
info "Deploy finished."
