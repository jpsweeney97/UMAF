# CLI

```bash
umaf --help
```

Core flags:

- `-i, --input`   input path (required)
- `--json`        output UMAF envelope JSON (default if no other mode is set)
- `--normalized`  output canonical normalized text (Markdown where possible)

Exit codes are stable and documented in `UMAFUserError.exitCode`.
