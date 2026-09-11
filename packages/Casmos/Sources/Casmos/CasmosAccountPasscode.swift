import Foundation
import Security
import CommonCrypto

/// Result of checking a typed passcode against per-account and panic hashes.
public enum CasmosPasscodeMatch: Equatable {
    case none
    case panic
    case account(Int64)
}

/// Per-account passcode, hide-account, and panic storage.
/// Hashes live in the Keychain (this device only). Plaintext is never stored.
/// Hide / include-in-panic flags are local prefs. Session unlocks are in-memory.
public enum CasmosAccountPasscode {
    private static let keychainService = "app.casmos.macos.passcode"
    private static let accountKeyPrefix = "account."
    private static let panicAccount = "panic"
    private static let hidePrefix = "casmos.pref.passcode.account."
    private static let panicPresentKey = "casmos.pref.passcode.panic.present"
    private static let pbkdf2Rounds: UInt32 = 100_000
    private static let saltLength = 16
    private static let derivedLength = 32
    private static let payloadVersion: UInt8 = 1

    private static var sessionUnlocked = Set<Int64>()
    private static var panicActive = false
    private static let lock = NSLock()

    private static var defaults: UserDefaults { .standard }

    private static func hideKey(_ accountId: Int64) -> String {
        hidePrefix + "\(accountId).hide"
    }

    private static func panicIncludeKey(_ accountId: Int64) -> String {
        hidePrefix + "\(accountId).allowPanic"
    }

    private static func presentKey(_ accountId: Int64) -> String {
        hidePrefix + "\(accountId).present"
    }

    private static func accountKeychainAccount(_ accountId: Int64) -> String {
        accountKeyPrefix + "\(accountId)"
    }

    public static func hasPasscode(accountId: Int64) -> Bool {
        if keychainData(account: accountKeychainAccount(accountId)) != nil {
            return true
        }
        return defaults.bool(forKey: presentKey(accountId))
    }

    @discardableResult
    public static func setPasscode(_ passcode: String, accountId: Int64) -> Bool {
        guard let payload = hashed(passcode),
              setKeychainData(payload, account: accountKeychainAccount(accountId)) else {
            return false
        }
        defaults.set(true, forKey: presentKey(accountId))
        CasmosPreferences.notifyDidChange()
        return true
    }

