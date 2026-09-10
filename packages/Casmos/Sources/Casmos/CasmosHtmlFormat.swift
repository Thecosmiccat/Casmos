import Foundation

/// A formatting span restored after HTML translate. `name` is bold / italic / underline /
/// strike / code / pre / url / mention / spoiler / quote.
public struct CasmosFormatSpan: Equatable {
    public let name: String
    public let start: Int
    public let end: Int
    public let extra: String?

    public init(name: String, start: Int, end: Int, extra: String? = nil) {
        self.name = name
        self.start = start
        self.end = end
        self.extra = extra
    }
}

public struct CasmosFormattedText: Equatable {
    public let text: String
    public let spans: [CasmosFormatSpan]

    public init(text: String, spans: [CasmosFormatSpan] = []) {
        self.text = text
        self.spans = spans
    }
}

/// Wrap / unwrap Telegram-style HTML so local translate engines can keep formatting.
public enum CasmosHtmlFormat {
    private struct TagPair {
        let open: String
        let close: String
        let name: String
        let extra: String?
    }

    public static func wrap(text: String, spans: [CasmosFormatSpan]) -> String {
        let ns = text as NSString
        let len = ns.length
        var opens: [Int: [(open: String, length: Int)]] = [:]
        var closes: [Int: [(close: String, length: Int)]] = [:]
        for span in spans {
            guard let tags = tags(for: span) else {
                continue
            }
            let start = max(0, min(span.start, len))
            let end = max(start, min(span.end, len))
            let length = end - start
            if length <= 0 {
                continue
            }
            opens[start, default: []].append((tags.open, length))
            closes[end, default: []].append((tags.close, length))
        }
        for key in opens.keys {
            opens[key]?.sort { $0.length > $1.length }
        }
        for key in closes.keys {
            closes[key]?.sort { $0.length < $1.length }
        }
        var result = ""
        var i = 0
        while i <= len {
            if let items = closes[i] {
                for item in items {
                    result += item.close
                }
            }
            if i == len {
                break
            }
            if let items = opens[i] {
                for item in items {
                    result += item.open
                }
            }
            let unit = ns.character(at: i)
            let step: Int
            if CFStringIsSurrogateHighCharacter(unit), i + 1 < len, CFStringIsSurrogateLowCharacter(ns.character(at: i + 1)) {
                step = 2
            } else {
                step = 1
            }
            result += escapeText(ns.substring(with: NSRange(location: i, length: step)))
            i += step
        }
        return result
    }

    public static func unwrap(_ html: String) -> CasmosFormattedText {
        let ns = html as NSString
        let len = ns.length
        var output = ""
        var outputLen = 0
        var spans: [CasmosFormatSpan] = []
        var stack: [(pair: TagPair, start: Int)] = []
        var i = 0
        while i < len {
            let ch = ns.character(at: i)
            if ch == 60 { // <
                let rest = ns.substring(from: i)
                if rest.hasPrefix("<!--") {
                    if let end = rest.range(of: "-->") {
                        i += rest.distance(from: rest.startIndex, to: end.upperBound)
                        continue
                    }
                }
                if let parsed = parseTag(ns, start: i, length: len) {
                    if parsed.isClose {
                        if let idx = stack.lastIndex(where: { $0.pair.name == parsed.name }) {
                            let opened = stack.remove(at: idx)
                            if outputLen > opened.start {
                                spans.append(CasmosFormatSpan(name: opened.pair.name, start: opened.start, end: outputLen, extra: opened.pair.extra))
                            }
                        }
                    } else if let pair = parsed.pair {
                        stack.append((pair, outputLen))
                    }
                    i = parsed.end
                    continue
                }
            }
            if ch == 38 { // &
                let rest = ns.substring(from: i)
                if rest.hasPrefix("&amp;") {
                    output += "&"
                    outputLen += 1
                    i += 5
                    continue
                }
                if rest.hasPrefix("&lt;") {
                    output += "<"
                    outputLen += 1
                    i += 4
                    continue
                }
                if rest.hasPrefix("&gt;") {
                    output += ">"
                    outputLen += 1
                    i += 4
                    continue
                }
                if rest.hasPrefix("&quot;") {
                    output += "\""
                    outputLen += 1
                    i += 6
                    continue
                }
                if rest.hasPrefix("&nbsp;") {
                    output += " "
                    outputLen += 1
                    i += 6
                    continue
                }
            }
            let step: Int
            if CFStringIsSurrogateHighCharacter(ch), i + 1 < len, CFStringIsSurrogateLowCharacter(ns.character(at: i + 1)) {
                step = 2
            } else {
                step = 1
            }
            output += ns.substring(with: NSRange(location: i, length: step))
            outputLen += step
            i += step
        }
        return CasmosFormattedText(text: output, spans: spans)
    }

