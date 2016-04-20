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
    
    var isAlertBeingPresented = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(StatusViewController.didUpdateStatus(_:)), name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: StatusManager.StatusNotifications.DidUpdateStatus.rawValue, object: nil)
    }
    
    func didUpdateStatus(notification : NSNotification) {
        
        let message = StatusManager.sharedInstance.statusDescription()
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.setText(message)
            //DLog("new status: \(message)")
            
            if (!self.isAlertBeingPresented) {       // Dont show a alert while another alert is being presented
                if let errorMessage = StatusManager.sharedInstance.errorDescription() {
                    self.isAlertBeingPresented = true
                    let alert = NSAlert()
                    alert.messageText = errorMessage
                    alert.addButtonWithTitle("Ok")
                    alert.alertStyle = .WarningAlertStyle
                    alert.beginSheetModalForWindow(self.view.window!, completionHandler: { [unowned self] (modalResponse) -> Void in
                        self.isAlertBeingPresented = false
                        })
                }
            }
            })
    }
    
    func setText(text : String) {
        statusTextField.stringValue = text
    }
    
}
