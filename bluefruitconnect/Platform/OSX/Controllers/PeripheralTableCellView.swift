//
//  PeripheralTableCellView.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class PeripheralTableCellView: NSTableCellView {

    // UI
    @IBOutlet weak var rssiImageView: NSImageView!
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var subtitleTextField: NSTextField!
    @IBOutlet weak var disconnectButton: NSButton!
    @IBOutlet weak var disconnectButtonWidthConstraint: NSLayoutConstraint!
    
    // Data
    var onDisconnect : (() -> ())?
    var onClickAdvertising : (() -> ())?

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }

    func showDisconnectButton(show: Bool) {
        disconnectButtonWidthConstraint.constant = show ? 24: 0
    }
    
    // MARK: - Actions
    @IBAction func onClickDisconnect(sender: AnyObject) {
        onDisconnect?()
    }

    @IBAction func onClickAdvertisingPacket(sender: AnyObject) {
        onClickAdvertising?()
    }
    
    
}
