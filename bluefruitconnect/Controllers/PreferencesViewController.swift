//
//  PreferencesViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 20/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {

    // Firmware Updates
    @IBOutlet weak var showBetaVersionsButton: NSButton!
    @IBOutlet weak var updateServerUrlLabel: NSTextField!
    @IBOutlet weak var databaseStatusLabel: NSTextField!
    @IBOutlet weak var databaseStatusWaitView: NSProgressIndicator!

    // Uart
    @IBOutlet weak var receivedDataColorWell: NSColorWell!
    @IBOutlet weak var sentDataColorWell: NSColorWell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        // Firmware Updates
        showBetaVersionsButton.state = Preferences.showBetaVersions ?NSOnState:NSOffState
        
        databaseStatusLabel.stringValue = ""
        databaseStatusWaitView.hidden = true
        if let absoluteUrlString = Preferences.updateServerUrl?.absoluteString {
            updateServerUrlLabel.stringValue = absoluteUrlString
        }

        // Uart
        let uartReceveivedDataColor = Preferences.uartReceveivedDataColor
        receivedDataColorWell.color = uartReceveivedDataColor
        
        let uartSentDataColor = Preferences.uartSentDataColor
        sentDataColorWell.color = uartSentDataColor

    }
    
    // MARK: - Firmware Updates
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

    
    // MARK: -Uart
    @IBAction func onColorChanged(sender: NSColorWell) {
        if (sender == receivedDataColorWell) {
            Preferences.uartReceveivedDataColor = sender.color
        }
        else if (sender == sentDataColorWell) {
            Preferences.uartSentDataColor = sender.color
        }
    }
}
