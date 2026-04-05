# Fynos Tally Connect — Releases

This repository is the public download channel for **Fynos Tally Connect**, the desktop sync agent that bridges [Tally ERP](https://tallysolutions.com/) with the [Fynos](https://fynos.com/) platform.

> Source code is maintained in a private repository. This repo only hosts signed release binaries so that customers and partners can download them without needing GitHub access to the source.

## Download the Latest Version

Head to the [**Releases**](https://github.com/fyn-os/fynos-tally-connect-releases/releases/latest) page and pick the installer for your platform:

| Platform | File |
| --- | --- |
| macOS (Apple Silicon) | `Fynos.Tally.Connect_<version>_aarch64.dmg` |
| macOS (Intel) | `Fynos.Tally.Connect_<version>_x64.dmg` |
| Windows (installer) | `Fynos.Tally.Connect_<version>_x64-setup.exe` |
| Windows (MSI) | `Fynos.Tally.Connect_<version>_x64_en-US.msi` |

The `.app.tar.gz` bundles attached to each release are used by the Tauri auto-updater and are not meant to be downloaded manually.

## What Fynos Tally Connect Does

- Connects to a locally running Tally ERP instance over its XML API
- Fetches ledgers and vouchers on a schedule (or on-demand)
- Uploads the data to the Fynos backend via signed GCS URLs
- Runs in the background with a system-tray icon and an in-app log viewer

## Requirements

- A running Tally ERP instance (default: `localhost:9000`)
- Backend URL and API key provided by your Fynos administrator

## Support

For questions, installation help, or bug reports, please contact your Fynos account manager or open an issue on this repository.

---

© Fynos Technologies Pvt. Ltd. — Proprietary software.
