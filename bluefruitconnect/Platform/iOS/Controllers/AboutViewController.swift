//
//  AboutViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 14/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var messageLabel: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get version
        if let shortVersion = NSBundle.mainBundle().infoDictionary!["CFBundleShortVersionString"]  as? String {
            versionLabel.text = "v.\(shortVersion)"
        }
        
        // Text
        let message = LocalizationManager.sharedInstance.localizedString("about_text")
        messageLabel.text = message
        
        messageLabel.layer.borderColor = UIColor(hex: 0xcacaca).CGColor
        messageLabel.layer.borderWidth = 1
        
        messageLabel.contentInset = UIEdgeInsetsMake(10, 0, 10, 0);
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Hack to make the textview start at the top: http://stackoverflow.com/questions/26835944/uitextview-text-content-doesnt-start-from-the-top
        messageLabel.contentOffset = CGPointZero
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onClickDone(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}
