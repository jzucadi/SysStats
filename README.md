# SysStats
<img width="485" height="36" alt="Screenshot 2025-12-30 at 6 18 06 PM" src="https://github.com/user-attachments/assets/f85068d6-02d0-4667-a0d5-960874b6cfb6" />

A lightweight macOS menu bar application that displays real-time system statistics directly in your status bar.

## Features

- **Menu bar only** - No dock icon, no main window, stays out of your way
- **Real-time monitoring** - Displays CPU, GPU, RAM usage and temperature
- **Auto-refresh** - Updates every 2 seconds
- **SwiftUI popover** - Click for additional details

## Display Format

<img width="164" height="33" alt="Screenshot 2025-12-31 at 1 40 06 PM" src="https://github.com/user-attachments/assets/7e4de76b-d575-42f7-b0dc-96add4952f79" />

- **C** - CPU usage percentage
- **G** - GPU usage percentage
- **R** - RAM usage percentage
- **°** - Temperature in Celsius

## Requirements

- macOS 13.0+
- Xcode 15.0+ (for building)

## Building

1. Open `SysStats.xcodeproj` in Xcode
2. Select your development team for code signing
3. Build and run (⌘R)

## License

MIT
