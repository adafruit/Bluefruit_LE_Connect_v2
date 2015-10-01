//
//  UartPreferencesViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa

class UartPreferencesViewController: NSViewController {

    @IBOutlet weak var receivedDataColorWell: NSColorWell!
    @IBOutlet weak var sentDataColorWell: NSColorWell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let uartReceveivedDataColor = Preferences.uartReceveivedDataColor 
        receivedDataColorWell.color = uartReceveivedDataColor
        
        
        let uartSentDataColor = Preferences.uartSentDataColor
        sentDataColorWell.color = uartSentDataColor

    }
}
