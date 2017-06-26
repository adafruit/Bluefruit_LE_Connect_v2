//
//  MainSplitViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 22/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class MainSplitViewController: NSSplitViewController {

    let kMinSplitDividerPosition: CGFloat = 200
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Fix for Autosave window position
        // http://stackoverflow.com/questions/16587058/nssplitview-auto-saving-divider-positions-doesnt-work-with-auto-layout-enable
        splitView.autosaveName = "Main Split View"
        
        // Start scanning
        BleManager.sharedInstance.startScan()
    }
    
    override func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if proposedPosition < kMinSplitDividerPosition {
            return kMinSplitDividerPosition
        }
        else {
            return proposedPosition
        }
    }
}
