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
        if let shortVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"]  as? String {
            versionLabel.text = "Version \(shortVersion)"
        }

        // Text
        let message = LocalizationManager.sharedInstance.localizedString("about_text")
        /*
        let htmlData = NSString(string: message).data(using: String.Encoding.unicode.rawValue)
        
        let attributedString = try! NSAttributedString(data: htmlData!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil)
        
        messageLabel.attributedText = attributedString
        
        */
        messageLabel.text = message

        messageLabel.layer.borderColor = UIColor(red: 202/255, green: 202/255, blue: 202/255, alpha: 1).cgColor
        messageLabel.layer.borderWidth = 1

        messageLabel.contentInset = UIEdgeInsetsMake(10, 0, 10, 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Hack to make the textview start at the top: http://stackoverflow.com/questions/26835944/uitextview-text-content-doesnt-start-from-the-top
        messageLabel.contentOffset = .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onClickDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
