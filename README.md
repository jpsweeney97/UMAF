# UMAF

UMAF (Universal Machine‑readable Archive Format) is a tiny, fast transformer that ingests
**plain text**, **Markdown**, **JSON**, and common formats (HTML, PDF, DOCX via adapters)
and emits a consistent, machine‑friendly **UMAF envelope**.

> Current envelope schema: `umaf-envelope-0.6.0`

---

## Quick start

### Build the CLI

```bash
swift build -c release
```

### Single File

Transform a single file and output to stdout:

```bash
./.build/release/umaf --input input.md --json > output.json
```

### Batch Mode (High Performance)

Process thousands of files in parallel using all CPU cores:

```bash
./.build/release/umaf --input-dir ./corpus --output-dir ./out --json
```

### Watch Mode

Live-update output files as you edit source content:

```bash
./.build/release/umaf --input-dir ./corpus --output-dir ./out --watch
```

## Features

- **Deterministic**: Stable hashing and normalization.
- **Fast**: Parallel batch processing (sub-millisecond overhead per file).
- **Live**: Watch mode for instant feedback loops.
- **Typed**: JSON Schema validation for all outputs.

## Project layout

- `Sources/UMAFCore`: Core logic and adapters.
- `Sources/umaf`: CLI entry point.
- `spec/`: JSON Schema definitions.

## License

ISC © 2025 JP Sweeney
