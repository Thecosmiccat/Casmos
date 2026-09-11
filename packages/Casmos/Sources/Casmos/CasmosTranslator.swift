import Foundation

/// Result of a local Casmos translator engine (not the official path).
public struct CasmosTranslationResult {
    public let detect: String?
    public let text: String

    public init(detect: String?, text: String) {
        self.detect = detect
        self.text = text
    }
}

public enum CasmosTranslatorError: Error {
    case unsupportedEngine
    case network
    case parse
    case missingKey
}

/// Structured local translation for polls and todo lists (question + options).
public struct CasmosMediaTranslation {
    public let text: String
    public let additional: [String]
    public let solution: String?

    public init(text: String, additional: [String], solution: String? = nil) {
        self.text = text
        self.additional = additional
        self.solution = solution
    }
}

/// In-memory translations produced by local engines (yandex / deepl / extra).
/// Chat rows read this when the official translation attribute is absent.
public enum CasmosLocalTranslations {
    private static let lock = NSLock()
    private static var texts: [String: String] = [:]
    private static var media: [String: CasmosMediaTranslation] = [:]

    public static func key(peerId: Int64, namespace: Int32, id: Int32) -> String {
        "\(peerId).\(namespace).\(id)"
    }

    private static func storageKey(_ key: String, toLang: String) -> String {
        "\(key)|\(toLang)"
    }

    private static var formatted: [String: CasmosFormattedText] = [:]

    public static func set(key: String, toLang: String, text: String, spans: [CasmosFormatSpan] = []) {
        lock.lock()
        let storage = storageKey(key, toLang: toLang)
        texts[storage] = text
        if spans.isEmpty {
            formatted.removeValue(forKey: storage)
        } else {
            formatted[storage] = CasmosFormattedText(text: text, spans: spans)
        }
        lock.unlock()
    }

    public static func setMedia(key: String, toLang: String, value: CasmosMediaTranslation) {
        lock.lock()
        let storage = storageKey(key, toLang: toLang)
        media[storage] = value
        texts[storage] = value.text
        lock.unlock()
    }

    public static func text(for key: String, toLang: String) -> String? {
        lock.lock()
        let value = texts[storageKey(key, toLang: toLang)]
        lock.unlock()
        return value
    }

    public static func formatted(for key: String, toLang: String) -> CasmosFormattedText? {
        lock.lock()
        let value = formatted[storageKey(key, toLang: toLang)]
        lock.unlock()
        return value
    }

    public static func media(for key: String, toLang: String) -> CasmosMediaTranslation? {
        lock.lock()
        let value = media[storageKey(key, toLang: toLang)]
        lock.unlock()
        return value
    }

    public static func contains(key: String, toLang: String) -> Bool {
        text(for: key, toLang: toLang) != nil || media(for: key, toLang: toLang) != nil
    }
}

/// Local translation engines. `system` and `extra` are routed elsewhere.
public enum CasmosTranslator {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    public static func translate(text: String, from: String?, to: String, html: Bool = false, engine: CasmosTranslatorEngine = CasmosPreferences.translatorEngine, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask? {
        switch engine {
        case .yandex:
            return translateYandex(text: text, from: from, to: to, html: html, completion: completion)
        case .deepl:
            return translateDeepl(text: text, from: from, to: to, html: html, completion: completion)
        case .system, .extra:
            completion(.failure(CasmosTranslatorError.unsupportedEngine))
            return nil
        }
    }

    private static func normalize(_ code: String) -> String {
        var value = code.lowercased()
        if value == "nb" {
            value = "no"
        }
        if value == "pt-br" {
            return "pt"
        }
        if value.hasPrefix("zh") {
            return "zh"
        }
        if let first = value.split(separator: "-").first {
            return String(first)
        }
        return value
    }

    private static func deeplCode(_ code: String) -> String {
        let value = normalize(code).uppercased()
        if value == "ZH" {
            return "ZH"
        }
        if value == "EN" {
            return "EN"
        }
        if value == "PT" {
            return "PT"
        }
        return value
    }

    private static func translateYandex(text: String, from: String?, to: String, html: Bool, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask? {
        let target = normalize(to)
        let lang: String
        if let from = from, !from.isEmpty, from != "auto" {
            lang = "\(normalize(from))-\(target)"
        } else {
            lang = target
        }
        var components = URLComponents(string: "https://translate.yandex.net/api/v1/tr.json/translate")
        components?.queryItems = [
            URLQueryItem(name: "id", value: "\(UUID().uuidString.lowercased())-0-0"),
            URLQueryItem(name: "srv", value: "android"),
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "format", value: html ? "html" : "plain")
        ]
        guard let url = components?.url else {
            completion(.failure(CasmosTranslatorError.network))
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        request.httpBody = "text=\(encoded)".data(using: .utf8)
        return dataTask(request: request) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return .failure(CasmosTranslatorError.parse)
            }
            let parts = json["text"] as? [String]
            let joined = parts?.joined() ?? ""
            if joined.isEmpty {
                return .failure(CasmosTranslatorError.parse)
            }
            let detected = (json["lang"] as? String)?.split(separator: "-").first.map(String.init)
            return .success(CasmosTranslationResult(detect: detected, text: joined))
        } completion: { result in
            completion(result)
        }
    }

