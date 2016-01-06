//
//  MainWindowController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 28/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

    @IBOutlet weak var startScanItem: NSToolbarItem!
    @IBOutlet weak var stopScanItem: NSToolbarItem!
    
     override func windowDidLoad() {
        super.windowDidLoad()

        // Fix for Autosave window position
        // http://stackoverflow.com/questions/25150223/nswindowcontroller-autosave-using-storyboard
        self.windowFrameAutosaveName = "Main App Window"
        
        updateScanItems()
    }
    
    override func validateToolbarItem(theItem: NSToolbarItem) -> Bool {
        return theItem.enabled
    }
    
    @IBAction func onClickScan(sender: NSToolbarItem) {
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
        
        startScanItem.enabled = !isScanning
        stopScanItem.enabled = isScanning
    }    
}
