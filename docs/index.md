# UMAF

UMAF turns plain text, Markdown, JSON, and a few other formats into a compact
**envelope** that's easy to consume, diff, and validate.

- **CLI:** `umaf`
- **Schema:** `spec/umaf-envelope-v0.5.0.json`

## Quick start

```bash
swift build -c release
./.build/release/umaf --input README.md --json > out.envelope.json
```

The CLI can emit:

- `--json` - a UMAF envelope as JSON
- `--normalized` - canonical normalized text (usually Markdown)
- `--json --dump-structure` - envelope JSON with populated `spans`, `blocks`,
  and `featureFlags.structure == true`

See [Envelope](envelope.md) for the schema and structural fields, and
[CLI](cli.md) for all flags.
