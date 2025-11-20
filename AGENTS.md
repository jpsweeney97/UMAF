# AGENTS.md — UMAF

UMAF (Universal Machine-readable Archive Format) is a small Swift + Node
toolchain for turning plain text / Markdown / JSON (and some richer formats via
adapters) into a deterministic **UMAF envelope** (JSON) and a canonical
normalized Markdown / text representation.

This file is for **coding agents** (Codex, CLIs, scripts, etc.). Treat it as
the source of truth for how to build, test, and safely modify this repository.

---

## Executive summary

- Protect determinism, schema stability, and crucible health in all UMAF tasks.
- Use the commands here as canonical build, test, and validation pipeline.
- Prefer small, reversible, well-tested diffs; escalate risky changes explicitly.

---

## Assumptions & scope

- **Audience:** Automated coding agents (Codex, CLIs, tools) and humans working on UMAF.
- **Goal:** Keep UMAF correct, deterministic, and maintainable while enabling safe evolution.
- **Inputs:** This repository (Swift package + Node tooling + crucible + schemas).
- **Constraints & limits:** No schema/version changes or non-determinism without explicit human approval.
- **Environment:** SwiftPM + Node. In Codex cloud: repo root is typically `/workspace/UMAF`.
- **Timeframe:** Valid for UMAF envelope schema `umaf-envelope-v0.5.0` and version string `umaf-0.5.0`.
- **Out of scope:** Git hosting details, CI configuration, release process specifics.

---

## 0. Golden rules

1. **Never break determinism.**

   - No randomness or hidden time-based behavior in core transforms.
   - The envelope already includes `createdAt`; do not add new non-deterministic
     fields or behaviors without an explicit schema version bump.

2. **Do not silently change the envelope schema.**

   - Current schema file: `spec/umaf-envelope-v0.5.0.json`.
   - Current version string in envelopes: `"umaf-0.5.0"`.
   - Swift model: `UMAFEnvelopeV0_5` (or similarly named versioned type).
   - Any incompatible change must be treated as a **new version** (0.5.x or
     0.6.0) and coordinated across:
     - JSON Schema
     - Swift models and encoders/decoders
     - Tests (unit + crucible)
     - Docs and CLI help

3. **Keep the Markdown transform stable and idempotent.**

   - For supported formats, the round-trip

     ```
     input
       → envelope JSON
       → normalized Markdown
       → envelope JSON
     ```

     must be stable (idempotent) for the same input.

   - Crucible fixtures under `crucible/` are the main testbed for this. Do not
     “tidy” them unless explicitly asked.

4. **Keep the suite green.**

   - `swift test -v`
   - `swift build -c release`
   - Crucible pipeline via `npm run validate:envelopes`
   - Strict JSON Schema validation of generated envelopes

5. **Prefer small, well-scoped diffs.**

   - Explain what changed and why.
   - Update or add tests alongside behavioral changes.
   - If you are about to make a large or risky change, pause and summarize
     tradeoffs instead of guessing.

If a request conflicts with these rules, **surface the conflict** in your
response before proceeding.

---

## 1. Repository layout (high level)

Paths are relative to the **repo root**.

- `Package.swift`
  SwiftPM manifest; defines library target `UMAFCore` and executable target
  `umaf`.

- `Sources/`

  - `UMAFCore/`

    - `UMAFCoreEngine.swift` – string-first transformer; canonical low-level API.
    - `Engine.swift` – `UMAFEngine` convenience wrapper used by the CLI.
    - `Router.swift` – input routing + normalization (`InputRouter.load`).
    - `Parsing/Markdown/MarkdownEngineV2.swift` – semantic Markdown entrypoint.
    - `Envelope.swift` – strongly typed `UMAFEnvelopeV0_5` model.
    - `Normalization.swift` – helpers for envelope decoding and root spans/blocks.
    - `Inputs/*Adapter.swift` – e.g. `HTMLAdapter`, `DOCXAdapter`, `PDFKitAdapter`,
      `OCRAdapter` (platform-specific adapters).
    - `Cache/CacheStore.swift` – optional on-disk cache keyed by file hash.
    - `UMAFError.swift` – user-facing error taxonomy.
    - `Logging.swift` – OSLog / logging helpers.

  - `umaf/`
    - `main.swift` – CLI implementation using `UMAFEngine`.

