//
//  StatusViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    @IBOutlet weak var statusTextField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didUpdateStatus:", name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }
    
    func didUpdateStatus(notification : NSNotification) {
        
        let message = StatusManager.sharedInstance.statusDescription()
        setText(message)
        
        if let errorMessage = StatusManager.sharedInstance.errorDescription() {
            let alert = NSAlert()
            alert.messageText = errorMessage
            alert.addButtonWithTitle("Ok")
            alert.alertStyle = .WarningAlertStyle
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        }
    }

    func setText(text : String) {
        statusTextField.stringValue = text
    }
    
}
