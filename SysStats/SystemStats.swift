import Foundation

class SystemStats {
    static let shared = SystemStats()

    private var previousCPUInfo: host_cpu_load_info?

    private init() {}

    func getCPUUsage() -> Double {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0.0
        }

        let currentUser = cpuLoadInfo.cpu_ticks.0
        let currentSystem = cpuLoadInfo.cpu_ticks.1
        let currentIdle = cpuLoadInfo.cpu_ticks.2
        let currentNice = cpuLoadInfo.cpu_ticks.3

        defer {
            previousCPUInfo = cpuLoadInfo
        }

        guard let previous = previousCPUInfo else {
            return 0.0
        }

        let previousUser = previous.cpu_ticks.0
        let previousSystem = previous.cpu_ticks.1
        let previousIdle = previous.cpu_ticks.2
        let previousNice = previous.cpu_ticks.3

        let userDelta = currentUser - previousUser
        let systemDelta = currentSystem - previousSystem
        let idleDelta = currentIdle - previousIdle
        let niceDelta = currentNice - previousNice

        let totalTicks = userDelta + systemDelta + idleDelta + niceDelta

        guard totalTicks > 0 else {
            return 0.0
        }

        let usedTicks = userDelta + systemDelta + niceDelta
        let cpuUsage = (Double(usedTicks) / Double(totalTicks)) * 100.0

        return cpuUsage
    }

    func getRAMUsage() -> Double {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0.0
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let totalRAM = UInt64(ProcessInfo.processInfo.physicalMemory)

        let activeMemory = UInt64(vmStats.active_count) * pageSize
        let wiredMemory = UInt64(vmStats.wire_count) * pageSize
        let compressedMemory = UInt64(vmStats.compressor_page_count) * pageSize

        let usedMemory = activeMemory + wiredMemory + compressedMemory
        let ramUsage = (Double(usedMemory) / Double(totalRAM)) * 100.0

        return ramUsage
    }
}
