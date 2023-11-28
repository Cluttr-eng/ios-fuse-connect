
import UIKit
import WebKit

public struct OnSuccess {
    public let authorization_id: String
}

public struct OnExit {
}

@available(iOS 13.0.0, *)
public class SnaptradeViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    let redirectUri: String
    let onSuccess: (OnSuccess) -> Void
    let onExit: (OnExit) -> Void
    var webView: WKWebView!
    var activityIndicator: UIActivityIndicatorView!

    public init(redirectUri: String, onSuccess: @escaping (OnSuccess) -> Void, onExit: @escaping (OnExit) -> Void) {
        self.redirectUri = redirectUri
        self.onSuccess = onSuccess
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self

        webView.frame = view.bounds
        webView.backgroundColor = .white
        view.addSubview(webView)

        let urlComponents = URLComponents(string: "\(redirectUri)")!
        let url = urlComponents.url!
        let request = URLRequest(url: url)

        webView.load(request)

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .black
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        view.addSubview(activityIndicator)
        activityIndicator.center = view.center

        let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)

        let source2 = """
        window.addEventListener('message', function(e) {
            window.webkit.messageHandlers.iosListener.postMessage(e.data);
        });
        """
        let script2 = WKUserScript(source: source2, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script2)

        // register the bridge script that listens for the output
        webView.configuration.userContentController.add(self, name: "logHandler")

        webView.configuration.userContentController.add(self, name: "iosListener")
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logHandler" {
            print("LOG: \(message.body)")
        }

        if message.name == "iosListener" {
            print("LOG SNAPTRADE: \(message.body)")

            if let bodyString = message.body as? String, bodyString.contains("SUCCESS") {
                let components = bodyString.components(separatedBy: ":")
                if components.count > 1 {
                    let authorizationId = components[1].trimmingCharacters(in: .whitespaces)
                    onSuccess(OnSuccess(authorization_id: authorizationId))
                } else {
                    print("No authorization id")
                    onSuccess(OnSuccess(authorization_id: ""))
                }
            } else if let bodyString = message.body as? String, bodyString.contains("ABANDONED") {
                dismiss(animated: false)
                onExit(OnExit())
            } else if let bodyString = message.body as? String, bodyString.contains("ERROR") {
                let components = bodyString.components(separatedBy: ":")
                if components.count > 1 {
                } else {}
            }
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url, url.scheme == "fuse" {}
        return WKNavigationActionPolicy.allow
    }
}