- `Tests/UMAFCoreTests/`

  - `UMAFCoreTests.swift` – envelope + normalization tests, crucible tests.
  - `SchemaValidationTests.swift` – assertions about required keys and invariants.
  - `MarkdownEngineV2Tests.swift` – parity vs basic Markdown behavior.

- `crucible/`

  - `markdown-crucible-v2.md` – comprehensive torture test for normalization.
  - `crucible/min/*` – smaller, focused edge-case fixtures.

- `spec/umaf-envelope-v0.5.0.json`
  JSON Schema for the envelope.

- `scripts/`

  - `validate2020.mjs` – generic JSON Schema validator (AJV, draft 2020-12).
  - `run-envelopes.mjs` – runs the Swift CLI over crucible Markdown to produce envelopes.
  - `validate-envelope.sh` – shell helper around `npx ajv validate`.
  - `swiftlint.sh` – convenience wrapper for SwiftLint (if present).

- `package.json`, `package-lock.json` – Node dev tooling (AJV, glob, etc.).

- `docs/`, `mkdocs.yml` – human-oriented documentation.

**Codex cloud note:** In Codex cloud environments, the repo is typically checked
out to `/workspace/UMAF`; treat that as the repo root when running commands.

---

## 2. Build, test, and validation pipeline

All commands below assume the **repo root** as current directory.

### 2.1 One-time / per-environment setup

```bash
# Install Node dev dependencies from package-lock.json (deterministic)
npm ci
```

The Swift toolchain is provided by the environment image (e.g. Swift 6.x on
macOS / Linux). Do **not** attempt to install toolchains yourself; surface
mismatches instead:

```bash
swift --version
```

If the version is incompatible with the project, report that rather than
modifying the environment.

### 2.2 Swift build and tests

```bash
# Debug build (fast iteration)
swift build

# Full test suite
swift test -v

# Release build (CLI used in validation pipelines)
swift build -c release
# CLI path:
#   .build/release/umaf
```

Sanity-check the CLI:

```bash
swift run umaf --help
# or:
.build/debug/umaf --help
```

### 2.3 Envelope / crucible validation pipeline

This is the **canonical end-to-end check** and must be green for meaningful
behavioral changes.

```bash
# From repo root
npm ci

# Build release CLI
swift build -c release

# Use the UMAF CLI to generate envelopes from crucible Markdown
UMAF_CLI=.build/release/umaf npm run validate:envelopes

# Validate generated envelopes against the JSON Schema (strict mode)
node scripts/validate2020.mjs   --schema spec/umaf-envelope-v0.5.0.json   --data ".build/envelopes/*.json"   --strict
```

The suite is considered **green** only when all of these succeed:

- `swift test -v`
- `swift build -c release`
- `UMAF_CLI=.build/release/umaf npm run validate:envelopes`
- `node scripts/validate2020.mjs --schema spec/umaf-envelope-v0.5.0.json --data ".build/envelopes/*.json" --strict`

Run this full pipeline whenever you modify:

- `Sources/UMAFCore/**`
- `umaf` CLI
- `spec/`
- `crucible/`
- `scripts/` involved in validation

---

## 3. Behavioral contracts

### 3.1 Envelope contracts

When emitting JSON envelopes via `UMAFCoreEngine.Transformer` (or equivalent):

- `version` must be exactly:

  ```json
  "umaf-0.5.0"
  ```

  until an explicit schema/version bump is coordinated.

- The set of **required top-level keys** is:

  ```jsonc
  [
    "version",
    "docTitle",
    "docId",
    "createdAt",
    "sourceHash",
    "sourcePath",
    "mediaType",
    "encoding",
    "sizeBytes",
    "lineCount",
    "normalized"
  ]
  ```

- `normalized` is the canonical normalized text/Markdown string.

- `lineCount` must equal the number of lines in `normalized` when split by
  `"
"` with `omittingEmptySubsequences: false`.

