import Foundation
import Combine

struct SystemMetrics {
    let cpuUsage: Int
    let gpuUsage: Int
    let ramUsage: Int
    let temperature: Double

    var temperatureString: String {
        if temperature > 0 {
            return String(format: "%d°", Int(temperature))
        } else {
            return "—°"
        }
    }

    var statusBarText: String {
        return String(format: "C:%d%% G:%d%% R:%d%% %@", cpuUsage, gpuUsage, ramUsage, temperatureString)
    }
}

@MainActor
class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published private(set) var currentMetrics: SystemMetrics = SystemMetrics(
        cpuUsage: 0,
        gpuUsage: 0,
        ramUsage: 0,
        temperature: 0
    )

    private var updateTask: Task<Void, Never>?
    private let updateInterval: TimeInterval = 2.0

    private init() {}

    func startMonitoring() {
        stopMonitoring()

        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchAllMetrics()
                try? await Task.sleep(nanoseconds: UInt64(2_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }

    private func fetchAllMetrics() async {
        // Fetch all metrics concurrently using async let
        async let cpuTask = fetchCPUUsage()
        async let gpuTask = fetchGPUUsage()
        async let ramTask = fetchRAMUsage()
        async let tempTask = fetchTemperature()

        let (cpu, gpu, ram, temp) = await (cpuTask, gpuTask, ramTask, tempTask)

        currentMetrics = SystemMetrics(
            cpuUsage: cpu,
            gpuUsage: gpu,
            ramUsage: ram,
            temperature: temp
        )
    }

    // MARK: - Individual Metric Fetchers

    private func fetchCPUUsage() async -> Int {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let usage = Int(SystemStats.shared.getCPUUsage())
                continuation.resume(returning: usage)
            }
        }
    }

    private func fetchGPUUsage() async -> Int {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let usage = Int(SystemStats.shared.getGPUUsage())
                continuation.resume(returning: usage)
            }
        }
    }

    private func fetchRAMUsage() async -> Int {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let usage = Int(SystemStats.shared.getRAMUsage())
                continuation.resume(returning: usage)
            }
        }
    }

    private func fetchTemperature() async -> Double {
        return await withCheckedContinuation { continuation in
            // First trigger async update
            SystemStats.shared.updateTemperatureAsync()

            // Then get cached value (will be updated by next cycle)
            DispatchQueue.global(qos: .utility).async {
                let temp = SystemStats.shared.getCPUTemperature()
                continuation.resume(returning: temp)
            }
        }
    }
}