    private static func tags(for span: CasmosFormatSpan) -> TagPair? {
        switch span.name {
        case "bold":
            return TagPair(open: "<b>", close: "</b>", name: "bold", extra: nil)
        case "italic":
            return TagPair(open: "<i>", close: "</i>", name: "italic", extra: nil)
        case "underline":
            return TagPair(open: "<u>", close: "</u>", name: "underline", extra: nil)
        case "strike":
            return TagPair(open: "<s>", close: "</s>", name: "strike", extra: nil)
        case "code":
            return TagPair(open: "<code>", close: "</code>", name: "code", extra: nil)
        case "spoiler":
            return TagPair(open: "<tg-spoiler>", close: "</tg-spoiler>", name: "spoiler", extra: nil)
        case "pre":
            if let language = span.extra, !language.isEmpty {
                return TagPair(open: "<pre lang=\"\(escapeAttr(language))\">", close: "</pre>", name: "pre", extra: language)
            }
            return TagPair(open: "<pre>", close: "</pre>", name: "pre", extra: nil)
        case "url":
            let href = span.extra ?? ""
            return TagPair(open: "<a href=\"\(escapeAttr(href))\">", close: "</a>", name: "url", extra: href)
        case "mention":
            let href = span.extra ?? ""
            return TagPair(open: "<a href=\"tg://user?id=\(escapeAttr(href))\">", close: "</a>", name: "mention", extra: href)
        case "quote":
            if span.extra == "1" {
                return TagPair(open: "<blockquote collapsed=\"1\">", close: "</blockquote>", name: "quote", extra: "1")
            }
            return TagPair(open: "<blockquote>", close: "</blockquote>", name: "quote", extra: span.extra)
        default:
            return nil
        }
    }

    private struct ParsedTag {
        let end: Int
        let isClose: Bool
        let name: String
        let pair: TagPair?
    }

    private static func parseTag(_ ns: NSString, start: Int, length: Int) -> ParsedTag? {
        guard start < length, ns.character(at: start) == 60 else {
            return nil
        }
        var j = start + 1
        guard j < length else {
            return nil
        }
        var isClose = false
        if ns.character(at: j) == 47 { // /
            isClose = true
            j += 1
        }
        let nameStart = j
        while j < length {
            let c = ns.character(at: j)
            if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45 {
                j += 1
            } else {
                break
            }
        }
        if j == nameStart {
            return nil
        }
        let rawName = ns.substring(with: NSRange(location: nameStart, length: j - nameStart)).lowercased()
        var attrs = ""
        while j < length {
            let c = ns.character(at: j)
            if c == 62 { // >
                j += 1
                break
            }
            if c == 47, j + 1 < length, ns.character(at: j + 1) == 62 {
                j += 2
                break
            }
            attrs += ns.substring(with: NSRange(location: j, length: 1))
            j += 1
        }
        let mapped = mapTag(rawName, attrs: attrs)
        if isClose {
            return ParsedTag(end: j, isClose: true, name: mapped?.name ?? rawName, pair: mapped)
        }
        if mapped == nil {
            return ParsedTag(end: j, isClose: false, name: rawName, pair: nil)
        }
        return ParsedTag(end: j, isClose: false, name: mapped!.name, pair: mapped)
    }

    private static func mapTag(_ raw: String, attrs: String) -> TagPair? {
        switch raw {
        case "b", "strong":
            return TagPair(open: "<b>", close: "</b>", name: "bold", extra: nil)
        case "i", "em":
            return TagPair(open: "<i>", close: "</i>", name: "italic", extra: nil)
        case "u":
            return TagPair(open: "<u>", close: "</u>", name: "underline", extra: nil)
        case "s", "strike", "del":
            return TagPair(open: "<s>", close: "</s>", name: "strike", extra: nil)
        case "code":
            return TagPair(open: "<code>", close: "</code>", name: "code", extra: nil)
        case "tg-spoiler":
            return TagPair(open: "<tg-spoiler>", close: "</tg-spoiler>", name: "spoiler", extra: nil)
        case "pre":
            let language = attr(attrs, name: "lang")
            return TagPair(open: "<pre>", close: "</pre>", name: "pre", extra: language)
        case "blockquote":
            let collapsed = attr(attrs, name: "collapsed") == "1" ? "1" : nil
            return TagPair(open: "<blockquote>", close: "</blockquote>", name: "quote", extra: collapsed)
        case "a":
            let href = attr(attrs, name: "href") ?? ""
            if href.hasPrefix("tg://user?id=") {
                let extra = String(href.dropFirst("tg://user?id=".count))
                return TagPair(open: "<a>", close: "</a>", name: "mention", extra: extra)
            }
            return TagPair(open: "<a>", close: "</a>", name: "url", extra: href)
        default:
            return nil
        }
    }

    private static func attr(_ raw: String, name: String) -> String? {
        let pattern = name + "=\""
        guard let range = raw.range(of: pattern, options: .caseInsensitive) else {
            return nil
        }
        let rest = raw[range.upperBound...]
        if let end = rest.firstIndex(of: "\"") {
            let value = String(rest[..<end])
            return unescapeAttr(value)
        }
        return nil
    }

    private static func escapeText(_ text: String) -> String {
        var result = ""
        for ch in text {
            switch ch {
            case "&":
                result += "&amp;"
            case "<":
                result += "&lt;"
            case ">":
                result += "&gt;"
            default:
                result.append(ch)
            }
        }
        return result
    }

    private static func escapeAttr(_ text: String) -> String {
        var result = escapeText(text)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }

    private static func unescapeAttr(_ text: String) -> String {
        text.replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
