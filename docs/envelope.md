# Envelope

The canonical JSON Schema for UMAF lives at `spec/umaf-envelope-v0.5.0.json`.
This document is a human-friendly overview; the schema is the source of truth.

## Core fields

These fields are always present and define the basic identity and payload of an
envelope:

| field        | type    | notes                                                  |
| ------------ | ------- | ------------------------------------------------------ |
| `version`    | string  | `"umaf-0.5.0"`                                         |
| `docTitle`   | string  | derived from first heading or filename                 |
| `docId`      | string  | stable identifier derived from `sourcePath` + content  |
| `createdAt`  | string  | RFC 3339 timestamp (UTC)                               |
| `sourceHash` | string  | SHA-256 of the original bytes (hex-encoded)            |
| `sourcePath` | string  | original path (or `"-"` for stdin)                     |
| `mediaType`  | string  | e.g. `text/plain`, `text/markdown`, `application/json` |
| `encoding`   | string  | `"utf-8"`                                              |
| `sizeBytes`  | integer | size of the original input in bytes                    |
| `lineCount`  | integer | number of lines in `normalized`                        |
| `normalized` | string  | canonical normalized content (usually Markdown)        |

Arrays such as `sections`, `bullets`, `frontMatter`, `tables`, and `codeBlocks`
are optional but, when present, are constrained by the JSON Schema.

## Structural fields: spans and blocks

UMAF v0.5.0 can emit a lightweight structural view of the normalized document
via the `spans` and `blocks` arrays. These fields are optional but, when
present, follow these conventions:

- `spans` is an array of `span` objects (`UMAFSpanV0_5` in Swift):

  - `id`: stable string identifier for the span (e.g. `span:root`,
    `span:sec:001`).
  - `startLine`, `endLine`: 1-based line numbers into `normalized`.
  - `startColumn`, `endColumn` (optional): 0-based column offsets.

- `blocks` is an array of `block` objects (`UMAFBlockV0_5` in Swift):

  - `id`: stable identifier for the block (e.g. `block:root`,
    `block:sec:001`).
  - `kind`: logical kind of block (root, section, paragraph, bullet, table,
    code, front-matter, raw, etc.).
  - `spanId`: reference into the `spans` array; every block must point at a
    real span.
  - `parentId`: parent block id (or `null` for the root block).
  - `level`: optional integer nesting level (e.g. heading level).
  - `heading`, `language`, `tableHeader`, `tableRows`, `metadata`:
    optional fields that surface extra structure for certain block kinds.

For UMAF v0.5.0, the following invariants are enforced by the implementation
and tests:

- There is always a `span:root` covering `[1 ... lineCount]` when structural
  data is emitted.
- There is always a `block:root` whose `kind` is `"root"`, whose `parentId` is
  `null`, and whose `spanId` is `"span:root"`.
- Every `block.spanId` corresponds to a `span.id`.
- All spans obey `1 <= startLine <= endLine <= lineCount`.

See the tests under `Tests/UMAFCoreTests/UMAFWalkerTask1Tests.swift`,
`UMAFWalkerTask2Tests.swift`, and `UMAFCLIIntegrationTests.swift` for the
precise invariants.

## Provenance, confidence, and feature flags

UMAF uses a simple provenance and confidence taxonomy for blocks:

- `provenance` is a string that describes how the block was derived, for
  example:

  - `umaf:0.5.0:markdown:heading-atx`
  - `umaf:0.5.0:markdown:bullet`
  - `umaf:0.5.0:markdown:paragraph`
  - `umaf:0.5.0:markdown:table:pipe`
  - `umaf:0.5.0:markdown:code:fenced-backtick`
  - `umaf:0.5.0:markdown:front-matter:yaml`

  These strings are computed by `BlockProvenanceV0_5` and are stable within
  the 0.5.0 schema.

- `confidence` is a float in `[0.0, 1.0]` that reflects how confident UMAF is
  about the semantic classification of the block. For v0.5.0, headings,
  bullets, front matter, tidy tables, and fenced code from Markdown inputs are
  typically assigned `1.0`, while ragged tables and raw content use slightly
  lower values.

At the envelope level, `featureFlags` is an optional object mapping string keys
to booleans. For v0.5.0 the only defined flag is:

- `featureFlags.structure == true` when the CLI was invoked with
  `--json --dump-structure` and structural data (`spans` and `blocks`) has
  been populated.

## Validation

To validate envelopes against the JSON Schema:

```bash
npm ci
node scripts/validate2020.mjs   --schema spec/umaf-envelope-v0.5.0.json   --data ".build/envelopes/*.json"   --strict
```
