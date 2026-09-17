import Foundation

/// Local JPEG plus an optional wallpaper slug so other Casmos clients can fetch it.
/// Slug is hidden in the user's bio with Unicode tags. Official Telegram does not
/// treat it as a profile photo. Not a Casmos database.
public enum CasmosProfileBanners {
    public static let didChangeNotification = Notification.Name("casmos.profileBanner.didChange")
    public static let peerIdKey = "peerId"

    private static let tagLo: UInt32 = 0xE0000
    private static let tagHi: UInt32 = 0xE007F
    private static let slugPrefix = "c/"

    private static func folder() -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Casmos", isDirectory: true)
            .appendingPathComponent("profile-banners", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func fileURL(peerId: Int64) -> URL {
        folder().appendingPathComponent("\(peerId).jpg")
    }

    private static func slugURL(peerId: Int64) -> URL {
        folder().appendingPathComponent("\(peerId).slug")
    }

    public static func exists(peerId: Int64) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(peerId: peerId).path)
    }

    public static func data(peerId: Int64) -> Data? {
        try? Data(contentsOf: fileURL(peerId: peerId))
    }

    public static func savedSlug(peerId: Int64) -> String? {
        guard let data = try? Data(contentsOf: slugURL(peerId: peerId)),
              let slug = String(data: data, encoding: .utf8), !slug.isEmpty else {
            return nil
        }
        return slug
    }

    public static func save(_ data: Data, peerId: Int64, slug: String? = nil) {
        try? data.write(to: fileURL(peerId: peerId), options: .atomic)
        if let slug, !slug.isEmpty {
            try? Data(slug.utf8).write(to: slugURL(peerId: peerId), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: slugURL(peerId: peerId))
        }
        NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: [peerIdKey: peerId])
    }

    public static func setSlug(_ slug: String?, peerId: Int64) {
        if let slug, !slug.isEmpty {
            try? Data(slug.utf8).write(to: slugURL(peerId: peerId), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: slugURL(peerId: peerId))
        }
    }

    public static func remove(peerId: Int64) {
        try? FileManager.default.removeItem(at: fileURL(peerId: peerId))
        try? FileManager.default.removeItem(at: slugURL(peerId: peerId))
        NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: [peerIdKey: peerId])
    }

    public static func visibleAbout(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else {
            return ""
        }
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            if scalar.value < tagLo || scalar.value > tagHi {
                scalars.append(scalar)
            }
        }
        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func slug(fromAbout raw: String?) -> String? {
        guard let raw else {
            return nil
        }
        var bytes: [UInt8] = []
        for scalar in raw.unicodeScalars {
            let delta = Int(scalar.value) - Int(tagLo)
            if delta >= 32 && delta < 127 {
                bytes.append(UInt8(delta))
            }
        }
        guard let decoded = String(bytes: bytes, encoding: .ascii), decoded.hasPrefix(slugPrefix) else {
            return nil
        }
        let slug = String(decoded.dropFirst(slugPrefix.count))
        guard !slug.isEmpty, slug.unicodeScalars.allSatisfy({ scalar in
            let v = scalar.value
            return (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122) || v == 45 || v == 95
        }) else {
            return nil
        }
        return slug
    }

    public static func encodeSlug(_ slug: String) -> String {
        var scalars = String.UnicodeScalarView()
        for byte in (slugPrefix + slug).utf8 {
            if let scalar = UnicodeScalar(tagLo + UInt32(byte)) {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    public static func applyingSlug(_ slug: String?, to stored: String, limit: Int) -> String {
        let visible = visibleAbout(stored)
        guard let slug, !slug.isEmpty else {
            return visible
        }
        let encoded = encodeSlug(slug)
        if visible.count + encoded.count > limit {
            return visible
        }
        return visible + encoded
    }

    public static func mergingAbout(visible: String, stored: String, limit: Int) -> String {
        applyingSlug(slug(fromAbout: stored), to: visible, limit: limit)
    }
}
