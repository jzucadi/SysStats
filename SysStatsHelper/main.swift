import Foundation
import IOKit

// MARK: - Platform Detection

func isAppleSilicon() -> Bool {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0)
        }
    }
    return machine?.contains("arm64") ?? false
}

// MARK: - Apple Silicon Temperature (IOReport)

class AppleSiliconTemperatureReader {

    func getTemperature() -> Double {
        // Try IOReport for thermal data on Apple Silicon
        if let temp = readIOReportThermal() {
            return temp
        }

        // Fallback: Try HID thermal sensors
        if let temp = readHIDThermal() {
            return temp
        }

        // Fallback: Try IOKit thermal sensors
        if let temp = readIOKitThermal() {
            return temp
        }

        return 0.0
    }

    private func readIOReportThermal() -> Double? {
        // IOReport channel for thermal
        guard let matching = IOServiceMatching("AppleARMIODevice") else { return nil }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var maxTemp: Double = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Look for temperature properties
            if let temp = props["Temperature"] as? Double, temp > 10 && temp < 120 {
                maxTemp = max(maxTemp, temp)
            }
        }

        return maxTemp > 0 ? maxTemp : nil
    }

    private func readHIDThermal() -> Double? {
        // Use IOHIDEventSystem for thermal events
        guard let matching = IOServiceMatching("AppleHIDThermalSensor") as? [String: Any] else {
            // Try alternative service names
            return readAlternativeHIDThermal()
        }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching as CFDictionary, &iterator) == KERN_SUCCESS else {
            return readAlternativeHIDThermal()
        }
        defer { IOObjectRelease(iterator) }

        var maxTemp: Double = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            if let temp = readTemperatureFromService(service) {
                maxTemp = max(maxTemp, temp)
            }
        }

        return maxTemp > 0 ? maxTemp : nil
    }

    private func readAlternativeHIDThermal() -> Double? {
        let serviceNames = [
            "AppleSocThermalSensor",
            "AppleM1ThermalSensor",
            "AppleM2ThermalSensor",
            "AppleM3ThermalSensor",
            "IOHIDEventDriver"
        ]

        var maxTemp: Double = 0

        for serviceName in serviceNames {
            guard let matching = IOServiceMatching(serviceName) else { continue }

            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }

                if let temp = readTemperatureFromService(service) {
                    maxTemp = max(maxTemp, temp)
                }
            }
        }

        return maxTemp > 0 ? maxTemp : nil
    }

    private func readTemperatureFromService(_ service: io_object_t) -> Double? {
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // Check various temperature property names
        let tempKeys = ["Temperature", "CurrentTemperature", "temperature", "temp", "die-temperature"]

        for key in tempKeys {
            if let temp = props[key] as? Double, temp > 10 && temp < 120 {
                return temp
            }
            if let temp = props[key] as? Int, temp > 10 && temp < 120 {
                return Double(temp)
            }
            // Some sensors report in centidegrees
            if let temp = props[key] as? Int, temp > 1000 && temp < 12000 {
                return Double(temp) / 100.0
            }
        }

        return nil
    }

    private func readIOKitThermal() -> Double? {
        // Query thermal zones via IOKit
        guard let matching = IOServiceMatching("IOPlatformExpertDevice") else { return nil }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        // Try to get thermal properties
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        // Look for any temperature-related values
        for (key, value) in props {
            if key.lowercased().contains("temp") || key.lowercased().contains("thermal") {
                if let temp = value as? Double, temp > 10 && temp < 120 {
                    return temp
                }
                if let temp = value as? Int, temp > 10 && temp < 120 {
                    return Double(temp)
                }
            }
        }

        return nil
    }
}

// MARK: - Intel SMC Temperature

class IntelSMCTemperatureReader {
    private var smcConnection: io_connect_t = 0

    struct SMCKeyData {
        struct Vers {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }

        struct LimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }

        struct KeyInfo {
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        var key: UInt32 = 0
        var vers = Vers()
        var pLimitData = LimitData()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private let kSMCHandleYieldKey: UInt32 = 2
    private let kSMCReadKey: UInt8 = 5
    private let kSMCGetKeyInfo: UInt8 = 9

    init() {
        openSMCConnection()
    }

    deinit {
        closeSMCConnection()
    }

    private func openSMCConnection() {
        let matchingDict = IOServiceMatching("AppleSMC")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result == KERN_SUCCESS {
            smcConnection = connection
        }
    }

    private func closeSMCConnection() {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
            smcConnection = 0
        }
    }

    private func fourCharCodeToUInt32(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }

