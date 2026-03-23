#!/usr/bin/env bash
set -euo pipefail

TYPELESS_DICT_BIN="${TYPELESS_DICT_BIN:-$HOME/bin/typeless-dict}"
DEFAULT_OUT_BASE="${TYPELESS_TRANSFER_BASE:-$HOME/Downloads}"

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

whoami_email() {
  "$TYPELESS_DICT_BIN" whoami | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
print(data.get("email") or "unknown")
PY
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

  echo "Current target account:"
  "$TYPELESS_DICT_BIN" whoami
  echo
  echo "Importing bundle:"
  echo "  $bundle_dir/dictionary.txt"
  "$TYPELESS_DICT_BIN" import "$bundle_dir/dictionary.txt"
}

usage() {
  cat <<'EOF'
Usage:
  typeless_dictionary_transfer.sh export-bundle [label]
  typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
  typeless_dictionary_transfer.sh import-bundle <bundle-dir>

Phases:
  export-bundle   Export the currently logged-in Typeless dictionary into a portable bundle.
  import-dry-run  Check what would be imported into the currently logged-in Typeless account.
  import-bundle   Import the bundle into the currently logged-in Typeless account.
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
    import_dry_run "${1:?bundle dir required}"
    ;;
  import-bundle)
    shift
    import_bundle "${1:?bundle dir required}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
