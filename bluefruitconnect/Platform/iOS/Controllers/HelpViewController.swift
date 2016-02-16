//
//  HelpViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 15/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var messageLabel: UITextView!

    private var helpTitle: String?
    private var helpMessage: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messageLabel.layer.borderColor = UIColor(hex: 0xcacaca).CGColor
        messageLabel.layer.borderWidth = 1
        
        messageLabel.contentInset = UIEdgeInsetsMake(10, 0, 10, 0);
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }
    
    func setHelp(message: String, title: String) {
        helpTitle = title
        helpMessage = message
        
        if isViewLoaded() {
            updateUI()
        }
    }
    
    private func updateUI() {
        // Title
        titleLabel.text = helpTitle
        
        // Text
        messageLabel.text = helpMessage
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
