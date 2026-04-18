import SwiftUI
import WebKit

struct WebSplatViewerView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black

        load(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        load(uiView)
    }

    private func load(_ webView: WKWebView) {
        webView.loadHTMLString(html(url: url.absoluteString), baseURL: nil)
    }

    private func html(url: String) -> String {
        let escaped = url.replacingOccurrences(of: "'", with: "\\'")

        return """
        <!doctype html>
        <html>
        <body style="margin:0;background:black;">
        <div id="root"></div>

        <script type="module">
        const url = '\(escaped)';

        try {
          const m = await import('https://unpkg.com/@mkkellogg/gaussian-splats-3d@0.4.7/build/gaussian-splats-3d.module.js');

          const viewer = new m.Viewer({
            rootElement: document.getElementById('root'),
            selfDrivenMode: true
          });

          await viewer.addSplatScene(url);
          viewer.start();

        } catch (e) {
          document.body.innerHTML = "<h3 style='color:white'>Render error</h3>";
        }
        </script>

        </body>
        </html>
        """
    }
}
