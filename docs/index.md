# UMAF

UMAF turns plain text, Markdown, JSON, and a few other formats into a compact
**envelope** that's easy to consume, diff, and validate.

- **CLI:** `umaf`
- **Schema:** `spec/umaf-envelope-v0.7.0.json`

## Quick start

```bash
swift build -c release
./.build/release/umaf --input README.md --json > out.envelope.json
```

The CLI can emit:

- `--json` - a UMAF envelope as JSON
- `--normalized` - canonical normalized text (usually Markdown)
- Structural spans/blocks are always included in `--json` output in UMAF 0.7.0.

See [Envelope](envelope.md) for the schema and structural fields, and
[CLI](cli.md) for all flags.
