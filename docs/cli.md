# CLI

```bash
umaf --help
```

Core flags:

- `-i, --input` input path (required)
- `--json` output UMAF envelope JSON (default if no other mode is set)
- `--normalized` output canonical normalized text (Markdown where possible)
- `--dump-structure` (with `--json`) populate structural `spans`/`blocks` and set `featureFlags.structure = true`

Exit codes are stable and documented in `UMAFUserError.exitCode`.

Example: generate a structural envelope for the crucible Markdown:

```bash
swift build -c release
./.build/release/umaf \
  --input crucible/markdown-crucible-v2.md \
  --json \
  --dump-structure \
  > crucible-structure.json
```
