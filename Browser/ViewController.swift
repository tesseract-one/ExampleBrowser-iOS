//
//  ViewController.swift
//  Browser
//
//  Created by Daniel Leping on 06/09/2018.
//  Copyright © 2018 Tesseract Systems, Inc. All rights reserved.
//

import UIKit
import WebKit
import Tesseract

public let TESSERACT_ETHEREUM_ENDPOINTS: Dictionary<UInt64, String> = [
    1: "https://mainnet.infura.io/v3/f20390fe230e46608572ac4378b70668",
    2: "https://ropsten.infura.io/v3/f20390fe230e46608572ac4378b70668",
    3: "https://kovan.infura.io/v3/f20390fe230e46608572ac4378b70668",
    4: "https://rinkeby.infura.io/v3/f20390fe230e46608572ac4378b70668"
]

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    var appUrl: URL? = nil
    var netVersion: UInt64? = nil
    
    var wallet:Wallet? = nil
    
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        print("WALLA!")
    }
    
    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        print("WALLA2!")
    }
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        print("HOLA1")
        
        return nil
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        print("HOLA2")
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        print("HOLA3")
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        print("HOLA4")
    }
    
    /*func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        print("HOLA5")
    }*/
    
    func webView(_ webView: WKWebView,
                 shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
        print("HOLA6")
        return true
    }
    
    func webView(_ webView: WKWebView,
                 previewingViewControllerForElement elementInfo: WKPreviewElementInfo,
                 defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        print("HOLA7")
        return nil
    }
    
    func webView(_ webView: WKWebView,
                 commitPreviewingViewController previewingViewController: UIViewController) {
        print("HOLA8")
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("JSMSG: " + message)
        /*webView.evaluateJavaScript("window.web3.isConnected();",
                                   completionHandler: {(res: AnyObject?, error: NSError?) in
                                    if let connected = res, connected as! NSInteger == 1
                                    {
                                        print("Connected to ethereum node")
                                    }
                                    else
                                    {
                                        print("Unable to connect ot the node. Check the setup.")
                                    }
                                    } as? (Any?, Error?) -> Void
        )*/
        completionHandler()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = TesWebView(frame: self.view.frame, networkId: netVersion!)
        
        let endpoint = TESSERACT_ETHEREUM_ENDPOINTS[netVersion!]!
        
        wallet = Wallet(
            web3: Tesseract.Ethereum.Web3(rpcUrl: endpoint),
            endpoint: endpoint,
            webState: webView
        )
        
        let myRequest = URLRequest(url: appUrl!)
        
        title = appUrl?.host
    
        wallet?.link(web: webView)
        
        self.view.addSubview(webView)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: webView, attribute: $0, relatedBy: .equal, toItem: webView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.load(myRequest)
        // Do any additional setup after loading the view, typically from a nib.
    }
}

