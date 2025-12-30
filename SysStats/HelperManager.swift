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
        var authRef: AuthorizationRef?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: nil, flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

        let status = AuthorizationCreate(&authRights, nil, authFlags, &authRef)

        guard status == errAuthorizationSuccess, let authorization = authRef else {
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
            isHelperInstalled = true
            setupConnection()
        }

        completion(success)
    }

    private func checkHelperInstallation() {
        // Try to connect to see if helper is already installed
        let connection = NSXPCConnection(machServiceName: HelperConstants.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.resume()

        let helper = connection.remoteObjectProxyWithErrorHandler { _ in
            // Helper not installed or not responding
        } as? HelperProtocol

        helper?.getVersion { [weak self] version in
            if version == HelperConstants.helperVersion {
                self?.isHelperInstalled = true
                self?.helperConnection = connection
            } else {
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
