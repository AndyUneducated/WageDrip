# WageDrip / 窝囊费

A salary ticker: a multiplatform SwiftUI app for iOS, iPadOS and macOS with widgets, a Live Activity and a Mac menu bar item.

## Working agreements

- **Do not use the superpowers plugin in this project.** Do not invoke any of its skills (brainstorming, writing-plans, executing-plans, subagent-driven-development and so on) or follow its workflows or directory conventions. (Explicit owner request, 2026-11-24.)
- **All documentation and commit messages are in English.** (Explicit owner request, 2026-11-24.) Code comments are English too. The app's own UI strings are bilingual and keyed by their Chinese text in `WageDrip/Localizable.xcstrings`.
- Talk to the owner in Chinese.
- Do not start executing until the owner clearly says to start; during discussion, offer suggestions and ask questions.
- The git identity is set to AndyUneducated in this repo only. Do not change the global git config.
- The repository is public at github.com/AndyUneducated/WageDrip. Keep team IDs, device identifiers and personal details out of the repo.

## Documents

- Design spec: `docs/specs/2026-11-24-wagedrip-design.md`
- Implementation plan: `docs/plans/2026-11-24-wagedrip-v1.md`

## Common commands

- Core tests: `swift test --package-path Packages/WageDripCore`
- Generate the project: `DEVELOPMENT_TEAM=<team ID> /opt/homebrew/bin/xcodegen generate` (team ID under Xcode › Settings › Accounts; never commit it)
- Simulator build: `xcodebuild -project WageDrip.xcodeproj -scheme WageDrip -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath DerivedData build`
- Watch testing: the Apple Watch Ultra 4 (49mm) simulator is paired with the iPhone 17 simulator. A simulator build also produces `DerivedData/Build/Products/Debug-watchsimulator/WageDripWatch.app`; install it on the watch simulator with `xcrun simctl install`. There is no Simulator window on this machine and the simulator tool does not drive watches, so interact through a temporary watchOS UI test (`XCUIDevice`, and `XCUIApplication(bundleIdentifier: "com.apple.Carousel")` for the watch face).
- This machine has no iPhone 17 Pro Max simulator; use iPhone 17. For iPad use iPad Pro 13-inch (M5).
- The diagnostics log on a physical device can be read directly: `xcrun devicectl device copy from --domain-type appGroupDataContainer --domain-identifier group.com.andyuneducated.wagedrip ...`
