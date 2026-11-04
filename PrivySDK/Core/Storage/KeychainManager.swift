import Foundation
internal import FactoryKit

internal class KeychainManager {
    static fileprivate let logger: Logger = PrivyContainer.shared.logger()

    @discardableResult
    internal static func createOrUpdate(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary

        let status = SecItemAdd(query, nil)

        return switch status {
        case errSecSuccess:
            true
        case errSecDuplicateItem:
            // if item already exists in keychain, update it
            self.update(data, service: service, account: account)
        default:
            // error
            false
        }
    }

    @discardableResult
    internal static func update(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ] as CFDictionary

        let attributesToUpdate = [kSecValueData: data] as CFDictionary

        let status = SecItemUpdate(query, attributesToUpdate)
        return status.isSuccess()
    }

    @discardableResult
    internal static func read(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true,
        ] as CFDictionary

        var result: AnyObject?
        SecItemCopyMatching(query, &result)

        return (result as? Data)
    }

    @discardableResult
    internal static func delete(service: String, account: String) -> Bool {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary

        let status = SecItemDelete(query)
        return status.isSuccess()
    }
}

internal extension KeychainManager {
    static func createOrUpdate<T>(_ item: T, service: String, account: String) -> Bool where T: Codable {
        do {
            let data = try JSONEncoder().encode(item)
            return createOrUpdate(data, service: service, account: account)
        } catch {
            return false
        }
    }

    static func read<T>(service: String, account: String, type: T.Type) -> T? where T: Decodable {
        guard let data = read(service: service, account: account) else {
            return nil
        }

        do {
            let item = try JSONDecoder().decode(type, from: data)
            logger.debugInternal("Successfully read item (\(service), \(account)) from keychain")
            return item
        } catch {
            logger.debugInternal("Failed to read item (\(service), \(account)) from keychain")
            return nil
        }
    }
}

internal extension OSStatus {
    func isSuccess() -> Bool {
        return self == errSecSuccess
    }
}
