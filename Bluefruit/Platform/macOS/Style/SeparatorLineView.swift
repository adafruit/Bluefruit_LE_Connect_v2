//
//  SeparatorLineView.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 22/09/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Cocoa

class SeparatorLineView: NSView {

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        layer?.backgroundColor = Color.lightGray.cgColor
    }

}
