//
//  MainWindowController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 28/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {
    
    // UI
    @IBOutlet weak var startScanItem: NSToolbarItem!
    @IBOutlet weak var stopScanItem: NSToolbarItem!
    
    // MARK: - View Lifecycle
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Fix for Autosave window position
        // http://stackoverflow.com/questions/25150223/nswindowcontroller-autosave-using-storyboard
        self.windowFrameAutosaveName = "Main App Window"
        
        updateScanItems()
    }
    
    override func validateToolbarItem(_ theItem: NSToolbarItem) -> Bool {
        return theItem.isEnabled
    }
    
    @IBAction func onClickScan(_ sender: NSToolbarItem) {
        let tag = sender.tag
        
        DLog("onClickScan: \(tag)")
        
        let bleManager = BleManager.sharedInstance
        if (tag == 0) {
            bleManager.startScan()
        }
        else if (tag == 1) {
            bleManager.stopScan()
        }
        
        updateScanItems()
    }
    
    func updateScanItems() {
        let bleManager = BleManager.sharedInstance
        let isScanning = bleManager.isScanning
        
        startScanItem.isEnabled = !isScanning
        stopScanItem.isEnabled = isScanning
    }    
}
