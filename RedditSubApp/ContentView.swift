import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var webViewStore = WebViewStore()
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            // A button to reload subreddits in case you log in, etc.
            HStack {
                Button("Go to Login") {
                    if let loginURL = URL(string: "https://old.reddit.com/login/") {
                        webViewStore.webView.load(URLRequest(url: loginURL))
                    }
                }
                Button("Load Subreddits") {
                    if let subredditsURL = URL(string: "https://old.reddit.com/subreddits/mine") {
                        webViewStore.webView.load(URLRequest(url: subredditsURL))
                    }
                }
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            // Our WebView container
            WebView(webView: webViewStore.webView)
                .onAppear {
                    webViewStore.errorHandler = { error in
                        self.errorMessage = error
                    }
                }
        }
        .onAppear {
            // Wait a moment before loading to ensure WebView is properly initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let url = URL(string: "https://old.reddit.com/subreddits/mine") {
                    let request = URLRequest(url: url)
                    webViewStore.webView.load(request)
                }
            }
        }
    }
}

// MARK: - WebView
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: NSViewRepresentableContext<WebView>) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: NSViewRepresentableContext<WebView>) {
        // No update needed
    }
}

// MARK: - WebViewStore
class WebViewStore: NSObject, ObservableObject {
    let webView: WKWebView
    var errorHandler: ((String) -> Void)? = nil
    
    override init() {
        // Create a proper configuration
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        
        // Configure JavaScript settings
        if #available(macOS 11.0, *) {
            let webpagePreferences = WKWebpagePreferences()
            webpagePreferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences = webpagePreferences
        } else {
            preferences.javaScriptEnabled = true
        }
        
        // Set additional preferences
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        // Configure process pool (can help with issues)
        let processPool = WKProcessPool()
        config.processPool = processPool
        
        // Allow insecure connections if needed for testing (remove in production)
        if #available(macOS 10.15, *) {
            config.websiteDataStore = WKWebsiteDataStore.default()
            config.limitsNavigationsToAppBoundDomains = false
        }
        
        // Create the web view
        webView = WKWebView(frame: .zero, configuration: config)
        
        super.init()
        
        // Set up delegates
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
}

// MARK: - WKNavigationDelegate
extension WebViewStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView successfully loaded page: \(webView.url?.absoluteString ?? "unknown")")
        
        // First, check if we're on the correct domain
        let checkDomainScript = """
            (function() {
                return window.location.hostname;
            })();
        """
        
        webView.evaluateJavaScript(checkDomainScript) { (result, error) in
            if let hostname = result as? String {
                print("Current hostname: \(hostname)")
                
                // Ensure we're on old.reddit.com
                if !hostname.contains("old.reddit.com") {
                    print("Not on old.reddit.com, redirecting...")
                    if let currentURL = webView.url {
                        let urlString = currentURL.absoluteString
                        let oldRedditURL = urlString.replacingOccurrences(of: "://reddit.com", with: "://old.reddit.com")
                                                  .replacingOccurrences(of: "://www.reddit.com", with: "://old.reddit.com")
                        if let url = URL(string: oldRedditURL) {
                            webView.load(URLRequest(url: url))
                            return
                        }
                    }
                }
                
                // Wait for jQuery with retries
                self.executeWithJQueryCheck(webView: webView, retries: 5)
            } else {
                print("Could not determine current hostname")
            }
        }
    }
    
    private func executeWithJQueryCheck(webView: WKWebView, retries: Int) {
        let checkJQueryScript = """
            (function() {
                return typeof jQuery !== 'undefined';
            })();
        """
        
        webView.evaluateJavaScript(checkJQueryScript) { [weak self] (result, error) in
            guard let self = self else { return }
            
            if let hasJQuery = result as? Bool, hasJQuery {
                print("jQuery detected, running main script...")
                self.executeMainScript(webView: webView)
            } else {
                if retries > 0 {
                    print("jQuery not found. Retrying in 1 second... (\(retries) retries left)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.executeWithJQueryCheck(webView: webView, retries: retries - 1)
                    }
                } else {
                    print("jQuery not found after multiple attempts")
                    self.errorHandler?("jQuery not found on the page. Make sure you're logged in to old.reddit.com")
                }
            }
        }
    }
    
    private func executeMainScript(webView: WKWebView) {
        let mainScript = """
        (function() {
            // Attempt to parse the modhash from the old reddit config
            var modhash = null;
            var configScript = document.querySelector('#config');
            if (configScript) {
                var text = configScript.innerHTML;
                var match = text.match(/"modhash":\\s*"([^"]+)"/);
                if (match && match[1]) {
                    modhash = match[1];
                }
            }

            // Use jQuery to find and process subscriptions
            var $ = window.jQuery;
            
            var subscriptionLinks = $('.subscription-box')
              .find('li')
              .find('a.title');

            if (!subscriptionLinks.length) {
                document.body.innerHTML = "<h3>No subscriptions found. Are you logged in to Reddit?</h3>";
                return;
            }

            var newHTML = "<h3>Your Subreddits</h3>";
            subscriptionLinks.each(function() {
                var subreddit = $(this).text().trim();
                newHTML += "<div>" +
                          "<a href='https://www.reddit.com/r/" + subreddit + "' target='_blank'>" + subreddit + "</a>" +
                          " <button class='unsub-button' data-subreddit='" + subreddit + "'>Unsubscribe</button>" +
                          "</div>";
            });
            document.body.innerHTML = newHTML;

            // Add a click handler to each unsubscribe button
            $('button.unsub-button').on('click', function() {
                var subreddit = $(this).data('subreddit');
                if (!modhash) {
                    alert('Error: Could not find modhash. Unsubscribe may fail.');
                }
                $.ajax({
                    url: '/api/subscribe',
                    type: 'POST',
                    data: {
                        action: 'unsub',
                        sr_name: subreddit,
                        uh: modhash
                    },
                    success: function(resp) {
                        alert('Unsubscribed from ' + subreddit);
                    },
                    error: function(err) {
                        alert('Error unsubscribing from ' + subreddit);
                    }
                });
            });
        })();
        """

        webView.evaluateJavaScript(mainScript) { (result, error) in
            if let error = error {
                print("Error injecting main script: \(error)")
                self.errorHandler?("Script injection failed: \(error.localizedDescription)")
            } else {
                print("Main script executed successfully")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error)")
        self.errorHandler?("Navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional navigation failed: \(error)")
        self.errorHandler?("Loading failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept all certificates during development (remove in production)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - WKUIDelegate
extension WebViewStore: WKUIDelegate {
    // Handle JavaScript alerts
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("JavaScript alert: \(message)")
        
        // Create an alert
        let alert = NSAlert()
        alert.messageText = "Alert"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        completionHandler()
    }
    
    // Handle JavaScript confirm dialogs
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }
}