- Optional structural arrays such as `sections`, `bullets`, `frontMatter`,
  `tables`, `codeBlocks`, `spans`, and `blocks`, when present, must:
  - Conform to the JSON Schema in `spec/umaf-envelope-v0.5.0.json`.
  - Match the Swift types in `UMAFEnvelopeV0_5` (or its current versioned
    equivalent).

### 3.2 Markdown normalization

For Markdown inputs and normalized outputs:

- Normalize line endings to `
`.
- Ensure **no trailing spaces** on lines outside code fences.
- Allow at most **one blank line** between block elements.
- Preserve the **contents of fenced code blocks** exactly:
  - Do not alter internal whitespace or content.
  - You may trim trailing whitespace on the fence lines themselves if already
    implemented that way.
- For unbalanced fences or malformed Markdown, **avoid deleting content**:
  - Prefer lossy-but-visible output over silent data loss.

Any changes to:

- `canonicalizeMarkdownLines`
- `buildMarkdownFromSemantic`
- Markdown structural detection (headings, lists, tables, code blocks)

must be accompanied by:

- Targeted tests in `UMAFCoreTests`
- Updates to crucible expectations (where relevant)

and must keep normalization **idempotent** (re-running UMAF on normalized output
should not change it).

---

## 4. Language and style conventions

### 4.1 Swift / UMAFCore

- Swift toolchain: Swift 5.9+ (Swift 6.x typical).
- Indentation: **2 spaces**.
- Style configuration:

  - `.swift-format`
  - `.swiftlint.yml`

- Preferred patterns:

  - Use small, pure functions and focused structs where possible.
  - Keep `UMAFCoreEngine.Transformer` as the **single entrypoint** for file
    transforms; new behavior should be expressed as parameters or helpers
    instead of parallel “top-level” transformers.
  - Avoid introducing new third-party Swift packages unless explicitly requested.
  - Keep platform-specific adapters (`DOCXAdapter`, `PDFKitAdapter`, `OCRAdapter`)
    **isolated**, as they may not compile/run in Linux containers. Core engine
    should remain testable on Linux.

- JSON output from Swift:
  - Use `JSONEncoder` with `outputFormatting = [.prettyPrinted, .sortedKeys]`
    for human-facing fixtures.
  - For canonicalization or round-trip comparisons, use a stable, sorted-key
    representation.

Run SwiftLint if needed:

```bash
./scripts/swiftlint.sh
```

### 4.2 JavaScript / Node tooling

- `package.json` is `"type": "module"`; use **ESM imports**:

  ```js
  import fs from 'node:fs';
  ```

- Keep scripts in `scripts/`:

  - Small, single-purpose.
  - Deterministic.
  - Portable across Unix-like environments (no OS-specific paths if avoidable).

- Do **not** introduce bundlers or TypeScript without explicit instruction.

### 4.3 JSON, Markdown, and docs

- JSON fixtures and manifests:

  - UTF-8, 2-space indent, no trailing commas.
  - Prefer sorted keys where reasonable (mirrors `JSONEncoder.sortedKeys`).

- JSON Schemas under `spec/`:

  - Maintain valid `$id` / `$schema` URIs.
  - Avoid removing required keys or changing semantics of existing fields.

- Markdown docs in `docs/`:
  - Human-oriented and concise.
  - Use fenced code blocks with explicit languages (`bash`, `swift`, `json`,
    etc.).
  - Follow the project’s normalization expectations where reasonable, but **do
    not** modify docs solely to satisfy the engine.

---

## 5. Codex and cloud environments

For agents running in Codex cloud:

- The repo is typically checked out to:

  ```text
  /workspace/UMAF
  ```

- From that directory, all commands in this file should work as written.

When running larger refactors or multi-step tasks:

1. **Read this file first.**
   Understand determinism, schema, and crucible constraints.

2. **Summarize the plan** before editing:

   - Which files will change.
   - Which commands you will run (build, tests, crucible, validation).
   - How you will detect regressions.

3. **Use the full validation pipeline** (Section 2.3) before declaring success.

If Codex or any agent cannot satisfy these constraints (e.g. missing toolchain,
partial checkout), it should **report the limitation** instead of trying to
self-modify the environment.

