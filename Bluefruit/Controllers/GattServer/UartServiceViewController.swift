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
        let localizationManager = LocalizationManager.shared
        self.title = localizationManager.localizedString("uart_tab_title")

        // Init Uart
        uartData = UartPeripheralModePacketManager(delegate: self, isPacketCacheEnabled: true, isMqttEnabled: true)
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
        
        uartPeripheralService?.uartEnable(uartRxHandler: { [weak self] data in
            self?.uartData.rxPacketReceived(data: data, peripheralIdentifier: nil, error: nil)
        })
        
        updateUartReadyUI(isReady: true)
    }
    
    override func send(message: String) {
        guard let uartData = self.uartData as? UartPeripheralModePacketManager else { DLog("Error send with invalid uartData class"); return }
        guard let uartPeripheralService = uartPeripheralService else  { return }
        
        uartData.send(uartPeripheralService: uartPeripheralService, text: message)
    }
    
    // MARK: - Stylei
    override func colorForPacket(packet: UartPacket) -> UIColor {
        return .black
    }
    
    // MARK: - MqttManagerDelegate
    override func onMqttMessageReceived(message: String, topic: String) {
        guard let uartPeripheralService = uartPeripheralService else { return }
        
        DispatchQueue.main.async {
            guard let uartData = self.uartData as? UartPeripheralModePacketManager else { DLog("Error send with invalid uartData class"); return }
            uartData.send(uartPeripheralService: uartPeripheralService, text: message, wasReceivedFromMqtt: true)
        }
    }
}

