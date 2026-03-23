# Typeless Dictionary Transfer

[![README-English](https://img.shields.io/badge/README-English-555555?style=for-the-badge)](README.md)
[![README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-2d6cdf?style=for-the-badge)](README.zh-CN.md)

Export, review, restore, and transfer Typeless personal dictionaries as portable bundles.

This project focuses on dictionary portability first and cross-account migration second. It helps you:

- export the currently logged-in Typeless dictionary
- review or edit the exported bundle before re-use
- dry-run an import into the current Typeless account
- import the bundle into another Typeless account after an explicit account switch

It does **not** automate Typeless login/logout itself. Account switching remains an intentional manual checkpoint to reduce the risk of importing into the wrong account.

## Quickstart

### 1. Check the current Typeless account

```bash
$HOME/bin/typeless-dict whoami
```

### 2. Export a portable bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle source-account
```

This creates a bundle under `~/Downloads/typeless-transfer-.../` with:

```text
account.json
dictionary.json
dictionary.txt
```

### 3. Dry-run an import

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run /path/to/bundle-dir
```

### 4. Import after explicit confirmation

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle /path/to/bundle-dir
```

## Requirements / Compatibility

- macOS with Typeless desktop app installed at `/Applications/Typeless.app`
- local helper binary at `$HOME/bin/typeless-dict`
- a Typeless account already logged into the desktop app
- Node.js available locally so the helper can attach to Typeless via remote debugging
- `python3` available locally because the wrapper uses it for small JSON parsing steps

Optional overrides:

- `TYPELESS_DICT_BIN` overrides the `typeless-dict` binary path (default: `$HOME/bin/typeless-dict`)
- `TYPELESS_TRANSFER_BASE` overrides the export bundle output base directory (default: `$HOME/Downloads`)

The workflow is designed around the local Typeless desktop client and its current request/signing behavior. If Typeless changes its desktop internals substantially, the helper may need to be updated.

## Installation

This skill is already structured for Codex under:

```text
$HOME/.codex/skills/typeless-dictionary-transfer/
```

If you only want the command-line workflow, the core helper is:

```bash
$HOME/bin/typeless-dict help
```

## What It Does

The workflow treats dictionary transfer as three operations:

1. **Export bundle** from the currently logged-in Typeless account
2. **Review/edit bundle** locally before any import
3. **Import bundle** into the currently logged-in Typeless account

This makes the same tooling useful for:

- backup
- restore
- same-account re-import
- cross-account transfer
- cross-machine transfer

## Repository Layout

```text
typeless-dictionary-transfer/
├── README.md
├── README.zh-CN.md
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── typeless_dictionary_transfer.sh
```

Related helper outside this skill directory:

```text
$HOME/bin/typeless-dict
```

## Usage

### Verify current account

```bash
$HOME/bin/typeless-dict whoami
```

### Export the current dictionary directly

```bash
$HOME/bin/typeless-dict export /tmp/typeless-dictionary.json --tab all --format json
$HOME/bin/typeless-dict export /tmp/typeless-dictionary.txt --tab all --format txt
```

### Dry-run import

```bash
$HOME/bin/typeless-dict import /path/to/dictionary.txt --dry-run
```

### Import

```bash
$HOME/bin/typeless-dict import /path/to/dictionary.txt
```

### Delete one term

```bash
$HOME/bin/typeless-dict delete "term-here"
```

## Wrapper Workflow

### Export bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle [label]
```

If you need custom paths, set `TYPELESS_DICT_BIN` or `TYPELESS_TRANSFER_BASE` first.

### Compare bundle vs current account

Exports the *currently logged-in* dictionary and compares it to the bundle:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh compare-bundle-vs-current <bundle-dir>
```

By default it prints JSON. Use `--text` for a human-friendly summary.

### Dry-run import from bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run <bundle-dir>
```

### Import bundle

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle <bundle-dir>
```

### Sync bundle to current account

Add-only sync (safe default):

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh sync-bundle-to-current <bundle-dir>
```

Mirror sync (adds missing terms and deletes extras) requires explicit opt-in:

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh sync-bundle-to-current <bundle-dir> --mode mirror --dry-run
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh sync-bundle-to-current <bundle-dir> --mode mirror --delete-extras
```

Note: deletions can be slow because the underlying helper deletes one term per run.

## Recommended Cross-Account Transfer Flow

### 1. Export from source account A

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh export-bundle source-a
```

### 2. Review the bundle

Inspect and, if needed, edit:

- `dictionary.json`
- `dictionary.txt`

### 3. Manually switch Typeless to account B

The tooling intentionally stops short of automating account login/logout.

### 4. Verify target account B

```bash
$HOME/bin/typeless-dict whoami
```

### 5. Dry-run the import

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-dry-run /path/to/bundle-dir
```

### 6. Import only after confirmation

```bash
$HOME/.codex/skills/typeless-dictionary-transfer/scripts/typeless_dictionary_transfer.sh import-bundle /path/to/bundle-dir
```

## Troubleshooting

- **Export returns zero terms unexpectedly**
  Verify the Typeless desktop app is logged in and the dictionary page is accessible. Re-run `typeless-dict whoami` first.

- **Dry run says too many terms already exist**
  Review and trim `dictionary.txt` before importing. The bundle is intentionally plain text for easy edits.

- **Wrong account risk**
  Always run `typeless-dict whoami` immediately before import. This is the main safety check.

- **Typeless helper stops working after an app update**
  The helper depends on current Typeless desktop behavior. Re-validate export/import after Typeless upgrades.

## Security / Privacy

- The workflow uses your local Typeless desktop session.
- Exported bundles contain personal dictionary data and should be treated as private.
- The bundle is intentionally stored on disk so you can inspect, edit, and archive it.
- Do not send exported bundles to third parties unless you intend to share the contained terminology.

## Support / Development

Primary implementation docs for Codex live in:

- [SKILL.md](SKILL.md)

Useful helper entry point:

- `$HOME/bin/typeless-dict`

If you update the skill workflow, make sure README, `SKILL.md`, and the wrapper script stay aligned.

## License / Status

This is currently a local skill/workflow maintained in the user's Codex environment. Repository packaging and public release strategy depend on where it is eventually published.
