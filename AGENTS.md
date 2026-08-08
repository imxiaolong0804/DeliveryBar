# Repository Guidelines

## Project Structure & Module Organization

DeliveryBar is a macOS 26+ menu bar app built with Swift 5, SwiftUI, AppKit, and SwiftData. Main source lives in `DeliveryBar/`:

- `DeliveryBarApp.swift` starts the accessory app, SwiftData container, status item, panels, and hotkeys.
- `Models/` contains SwiftData models and enums such as `Requirement`, `TemporaryTask`, `QuickEntry`, and `JSONFormatHistory`.
- `Views/` contains SwiftUI screens and components, including `MenuBarView`, editors, settings, and `DeliveryBarTheme`.
- `Services/` contains AppKit/system integration: status bar, floating panels, hotkeys, and reminders.
- `Utils/` contains shared helpers.
- `Assets.xcassets/` stores app icon and accent color assets.
- `scripts/` contains packaging and icon-generation utilities. Build artifacts belong in `.build/` and `dist/`.

## Build, Test, and Development Commands

- `open DeliveryBar.xcodeproj` opens the app in Xcode; run with `Cmd+R`.
- `xcodebuild -project DeliveryBar.xcodeproj -scheme DeliveryBar -configuration Debug build` builds a local debug app.
- `xcodebuild -project DeliveryBar.xcodeproj -scheme DeliveryBar -configuration Release -destination "generic/platform=macOS" build` verifies the release build.
- `./scripts/package_dmg.sh 2.0.0` creates `dist/DeliveryBar-2.0.0.dmg`.
- `swift scripts/generate_app_icon.swift` regenerates app icon PNGs in `DeliveryBar/Assets.xcassets/AppIcon.appiconset`.

## Coding Style & Naming Conventions

Use standard Swift formatting with 4-space indentation. Prefer `struct` for SwiftUI views, `final class` for reference types, and small private helpers or nested enums for layout constants. Keep model names singular (`Requirement`, `QuickEntry`) and view files suffixed with `View`. Preserve the existing direct SwiftUI style and avoid adding third-party dependencies unless there is a clear project need.

## Testing Guidelines

No committed XCTest target is currently present. For now, run the debug or release `xcodebuild` command before opening a PR and manually verify menu bar launch, `Cmd+Shift+D`, `Cmd+Shift+J`, SwiftData persistence, reminders, and DMG packaging when touched. When adding tests, place them in a future `DeliveryBarTests/` target, name files `FeatureTests.swift`, and name methods `test...`.

## Commit & Pull Request Guidelines

Recent history uses short prefixes such as `feat：`, `doc：`, and `version`, often with Chinese descriptions. Follow that concise style, for example `feat：优化快捷录搜索` or `doc：更新打包说明`. PRs should include a clear summary, manual verification steps, linked issue or context, and screenshots or screen recordings for visible UI changes.

## Security & Configuration Tips

DeliveryBar is intentionally local-first: no accounts, network services, or external tracking. Do not commit personal SwiftData stores, derived data, DMGs, or local Xcode user settings.
