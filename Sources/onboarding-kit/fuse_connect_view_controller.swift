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
    public var err: ConnectError?
    public var metadata: [String: Any]?
}

public struct ConnectError {
    public var errorCode: String?
    public var errorType: String?
    public var displayMessage: String?
    public var errorMessage: String?
}

@available(iOS 13.0.0, *)
public class FuseConnectViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
//    static let webViewURL = "https://shoreditch-indol.vercel.app"
    static let webViewURL = "http://192.168.1.151:3002"

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

        var urlComponents = URLComponents(string: "\(FuseConnectViewController.webViewURL)/intro")!
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

                        var urlComponents = URLComponents(string: "\(FuseConnectViewController.webViewURL)/bank-link")!
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
        var configuration = LinkTokenConfiguration(
            token: token,
            onSuccess: { linkSuccess in
                print("plaid onSuccess")
                let fusePublicToken = self.createPublicTokenFromPlaidToken(sessionClientSecret: self.clientSecret, publicToken: linkSuccess.publicToken)
                self.onSuccess(LinkSuccess(public_token: fusePublicToken))
            }
        )

        configuration.onExit = { linkExit in
            if let error = linkExit.error {
                switch error.errorCode {
                case .apiError:
                    self.onExit(Exit(err: ConnectError(errorCode: "API_ERROR", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .authError:
                    self.onExit(Exit(err: ConnectError(errorCode: "AUTH_ERROR", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .assetReportError:
                    self.onExit(Exit(err: ConnectError(errorCode: "ASSET_REPORT_ERROR", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .internal:
                    self.onExit(Exit(err: ConnectError(errorCode: "INTERNAL", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .institutionError:
                    self.onExit(Exit(err: ConnectError(errorCode: "INSTITUTION_ERROR", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .itemError:
                    self.onExit(Exit(err: ConnectError(errorCode: "ITEM_ERROR", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .invalidInput:
                    self.onExit(Exit(err: ConnectError(errorCode: "INVALID_INPUT", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .invalidRequest:
                    self.onExit(Exit(err: ConnectError(errorCode: "INVALID_REQUEST", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .rateLimitExceeded:
                    self.onExit(Exit(err: ConnectError(errorCode: "RATE_LIMIT_EXCEEDED", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                case .unknown:
                    self.onExit(Exit(err: ConnectError(errorCode: "UNKNOWN", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                @unknown default:
                    self.onExit(Exit(err: ConnectError(errorCode: "UNKNOWN", errorType: "", errorMessage: error.errorMessage), metadata: [:]))
                }
                // Optionally handle linkExit data according to your application's needs
            } else {
                self.onExit(Exit(err: nil, metadata: [:]))
            }
        }

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
