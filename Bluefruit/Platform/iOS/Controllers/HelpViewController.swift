//
//  HelpViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 15/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController {
    @IBOutlet weak var messageLabel: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        messageLabel.layer.borderColor = UIColor(hex: 0xcacaca).cgColor
        messageLabel.layer.borderWidth = 1

        messageLabel.contentInset = UIEdgeInsetsMake(10, 0, 10, 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }

    func setHelp(_ message: String, title: String) {
        
        loadViewIfNeeded()
        
        // Text
        messageLabel.text = message
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