    public static func removePasscode(accountId: Int64) {
        deleteKeychain(account: accountKeychainAccount(accountId))
        defaults.removeObject(forKey: hideKey(accountId))
        defaults.removeObject(forKey: panicIncludeKey(accountId))
        defaults.removeObject(forKey: presentKey(accountId))
        lock.lock()
        sessionUnlocked.remove(accountId)
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    public static func verify(_ passcode: String, accountId: Int64) -> Bool {
        guard let payload = keychainData(account: accountKeychainAccount(accountId)) else {
            return false
        }
        return check(passcode, payload: payload)
    }

    public static func isHidden(accountId: Int64) -> Bool {
        hasPasscode(accountId: accountId) && defaults.bool(forKey: hideKey(accountId))
    }

    public static func setHidden(_ hide: Bool, accountId: Int64) {
        guard hasPasscode(accountId: accountId) else {
            return
        }
        defaults.set(hide, forKey: hideKey(accountId))
        if hide {
            lock.lock()
            sessionUnlocked.remove(accountId)
            lock.unlock()
        }
        CasmosPreferences.notifyDidChange()
    }

    public static func isSessionUnlocked(accountId: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return sessionUnlocked.contains(accountId)
    }

    public static func unlockSession(accountId: Int64) {
        lock.lock()
        sessionUnlocked.insert(accountId)
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    public static func lockAllSessions() {
        lock.lock()
        sessionUnlocked.removeAll()
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    /// Hidden or panic-session accounts stay in the switcher while current or session-unlocked.
    public static func shouldHideFromSwitcher(accountId: Int64, currentId: Int64?) -> Bool {
        if currentId == accountId {
            return false
        }
        if isSessionUnlocked(accountId: accountId) {
            return false
        }
        if isHidden(accountId: accountId) {
            return true
        }
        lock.lock()
        let panicked = panicActive
        lock.unlock()
        return panicked && allowPanic(accountId: accountId) && hasPasscode(accountId: accountId)
    }

    public static func allowPanic(accountId: Int64) -> Bool {
        if defaults.object(forKey: panicIncludeKey(accountId)) == nil {
            return true
        }
        return defaults.bool(forKey: panicIncludeKey(accountId))
    }

    public static func setAllowPanic(_ allow: Bool, accountId: Int64) {
        defaults.set(allow, forKey: panicIncludeKey(accountId))
        CasmosPreferences.notifyDidChange()
    }

    public static func hasPanicPasscode() -> Bool {
        if keychainData(account: panicAccount) != nil {
            return true
        }
        return defaults.bool(forKey: panicPresentKey)
    }

    @discardableResult
    public static func setPanicPasscode(_ passcode: String) -> Bool {
        guard let payload = hashed(passcode),
              setKeychainData(payload, account: panicAccount) else {
            return false
        }
        defaults.set(true, forKey: panicPresentKey)
        CasmosPreferences.notifyDidChange()
        return true
    }

    public static func removePanicPasscode() {
        deleteKeychain(account: panicAccount)
        defaults.removeObject(forKey: panicPresentKey)
        lock.lock()
        panicActive = false
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    public static func verifyPanic(_ passcode: String) -> Bool {
        guard let payload = keychainData(account: panicAccount) else {
            return false
        }
        return check(passcode, payload: payload)
    }

    public static func knownAccountIds() -> [Int64] {
        var ids = Set<Int64>()
        let prefix = accountKeyPrefix
        for account in keychainAccounts() {
            guard account.hasPrefix(prefix), let id = Int64(String(account.dropFirst(prefix.count))) else {
                continue
            }
            ids.insert(id)
        }
        let presentSuffix = ".present"
        for key in defaults.dictionaryRepresentation().keys {
            guard key.hasPrefix(hidePrefix), key.hasSuffix(presentSuffix), defaults.bool(forKey: key) else {
                continue
            }
            let middle = String(key.dropFirst(hidePrefix.count).dropLast(presentSuffix.count))
            if let id = Int64(middle) {
                ids.insert(id)
            }
        }
        return Array(ids)
    }

    /// Accounts that hide or log out when panic runs.
    public static func panicAccountIds() -> [Int64] {
        knownAccountIds().filter { allowPanic(accountId: $0) && hasPasscode(accountId: $0) }
    }

    public static func match(_ passcode: String) -> CasmosPasscodeMatch {
        guard !passcode.isEmpty else {
            return .none
        }
        if hasPanicPasscode(), verifyPanic(passcode) {
            return .panic
        }
        for id in knownAccountIds() {
            if verify(passcode, accountId: id) {
                return .account(id)
            }
        }
        return .none
    }

    public static func runPanic() {
        lock.lock()
        sessionUnlocked.removeAll()
        panicActive = true
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    /// Reveal every known passcoded account for this process only. Caller must have passed LocalAuthentication.
    public static func revealHiddenSessions() {
        lock.lock()
        for id in knownAccountIds() {
            sessionUnlocked.insert(id)
        }
        panicActive = false
        lock.unlock()
        CasmosPreferences.notifyDidChange()
    }

    private static func hashed(_ passcode: String) -> Data? {
        let trimmed = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let passcodeData = trimmed.data(using: .utf8) else {
            return nil
        }
        var saltBytes = [UInt8](repeating: 0, count: saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard status == errSecSuccess else {
            return nil
        }
        guard let derived = pbkdf2(passcode: passcodeData, salt: Data(saltBytes), rounds: pbkdf2Rounds) else {
            return nil
        }
        var payload = Data()
        payload.append(payloadVersion)
        var roundsBE = pbkdf2Rounds.bigEndian
        payload.append(Data(bytes: &roundsBE, count: MemoryLayout<UInt32>.size))
        payload.append(contentsOf: saltBytes)
        payload.append(derived)
        return payload
    }

    private static func check(_ passcode: String, payload: Data) -> Bool {
        guard let passcodeData = passcode.data(using: .utf8) else {
            return false
        }
        let header = 1 + MemoryLayout<UInt32>.size
        guard payload.count == header + saltLength + derivedLength, payload[0] == payloadVersion else {
            return false
        }
        let rounds: UInt32 = {
            var value: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &value) { dest in
                payload.copyBytes(to: dest, from: 1..<header)
            }
            return UInt32(bigEndian: value)
        }()
        let salt = payload.subdata(in: header..<(header + saltLength))
        let expected = payload.subdata(in: (header + saltLength)..<payload.count)
        guard let computed = pbkdf2(passcode: passcodeData, salt: salt, rounds: rounds) else {
            return false
        }
        return timingSafeEqual(computed, expected)
    }

    private static func pbkdf2(passcode: Data, salt: Data, rounds: UInt32) -> Data? {
        var derived = [UInt8](repeating: 0, count: derivedLength)
        let result: Int32 = passcode.withUnsafeBytes { passPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passcode.count,
                    saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    &derived,
                    derived.count
                )
            }
        }
        guard result == kCCSuccess else {
            return nil
        }
        return Data(derived)
    }

    private static func timingSafeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        var diff: UInt8 = 0
        for i in 0..<lhs.count {
            diff |= lhs[i] ^ rhs[i]
        }
        return diff == 0
    }

    private static func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private static func keychainData(account: String) -> Data? {
        var query = keychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            return nil
        }
        return data
    }

    private static func setKeychainData(_ data: Data, account: String) -> Bool {
        deleteKeychain(account: account)
        var query = keychainQuery(account: account)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecValueData as String] = data
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private static func deleteKeychain(account: String) {
        let query = keychainQuery(account: account)
        SecItemDelete(query as CFDictionary)
    }

    private static func keychainAccounts() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
