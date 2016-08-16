//
//  DetailViewController.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/16/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation
import UIKit

class DetailViewConroller: UIViewController
{
    @IBOutlet weak var webView: UIWebView!
    
    var link: NSURL!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        let request = NSURLRequest(URL: link)
        webView.loadRequest(request)
        title = link.host
    }
}