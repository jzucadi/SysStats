import Foundation
import ServiceManagement
import Security

class HelperManager {
    static let shared = HelperManager()

    private var helperConnection: NSXPCConnection?
    private var isHelperInstalled = false

    private init() {
        checkHelperInstallation()
    }

    // MARK: - Helper Installation

    func installHelper(completion: @escaping (Bool) -> Void) {
        Log.helper.info("Attempting to install privileged helper")

        kSMRightBlessPrivilegedHelper.withCString { cString in
            var authRef: AuthorizationRef?
            var authItem = AuthorizationItem(name: cString, valueLength: 0, value: nil, flags: 0)
            var authRights = AuthorizationRights(count: 1, items: &authItem)
            let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

            let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)

            guard status == errAuthorizationSuccess, let authorization = authRef else {
                Log.helper.error("Failed to create authorization: \(status)")
                completion(false)
                return
            }

            var error: Unmanaged<CFError>?
            let success = SMJobBless(
                kSMDomainSystemLaunchd,
                HelperConstants.machServiceName as CFString,
                authorization,
                &error
            )

            AuthorizationFree(authorization, [])

            if success {
                Log.helper.info("Helper installed successfully")
                self.isHelperInstalled = true
                self.setupConnection()
            } else if let cfError = error?.takeRetainedValue() {
                Log.helper.error("Helper installation failed: \(cfError)")
            }

            completion(success)
        }
    }

    private func checkHelperInstallation() {
        Log.helper.debug("Checking helper installation status")

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
