# OpenToF

Monorepo for an open-source trampoline time-of-flight sensor: Arduino firmware (`firmware/`) and a Flutter companion
app (`app/`) that talk over BLE. Start with `README.md` (overview, layout, releasing); read `app/CLAUDE.md` or
`firmware/CLAUDE.md` before working in those folders.

## Docs and what they're for
- `docs/PROTOCOL.md` — the BLE interface and algorithm API. App and firmware must change together; update it with
  any protocol change.
- `docs/DECISIONS.md` — product decisions; **overrides** anything else on conflict. Not covered there = ask the user.
  Record new decisions there (decision + why, with the date), not in other files.
- `docs/ROADMAP.md` — architecture and open/unverified items. Remove items when they are done.
- `Changelog.md` — user-facing changes per release; the app parses it (format rules in the README, "Releasing").

## Rules
- Before committing, follow "Releasing" in `README.md`: version bumps (app and firmware share MAJOR.MINOR), the
  Changelog format (it is not Keep a Changelog), and `dart run tool/sync_changelog.dart` after editing it.
- Ask before switching, creating, merging or rebasing branches.
- `software/`, `cad/` and `img/` are independent of the BLE protocol; `cad/opentof_housing.py` is the source of the
  `.FCStd`/STL files (see `cad/README.md`).
