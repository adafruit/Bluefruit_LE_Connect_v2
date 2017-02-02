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

    fileprivate var helpTitle: String?
    fileprivate var helpMessage: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messageLabel.layer.borderColor = UIColor(hex: 0xcacaca).cgColor
        messageLabel.layer.borderWidth = 1
        
        messageLabel.contentInset = UIEdgeInsetsMake(10, 0, 10, 0);
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }
    
    func setHelp(_ message: String, title: String) {
        helpTitle = title
        helpMessage = message
        
        if isViewLoaded {
            updateUI()
        }
    }
    
    fileprivate func updateUI() {
        // Title
        titleLabel.text = helpTitle
        
        // Text
        messageLabel.text = helpMessage
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Hack to make the textview start at the top: http://stackoverflow.com/questions/26835944/uitextview-text-content-doesnt-start-from-the-top
        messageLabel.contentOffset = CGPoint()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onClickDone(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }

}
