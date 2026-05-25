import Foundation
import WebKit

/// 文章正文抽取: WKWebView 加载 URL, 等 didFinish, 注入 Mozilla Readability.js, evaluateJavaScript 拿结果。
/// 这是 v0 选择的 "最稳但稍慢" 方案 (按 design doc Q2)。
@MainActor
final class ArticleExtractor: NSObject {
    static let shared = ArticleExtractor()

    struct Extracted {
        let url: String
        let title: String
        let byline: String
        let textContent: String
        let excerpt: String
    }

    enum ExtractError: LocalizedError {
        case invalidURL
        case loadFailed(String)
        case timeout
        case readabilityFailed(String)
        case bundleMissing

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL 格式不对"
            case .loadFailed(let m): return "页面加载失败: \(m)"
            case .timeout: return "页面加载超时 (30s)"
            case .readabilityFailed(let m): return "Readability 抽取失败: \(m)"
            case .bundleMissing: return "Readability.js 资源缺失 (build 配置问题)"
            }
        }
    }

    private var readabilityJS: String? {
        guard let url = Bundle.main.url(forResource: "Readability", withExtension: "js"),
              let data = try? Data(contentsOf: url),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    /// 抽取一个 URL 的正文。30s 超时。
    func extract(urlString: String) async throws -> Extracted {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            throw ExtractError.invalidURL
        }
        guard let readabilityScript = readabilityJS else {
            throw ExtractError.bundleMissing
        }

        return try await withCheckedThrowingContinuation { continuation in
            let config = WKWebViewConfiguration()
            config.suppressesIncrementalRendering = true
            let webView = WKWebView(frame: .zero, configuration: config)
            let coordinator = ExtractCoordinator(
                webView: webView,
                readabilityScript: readabilityScript,
                originalURL: url.absoluteString,
                continuation: continuation
            )
            webView.navigationDelegate = coordinator
            // Hold strong reference until completion
            coordinator.retainSelf = coordinator
            webView.load(URLRequest(url: url))
        }
    }
}

private final class ExtractCoordinator: NSObject, WKNavigationDelegate {
    var retainSelf: ExtractCoordinator?
    let webView: WKWebView
    let readabilityScript: String
    let originalURL: String
    let continuation: CheckedContinuation<ArticleExtractor.Extracted, Error>
    private var didResume = false
    private var timeoutTask: Task<Void, Never>?

    init(webView: WKWebView,
         readabilityScript: String,
         originalURL: String,
         continuation: CheckedContinuation<ArticleExtractor.Extracted, Error>) {
        self.webView = webView
        self.readabilityScript = readabilityScript
        self.originalURL = originalURL
        self.continuation = continuation
        super.init()
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self else { return }
            await MainActor.run { self.resume(.failure(ArticleExtractor.ExtractError.timeout)) }
        }
    }

    @MainActor
    private func resume(_ result: Result<ArticleExtractor.Extracted, Error>) {
        guard !didResume else { return }
        didResume = true
        timeoutTask?.cancel()
        switch result {
        case .success(let v): continuation.resume(returning: v)
        case .failure(let e): continuation.resume(throwing: e)
        }
        retainSelf = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = """
        (function() {
          \(readabilityScript)
          try {
            var docClone = document.cloneNode(true);
            var article = new Readability(docClone).parse();
            if (!article) return { error: "Readability returned null" };
            // article.textContent flattens all <p> boundaries, producing things like
            // "July 2023If you collected..." Re-extract from article.content (HTML)
            // by walking block-level elements and joining with \\n\\n.
            var staging = document.createElement("div");
            staging.innerHTML = article.content || "";
            var blocks = staging.querySelectorAll("p, h1, h2, h3, h4, h5, h6, li, blockquote, pre");
            var parts = [];
            for (var i = 0; i < blocks.length; i++) {
              var t = (blocks[i].innerText || blocks[i].textContent || "").trim();
              if (t.length > 0) parts.push(t);
            }
            var betterText = parts.join("\\n\\n");
            // Fallback to original textContent if HTML parse produced nothing.
            if (betterText.length < 20) betterText = article.textContent || "";
            return {
              title: article.title || "",
              byline: article.byline || "",
              textContent: betterText,
              excerpt: article.excerpt || ""
            };
          } catch (e) {
            return { error: String(e) };
          }
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error = error {
                    self.resume(.failure(ArticleExtractor.ExtractError.readabilityFailed(error.localizedDescription)))
                    return
                }
                guard let dict = result as? [String: Any] else {
                    self.resume(.failure(ArticleExtractor.ExtractError.readabilityFailed("Result not a dict")))
                    return
                }
                if let errMsg = dict["error"] as? String {
                    self.resume(.failure(ArticleExtractor.ExtractError.readabilityFailed(errMsg)))
                    return
                }
                let extracted = ArticleExtractor.Extracted(
                    url: self.originalURL,
                    title: (dict["title"] as? String) ?? "",
                    byline: (dict["byline"] as? String) ?? "",
                    textContent: (dict["textContent"] as? String) ?? "",
                    excerpt: (dict["excerpt"] as? String) ?? ""
                )
                self.resume(.success(extracted))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.resume(.failure(ArticleExtractor.ExtractError.loadFailed(error.localizedDescription))) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.resume(.failure(ArticleExtractor.ExtractError.loadFailed(error.localizedDescription))) }
    }
}
