//
//  StatusViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class StatusViewController: NSViewController {

    // UI
    @IBOutlet weak var statusTextField: NSTextField!
    
    // Data
    private var isAlertBeingPresented = false
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        registerNotifications(enabled: true)
    }
    
    deinit {
        registerNotifications(enabled: false)
    }
    
    
    // MARK: - BLE Notifications
    private weak var didUpdateStatusObserver: NSObjectProtocol?

    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdateStatusObserver = notificationCenter.addObserver(forName: .didUpdateStatus, object: nil, queue: .main, using: didUpdateStatus)
        } else {
            if let didUpdateStatusObserver = didUpdateStatusObserver {notificationCenter.removeObserver(didUpdateStatusObserver)}
        }
    }
    
    func didUpdateStatus(notification: Notification) {
        
        let message = StatusManager.sharedInstance.statusDescription()
        
        self.setText(message)
        //DLog("new status: \(message)")
        
        if (!self.isAlertBeingPresented) {       // Don't show a alert while another alert is being presented
            if let errorMessage = StatusManager.sharedInstance.errorDescription() {
                self.isAlertBeingPresented = true
                let alert = NSAlert()
                alert.messageText = errorMessage
                alert.addButton(withTitle: "Ok")
                alert.alertStyle = .warning
                alert.beginSheetModal(for: self.view.window!, completionHandler: { [unowned self] modalResponse in
                    self.isAlertBeingPresented = false
                })
            }
        }
    }
    
    
    // MARK: - UI
    func setText(_ text: String) {
        statusTextField.stringValue = text
    }
}
