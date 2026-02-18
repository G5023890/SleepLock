# SleepLock

SleepLock is a native macOS menu bar utility that controls when your Mac is allowed to sleep.

The app is designed as a lightweight system-style tool:
- menu bar only (`LSUIElement = true`)
- no Dock icon
- native AppKit + SwiftUI
- low overhead and simple interaction

## Requirements

- macOS 13+
- Swift toolchain (SwiftPM)
- Apple Development certificate (optional, but recommended for stable signing)

## Core behavior

SleepLock uses native power activity APIs:
- `ProcessInfo.processInfo.beginActivity(.idleSystemSleepDisabled)`
- `ProcessInfo.processInfo.endActivity(...)`

No shell `caffeinate` process is used.

## Modes

Internal state model:
- `off`
- `keepAwakeInfinite`
- `keepAwakeUntil(Date)`
- `allowSleepAfter(Date)`

### Semantics

- **Keep Awake For**: prevents sleep immediately and keeps Mac awake until timer end.
- **Allow Sleep In**: also prevents sleep immediately for a fixed duration; when timer expires, SleepLock disables its override and requests system sleep.
- **Turn Off**: cancels timers, ends sleep override, returns to neutral behavior.

Timers are absolute wall-clock timers and do not reset based on user activity.

## Menu bar icons

- **Startup / Idle (`off`)**: combined moon+sun template icon.
- **Stay awake infinite**: `sun.max.fill`.
- **Keep awake timer**: `sun.max.fill` + remaining time (`Nh` / `Nm`).
- **Allow sleep timer**: `moon.fill` + remaining time (`Nh` / `Nm`).

All menu bar icons are template monochrome icons and adapt automatically to Light/Dark mode.

## Current menu structure

- `Turn Off`
- `Keep a wake for:`
  - `1 hour`
  - `3 Hour`
  - `5 Hour`
  - `Until manually turn off`
- `Allow Sleep In:`
  - `30 min`
  - `1 hour`
  - `2 hour`
- `Launch at login`
- `Quit`

## UX shortcuts

- `Option + left click` on status item: quick toggle on/off.
- `Right click`: opens full menu.

## Launch at login

The app uses `SMAppService.mainApp` for launch-at-login registration.

## Build and install

Project includes scripts for stable local install/signing workflow.

### 1) Generate app icon (`AppIcon.icns`)

```bash
/Users/grigorymordokhovich/Documents/Develop/SleepLock/scripts/generate_app_icon.sh
```

You can pass a custom PNG path:

```bash
/Users/grigorymordokhovich/Documents/Develop/SleepLock/scripts/generate_app_icon.sh /absolute/path/icon.png
```

### 2) Build and install to `/Applications`

```bash
/Users/grigorymordokhovich/Documents/Develop/SleepLock/scripts/build_and_install_app.sh
```

Output app locations:
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/dist/SleepLock.app`
- `/Applications/SleepLock.app`

## Development

### Run tests

```bash
cd /Users/grigorymordokhovich/Documents/Develop/SleepLock
swift test
```

### Release build

```bash
cd /Users/grigorymordokhovich/Documents/Develop/SleepLock
swift build -c release
```

## Repository

GitHub remote:
- [https://github.com/G5023890/SleepLock](https://github.com/G5023890/SleepLock)

## Project structure

- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/SleepLockApp.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/StatusBarController.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/SleepController.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/SleepSystemController.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/LaunchAtLoginManager.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/Sources/SleepLock/SleepTimeFormatter.swift`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/scripts/build_and_install_app.sh`
- `/Users/grigorymordokhovich/Documents/Develop/SleepLock/scripts/generate_app_icon.sh`
