#!/usr/bin/env bash
set -euo pipefail

TYPELESS_DICT_BIN="${TYPELESS_DICT_BIN:-$HOME/bin/typeless-dict}"
DEFAULT_OUT_BASE="${TYPELESS_TRANSFER_BASE:-$HOME/Downloads}"

die() {
  echo "$*" >&2
  exit 1
}

need_bin() {
  if [[ ! -x "$TYPELESS_DICT_BIN" ]]; then
    echo "Missing typeless-dict at $TYPELESS_DICT_BIN" >&2
    exit 1
  fi
}

timestamp() {
  date +"%Y-%m-%d-%H%M%S"
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr '@' '-' | tr -c 'a-z0-9._-' '-'
}

need_bundle_dir() {
  local bundle_dir="${1:?bundle dir required}"
  if [[ ! -d "$bundle_dir" ]]; then
    die "Bundle dir does not exist: $bundle_dir"
  fi
  if [[ ! -f "$bundle_dir/dictionary.txt" ]]; then
    die "Bundle missing dictionary.txt: $bundle_dir/dictionary.txt"
  fi
}

mktemp_file() {
  mktemp "${TMPDIR:-/tmp}/typeless-transfer.XXXXXX"
}

run_typeless() {
  # Usage: run_typeless <port-or-empty> <args...>
  local port="${1:-}"
  shift || true
  if [[ -n "$port" ]]; then
    "$TYPELESS_DICT_BIN" "$@" --port "$port"
  else
    "$TYPELESS_DICT_BIN" "$@"
  fi
}

whoami_email() {
  local raw
  raw="$("$TYPELESS_DICT_BIN" whoami)"
  python3 -c 'import json,sys; data=json.loads(sys.argv[1]); print(data.get("email") or "unknown")' "$raw"
}

export_bundle() {
  need_bin
  local label="${1:-dictionary}"
  local account_email
  account_email="$(whoami_email)"
  local dir="$DEFAULT_OUT_BASE/typeless-transfer-$(slugify "$label")-$(timestamp)"
  mkdir -p "$dir"

  "$TYPELESS_DICT_BIN" whoami > "$dir/account.json"
  "$TYPELESS_DICT_BIN" export "$dir/dictionary.json" --tab all --format json
  "$TYPELESS_DICT_BIN" export "$dir/dictionary.txt" --tab all --format txt

  cat <<EOF
Created Typeless dictionary bundle:
  $dir

Current account:
  $account_email

Files:
  $dir/account.json
  $dir/dictionary.json
  $dir/dictionary.txt
EOF
}

import_dry_run() {
  need_bin
  local bundle_dir="${1:?bundle dir required}"
  need_bundle_dir "$bundle_dir"

  echo "Current target account:"
  "$TYPELESS_DICT_BIN" whoami
  echo
  echo "Dry run using bundle:"
  echo "  $bundle_dir/dictionary.txt"
  "$TYPELESS_DICT_BIN" import "$bundle_dir/dictionary.txt" --dry-run
}

import_bundle() {
  need_bin
  local bundle_dir="${1:?bundle dir required}"
  need_bundle_dir "$bundle_dir"

  echo "Current target account:"
  "$TYPELESS_DICT_BIN" whoami
  echo
  echo "Importing bundle:"
  echo "  $bundle_dir/dictionary.txt"
  "$TYPELESS_DICT_BIN" import "$bundle_dir/dictionary.txt"
}

compare_bundle_vs_current() {
  need_bin
  local bundle_dir="${1:?bundle dir required}"
  shift || true
  need_bundle_dir "$bundle_dir"

  local port=""
  local text=0
  local no_words=0
  local limit_words=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        port="${2:?--port requires a value}"
        shift 2
        ;;
      --text)
        text=1
        shift
        ;;
      --no-words)
        no_words=1
        shift
        ;;
      --limit-words)
        limit_words="${2:?--limit-words requires a value}"
        shift 2
        ;;
      *)
        die "Unknown option for compare-bundle-vs-current: $1"
        ;;
    esac
  done

  local current_txt
  current_txt="$(mktemp_file)"
  local whoami_json
  whoami_json="$(mktemp_file)"

  trap 'rm -f "$current_txt" "$whoami_json"' RETURN

  run_typeless "$port" whoami > "$whoami_json"
  run_typeless "$port" export "$current_txt" --tab all --format txt >/dev/null 2>&1

  python3 - "$bundle_dir/dictionary.txt" "$current_txt" "$whoami_json" "$bundle_dir/account.json" "$text" "$no_words" "$limit_words" <<'PY'
