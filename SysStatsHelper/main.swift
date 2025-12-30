import Foundation

// MARK: - SMC Structures (same as main app)

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

let kSMCHandleYieldKey: UInt32 = 2
let kSMCReadKey: UInt8 = 5
let kSMCGetKeyInfo: UInt8 = 9

// MARK: - SMC Temperature Reader

class SMCTemperatureReader {
    private var smcConnection: io_connect_t = 0

    init() {
        openSMCConnection()
    }

    deinit {
        closeSMCConnection()
    }

    private func openSMCConnection() {
        let serviceNames = ["AppleSMC", "AppleSMCFamily"]

        for serviceName in serviceNames {
            let matchingDict = IOServiceMatching(serviceName)
            var iterator: io_iterator_t = 0

            guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
                continue
            }

            let service = IOIteratorNext(iterator)
            IOObjectRelease(iterator)

            guard service != 0 else { continue }

            for clientType: UInt32 in 0...2 {
                var connection: io_connect_t = 0
                let result = IOServiceOpen(service, mach_task_self_, clientType, &connection)
                if result == KERN_SUCCESS && connection != 0 {
                    smcConnection = connection
                    IOObjectRelease(service)
                    return
                }
            }

            IOObjectRelease(service)
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
        let appleSiliconKeys = [
            "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b",
            "Tp0f", "Tp0j", "Tp0n", "Tp0r",
            "Tp02", "Tp06", "Tp0A", "Tp0E", "Tp0I", "Tp0M", "Tp0Q", "Tp0U", "Tp0Y", "Tp0c",
            "Tc0a", "Tc0b", "Tc0c", "Tc0d",
            "Ts0P", "Ts0S", "Ts1P", "Ts1S",
            "Tw0P", "TW0P"
        ]

        let intelKeys = [
            "TC0P", "TC0H", "TC0D", "TC0E", "TC0F",
            "TC1C", "TC2C", "TC3C", "TC4C", "TC5C", "TC6C", "TC7C", "TC8C",
            "TCAD", "TCGC", "TCSA", "TCTD"
        ]

        for key in appleSiliconKeys {
            if let temp = readSMCKey(key), temp > 10 && temp < 120 {
                return temp
            }
        }

        for key in intelKeys {
            if let temp = readSMCKey(key), temp > 10 && temp < 120 {
                return temp
            }
        }

        return 0.0
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
    private let temperatureReader = SMCTemperatureReader()

    func getTemperature(completion: @escaping (Double) -> Void) {
        let temp = temperatureReader.getTemperature()
        completion(temp)
    }

    func getVersion(completion: @escaping (String) -> Void) {
        completion(HelperConstants.helperVersion)
    }
}

// MARK: - Protocol Definition (must match main app)

@objc(HelperProtocol)
protocol HelperProtocol {
    func getTemperature(completion: @escaping (Double) -> Void)
    func getVersion(completion: @escaping (String) -> Void)
}

struct HelperConstants {
    static let machServiceName = "com.example.SysStatsHelper"
    static let helperVersion = "1.0.0"
}

// MARK: - Main Entry Point

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
