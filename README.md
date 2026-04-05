# Fynos Tally Connect — Releases

This repository is the public distribution channel for **Fynos Tally Connect**, the desktop sync agent that bridges [Tally ERP](https://tallysolutions.com/) with the [Fynos](https://fynos.com/) platform.

> Source code is maintained in a private repository. This repo hosts the signed release binaries, a client setup playbook, and a fallback export script so that customers and partners can get their Tally data into Fynos without needing source access.

## For Clients: Start Here

**New to Fynos Tally Connect? Follow the step-by-step setup guide:**

### [📘 CLIENT_PLAYBOOK.md — Setup Playbook](CLIENT_PLAYBOOK.md)

The playbook walks you through three ways to get your Tally data into Fynos, in order of preference:

1. **The desktop app** — recommended for most users. Auto-syncs in the background.
2. **The fallback script** — for when the app cannot reach Tally for environment-specific reasons.
3. **Manual export from Tally menus** — the last-resort option that works on every Tally installation.

Before you start, ask your Fynos account manager for an **invite code** (looks like `FTC-A7K9P`). You will need it on first run.

## Downloads

### Desktop App (Option A in the playbook)

Go to the [**Releases**](https://github.com/fyn-os/fynos-tally-connect-releases/releases/latest) page and pick the installer for your platform:

| Platform | File |
| --- | --- |
| Windows (installer) | `Fynos.Tally.Connect_<version>_x64-setup.exe` |
| Windows (MSI) | `Fynos.Tally.Connect_<version>_x64_en-US.msi` |
| macOS (Apple Silicon) | `Fynos.Tally.Connect_<version>_aarch64.dmg` |
| macOS (Intel) | `Fynos.Tally.Connect_<version>_x64.dmg` |

The `.app.tar.gz` bundles attached to each release are used by the in-app auto-updater and are not meant to be downloaded manually.

### Fallback Script (Option B in the playbook)

If the desktop app cannot reach Tally on your machine, use the PowerShell fallback script:

**[scripts/tally-export.ps1](scripts/tally-export.ps1)**

Direct download (right-click → **Save link as**): [raw.githubusercontent.com/.../tally-export.ps1](https://raw.githubusercontent.com/fyn-os/fynos-tally-connect-releases/main/scripts/tally-export.ps1)

See section B of the [Client Playbook](CLIENT_PLAYBOOK.md) for full instructions.

## What Fynos Tally Connect Does

- Connects to a locally running Tally ERP instance over its XML API
- Fetches ledgers, groups, and vouchers on a schedule (or on-demand)
- Uploads the data to the Fynos backend via signed GCS URLs
- Runs in the background with a system-tray icon and an in-app log viewer

## Requirements

- A running Tally ERP instance (default: `localhost:9000`) with a company loaded
- An invite code from your Fynos account manager
- Internet connection (desktop app only — the fallback script works offline)

## Support

For questions, installation help, or to report an issue, please contact your Fynos account manager or open an issue on this repository.

---

© Fynos Technologies Pvt. Ltd. — Proprietary software.