---

## 6. Typical tasks and how to approach them

### 6.1 Adding or fixing normalization behavior

1. Identify the exact input pattern:
   - Ideally add or update a case in `crucible/` to capture it.
2. Update:
   - `UMAFCoreEngine.parseSemanticStructure`
   - and/or `canonicalizeMarkdownLines`
   - and/or `buildMarkdownFromSemantic`
3. Add or adjust tests:
   - Specific tests in `UMAFCoreTests`.
   - Additional coverage in `MarkdownEngineV2Tests` if semantic behavior changes.
4. Run the **full** pipeline:
   - `swift test -v`
   - `swift build -c release`
   - `UMAF_CLI=.build/release/umaf npm run validate:envelopes`
   - `node scripts/validate2020.mjs --schema spec/umaf-envelope-v0.5.0.json --data ".build/envelopes/*.json" --strict`

### 6.2 Changing CLI UX (flags, output modes)

1. Work in:

   - `Sources/umaf/main.swift`
   - and, if needed, `Sources/UMAFCore/Engine.swift` (`UMAFEngine`).

2. Preserve existing flags and behavior, e.g.:

   - `--input`
   - `--json`
   - `--normalized`

3. For new flags:

   - Update help text.
   - Document new behavior (e.g. in `docs/cli.md` or `README.md`).
   - Add tests or simple shell examples.

4. Avoid changing defaults (such as default output mode) unless explicitly
   requested.

### 6.3 Schema evolution (only when explicitly requested)

1. Coordinate changes between:

   - `spec/umaf-envelope-vX.Y.Z.json`
   - Versioned Swift models (`UMAFEnvelopeV0_5` or its successor)
   - Normalization/build logic
   - Tests and docs

2. Bump version strings consistently:

   - Envelope `version` field.
   - Any embedded provenance/version strings in code and docs.

3. Prefer additive migrations:
   - Add new optional fields rather than removing or reinterpreting existing
     ones, unless there is a clear migration story.

---

## 7. Safety, non-goals, and things to avoid

### 7.1 Safe defaults

- Use `git status` and `git diff` frequently (where Git is available).
- Keep changes **narrow and purposeful**:
  - A small set of related files per task.
- Always finish tasks with a **green suite** (Section 2.3).

When in doubt, propose a summary of options and tradeoffs rather than taking a
destructive action.

### 7.2 Do **not** do these things unless explicitly requested

- Change:

  - The envelope version string (`"umaf-0.5.0"`).
  - The schema `$id` or structural requirements in `spec/umaf-envelope-v0.5.0.json`.
  - The public API surface of `UMAFEngine` (or other public types) without
    updating tests and docs.

- Modify the environment by:

  - Installing system packages (`apt`, `brew`, `sudo`, etc.).
  - Editing user-wide configuration files (shell rc, global git config, etc.).

- Touch project structure by:

  - Renaming top-level folders (`Sources`, `Tests`, `spec`, `crucible`, etc.).
  - Committing build artifacts (`.build/`, `node_modules/`, etc.).

- “Clean up” crucible inputs:
  - Files under `crucible/` are intentionally weird and hostile.
  - Do not reformat or simplify them unless the task is specifically about
    adjusting the crucible.

If a task appears to require any of the above, **stop and ask for explicit
human approval**.

---

## 8. Quick reference

**Core commands**

```bash
# Swift
swift build
swift test -v
swift build -c release

# Node / schema checks
npm ci
UMAF_CLI=.build/release/umaf npm run validate:envelopes
node scripts/validate2020.mjs   --schema spec/umaf-envelope-v0.5.0.json   --data ".build/envelopes/*.json"   --strict
```

**Key files to read before deep changes**

- `README.md`
- `AGENTS.md` (this file)
- `spec/umaf-envelope-v0.5.0.json`
- `Sources/UMAFCore/UMAFCoreEngine.swift`
- `Sources/UMAFCore/Envelope.swift`
- `Sources/UMAFCore/Normalization.swift`
- `crucible/markdown-crucible-v2.md`
- `Tests/UMAFCoreTests/UMAFCoreTests.swift`

End of `AGENTS.md`.
