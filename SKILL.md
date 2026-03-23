---
name: typeless-dictionary-transfer
description: Export, review, restore, and transfer Typeless personal dictionaries by creating a portable bundle and then importing it into the currently logged-in Typeless account. Use when the user wants Typeless dictionary export/import, backup/restore, cross-account transfer, or a dry-run before importing a dictionary bundle.
---

# Typeless Dictionary Transfer

## Overview

This skill is for Typeless dictionary portability first, and account migration second. It packages the current Typeless dictionary into portable files, lets the user review or edit those files, and then imports the bundle into whichever Typeless account is currently logged in.

## Use This Skill When

- The user wants to export a Typeless dictionary for backup.
- The user wants to review a Typeless dictionary before importing it somewhere else.
- The user wants to import a previously exported Typeless dictionary bundle.
- The user wants to transfer dictionary entries from Typeless account A to account B.
- The user wants to dry-run a Typeless dictionary import before committing it.

## Mental Model

Treat this as a two-step portability flow:

1. Export the current Typeless dictionary into a bundle.
2. Import that bundle into the currently logged-in Typeless account.

Switching accounts is optional workflow glue, not the core capability. The core capability is `export -> review -> import`.

## Guardrails

- Always verify the currently logged-in Typeless account before export and before import.
- Default to a dry run before import unless the user explicitly asks to proceed.
- Keep the exported bundle on disk even after a successful import.
- If the import target is the same account as the export source, call that out as restore/sync, not migration.
- Do not silently import into a different Typeless account without an explicit confirmation point.
- For “mirror sync” (deleting terms that exist in the current account but not in the bundle), require an explicit opt-in and strongly prefer a dry run first.

## Prerequisites

- Typeless desktop app exists at `/Applications/Typeless.app`.
- The local helper binary exists at `$HOME/bin/typeless-dict` by default, or the caller overrides it with `TYPELESS_DICT_BIN`.
- The export bundle base directory defaults to `$HOME/Downloads`, or the caller overrides it with `TYPELESS_TRANSFER_BASE`.
- Typeless desktop app is openable and the intended account is logged in.
- `typeless-dict whoami` returns the current account successfully.
- Node.js is available locally for the Typeless helper workflow.
- `python3` is available locally for small wrapper-side JSON parsing.

## Core Commands

Verify the currently logged-in Typeless account:

```bash
$HOME/bin/typeless-dict whoami
```

Export the currently logged-in dictionary:

```bash
$HOME/bin/typeless-dict export /tmp/typeless-dictionary.json --tab all --format json
$HOME/bin/typeless-dict export /tmp/typeless-dictionary.txt --tab all --format txt
```

Dry-run an import into the currently logged-in account:

```bash
$HOME/bin/typeless-dict import /path/to/dictionary.txt --dry-run
```

Import into the currently logged-in account:

```bash
$HOME/bin/typeless-dict import /path/to/dictionary.txt
```

Delete one term from the currently logged-in account:

```bash
$HOME/bin/typeless-dict delete "term-here"
```

## Recommended Workflow

### 1. Export Bundle

Use the wrapper script:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle [label]
```

This creates a bundle under `~/Downloads/typeless-transfer-.../` with:

- `account.json`
- `dictionary.json`
- `dictionary.txt`

### 2. Review Or Edit Bundle

Review the exported files. If needed, edit `dictionary.txt` before import.

This is the right point to:

- remove junk terms
- normalize spelling
- add extra terms manually
- compare source and target dictionaries

### 2.5 Compare Bundle vs Current (Optional)

If you want a precise diff between a bundle and the *currently logged-in* account (adds vs extras), use:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh compare-bundle-vs-current <bundle-dir>
```

This exports the current dictionary on demand and prints a JSON summary.

### 3. Optional Account Switch

If the goal is cross-account transfer, ask the user to sign out of Typeless account A and sign into account B.

Do not continue until `typeless-dict whoami` confirms the target account.

### 4. Dry Run Import

Use:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
```

Review:

- how many terms already exist
- how many would be added
- whether the bundle still needs editing

### 5. Import Bundle

Only after explicit confirmation:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle <bundle-dir>
```

### 6. Validate Result

Run:

```bash
$HOME/bin/typeless-dict export /tmp/typeless-post-import.json --tab all --format json
```

Then compare:

- source bundle count
- target post-import count
- skipped existing count
- failed count, if any

## Wrapper Script

Bundled helper:

- `scripts/typeless_dictionary_transfer.sh`

Usage:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle [label]
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle <bundle-dir>
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh compare-bundle-vs-current <bundle-dir> [--text] [--no-words] [--limit-words N] [--port PORT]
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh sync-bundle-to-current <bundle-dir> [--mode add-only|mirror] [--dry-run] [--delete-extras] [--delete-extras-max N] [--port PORT]
```

## Failure Handling

- If Typeless is not logged in, stop and ask the user to log into the intended account.
- If export unexpectedly returns zero terms, inspect the current Typeless dictionary page before continuing.
- If dry run shows suspicious terms, edit the bundle before import.
- If import or delete partially fails, keep the bundle and report the failed terms explicitly.
- If a mirror sync is requested, call out that deletions can be slow because the underlying helper does not support batch delete in a single run.

## Output Expectations

When using this skill, report:

- which Typeless account was exported
- which Typeless account is about to receive the import
- the bundle path
- the dry-run summary
- the final import summary

Do not treat “same-account import” as an error; call it restore/sync and continue only if the user wants that behavior.
