# VitalBar

VitalBar is a macOS menu bar app that samples system status and visualizes it in place.
The v1 implementation focuses on CPU load history only.

## v1 scope

- Menu-bar-only app (`LSUIElement` behavior).
- CPU load sampling every second.
- Last 120 samples (2 minutes) shown as a sparkline + current percentage.
- Stale state after 5 seconds without successful sampling.
- Core logic and ViewModel tests.
- CI and release workflows for build/test/coverage and signed+notarized release.

## Project structure

- `Sources/VitalBarCore`: sampling, history buffer, service actor, extension-friendly interfaces.
- `Sources/VitalBarApp`: `MenuBarExtra` UI, view model, app lifecycle.
- `Tests/VitalBarCoreTests`: unit tests for calculator, sampler, history, service.
- `Tests/VitalBarAppTests`: integration-like tests for view model and display rules.
- `.github/workflows`: CI and release workflows.

## Build and run locally

```bash
swift run VitalBarApp
```

## Make shortcuts

```bash
make help
make build
make run
make test
make coverage
make bundle VERSION=0.1.0
```

## Run tests

```bash
swift test
```

## Coverage gate (VitalBarCore >= 80%)

```bash
swift test --enable-code-coverage
./Scripts/check-core-coverage.sh 80
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

1. Launch app and confirm menu bar label appears within 5 seconds.
2. Confirm sparkline and current `%` update every second.
3. Generate CPU load and verify graph/value react.
4. Verify stale warning appears if sampling cannot update for >5 seconds.

## License

This project is licensed under the MIT License. See `LICENSE`.
