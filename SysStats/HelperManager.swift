import Foundation
import ServiceManagement

class HelperManager {
    static let shared = HelperManager()

    private var helperConnection: NSXPCConnection?
    private var isHelperInstalled = false
    private let daemonService: SMAppService

    private init() {
        daemonService = SMAppService.daemon(plistName: "\(HelperConstants.machServiceName).plist")
        checkHelperInstallation()
    }

    // MARK: - Helper Installation

    func installHelper(completion: @escaping (Bool) -> Void) {
        Log.helper.info("Attempting to install privileged helper")

        do {
            try daemonService.register()
            Log.helper.info("Helper installed successfully")
            self.isHelperInstalled = true
            self.setupConnection()
            completion(true)
        } catch {
            Log.helper.error("Helper installation failed: \(error.localizedDescription)")
            completion(false)
        }
    }

    private func checkHelperInstallation() {
        Log.helper.debug("Checking helper installation status")

        // First check SMAppService status
        let status = daemonService.status
        Log.helper.debug("Daemon service status: \(String(describing: status))")

        guard status == .enabled else {
            Log.helper.debug("Helper service not enabled (status: \(String(describing: status)))")
            return
        }

        // Verify helper is actually running and has correct version
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.resume()

        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            Log.helper.debug("Helper not available: \(error.localizedDescription)")
        } as? HelperProtocol

        helper?.getVersion { [weak self] version in
            if version == HelperConstants.helperVersion {
                Log.helper.info("Helper found with matching version: \(version)")
                self?.isHelperInstalled = true
                self?.helperConnection = connection
            } else {
                Log.helper.warning("Helper version mismatch: expected \(HelperConstants.helperVersion), got \(version)")
                connection.invalidate()
            }
        }
    }

    // MARK: - Connection Management

    private func setupConnection() {
        helperConnection?.invalidate()

        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = { [weak self] in
            self?.helperConnection = nil
        }
        connection.resume()
        helperConnection = connection
    }

    // MARK: - Temperature Reading

    func getTemperature(completion: @escaping (Double) -> Void) {
        guard let connection = helperConnection else {
            // Try to setup connection if not available
            setupConnection()
            guard let conn = helperConnection else {
                completion(0.0)
                return
            }
            getTemperatureFromConnection(conn, completion: completion)
            return
        }

        getTemperatureFromConnection(connection, completion: completion)
    }

    private func getTemperatureFromConnection(_ connection: NSXPCConnection, completion: @escaping (Double) -> Void) {
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            completion(0.0)
        } as? HelperProtocol

        helper?.getTemperature { temp in
            completion(temp)
        }
    }

    var needsInstallation: Bool {
        return !isHelperInstalled
    }
}
