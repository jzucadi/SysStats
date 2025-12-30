import Foundation
import ServiceManagement
import Combine

enum UpdateInterval: Double, CaseIterable {
    case one = 1.0
    case two = 2.0
    case five = 5.0

    var label: String {
        switch self {
        case .one: return "1s"
        case .two: return "2s"
        case .five: return "5s"
        }
    }
}

enum TemperatureUnit: String, CaseIterable {
    case celsius = "C"
    case fahrenheit = "F"

    var label: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let updateInterval = "updateInterval"
        static let showCPU = "showCPU"
        static let showGPU = "showGPU"
        static let showRAM = "showRAM"
        static let showTemperature = "showTemperature"
        static let temperatureUnit = "temperatureUnit"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var updateInterval: UpdateInterval {
        didSet {
            defaults.set(updateInterval.rawValue, forKey: Keys.updateInterval)
        }
    }

    @Published var showCPU: Bool {
        didSet {
            defaults.set(showCPU, forKey: Keys.showCPU)
        }
    }

    @Published var showGPU: Bool {
        didSet {
            defaults.set(showGPU, forKey: Keys.showGPU)
        }
    }

    @Published var showRAM: Bool {
        didSet {
            defaults.set(showRAM, forKey: Keys.showRAM)
        }
    }

    @Published var showTemperature: Bool {
        didSet {
            defaults.set(showTemperature, forKey: Keys.showTemperature)
        }
    }

    @Published var temperatureUnit: TemperatureUnit {
        didSet {
            defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    private init() {
        // Load saved values or use defaults
        let savedInterval = defaults.double(forKey: Keys.updateInterval)
        self.updateInterval = UpdateInterval(rawValue: savedInterval) ?? .two

        // Default to true for all stats if not set
        self.showCPU = defaults.object(forKey: Keys.showCPU) == nil ? true : defaults.bool(forKey: Keys.showCPU)
        self.showGPU = defaults.object(forKey: Keys.showGPU) == nil ? true : defaults.bool(forKey: Keys.showGPU)
        self.showRAM = defaults.object(forKey: Keys.showRAM) == nil ? true : defaults.bool(forKey: Keys.showRAM)
        self.showTemperature = defaults.object(forKey: Keys.showTemperature) == nil ? true : defaults.bool(forKey: Keys.showTemperature)

        let savedUnit = defaults.string(forKey: Keys.temperatureUnit) ?? "C"
        self.temperatureUnit = TemperatureUnit(rawValue: savedUnit) ?? .celsius

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }

    private func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // SMAppService requires the app to be properly code-signed
                // This will fail in development builds but work in signed releases
                #if DEBUG
                print("Launch at login requires code-signed app (expected in development)")
                #endif
            }
        }
    }

    func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            launchAtLogin = (status == .enabled)
        }
    }
}
