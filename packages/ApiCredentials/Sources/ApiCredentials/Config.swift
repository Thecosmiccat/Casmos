import Cocoa

public final class ApiEnvironment {
    /// Replace before building. Marker: CASMOS_PLACEHOLDER_API_ID
    public static var apiId:Int32 {
        return 0
    }
    public static var apiHash:String {
        return "CASMOS_PLACEHOLDER_API_HASH"
    }
    
    public static var bundleId: String {
        return "app.casmos.macos"
    }
    public static var intentsBundleId: String {
        return teamId + "." + bundleId + ".FocusIntents"
    }
    public static var teamId: String {
        // CASMOS_PLACEHOLDER_TEAM_ID — set to your 10-character Apple Team ID
        return "CASM0STEAM"
    }
    
    
    
    public static var containerURL: URL? {
        return resolvedContainerURL
    }

    private static let resolvedContainerURL: URL? = resolveApplicationSupportContainerURL()

    private static func applicationSupportCasmosRoot() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            NSLog("[Casmos] Application Support directory is unavailable")
            return nil
        }
        return base.appendingPathComponent("Casmos", isDirectory: true)
    }

    private static func resolveApplicationSupportContainerURL() -> URL? {
        guard let root = applicationSupportCasmosRoot() else {
            return nil
        }
        let url = root.appendingPathComponent(prefix, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        NSLog("[Casmos] Application Support basePath %@", url.path)
        return url
    }
    
    public static func migrate() {
        NSLog("[Casmos] migrate skipped")
    }
    
    public static var legacyContainerURL: URL? {
        return applicationSupportCasmosRoot()
    }
    
    public static var group: String {
        return teamId + "." + bundleId
    }
    
    public static var appData: Data {
        let apiData = evaluateApiData() ?? ""
        let dict:[String: String] = ["bundleId": bundleId, "data": apiData]
        return try! JSONSerialization.data(withJSONObject: dict, options: [])
    }
    public static var language: String {
        return "macos"
    }
    
    public static var prefixList:[String] {
        return ["debug", "stable", "appstore", "beta"]
    }
    
    public static var resolvedDeviceName:[String : String]? {
        if let file = Bundle.main.path(forResource: "mac_devices", ofType: "txt") {
            if let string = try? String(contentsOf: .init(fileURLWithPath: file)) {
                let lines = string.components(separatedBy: "\n\n")
                
                var result:[String : String] = [:]
                for line in lines {
                    let resolved = line.components(separatedBy: "\n")
                    if resolved.count == 2 {
                        result[resolved[1]] = resolved[0]
                    }
                }
                
                return result
            }
        }
        return nil
    }
    
    public static var prefix: String {
        var prefix: String = ""
        switch Configuration.value(for: .source) {
        case "DEBUG":
            prefix = "debug"
        case "STABLE":
            prefix = "stable"
        case "APP_STORE":
            prefix = "appstore"
        default:
            prefix = "beta"
        }
        return prefix
    }
    
    public static var version: String {
        var suffix: String = ""
        
        suffix = Configuration.value(for: .source) ?? "DEBUG"
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        return "\(shortVersion) \(suffix)"
    }
    
    public static var premiumProductId: String {
        return "org.telegram.telegramPremium.monthly"
    }
}



