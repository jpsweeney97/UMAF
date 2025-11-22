# CLI

```bash
umaf --help
```

## Core flags

- `-i, --input <path>`: Single file input mode.
- `--input-dir <path>`: **Batch Mode** input directory (scans recursively).
- `--output-dir <path>`: **Batch Mode** output directory (required with `--input-dir`).
- `--watch`: Watch input directory for changes and re-process instantly.
- `--json`: Output UMAF envelope JSON (default).
- `--normalized`: Output canonical normalized text (Markdown where possible).
- `--dump-structure`: (with `--json`) Populate structural `spans`/`blocks` (omitted otherwise).

## Examples

**Single File:**

```bash
# Output JSON to stdout
umaf --input README.md --json > envelope.json
```

**Batch Processing (Power User):**
Process an entire folder of Markdown files in parallel, utilizing all CPU cores.

```bash
# Process all files in "data/" and write results to "dist/"
umaf --input-dir ./data --output-dir ./dist --json
```

**Watch Mode (God Mode):**
Instantly re-process files on save.

```bash
umaf --input-dir ./crucible --output-dir ./dist --watch
```

## Exit Codes

Exit codes are stable and documented in `UMAFUserError.exitCode`.
