//
//  MainWindowController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 28/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

     override func windowDidLoad() {
        super.windowDidLoad()
    
        // Fix for Autosave window position
        // http://stackoverflow.com/questions/25150223/nswindowcontroller-autosave-using-storyboard
        self.windowFrameAutosaveName = "Main App Window"

    }

}