import json, sys, os, re

bundle_txt, current_txt, whoami_json, bundle_account_json, text, no_words, limit_words = sys.argv[1:]
text = bool(int(text))
no_words = bool(int(no_words))
try:
  limit_words = int(limit_words)
except Exception:
  limit_words = 0

def norm(s: str) -> str:
  return re.sub(r"\s+", " ", (s or "").strip())

def load_terms_txt(p: str):
  raw = open(p, "r", encoding="utf-8").read().splitlines()
  out = []
  for line in raw:
    line = line.strip()
    if not line:
      continue
    if line.startswith("#"):
      continue
    out.append(norm(line))
  # stable, unique
  seen = set()
  uniq = []
  for t in out:
    if not t:
      continue
    if t in seen:
      continue
    seen.add(t)
    uniq.append(t)
  return uniq

def load_json_or_null(p: str):
  if not p or not os.path.exists(p):
    return None
  try:
    return json.load(open(p, "r", encoding="utf-8"))
  except Exception:
    return None

bundle_terms = load_terms_txt(bundle_txt)
current_terms = load_terms_txt(current_txt)
bundle_set = set(bundle_terms)
current_set = set(current_terms)

to_add = sorted(bundle_set - current_set)
extras = sorted(current_set - bundle_set)

def maybe_limit(items):
  if limit_words and len(items) > limit_words:
    return items[:limit_words]
  return items

whoami = load_json_or_null(whoami_json) or {}
bundle_account = load_json_or_null(bundle_account_json) or {}

result = {
  "bundleDir": os.path.dirname(bundle_txt),
  "targetAccount": {
    "loggedIn": whoami.get("loggedIn", None),
    "email": whoami.get("email", None),
    "user_id": whoami.get("user_id", None),
  },
  "bundleAccount": {
    "loggedIn": bundle_account.get("loggedIn", None),
    "email": bundle_account.get("email", None),
    "user_id": bundle_account.get("user_id", None),
  },
  "bundleUnique": len(bundle_set),
  "currentUnique": len(current_set),
  "inBundleNotCurrentCount": len(to_add),
  "inCurrentNotBundleCount": len(extras),
  "wordListsTruncatedTo": (limit_words or None),
}

if not no_words:
  result["toAdd"] = maybe_limit(to_add)
  result["extras"] = maybe_limit(extras)

if text:
  # Human-readable summary
  print("Target account:")
  print(json.dumps(result["targetAccount"], ensure_ascii=False))
  print()
  print("Bundle account (if present):")
  print(json.dumps(result["bundleAccount"], ensure_ascii=False))
  print()
  print(f"Bundle unique terms:  {result['bundleUnique']}")
  print(f"Current unique terms: {result['currentUnique']}")
  print(f"To add:              {result['inBundleNotCurrentCount']}")
  print(f"Extras:              {result['inCurrentNotBundleCount']}")
  if not no_words:
    if result.get("toAdd"):
      print()
      print("Sample toAdd:")
      for t in result["toAdd"]:
        print(f"  + {t}")
    if result.get("extras"):
      print()
      print("Sample extras:")
      for t in result["extras"]:
        print(f"  - {t}")
else:
  print(json.dumps(result, ensure_ascii=False, indent=2))
PY
}

