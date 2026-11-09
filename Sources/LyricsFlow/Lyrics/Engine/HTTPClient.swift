import Foundation

enum HTTPClient {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 6
        c.timeoutIntervalForResource = 10
        return URLSession(configuration: c)
    }()

    static let browserUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    /// Percent-encodes like Python's urlencode (a literal "+" in a title must become %2B).
    static func query(_ items: [(String, String)]) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        return items.map { "\(enc($0.0))=\(enc($0.1))" }.joined(separator: "&")
    }

    static func json(_ base: String, _ params: [(String, String)], headers: [String: String] = [:]) async -> [String: Any]? {
        guard let url = URL(string: base + "?" + query(params)) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(browserUA, forHTTPHeaderField: "User-Agent")
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (data, _) = try? await session.data(for: req) else { return nil }
        return parse(data)
    }

    /// Tolerates JSONP wrappers such as `callback({...})`.
    static func parse(_ data: Data) -> [String: Any]? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { return obj }
        guard let text = String(data: data, encoding: .utf8),
              let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"), a < b,
              let inner = text[a...b].data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: inner) as? [String: Any]
    }
}

func asString(_ v: Any?) -> String {
    switch v {
    case let s as String: return s
    case let n as NSNumber: return n.stringValue
    default: return ""
    }
}

func asDouble(_ v: Any?) -> Double {
    switch v {
    case let n as NSNumber: return n.doubleValue
    case let s as String: return Double(s) ?? 0
    default: return 0
    }
}
