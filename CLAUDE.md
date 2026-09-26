# OpenToF

Open-source Time-of-Flight measurement system for trampolining: an Arduino sensor mounted under the mat
measures how long a jumper is airborne and reports it over BLE; a Flutter companion app connects to it.

This is a small monorepo:
- `app/` — the Flutter companion app (iOS + Android). Read `app/CLAUDE.md` before working here.
- `firmware/` — the Arduino sketch for the sensor (XIAO MG24 Sense). Read `firmware/CLAUDE.md` before working here.
- `software/` — standalone Python tools for dumping/plotting raw sensor data. Unrelated to the app/firmware
  BLE protocol; no CLAUDE.md of its own yet.
- `img/` — shared branding source (e.g. the OpenToF logo); not owned by `app/`.
- `docs/DECISIONS.md` — resolved product/engineering decisions for the whole project (app **and** firmware);
  **overrides** any spec on conflict.
- `docs/PLAN.md` — architecture + milestone checklist across app and firmware.

## Git & versioning policy (decided 2026-09-23) — READ BEFORE ANY git COMMAND
This overrides any general "just do it" / auto-mode / yolo-mode instruction. It applies everywhere in this
repo, for every agent session, no exceptions.
- **NEVER run `git push` (or anything that publishes commits/branches/tags to `origin`), ever.** The user
  pushes, always, personally. Not even if asked to "just push it" in the moment — stop and confirm that's
  really meant, since it contradicts this file.
- **Before every `git commit`, and before every branch change** (`checkout`/`switch`, creating a branch,
  `merge`, `rebase`, `reset` onto a different commit) **ask the user first** and wait for an explicit go-ahead
  — regardless of the permission/auto mode the session is running in. Describe what you're about to commit or
  switch to; don't just do it and mention it afterwards.
- **Version bumps.** Before a commit that changes code in the Flutter app (`app/`) or the **main** firmware
  sketch (`firmware/OpenToF_Firmware/` — not the helper sketches/scripts: `firmware/datalogger_selfmade/`,
  `firmware/ble_test/`, `firmware/deep_sleep_test/`, or `software/`), ask the user whether it's a **major**,
  **minor**, or **hotfix/patch** bump, and bump the corresponding version as part of that same commit:
  - Flutter app: `version:` in `app/pubspec.yaml` (`MAJOR.MINOR.PATCH+BUILD`; bump the build number too).
  - Main firmware: `FIRMWARE_VERSION` in `firmware/OpenToF_Firmware/config/FirmwareConfig.h`.
  - A commit touching both bumps both, independently (they don't have to move in lockstep) — ask separately for each.
  - Docs-only, helper-script-only, or tooling-only commits don't need a version bump; still ask before committing.

## Restructuring note (2026-09-23)
`app/`, `docs/` staying at root, and the CLAUDE.md split into this file + `app/CLAUDE.md` + `firmware/CLAUDE.md`,
were introduced to merge the Flutter companion app into this repo (which already had `firmware/`, `software/`
and `img/`) as a new branch. That merge has now happened for real (see `git log`, `git remote -v`); this repo
is connected to `git@github.com:nrother/OpenToF.git`.
