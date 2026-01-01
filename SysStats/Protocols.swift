import Foundation

// MARK: - System Stats Protocol

protocol SystemStatsProtocol {
    func getCPUUsage() -> Double
    func getRAMUsage() -> Double
    func getGPUUsage() -> Double
    func getCPUTemperature() -> Double
    func updateTemperatureAsync()
}

// MARK: - Preferences Protocol

protocol PreferencesProtocol: AnyObject {
    var updateInterval: UpdateInterval { get set }
    var showCPU: Bool { get set }
    var showGPU: Bool { get set }
    var showRAM: Bool { get set }
    var showTemperature: Bool { get set }
    var temperatureUnit: TemperatureUnit { get set }
    var launchAtLogin: Bool { get set }
}

// MARK: - Helper Manager Protocol

protocol HelperManagerProtocol {
    var needsInstallation: Bool { get }
    func installHelper(completion: @escaping (Bool) -> Void)
    func getTemperature(completion: @escaping (Double) -> Void)
}

// MARK: - Protocol Conformance Extensions

extension SystemStats: SystemStatsProtocol {}
extension PreferencesManager: PreferencesProtocol {}
extension HelperManager: HelperManagerProtocol {}
