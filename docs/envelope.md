# Envelope

The canonical JSON Schema for UMAF lives at `spec/umaf-envelope-v0.5.0.json`.

Key fields:

| field       | type   | notes                                         |
|-------------|--------|-----------------------------------------------|
| `version`   | string | `"umaf-0.5.0"`                                |
| `encoding`  | string | `"utf-8"`                                     |
| `mediaType` | string | `text/plain | text/markdown | application/json` |
| `docTitle`  | string | derived from first heading or filename        |
| `normalized`| string | canonical normalized content                  |

Validation:

```bash
npm ci
node scripts/validate2020.mjs --schema spec/umaf-envelope-v0.5.0.json --data ".build/envelopes/*.json" --strict
```
