//
//  UartServiceViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class UartServiceViewController: UartBaseViewController {

    
    // Parameters
    var uartPeripheralService: UartPeripheralService?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        self.title = localizationManager.localizedString("uart_tab_title")

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UART
    override func isInMultiUartMode() -> Bool {
        return false
    }

    override func setupUart() {
        updateUartReadyUI(isReady: true)
    }
    
    override func send(message: String) {
        DLog("send: \(message)")
        
        uartPeripheralService?.tx = message.data(using: .utf8)
    }
    
     // MARK: - Style
    override func colorForPacket(packet: UartPacket) -> UIColor {
        return .black
    }
}
