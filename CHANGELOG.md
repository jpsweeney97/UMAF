# Changelog

## Unreleased

- (none)

## 0.7.0 — 2025-11-21

- **Breaking:** Schema bumped to `umaf-envelope-v0.7.0`; spans, blocks, and featureFlags are required and every block must carry provenance + confidence.
- **Rich envelopes by default:** Engine always performs structural analysis and sets `featureFlags.structure == true`; CLI no longer offers a slim/structure toggle.
- **Model updates:** Introduced `UMAFEnvelopeV0_7`/span/block types with non-optional provenance/confidence; walker/engine logic emits full structure.
- **Provenance:** Rule paths now use the 0.7.0 prefix with default confidence 1.0 for unambiguous syntax; paragraph/ragged cases retain lower scores.
- **Schema/docs:** Added `spec/umaf-envelope-v0.7.0.json`, updated docs/README/validation scripts to reference v0.7.0.

## 0.5.1 — 2025-11-21

- Refactored UMAFCoreEngine: extracted core models into `Sources/UMAFCore/CoreModels.swift`, parsing helpers into `Sources/UMAFCore/Parsing/Markdown/LineScanner.swift`, and slimmed adapters with shared `TextNormalization`.
- Transformer now returns typed results (envelope or markdown), removing JSON round-trips in `Engine.swift` and CLI paths.
- Updated tests to consume typed transformer output and retained behavior; suite currently passes.
- Centralized version constants in `UMAFVersion` and wired provenance strings to avoid duplicated prefixes; cleaned redundant PDF normalization and removed legacy MarkdownEngineV2/test scaffolding.

## 0.6.0 — 2025-11-21

### Added

- **HTML Support:** Replaced regex-based parsing with `SwiftSoup` for robust handling of nested tags and malformed HTML.
- **Concurrency:** Adopted Swift Actors and TaskGroups for thread-safe, high-performance batch processing.
- **Logging:** Integrated `swift-log` for standardized, cross-platform logging.
- **Linux Support:** Added CI matrix testing for Ubuntu and guarded macOS-specific adapters (`PDFKit`, `Vision`, `textutil`).

### Changed

- **Architecture:** Replaced bespoke `LineScanner` with `swift-markdown`. The parser now generates normalized text and semantic indices in a single pass ("Unified Truth"), eliminating invariant crashes in `UMAFWalker`.
- **Caching:** Cache file is now stored in the system's user cache directory instead of polluting the input folder.
- **Fidelity:** "Inverse Scan" strategy ensures 100% preservation of source formatting (whitespace, indentation) in the normalized output.
