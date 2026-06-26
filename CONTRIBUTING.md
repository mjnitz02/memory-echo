# Contributing

MemoryEcho is a personal, single-maintainer project built for exactly one user.
It's open source in case the approach helps someone, but it isn't seeking to grow
into a general-purpose product. That shapes how contributions are handled:

- **Bug reports and ideas are welcome** via [issues](https://github.com/mjnitz02/FocusEcho/issues).
- **PRs may be declined** if they don't fit the design guardrails — even if they're
  well made. Please open an issue to discuss anything non-trivial first.

## Design guardrails (non-negotiable)

These override "nice to have." See [`docs/PLAN.md`](docs/PLAN.md) for the full rationale.

1. **Capture is the #1 surface** — any friction loses the thought.
2. **Get out of the way** — anti-engagement is a feature.
3. **No settings screen** — tunables live in code (`Tuning`), never as user knobs.
4. **No hierarchy, no calendar** — one pool; "today, loosely tomorrow."
5. **Prioritization is derived**, never a manual picker.

## Development

Everything runs through the `Makefile` (see [`README.md`](README.md) for the full list):

```sh
make install-tools   # SwiftLint + SwiftFormat
make install-hooks   # pre-commit hook (lint + format-check)

make test-unit       # the CI gate
make lint            # SwiftLint (strict)
make format          # apply formatting
```

## Before you open a PR

- `make test-unit` passes.
- `make lint` and `make format-check` pass (the pre-commit hook covers this).
- Keep changes focused; match the style of the surrounding code.
- Fill in the PR template.

## Environment

- macOS on **Apple Silicon** (no Intel/Rosetta support), Xcode 26+, an iOS 26.5 simulator.

## License

By contributing, you agree your contributions are licensed under the
[MIT License](LICENSE).
