# SysStats

<img width="485" height="36" alt="Screenshot 2025-12-30 at 6 18 06 PM" src="https://github.com/user-attachments/assets/f85068d6-02d0-4667-a0d5-960874b6cfb6" />

A lightweight macOS menu bar application that displays real-time system statistics directly in your status bar.

## Features

- **Menu bar only** - No dock icon, no main window, stays out of your way
- **Real-time monitoring** - Displays CPU, GPU, RAM usage and temperature
- **Icon-based display** - Uses SF Symbols for a clean, native look
- **Configurable refresh rate** - Choose between 1s, 2s, or 5s update intervals
- **SwiftUI popover** - Click for detailed stats with color-coded progress bars
- **Preferences panel** - Customize which stats to show, temperature unit, and more
- **Launch at login** - Optional auto-start when you log in
- **Apple Silicon support** - Optimized for M1/M2/M3 Macs with IOKit thermal sensors

## Menu Bar Display

<img width="164" height="33" alt="Screenshot 2025-12-31 at 1 40 06 PM" src="https://github.com/user-attachments/assets/7e4de76b-d575-42f7-b0dc-96add4952f79" />

| Icon | Metric |
|------|--------|
| 🖥️ | CPU usage percentage |
| 🧊 | GPU usage percentage |
| 💾 | RAM usage percentage |
| 🌡️ | Temperature (°C or °F) |

## Popover Details

Click the menu bar item to see:
- Detailed stats with progress bars
- Color-coded usage levels (green/yellow/red)
- Gear icon to access preferences
- Quit button

## Preferences

Access preferences via the gear icon in the popover:

- **Update Interval** - 1s, 2s, or 5s refresh rate
- **Show in Menu Bar** - Toggle CPU, GPU, RAM, Temperature visibility
- **Temperature Unit** - Celsius (°C) or Fahrenheit (°F)
- **Launch at Login** - Start automatically on login

## Requirements

- macOS 13.0+
- Xcode 15.0+ (for building)

## Building

1. Open `SysStats.xcodeproj` in Xcode
2. Select your development team for code signing
3. Build and run (⌘R)

## Distribution

For distribution builds with Hardened Runtime:

```bash
# Build release
./scripts/build-release.sh 1.0

# Create DMG
./scripts/create-dmg.sh 1.0
```

**Note:** Temperature reading requires the privileged helper to be signed with a Developer ID certificate for SMJobBless to work properly.

## Architecture

| Component | Description |
|-----------|-------------|
| `AppDelegate` | Status bar setup and Combine observation |
| `StatsManager` | Async metrics fetching with configurable interval |
| `SystemStats` | IOKit-based CPU, GPU, RAM, temperature reading |
| `PreferencesManager` | UserDefaults-backed settings with @Published properties |
| `SysStatsHelper` | Privileged helper for temperature access on Apple Silicon |

## License

MIT