    private func readSMCKey(_ key: String) -> Double? {
        guard smcConnection != 0 else { return nil }

        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        let keyCode = fourCharCodeToUInt32(key)
        inputStruct.key = keyCode
        inputStruct.data8 = kSMCGetKeyInfo

        var inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        let result1 = IOConnectCallStructMethod(
            smcConnection,
            kSMCHandleYieldKey,
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result1 == KERN_SUCCESS else { return nil }

        inputStruct.keyInfo.dataSize = outputStruct.keyInfo.dataSize
        inputStruct.keyInfo.dataType = outputStruct.keyInfo.dataType
        inputStruct.data8 = kSMCReadKey

        outputStruct = SMCKeyData()

        let result2 = IOConnectCallStructMethod(
            smcConnection,
            kSMCHandleYieldKey,
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result2 == KERN_SUCCESS else { return nil }

        let dataType = outputStruct.keyInfo.dataType
        let bytes = outputStruct.bytes
        let dataSize = outputStruct.keyInfo.dataSize

        // Handle flt (float) type
        if dataType == fourCharCodeToUInt32("flt ") && dataSize >= 4 {
            var floatValue: Float = 0
            withUnsafeMutableBytes(of: &floatValue) { ptr in
                ptr[0] = bytes.0
                ptr[1] = bytes.1
                ptr[2] = bytes.2
                ptr[3] = bytes.3
            }
            if floatValue < 0 || floatValue > 150 {
                withUnsafeMutableBytes(of: &floatValue) { ptr in
                    ptr[0] = bytes.3
                    ptr[1] = bytes.2
                    ptr[2] = bytes.1
                    ptr[3] = bytes.0
                }
            }
            return Double(floatValue)
        }

        // Handle sp78 (signed fixed-point 7.8)
        if dataType == fourCharCodeToUInt32("sp78") && dataSize >= 2 {
            let intValue = Int16(bytes.0) << 8 | Int16(bytes.1)
            return Double(intValue) / 256.0
        }

        // Handle fpe2 (unsigned fixed-point)
        if dataType == fourCharCodeToUInt32("fpe2") && dataSize >= 2 {
            let intValue = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            return Double(intValue) / 4.0
        }

        return nil
    }

    func getTemperature() -> Double {
        let keys = [
            "TC0P", "TC0H", "TC0D", "TC0E", "TC0F",
            "TC1C", "TC2C", "TC3C", "TC4C", "TC5C", "TC6C", "TC7C", "TC8C",
            "TCAD", "TCGC", "TCSA", "TCTD",
            "TG0P", "TG0D", "TG0H"
        ]

        for key in keys {
            if let temp = readSMCKey(key), temp > 10 && temp < 120 {
                return temp
            }
        }

        return 0.0
    }
}

// MARK: - Combined Temperature Reader

class TemperatureReader {
    private let appleSiliconReader = AppleSiliconTemperatureReader()
    private let intelReader = IntelSMCTemperatureReader()
    private let useAppleSilicon: Bool

    init() {
        useAppleSilicon = isAppleSilicon()
    }

    func getTemperature() -> Double {
        if useAppleSilicon {
            let temp = appleSiliconReader.getTemperature()
            if temp > 0 {
                return temp
            }
            // Fallback to SMC if IOKit methods fail
            return intelReader.getTemperature()
        } else {
            return intelReader.getTemperature()
        }
    }
}

// MARK: - XPC Service Delegate

class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = Helper()
        newConnection.resume()
        return true
    }
}

// MARK: - Helper Protocol Implementation

@objc class Helper: NSObject, HelperProtocol {
    private let temperatureReader = TemperatureReader()

    func getTemperature(completion: @escaping (Double) -> Void) {
        let temp = temperatureReader.getTemperature()
        completion(temp)
    }

    func getVersion(completion: @escaping (String) -> Void) {
        completion(HelperConstants.helperVersion)
    }

    func getPlatformInfo(completion: @escaping (String) -> Void) {
        let platform = isAppleSilicon() ? "Apple Silicon" : "Intel"
        completion(platform)
    }
}

// MARK: - Protocol Definition (must match main app)

@objc(HelperProtocol)
protocol HelperProtocol {
    func getTemperature(completion: @escaping (Double) -> Void)
    func getVersion(completion: @escaping (String) -> Void)
    func getPlatformInfo(completion: @escaping (String) -> Void)
}

struct HelperConstants {
    static let machServiceName = "com.example.SysStatsHelper"
    static let helperVersion = "1.0.1"
}

// MARK: - Main Entry Point

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
