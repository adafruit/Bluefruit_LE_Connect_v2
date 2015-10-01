//
//  FirmwareUpdatePreferencesViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class FirmwareUpdatePreferencesViewController: NSViewController {
    
    @IBOutlet weak var updateServerUrlLabel: NSTextField!
    @IBOutlet weak var databaseStatusLabel: NSTextField!
    @IBOutlet weak var databaseStatusWaitView: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        databaseStatusLabel.stringValue = ""
        databaseStatusWaitView.hidden = true
        if let absoluteUrlString = Preferences.updateServerUrl?.absoluteString {
            updateServerUrlLabel.stringValue = absoluteUrlString
        }
        
    }
    
    @IBAction func onEndEditingUpdateServerUrl(sender: AnyObject) {
        DLog("url: \(updateServerUrlLabel.stringValue)")
        
        let url = NSURL(string: updateServerUrlLabel.stringValue)
        databaseStatusLabel.stringValue = "Updating database..."
        databaseStatusWaitView.hidden = false
        
        Preferences.updateServerUrl = url

        FirmwareUpdater.refreshSoftwareUpdatesDatabaseWithCompletionHandler { [weak self] (success) -> Void in
            let text = success ?"Database updated successfully" : "Error updating database. Check the URL and Internet connectivity"
            self?.databaseStatusLabel.stringValue = text
            self?.databaseStatusWaitView.hidden = true
        }
    }

    @IBAction func onChangedShowBetaVersions(sender: NSButton) {
        Preferences.showBetaVersions = sender.state == NSOnState
    }
    
}