sync_bundle_to_current() {
  need_bin
  local bundle_dir="${1:?bundle dir required}"
  shift || true
  need_bundle_dir "$bundle_dir"

  local port=""
  local mode="add-only" # add-only|mirror
  local dry_run=0
  local delete_extras=0
  local delete_extras_max=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        port="${2:?--port requires a value}"
        shift 2
        ;;
      --mode)
        mode="${2:?--mode requires add-only|mirror}"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      --delete-extras)
        delete_extras=1
        shift
        ;;
      --delete-extras-max)
        delete_extras_max="${2:?--delete-extras-max requires a value}"
        shift 2
        ;;
      *)
        die "Unknown option for sync-bundle-to-current: $1"
        ;;
    esac
  done

  if [[ "$mode" != "add-only" && "$mode" != "mirror" ]]; then
    die "Unsupported --mode: $mode (expected add-only|mirror)"
  fi

  if [[ "$mode" == "mirror" && "$delete_extras" -ne 1 ]]; then
    die "Refusing to delete extras in mirror mode without explicit --delete-extras"
  fi

  local current_txt extras_txt plan_json whoami_json
  current_txt="$(mktemp_file)"
  extras_txt="$(mktemp_file)"
  plan_json="$(mktemp_file)"
  whoami_json="$(mktemp_file)"

  trap 'rm -f "$current_txt" "$extras_txt" "$plan_json" "$whoami_json"' RETURN

  run_typeless "$port" whoami > "$whoami_json"
  run_typeless "$port" export "$current_txt" --tab all --format txt >/dev/null 2>&1

  python3 - "$bundle_dir/dictionary.txt" "$current_txt" "$whoami_json" "$bundle_dir/account.json" "$mode" "$delete_extras" "$delete_extras_max" "$plan_json" "$extras_txt" <<'PY'
import json, sys, os, re

bundle_txt, current_txt, whoami_json, bundle_account_json, mode, delete_extras, delete_extras_max, plan_json, extras_txt = sys.argv[1:]
delete_extras = bool(int(delete_extras))
try:
  delete_extras_max = int(delete_extras_max)
except Exception:
  delete_extras_max = 0

def norm(s: str) -> str:
  return re.sub(r"\s+", " ", (s or "").strip())

def load_terms_txt(p: str):
  raw = open(p, "r", encoding="utf-8").read().splitlines()
  out = []
  for line in raw:
    line = line.strip()
    if not line or line.startswith("#"):
      continue
    out.append(norm(line))
  seen = set()
  uniq = []
  for t in out:
    if not t or t in seen:
      continue
    seen.add(t)
    uniq.append(t)
  return uniq

def load_json_or_null(p: str):
  if not p or not os.path.exists(p):
    return None
  try:
    return json.load(open(p, "r", encoding="utf-8"))
  except Exception:
    return None

bundle_terms = load_terms_txt(bundle_txt)
current_terms = load_terms_txt(current_txt)
bundle_set = set(bundle_terms)
current_set = set(current_terms)

to_add = sorted(bundle_set - current_set)
extras = sorted(current_set - bundle_set)

extras_to_delete = []
if mode == "mirror" and delete_extras:
  extras_to_delete = extras
  if delete_extras_max and len(extras_to_delete) > delete_extras_max:
    extras_to_delete = extras_to_delete[:delete_extras_max]

whoami = load_json_or_null(whoami_json) or {}
bundle_account = load_json_or_null(bundle_account_json) or {}

plan = {
  "bundleDir": os.path.dirname(bundle_txt),
  "mode": mode,
  "dryRunOnly": True,  # wrapper flips after execution
  "targetAccount": {
    "loggedIn": whoami.get("loggedIn", None),
    "email": whoami.get("email", None),
    "user_id": whoami.get("user_id", None),
  },
  "bundleAccount": {
    "loggedIn": bundle_account.get("loggedIn", None),
    "email": bundle_account.get("email", None),
    "user_id": bundle_account.get("user_id", None),
  },
  "bundleUnique": len(bundle_set),
  "currentUnique": len(current_set),
  "toAddCount": len(to_add),
  "extrasCount": len(extras),
  "extrasToDeleteCount": len(extras_to_delete),
  "deleteExtrasMax": (delete_extras_max or None),
}

