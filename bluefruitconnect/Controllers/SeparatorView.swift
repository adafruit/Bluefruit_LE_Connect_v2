//
//  SeparatorView.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class SeparatorView: NSView {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.blackColor().colorWithAlphaComponent(0.2).CGColor
    }
    
}
