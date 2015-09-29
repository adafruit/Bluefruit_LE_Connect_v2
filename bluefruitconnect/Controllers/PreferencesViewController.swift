//
//  PreferencesViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    
    @IBOutlet weak var updateServerUrlLabel: NSTextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let absoluteUrlString = Preferences.updateServerUrl?.absoluteString {
            updateServerUrlLabel.stringValue = absoluteUrlString
        }
    }
    
    @IBAction func onEndEditingUpdateServerUrl(sender: AnyObject) {
        DLog("url: \(updateServerUrlLabel.stringValue)")
        
        let url = NSURL(string: updateServerUrlLabel.stringValue)
        Preferences.updateServerUrl = url

        FirmwareUpdater.refreshSoftwareUpdatesDatabase()
        
        // TODO: refresh DFUViewController if loaded and add something to the prefrences panel to warn the user if the url is not valid or the file is corrupt
    }
}
