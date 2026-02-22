# Repository Guidelines

## Project Structure & Module Organization
- `Sources/VitalBarCore`: core sampling and metrics logic (CPU, memory, history, shared support types).
- `Sources/VitalBarApp`: macOS menu bar app (`MenuBarExtra`), SwiftUI views, and app lifecycle wiring.
- `Tests/VitalBarCoreTests` and `Tests/VitalBarAppTests`: XCTest suites aligned to module boundaries.
- `Scripts/`: development and release helpers (`build-app-bundle.sh`, `check-core-coverage.sh`, icon scripts).
- `Assets/`: app icon files and icon candidates.
- `dist/`: generated release outputs; treat as build artifacts.

## Build, Test, and Development Commands
- `make help`: list available tasks.
- `make build`: build the Swift package in debug mode.
- `make run` (or `swift run VitalBarApp`): launch the app locally.
- `make test`: run all tests.
- `make coverage`: run coverage-enabled tests and enforce threshold.
- `make bundle VERSION=0.1.0`: build `dist/VitalBar.app`.
- `make ci`: run local CI-equivalent checks (`build`, coverage test, coverage gate).

## Coding Style & Naming Conventions
- Language/toolchain: Swift 6.2, target macOS 14+.
- Follow idiomatic Swift style: 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for methods/properties.
- Keep boundaries clean: reusable/system logic in `VitalBarCore`; UI-only behavior in `VitalBarApp`.
- Prefer small, testable units (for example samplers/calculators/services) over large stateful classes.

## Testing Guidelines
- Test framework: `XCTest`.
- Naming: files end with `*Tests.swift`; test methods start with `test`.
- Add tests in the matching test module whenever behavior changes.
- CI enforces `VitalBarCore` line coverage of at least 80% via `Scripts/check-core-coverage.sh`.

## Commit & Pull Request Guidelines
- Use short, imperative commit subjects in sentence case, consistent with history (example: `Add memory usage sampling and display used/total format`).
- Keep commits focused; avoid mixing refactors and behavior changes without reason.
- PRs should include:
  - clear change summary and rationale,
  - linked issue (if applicable),
  - verification steps/results (`make ci`),
  - screenshots or short recordings for UI-visible changes.

## Security & Release Notes
- Never commit signing or notarization credentials.
- Tagged releases (`v*`) run the release workflow; required secrets are documented in `README.md`.
- Validate generated artifacts in `dist/` before publishing.
