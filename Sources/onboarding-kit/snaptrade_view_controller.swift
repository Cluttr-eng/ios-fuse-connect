
import UIKit
import WebKit

public struct OnSuccess {
    public let authorization_id: String
}

@available(iOS 13.0.0, *)
public class SnaptradeViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    let redirectUri: String
    let onSuccess: (OnSuccess) -> Void
    var webView: WKWebView!
    var activityIndicator: UIActivityIndicatorView!

    public init(redirectUri: String, onSuccess: @escaping (OnSuccess) -> Void) {
        self.redirectUri = redirectUri
        self.onSuccess = onSuccess
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
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logHandler" {
            print("LOG: \(message.body)")
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        
    }
}
