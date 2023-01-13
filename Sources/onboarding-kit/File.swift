import LinkKit
import UIKit
import WebKit

public struct LinkSuccess {
    public let public_token: String
}

public struct InstitutionSelect {
    public let institution_id: String
    public var callback: (_ link_token: String) -> Void
}

public struct Exit {
    public var err: Error?
    public var metadata: [String: Any]?
}

@available(iOS 13.0.0, *)
public class WebViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    static let webViewURL = "https://shoreditch-indol.vercel.app"
//    static let webViewURL = "http://10.38.63.212:3000"

    let clientSecret: String
    let onSuccess: (LinkSuccess) -> Void
    let onInstitutionSelected: (InstitutionSelect) -> Void
    let onExit: (Exit) -> Void
    let onEvent: (String, [String: String]) -> Void

    var handler: Handler!
    var webView: WKWebView!

    var activityIndicator: UIActivityIndicatorView!

    public init(clientSecret: String, onEvent: @escaping (String, [String: String]) -> Void, onSuccess: @escaping (LinkSuccess) -> Void, onInstitutionSelected: @escaping (InstitutionSelect) -> Void, onExit: @escaping (Exit) -> Void) {
        self.clientSecret = clientSecret
        self.onEvent = onEvent
        self.onSuccess = onSuccess
        self.onInstitutionSelected = onInstitutionSelected
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self

        webView.frame = view.bounds
        webView.backgroundColor = .white
        view.addSubview(webView)

        var urlComponents = URLComponents(string: "\(WebViewController.webViewURL)/intro")!
        urlComponents.queryItems = [URLQueryItem(name: "client_secret", value: clientSecret), URLQueryItem(name: "webview", value: "true")]
        let url = urlComponents.url!
        let request = URLRequest(url: url)

        webView.load(request)

        // Show the loading indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .black
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()

        view.addSubview(activityIndicator)
        activityIndicator.center = view.center

        let source = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        // register the bridge script that listens for the output
        webView.configuration.userContentController.add(self, name: "logHandler")
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logHandler" {
            print("LOG: \(message.body)")
        }
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        print("navigationAction")
        // handle communication with the view controller through URL here
        if let url = navigationAction.request.url, url.scheme == "fuse" {
            // handle redirect with "fuse://" scheme
            let eventName = url.queryParameters["event_name"]

            if let eventName = eventName {
                switch eventName {
                case "ON_SUCCESS":
                    onSuccess(LinkSuccess(public_token: url.queryParameters["public_token"]!))
                case "ON_INSTITUTION_SELECTED":
                    let institutionId = url.queryParameters["institution_id"]!
                    onInstitutionSelected(InstitutionSelect(institution_id: institutionId, callback: { link_token in
                        print("Received call back \(link_token)")

                        var urlComponents = URLComponents(string: "\(WebViewController.webViewURL)/bank-link")!
                        urlComponents.queryItems = [URLQueryItem(name: "link_token", value: link_token)]
                        let url = urlComponents.url!
                        let request = URLRequest(url: url)

                        webView.load(request)
                    }))
                case "OPEN_PLAID":
                    let plaidLinkToken = url.queryParameters["plaid_link_token"]!
                    let linkToken = plaidLinkToken
                    openPlaid(token: linkToken)
                case "ON_EXIT":
                    onExit(Exit(err: nil, metadata: nil))
                default:
                    break
                }

                print("Event name: \(eventName)")
            }

            return WKNavigationActionPolicy.cancel
        }
        return WKNavigationActionPolicy.allow
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }

    public func openPlaid(token: String) {
        let configuration = LinkTokenConfiguration(
            token: token,
            onSuccess: { linkSuccess in
                print("plaid onSuccess")
                let fusePublicToken = self.createPublicTokenFromPlaidToken(sessionClientSecret: self.clientSecret, publicToken: linkSuccess.publicToken)
                self.onSuccess(LinkSuccess(public_token: fusePublicToken))
            }
        )

        let result = Plaid.create(configuration)

        switch result {
        case .failure(let error):
            print("Unable to create Plaid handler due to: \(error)")
        case .success(let handler):
            self.handler = handler
        }

        print("opening")
        let method: PresentationMethod = .viewController(topMostController())
        handler.open(presentUsing: method)
    }

    func createPublicTokenFromPlaidToken(sessionClientSecret: String, publicToken: String) -> String {
        let data = [
            "type": "plaid",
            "public_token": publicToken
        ]
        let payload = [
            "session_client_secret": sessionClientSecret,
            "data": data
        ] as [String: Any]

        guard let jsonPayload = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return ""
        }

        let encodedJSON = jsonPayload.base64EncodedString()
        return encodedJSON
    }

    func topMostController() -> UIViewController {
        var topController: UIViewController = UIApplication.shared.keyWindow!.rootViewController!
        while topController.presentedViewController != nil {
            topController = topController.presentedViewController!
        }
        return topController
    }
}

extension URL {
    var queryParameters: [String: String] {
        var params = [String: String]()
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce([:]) { _, item -> [String: String] in
                params[item.name] = item.value
                return params
            } ?? [:]
    }
}
