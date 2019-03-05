//
//  WKWebViewer.swift
//  K12Net Mobile
//
//  Created by Ilhami Sisnelioglu on 19.02.2019.
//  Copyright © 2019 K12Net. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class WKWebViewer: NSObject, WKNavigationDelegate, WKUIDelegate, IWebView {
    
    static var commonProcessPool : WKProcessPool = WKProcessPool()
    
    var web_viewer: WKWebView!
    var container: DocumentView!
    
    init(dv: DocumentView) {
        super.init()
        
        self.container = dv
    }
    
    func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        
        var Ycord : CGFloat = 0.0 // for top space
        if UIScreen.main.bounds.height == 812 { //Check for iPhone-x
            Ycord = 44.0
        }
        else {
            Ycord = 20.0
        }
        
        let customFrame = CGRect(x: 0.0, y: Ycord, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-Ycord)
        
        if #available(iOS 11.0, *) {
            
        } else {
            let userContentController = WKUserContentController()
            
            if let cookies = HTTPCookieStorage.shared.cookies {
                let script = getJSCookiesString(for: cookies)
                let cookieScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                userContentController.addUserScript(cookieScript)
            }
            
            webConfiguration.userContentController = userContentController
            
            //let addCookieScript="var cookieNames = document.cookie.split(\'; \').map(function(cookie) { return cookie.split(\'=\')[0] } );\nif (cookieNames.indexOf(\'mycookie\') == -1) { document.cookie=\'mycookie=abc;domain=.k12net.com;path=/\'; };\n"
            
            //let script = WKUserScript(source: addCookieScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            
            //webConfiguration.userContentController.addUserScript(script)
        }
        
        webConfiguration.allowsInlineMediaPlayback = true
        
        webConfiguration.applicationNameForUserAgent = "K12Net_IOS"
        webConfiguration.processPool = WKWebViewer.commonProcessPool
        
        if #available(iOS 10.0, *) {
            webConfiguration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.all
        } else {
            // Fallback on earlier versions
        }
        
        web_viewer = WKWebView(frame: customFrame, configuration: webConfiguration)
        web_viewer.uiDelegate = self
        web_viewer.contentMode = UIView.ContentMode.scaleToFill
        web_viewer.allowsBackForwardNavigationGestures=true
        web_viewer.translatesAutoresizingMaskIntoConstraints=false
        web_viewer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        web_viewer.scrollView.delegate = container
        
        container.view.addSubview(web_viewer)
        
        container.preloader.removeFromSuperview()
        container.view.addSubview(container.preloader)
    }
    
    func viewDidLoad() {        
        web_viewer.navigationDelegate = self
        
        web_viewer.uiDelegate = self
        
        web_viewer.scrollView.bounces = false
        
        self.web_viewer.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        
        if(container.startUrl == nil) {
            let logonAddress = (K12NetUserPreferences.getHomeAddress() as String) + "/Logon.aspx";
            container.last_address = logonAddress;
            
            container.startUrl = URL(string: logonAddress as String);
        } else {
            container.last_address = container.startUrl?.absoluteString;
        }
        
        if(container.simple_page){
            self.loadURL(url: container.startUrl!);
        }
        else  {
            
            self.configureView();
            
            K12NetUserPreferences.resetBadgeCount();
            
            K12NetLogin.refreshAppBadge();
        }
    }
    
    func viewWillAppear(_ animated: Bool) {
        container.navigationController?.isToolbarHidden = false;
        container.navigationController?.isNavigationBarHidden = true;
        container.browseButton?.tintColor = .clear;
    }
    
    func configureView() {
        if (container.startUrl == nil) {
            let logonAddress = (K12NetUserPreferences.getHomeAddress() as String) + "/Logon.aspx";
            container.last_address = logonAddress;
            
            container.startUrl = URL(string: logonAddress as String);
        } else {
            container.last_address = container.startUrl?.absoluteString;
        }
        
        if let urlAddress = container.startUrl {
            self.loadURL(url: urlAddress);
        } else {
            let alertController = UIAlertController(title: "Web View", message:
                "K12Net url address is wrong", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default,handler: nil))
            
            container.addActionSheetForiPad(actionSheet: alertController)
            container.present(alertController, animated: true, completion: nil)
            
            container.navigationItem.rightBarButtonItem = nil;
        }
    }
    
    func homeView(_ sender: AnyObject) {
        container.startUrl = URL(string: K12NetUserPreferences.getHomeAddress() as String);
        self.loadURL(url: container.startUrl!);
        //progressIndicator.stopAnimating();
    }
    
    func browseView(_ sender: AnyObject) {
        if(container.startUrl == nil) {
            return
        }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(container.startUrl!, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
        } else {
            UIApplication.shared.openURL(container.startUrl!)
        }
        
    }
    
    func refreshView(_ sender: AnyObject) {
        
        self.loadURL(url: URL(string: container.last_address!)!);
        
        //web_viewer.reload();
    }
    
    func backView(_ sender: AnyObject) {
        if web_viewer.canGoBack {
            web_viewer.goBack();
        }
        else if(container.simple_page) {
            container.navigationController?.popViewController(animated: true);
        }
    }
    
    func nextView(_ sender: AnyObject) {
        if web_viewer.canGoForward {
            web_viewer.goForward();
        }
    }
    
    func loadURL(url: URL) {
        let request = URLRequest(url: url)
        
        DocumentView.setCookie()
        
        let cookies = HTTPCookieStorage.shared.cookies ?? [HTTPCookie]()
        
        if #available(iOS 11.0, *) {
            cookies.forEach({
                web_viewer.configuration.websiteDataStore.httpCookieStore.setCookie($0, completionHandler: nil)
            })
        } else {
            /*var values = [String]()
             cookies.forEach({
             values.append($0.name + "=" + $0.value)
             })
             
             if(HTTPCookieStorage.shared.cookies != nil && (HTTPCookieStorage.shared.cookies?.count)! > 0) {
             let df = DateFormatter()
             df.timeZone = TimeZone(abbreviation: "UTC")
             df.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
             
             let cookie = HTTPCookieStorage.shared.cookies![(HTTPCookieStorage.shared.cookies?.count)!-1];
             
             values.append("domain=" + cookie.domain)
             values.append("originURL=" + cookie.domain)
             values.append("path=" + cookie.path)
             values.append("expires=" + (cookie.expiresDate == nil ? "" : df.string(from: cookie.expiresDate!)))
             if(cookie.isSecure) {values.append("secure")}
             }
             
             request.addValue(values.joined(separator: ";"), forHTTPHeaderField: "Cookie")*/
            
            /*let headers = HTTPCookie.requestHeaderFields(with: cookies)
             for (name, value) in headers {
             request.addValue(value, forHTTPHeaderField: name)
             }*/
        }
        
        web_viewer.load(request);
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let hostAddress = navigationAction.request.url?.host
        
        let address = navigationAction.request.url!.absoluteString.lowercased();
        
        print(address);
        
        DocumentView.setCookie()
        
        if #available(iOS 11.0, *) {
            let cookies = HTTPCookieStorage.shared.cookies ?? [HTTPCookie]()
            
            cookies.forEach({
                web_viewer.configuration.websiteDataStore.httpCookieStore.setCookie($0, completionHandler: nil)
            })
        } else {
            let cookies = HTTPCookie.requestHeaderFields(with: HTTPCookieStorage.shared.cookies ?? [])
            
            var headers = navigationAction.request.allHTTPHeaderFields ?? [:]
            cookies.forEach { c in
                headers[c.key] = c.value
            }
            
            var req = navigationAction.request
            req.allHTTPHeaderFields = headers
            req.httpShouldHandleCookies = true
        }
        
        // To connnect app store
        if hostAddress == "itunes.apple.com" {
            if UIApplication.shared.canOpenURL(navigationAction.request.url!) {
                UIApplication.shared.openURL(navigationAction.request.url!)
                decisionHandler(.cancel)
                return
            }
        }
        
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request);
        } else if (!(navigationAction.targetFrame?.isMainFrame)! && address == "about:blank") {
            /*decisionHandler(.cancel)
             return*/
        }
        
        if((address.contains("getfile.aspx") || address.contains("getimage.aspx")) && !address.contains(".google.com")) {
            container.preloader.startAnimating()
            container.preloader.isHidden = false
            
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig)
            
            let task = session.downloadTask(with: navigationAction.request) { (tempLocalUrl, response, error) in
                if let tempLocalUrl = tempLocalUrl, error == nil {
                    var fileName = "downloaded_file.pdf"
                    
                    if(address.contains("filename=")) {
                        fileName = address.components(separatedBy: "filename=").last!.components(separatedBy: "&").first!
                    } else if(address.contains("path=")) {
                        fileName = address.components(separatedBy: "path=").last!.components(separatedBy: "/").last!.components(separatedBy: "&").first!
                    }
                    
                    let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    let destinationFileUrl = documentsUrl!.appendingPathComponent(fileName.removingPercentEncoding!)
                    
                    // Success
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        print("destinationFileUrl: \(destinationFileUrl.absoluteString)")
                        
                        if statusCode == 200 {
                            
                            do {
                                
                                if(FileManager.default.fileExists(atPath: destinationFileUrl.path)) {
                                    _ = try FileManager.default.replaceItemAt(destinationFileUrl, withItemAt: tempLocalUrl)
                                } else {
                                    try FileManager.default.copyItem(at: tempLocalUrl, to: destinationFileUrl)
                                }
                                
                                let open = DocViewer(barButton: self.container.backButton, controller: self.container.navigationController!)
                                let activityVC = UIActivityViewController(activityItems: [destinationFileUrl],applicationActivities: [open])
                                
                                self.container.present(activityVC, animated: true, completion: nil)
                                
                                DispatchQueue.main.async {
                                    self.container.preloader.stopAnimating()
                                    self.container.preloader.isHidden = true
                                }
                                
                            } catch (let writeError) {
                                print("Error creating a file \(destinationFileUrl) : \(writeError)")
                            }
                            
                        }
                    }
                    
                } else {
                    print("Error took place while downloading a file. Error description: %@", error?.localizedDescription ?? "");
                }
            }
            
            task.resume()
            
            decisionHandler(.cancel)
            return;
        }
        
        if (address.contains("login.aspx")){
            if(K12NetUserPreferences.getRememberMe()) {
                
                container.preloader.startAnimating()
                container.preloader.isHidden = false
                
                LoginAsyncTask.loginOperation();
                
                self.loadURL(url: URL(string: container.last_address!)!);
                
                container.preloader.stopAnimating()
                container.preloader.isHidden = true
            }
            else {
                self.container.navigationController?.popToRootViewController(animated: true);
            }
            
            decisionHandler(.cancel)
            return;
        }            
        else if(address.contains("logout.aspx")) {
            K12NetUserPreferences.saveRememberMe(false);
            K12NetLogin.isLogout = true;
            self.container.navigationController?.popToRootViewController(animated: true);
            
            decisionHandler(.cancel)
            return;
        }
        
        if navigationAction.request.url?.scheme == "tel" {
            
            UIApplication.shared.openURL(navigationAction.request.url!)
            
            decisionHandler(.cancel)
            
        }
        else if navigationAction.request.url?.scheme == "mailto" {
            
            UIApplication.shared.openURL(navigationAction.request.url!)
            
            decisionHandler(.cancel)
            
        }
        else if #available(iOS 11.0, *)  {
            decisionHandler(.allow)
        }
        else {
            let headerKeys = navigationAction.request.allHTTPHeaderFields?.keys
            let hasCookies = headerKeys?.contains("Cookie") ?? false
            
            if hasCookies {
                decisionHandler(.allow)
            } else {
                let cookies = HTTPCookie.requestHeaderFields(with: HTTPCookieStorage.shared.cookies ?? [])
                
                var headers = navigationAction.request.allHTTPHeaderFields ?? [:]
                cookies.forEach { c in
                    headers[c.key] = c.value
                }
                
                var req = navigationAction.request
                req.allHTTPHeaderFields = headers
                req.httpShouldHandleCookies = true
                webView.load(req)
                
                decisionHandler(.cancel)
            }
        }
        
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { (action) in
            completionHandler()
        }))
        
        container.addActionSheetForiPad(actionSheet: alertController)
        container.present(alertController, animated: true, completion: nil)
        
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .default, handler: { (action) in
            completionHandler(false)
        }))
        
        container.addActionSheetForiPad(actionSheet: alertController)
        container.present(alertController, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        
        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        container.addActionSheetForiPad(actionSheet: alertController)
        container.present(alertController, animated: true, completion: nil)
    }
    
    /*func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
     
         if let urlResponse = navigationResponse.response as? HTTPURLResponse,
         let url = urlResponse.url,
         let allHeaderFields = urlResponse.allHeaderFields as? [String : String] {
         let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: url)
         HTTPCookieStorage.shared.setCookies(cookies , for: urlResponse.url!, mainDocumentURL: nil)
         decisionHandler(.allow)
         }
        
    }*/
    
    public func getJSCookiesString(for cookies: [HTTPCookie]) -> String {
        var result = ""
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
        
        for cookie in cookies {
            result += "document.cookie='\(cookie.name)=\(cookie.value); domain=\(cookie.domain); path=\(cookie.path); "
            if let date = cookie.expiresDate {
                result += "expires=\(dateFormatter.string(from: date)); "
            }
            if (cookie.isSecure) {
                result += "secure; "
            }
            result += "'; "
        }
        return result
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "loading" {
            
            if self.web_viewer.isLoading {
                webViewDidStartLoad()
            } else {
                webViewDidFinishLoad()
            }
            
        }
        
    }
    
    func webViewDidStartLoad() {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        container.preloader.startAnimating()
        container.preloader.isHidden = false
    }
    
    func webViewDidFinishLoad() {
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        
        container.preloader.stopAnimating()
        container.preloader.isHidden = true
        
        if web_viewer.canGoBack || container.simple_page {
            container.backButton.isEnabled = true;
        }
        else {
            container.backButton.isEnabled = false;
        }
        
        if web_viewer.canGoForward {
            container.nextButton.isEnabled = true;
        }
        else {
            container.nextButton.isEnabled = false;
        }
        
        container.last_address = web_viewer.url?.absoluteString;
        
        web_viewer.evaluateJavaScript("document.head.innerHTML") { (htmlCode, error) in
            if error != nil {
                if((htmlCode as! String).contains("atlas-mobile-web-app-no-sleep")) {
                    UIApplication.shared.isIdleTimerDisabled = true;
                }
                else {
                    UIApplication.shared.isIdleTimerDisabled = false;
                }
            }
        }
        
        K12NetUserPreferences.resetBadgeCount();
        
        K12NetLogin.refreshAppBadge();
        
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}