    private static func translateDeepl(text: String, from: String?, to: String, html: Bool, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask? {
        let key = CasmosPreferences.deeplKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if CasmosPreferences.hasLiveDeeplKey {
            return translateDeeplOfficial(text: text, from: from, to: to, key: key, html: html, completion: completion)
        }
        return translateDeeplWeb(text: text, from: from, to: to, completion: completion)
    }

    private static func translateDeeplOfficial(text: String, from: String?, to: String, key: String, html: Bool, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask? {
        guard let url = URL(string: "https://api-free.deepl.com/v2/translate") else {
            completion(.failure(CasmosTranslatorError.network))
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(key)", forHTTPHeaderField: "Authorization")
        var body = "text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text)&target_lang=\(deeplCode(to))"
        if html {
            body += "&tag_handling=html"
        }
        if let from = from, !from.isEmpty, from != "auto" {
            body += "&source_lang=\(deeplCode(from))"
        }
        request.httpBody = body.data(using: .utf8)
        return dataTask(request: request) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let translations = json["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translated = first["text"] as? String,
                  !translated.isEmpty else {
                return .failure(CasmosTranslatorError.parse)
            }
            let detect = first["detected_source_language"] as? String
            return .success(CasmosTranslationResult(detect: detect?.lowercased(), text: translated))
        } completion: { result in
            completion(result)
        }
    }

    private static func translateDeeplWeb(text: String, from: String?, to: String, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask? {
        guard let url = URL(string: "https://www2.deepl.com/jsonrpc") else {
            completion(.failure(CasmosTranslatorError.missingKey))
            return nil
        }
        let requestId = Int.random(in: 100_000..<1_000_000)
        let source = (from == nil || from == "auto" || from?.isEmpty == true) ? "auto" : deeplCode(from ?? "auto")
        var iCount = 0
        for ch in text where ch == "i" {
            iCount += 1
        }
        var timestamp = Int(Date().timeIntervalSince1970 * 1000)
        if iCount > 0 {
            timestamp = timestamp - (timestamp % iCount) + iCount
        }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "LMT_handle_texts",
            "id": requestId,
            "params": [
                "texts": [["text": text, "requestAlternatives": 0]],
                "splitting": "newlines",
                "lang": [
                    "source_lang_user_selected": source,
                    "target_lang": deeplCode(to)
                ],
                "timestamp": timestamp
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(CasmosTranslatorError.parse))
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.deepl.com/translator", forHTTPHeaderField: "Referer")
        request.httpBody = body
        return dataTask(request: request) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let resultObj = json["result"] as? [String: Any],
                  let texts = resultObj["texts"] as? [[String: Any]],
                  let translated = texts.first?["text"] as? String,
                  !translated.isEmpty else {
                return .failure(CasmosTranslatorError.parse)
            }
            let detect = resultObj["lang"] as? String
            return .success(CasmosTranslationResult(detect: detect?.lowercased(), text: translated))
        } completion: { result in
            completion(result)
        }
    }

    private static func dataTask(request: URLRequest, parse: @escaping (Data) -> Result<CasmosTranslationResult, Error>, completion: @escaping (Result<CasmosTranslationResult, Error>) -> Void) -> URLSessionDataTask {
        let task = session.dataTask(with: request) { data, _, error in
            if error != nil {
                completion(.failure(CasmosTranslatorError.network))
                return
            }
            guard let data = data else {
                completion(.failure(CasmosTranslatorError.network))
                return
            }
            completion(parse(data))
        }
        task.resume()
        return task
    }
}
