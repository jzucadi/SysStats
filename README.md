# SysStats
<img width="479" height="33" alt="Screenshot 2025-12-30 at 6 12 42 PM" src="https://github.com/user-attachments/assets/c3de50dd-53b1-45d7-90e2-a19692824f7e" />

A lightweight macOS menu bar application that displays real-time system statistics directly in your status bar.

## Features

- **Menu bar only** - No dock icon, no main window, stays out of your way
- **Real-time monitoring** - Displays CPU, GPU, RAM usage and temperature
- **Auto-refresh** - Updates every 2 seconds
- **SwiftUI popover** - Click for additional details

## Display Format

```
C:45% G:30% R:62% 52°
```

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
