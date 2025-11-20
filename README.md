# UMAF

UMAF (Universal Machine‑readable Archive Format) is a tiny, fast transformer that ingests
**plain text**, **Markdown**, **JSON**, and a few other common formats (HTML, PDF, DOCX via
adapters) and emits a consistent, machine‑friendly **UMAF envelope**.

This repo ships as:

- a reusable Swift library (`UMAFCore`)
- a SwiftPM CLI (`umaf`) for pipelines and CI
- test crucibles and JSON Schema for the envelope format

> Current envelope schema: `umaf-envelope-0.5.0`

---

## What does it do?

Given an input file (`.txt`, `.md`, `.json`, `.html`, `.pdf`, `.docx`, etc.), UMAF:

- computes a stable hash
- normalizes line endings and whitespace
- extracts structure (headings, bullets, tables, fenced code blocks, and optional front‑matter)
- returns either:
  - a JSON **envelope** with normalized content and extracted metadata, or
  - canonical normalized text (usually Markdown)

The envelope is designed to be lightweight but predictable and is validated using a JSON Schema
in this repo.

## Project layout

```text
.
├─ Sources/
│  ├─ UMAFCore/              # Core engine, routers, envelope model
│  └─ umaf/                  # SwiftPM CLI (ArgumentParser-powered)
├─ Tests/
│  └─ UMAFCoreTests/         # Schema + engine tests
├─ spec/                     # JSON Schemas (v0.5.0+)
├─ crucible/                 # Markdown torture tests
├─ scripts/                  # Tooling (SwiftLint, envelope validation)
├─ docs/                     # MkDocs documentation
└─ .github/workflows/        # CI for Swift + Node validation
```

## Quick start

### Build the CLI

```bash
# macOS 13+ with Xcode 15+ (Swift 5.9+) or Swift toolchain 5.9+
swift build -c release
./.build/release/umaf --help
```

Transform a file:

```bash
# Emit UMAF envelope JSON (default)
./.build/release/umaf --input path/to/input.md --json > out.envelope.json

# Emit canonical normalized text (Markdown where possible)
./.build/release/umaf --input path/to/input.md --normalized > normalized.md
```

## Envelope format (summary)

The envelope is emitted as JSON with this top-level shape
(see the [full schema](./spec/umaf-envelope-v0.5.0.json) for details):

```jsonc
{
  "version": "umaf-0.5.0",
  "docTitle": "...",
  "docId": "...",            // stable identifier derived from source
  "createdAt": "2025-11-13T21:00:00Z",
  "sourceHash": "...",       // SHA-256 (hex)
  "sourcePath": "...",       // original path (or "-" for stdin)
  "mediaType": "text/markdown",
  "encoding": "utf-8",
  "sizeBytes": 12345,
  "lineCount": 420,
  "normalized": "...",       // normalized text/markdown
  "sections": [{ "heading": "...", "level": 2, "lines": [...], "paragraphs": [...] }],
  "bullets": [{ "text": "...", "lineIndex": 10, "sectionHeading": "..." }],
  "frontMatter": [{ "key": "title", "value": "..." }],
  "tables": [{ "startLineIndex": 12, "header": ["A", "B"], "rows": [["1","2"]] }],
  "codeBlocks": [{ "startLineIndex": 40, "language": "swift", "code": "..." }],
  "spans": [{ "id": "span:root", "startLine": 1, "endLine": 420 }],
  "blocks": [{ "id": "block:root", "kind": "root", "spanId": "span:root" }]
}
```

## Developing

- **Formatting**: `.swift-format` and `.swiftlint.yml` are configured; run `swift run swiftlint` or `./scripts/swiftlint.sh`.
- **Tests**: run `swift test` to exercise the library.
- **CI**: GitHub Actions builds the Swift package and validates envelopes against the schema.

### Common tasks

```bash
# Build CLI and run a sample transform
swift build
./.build/debug/umaf --input README.md --json | jq .version

# Run UMAFCore tests
swift test -v --filter UMAFCoreTests

# Lint Swift (if you have SwiftLint installed)
./scripts/swiftlint.sh
```

### Schema validation and crucible

```bash
# Generate UMAF envelopes from crucible inputs using the release CLI
swift build -c release
UMAF_CLI=.build/release/umaf npm run validate:envelopes

# Validate all generated envelopes against the UMAF 0.5.0 schema
node scripts/validate2020.mjs \
  --schema spec/umaf-envelope-v0.5.0.json \
  --data ".build/envelopes/*.json" \
  --strict


## License

ISC © 2025 JP Sweeney
```
