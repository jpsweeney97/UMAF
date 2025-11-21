# Changelog

## Unreleased
- (none)

## 0.5.1 — 2025-11-21
- Refactored UMAFCoreEngine: extracted core models into `Sources/UMAFCore/CoreModels.swift`, parsing helpers into `Sources/UMAFCore/Parsing/Markdown/LineScanner.swift`, and slimmed adapters with shared `TextNormalization`.
- Transformer now returns typed results (envelope or markdown), removing JSON round-trips in `Engine.swift` and CLI paths.
- Updated tests to consume typed transformer output and retained behavior; suite currently passes.
