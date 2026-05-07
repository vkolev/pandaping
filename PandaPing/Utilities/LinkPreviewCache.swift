import Foundation

struct LinkMetadata: Sendable {
    let url: URL
    let title: String?
    let description: String?
    let imageURL: URL?
    let faviconURL: URL?
    let isDirectImage: Bool
}

actor LinkPreviewCache {
    static let shared = LinkPreviewCache()

    private var cache: [URL: LinkMetadata] = [:]
    private var inFlight: [URL: Task<LinkMetadata, Never>] = [:]

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "ico"
    ]

    func fetch(_ url: URL) async -> LinkMetadata {
        if let cached = cache[url] {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<LinkMetadata, Never> {
            await Self.fetchMetadata(for: url)
        }
        inFlight[url] = task
        let result = await task.value
        cache[url] = result
        inFlight.removeValue(forKey: url)
        return result
    }

    // MARK: - Metadata Fetching

    private nonisolated static func fetchMetadata(for url: URL) async -> LinkMetadata {
        let ext = url.pathExtension.lowercased()
        if imageExtensions.contains(ext) {
            return LinkMetadata(url: url, title: nil, description: nil, imageURL: url, faviconURL: nil, isDirectImage: true)
        }

        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               contentType.lowercased().hasPrefix("image/") {
                return LinkMetadata(url: url, title: nil, description: nil, imageURL: url, faviconURL: nil, isDirectImage: true)
            }

            let limitedData = data.prefix(65536)
            guard let html = String(data: limitedData, encoding: .utf8)
                    ?? String(data: limitedData, encoding: .ascii) else {
                return fallbackMetadata(for: url)
            }

            let title = parseMetaContent(html: html, attr: "property", value: "og:title")
                ?? parseMetaContent(html: html, attr: "name", value: "twitter:title")
                ?? parseHTMLTitle(html: html)

            let description = parseMetaContent(html: html, attr: "property", value: "og:description")
                ?? parseMetaContent(html: html, attr: "name", value: "twitter:description")
                ?? parseMetaContent(html: html, attr: "name", value: "description")

            let imageString = parseMetaContent(html: html, attr: "property", value: "og:image")
                ?? parseMetaContent(html: html, attr: "name", value: "twitter:image")
            let imageURL = imageString.flatMap { resolveURL($0, base: url) }

            let favicon = parseFaviconLink(html: html, base: url) ?? defaultFaviconURL(for: url)

            return LinkMetadata(
                url: url,
                title: title,
                description: description,
                imageURL: imageURL,
                faviconURL: favicon,
                isDirectImage: false
            )
        } catch {
            return fallbackMetadata(for: url)
        }
    }

    private nonisolated static func fallbackMetadata(for url: URL) -> LinkMetadata {
        LinkMetadata(url: url, title: nil, description: nil, imageURL: nil, faviconURL: defaultFaviconURL(for: url), isDirectImage: false)
    }

    // MARK: - HTML Parsing

    private nonisolated static func parseMetaContent(html: String, attr: String, value: String) -> String? {
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        let patterns = [
            "<meta[^>]*\(attr)\\s*=\\s*[\"']\(escapedValue)[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"']",
            "<meta[^>]*content\\s*=\\s*[\"']([^\"']*)[\"'][^>]*\(attr)\\s*=\\s*[\"']\(escapedValue)[\"']"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let text = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : decodeHTMLEntities(text)
            }
        }
        return nil
    }

    private nonisolated static func parseHTMLTitle(html: String) -> String? {
        let pattern = "<title[^>]*>([^<]*)</title>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            let text = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : decodeHTMLEntities(text)
        }
        return nil
    }

    private nonisolated static func parseFaviconLink(html: String, base: URL) -> URL? {
        let patterns = [
            #"<link[^>]*rel\s*=\s*["'](?:shortcut )?icon["'][^>]*href\s*=\s*["']([^"']*)["']"#,
            #"<link[^>]*href\s*=\s*["']([^"']*)["'][^>]*rel\s*=\s*["'](?:shortcut )?icon["']"#,
            #"<link[^>]*rel\s*=\s*["']apple-touch-icon["'][^>]*href\s*=\s*["']([^"']*)["']"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let href = String(html[range])
                return resolveURL(href, base: base)
            }
        }
        return nil
    }

    // MARK: - URL Helpers

    private nonisolated static func defaultFaviconURL(for url: URL) -> URL? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        return URL(string: "\(scheme)://\(host)/favicon.ico")
    }

    private nonisolated static func resolveURL(_ string: String, base: URL) -> URL? {
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string)
        }
        if string.hasPrefix("//") {
            return URL(string: (base.scheme ?? "https") + ":" + string)
        }
        return URL(string: string, relativeTo: base)?.absoluteURL
    }

    private nonisolated static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&#x27;", "'"), ("&nbsp;", " "), ("&#x2F;", "/"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