open(plan_json, "w", encoding="utf-8").write(json.dumps(plan, ensure_ascii=False, indent=2) + "\n")
open(extras_txt, "w", encoding="utf-8").write("\n".join(extras_to_delete) + ("\n" if extras_to_delete else ""))
PY

  if [[ "$dry_run" -eq 1 ]]; then
    cat "$plan_json"
    return
  fi

  # Import is add-only; typeless-dict handles de-dupe and skips existing.
  local import_json
  import_json="$(mktemp_file)"
  trap 'rm -f "$current_txt" "$extras_txt" "$plan_json" "$whoami_json" "$import_json"' RETURN

  run_typeless "$port" whoami >/dev/null
  run_typeless "$port" import "$bundle_dir/dictionary.txt" >"$import_json"

  local attempted_deletes=0
  local failed_deletes=0
  local failed_terms
  failed_terms="$(mktemp_file)"
  trap 'rm -f "$current_txt" "$extras_txt" "$plan_json" "$whoami_json" "$import_json" "$failed_terms"' RETURN

  if [[ "$mode" == "mirror" && "$delete_extras" -eq 1 ]]; then
    while IFS= read -r term; do
      [[ -n "$term" ]] || continue
      attempted_deletes=$((attempted_deletes + 1))
      if ! run_typeless "$port" delete "$term" --all-matches >/dev/null; then
        failed_deletes=$((failed_deletes + 1))
        echo "$term" >>"$failed_terms"
      fi
    done <"$extras_txt"
  fi

  python3 - "$plan_json" "$import_json" "$attempted_deletes" "$failed_deletes" "$failed_terms" <<'PY'
import json, sys, os

plan_json, import_json, attempted_deletes, failed_deletes, failed_terms_path = sys.argv[1:]
attempted_deletes = int(attempted_deletes)
failed_deletes = int(failed_deletes)

plan = json.load(open(plan_json, "r", encoding="utf-8"))
plan["dryRunOnly"] = False

import_result = {}
try:
  import_result = json.load(open(import_json, "r", encoding="utf-8"))
except Exception:
  import_result = {"raw": open(import_json, "r", encoding="utf-8").read()}

failed_terms = []
if failed_terms_path and os.path.exists(failed_terms_path):
  failed_terms = [line.strip() for line in open(failed_terms_path, "r", encoding="utf-8") if line.strip()]

result = {
  "plan": plan,
  "importResult": import_result,
  "deleteExtras": {
    "attempted": attempted_deletes,
    "failed": failed_deletes,
    "failedTermsSample": failed_terms[:20],
    "failedTermsTruncatedTo": (20 if len(failed_terms) > 20 else None),
  },
}

print(json.dumps(result, ensure_ascii=False, indent=2))
PY
}

usage() {
  cat <<'EOF'
Usage:
  typeless_dictionary_transfer.sh export-bundle [label]
  typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
  typeless_dictionary_transfer.sh import-bundle <bundle-dir>
  typeless_dictionary_transfer.sh compare-bundle-vs-current <bundle-dir> [--text] [--no-words] [--limit-words N] [--port PORT]
  typeless_dictionary_transfer.sh sync-bundle-to-current <bundle-dir> [--mode add-only|mirror] [--dry-run] [--delete-extras] [--delete-extras-max N] [--port PORT]

Phases:
  export-bundle   Export the currently logged-in Typeless dictionary into a portable bundle.
  import-dry-run  Check what would be imported into the currently logged-in Typeless account.
  import-bundle   Import the bundle into the currently logged-in Typeless account.
  compare-bundle-vs-current  Export current dictionary and compare it against a bundle (read-only).
  sync-bundle-to-current     Add missing terms from bundle to current account; optionally delete extras (explicit opt-in).
EOF
}

cmd="${1:-}"
case "$cmd" in
  export-bundle)
    shift
    export_bundle "${1:-dictionary}"
    ;;
  import-dry-run)
    shift
    [[ $# -ge 1 ]] || die "bundle dir required"
    import_dry_run "$1"
    ;;
  import-bundle)
    shift
    [[ $# -ge 1 ]] || die "bundle dir required"
    import_bundle "$1"
    ;;
  compare-bundle-vs-current)
    shift
    [[ $# -ge 1 ]] || die "bundle dir required"
    compare_bundle_vs_current "$1" "${@:2}"
    ;;
  sync-bundle-to-current)
    shift
    [[ $# -ge 1 ]] || die "bundle dir required"
    sync_bundle_to_current "$1" "${@:2}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
