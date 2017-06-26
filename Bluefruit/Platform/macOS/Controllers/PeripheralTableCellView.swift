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
    @IBOutlet weak var hasUartView: NSTextField!
    @IBOutlet weak var disconnectButton: NSButton!
    @IBOutlet weak var disconnectButtonWidthConstraint: NSLayoutConstraint!
    
    // Data
    var onDisconnect: (() -> ())?
    var onClickAdvertising: (() -> ())?

    // MARK: - View Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        
        hasUartView.wantsLayer = true
        hasUartView.layer?.borderWidth = 1
        hasUartView.layer?.borderColor = NSColor.lightGray.cgColor
        hasUartView.layer?.cornerRadius = 4
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    // MARK - 
    func showDisconnectButton(_ show: Bool) {
        disconnectButtonWidthConstraint.constant = show ? 24: 0
    }
    
    // MARK: - Actions
    @IBAction func onClickDisconnect(_ sender: AnyObject) {
        onDisconnect?()
    }

    @IBAction func onClickAdvertisingPacket(_ sender: AnyObject) {
        onClickAdvertising?()
    }
    
    
}
