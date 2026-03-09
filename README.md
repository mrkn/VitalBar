# VitalBar

VitalBar is a macOS menu bar app that samples system status and visualizes it directly in the menu bar.

## Current features

- Menu-bar-only app (`LSUIElement` behavior).
- Compact menu bar label with CPU, memory, and disk history graphs.
- Current CPU percentage in the primary menu.
- Memory display with:
  - used / total
  - memory pressure
  - app memory
  - wired memory
  - cached files
  - compressed memory
  - swap used
- Disk usage display with `used / total (percent)`.
- Uptime display.
- Temperature sampling:
  - CPU and SoC summary in the primary menu
  - full temperature detail submenu when additional sensors are available
  - SMC sampling with IOHID fallback for environments where AppleSMC access is unavailable
- Stale state when sampling stops updating.
- `VitalBar` submenu with:
  - `Keep Mac Awake`
  - `Launch at Login`
  - `Quit VitalBar`
- Menu bar status indicator for `Keep Mac Awake`.
- Unit and view model tests.
- CI and release workflows for build, test, coverage, signing, and notarized releases.

## Requirements

- macOS 14 or later
- Swift 6.2
- Xcode 16.1 or a compatible toolchain

## Project structure

- `Sources/VitalBarCore`: core sampling, history buffers, shared models, and service logic.
- `Sources/VitalBarApp`: app lifecycle, menu bar UI, launch-at-login, keep-awake, and temperature integration.
- `Tests/VitalBarCoreTests`: unit tests for core sampling and support types.
- `Tests/VitalBarAppTests`: UI-facing and view model behavior tests.
- `Scripts/`: build, coverage, and icon helper scripts.
- `.github/workflows`: CI and release workflows.

## Build and run locally

```bash
make run
```

Direct SwiftPM invocation also works:

```bash
swift run VitalBarApp
```

## Make targets

```bash
make help
make build
make run
make test
make coverage
make app VERSION=0.1.0
make bundle VERSION=0.1.0
make icon
make icon-candidates
make ci
```

## Build a local app bundle

```bash
make app VERSION=0.1.0
```

This creates `dist/VitalBar.app`.

If you want `Launch at Login` to work, run the bundled app from `/Applications`, for example:

```bash
cp -R dist/VitalBar.app /Applications/
open /Applications/VitalBar.app
```

## Run tests

```bash
make test
```

## Coverage gate

`VitalBarCore` line coverage must stay at or above 80%.

```bash
make coverage
```

## Release workflow secrets

Set these GitHub repository secrets before pushing `v*` tags:

- `MACOS_CERTIFICATE_P12` (base64-encoded Developer ID Application certificate)
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_CERTIFICATE_IDENTITY` (codesign identity string)
- `KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

## Manual acceptance checklist

1. Launch the app and confirm the menu bar label appears within a few seconds.
2. Confirm CPU, memory, and disk graphs update over time.
3. Open the primary menu and verify current CPU, memory, disk, and uptime values render.
4. Verify temperature behavior:
   - `Temperature` is disabled when no temperature is available.
   - `CPU / SoC` appears when either reading is available.
   - the detail submenu appears only when sensors beyond CPU / SoC are available.
5. Toggle `Keep Mac Awake` and confirm:
   - the submenu item changes state
   - the coffee cup indicator appears in the menu bar
6. Toggle `Launch at Login` from the bundled app in `/Applications`.
7. Verify stale warning appears if sampling cannot update for several seconds.

## License

This project is licensed under the MIT License. See `LICENSE`.
