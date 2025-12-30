import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func getTemperature(completion: @escaping (Double) -> Void)
    func getVersion(completion: @escaping (String) -> Void)
}

struct HelperConstants {
    static let machServiceName = "com.example.SysStatsHelper"
    static let helperVersion = "1.0.0"
}
