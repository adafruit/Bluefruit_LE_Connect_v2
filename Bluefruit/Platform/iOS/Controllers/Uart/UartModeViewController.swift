//
//  UartModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UartModeViewController: UartBaseViewController {

    // UI
    @IBOutlet weak var sendPeripheralButton: UIButton!
    
    // Data
    fileprivate var colorForPeripheral = [UUID: UIColor]()
    fileprivate var multiUartSendToPeripheralId: UUID?       // nil = all peripherals

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("uart_navigation_title_format"), arguments: [name])  : localizationManager.localizedString("uart_tab_title")
        
        // Setup controls
        sendPeripheralButton.isHidden = !isInMultiUartMode()
      
        // Localization
        sendPeripheralButton.setTitle(localizationManager.localizedString("uart_send_toall_action"), for: .normal)     // Default value
        
        // Init Uart
        uartData = UartPacketManager(delegate: self, isPacketCacheEnabled: true, isMqttEnabled: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - UART
    override func isInMultiUartMode() -> Bool {
        return blePeripheral == nil
    }
    
    override func setupUart() {
        updateUartReadyUI(isReady: false)
        
        // Reset colors assigned to peripherals
        let colors = UartStyle.defaultColors()
        colorForPeripheral.removeAll()
        
        // Enable uart
        let localizationManager = LocalizationManager.shared
        if isInMultiUartMode() {            // Multiple peripheral mode
            let blePeripherals = BleManager.shared.connectedPeripherals()
            for (i, blePeripheral) in blePeripherals.enumerated() {
                colorForPeripheral[blePeripheral.identifier] = colors[i % colors.count]
                blePeripheral.uartEnable(uartRxHandler: uartData.rxPacketReceived) { [weak self] error in
                    guard let context = self else { return }
                    
                    let peripheralName = blePeripheral.name ?? blePeripheral.identifier.uuidString
                    DispatchQueue.main.async {
                        guard error == nil else {
                            DLog("Error initializing uart")
                            context.dismiss(animated: true, completion: { [weak self] () -> Void in
                                if let context = self {
                                    showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: String(format: localizationManager.localizedString("uart_error_multipleperiperipheralinit_format"), peripheralName))
                                    
                                    BleManager.shared.disconnect(from: blePeripheral)
                                }
                            })
                            return
                        }
                        
                        // Done
                        DLog("Uart enabled for \(peripheralName)")
                        
                        if blePeripheral == blePeripherals.last {
                            context.updateUartReadyUI(isReady: true)
                        }
                    }
                }
            }
        } else if let blePeripheral = blePeripheral {         //  Single peripheral mode
            colorForPeripheral[blePeripheral.identifier] = colors.first
            blePeripheral.uartEnable(uartRxHandler: uartData.rxPacketReceived) { [weak self] error in
                guard let context = self else { return }
                
                DispatchQueue.main.async {
                    guard error == nil else {
                        DLog("Error initializing uart")
                        context.dismiss(animated: true, completion: { [weak self] in
                            if let context = self {
                                showErrorAlert(from: context, title: localizationManager.localizedString("dialog_error"), message: localizationManager.localizedString("uart_error_peripheralinit"))
                                
                                if let blePeripheral = context.blePeripheral {
                                    BleManager.shared.disconnect(from: blePeripheral)
                                }
                            }
                        })
                        return
                    }
                    
                    // Done
                    DLog("Uart enabled")
                    context.updateUartReadyUI(isReady: true)
                }
            }
        }
    }

    override func send(message: String) {
        guard let uartData = self.uartData as? UartPacketManager else { DLog("Error send with invalid uartData class"); return }
        
        if let blePeripheral = blePeripheral {      // Single peripheral mode
            uartData.send(blePeripheral: blePeripheral, text: message)
        } else {      // Multiple peripheral mode
            let peripherals = BleManager.shared.connectedPeripherals()
            
            if let multiUartSendToPeripheralId = multiUartSendToPeripheralId {
                // Send to single peripheral
                if let peripheral = peripherals.first(where: {$0.identifier == multiUartSendToPeripheralId}) {
                    uartData.send(blePeripheral: peripheral, text: message)
                }
            } else {
                // Send to all peripherals
                for peripheral in peripherals {
                    uartData.send(blePeripheral: peripheral, text: message)
                }
            }
        }
    }
    
    // MARK: - UI Actions
    @IBAction func onClickPeripheralToSend(_ sender: UIButton) {
        let viewController = storyboard!.instantiateViewController(withIdentifier: "UartSelectPeripheralViewController") as! UartSelectPeripheralViewController
        viewController.delegate = self
        viewController.colorForPeripheral = colorForPeripheral
        
        viewController.modalPresentationStyle = .popover
        if let popovoverController = viewController.popoverPresentationController {
            popovoverController.sourceView = sender
            popovoverController.sourceRect = sender.bounds
            popovoverController.delegate = self
            
            // popovoverController.backgroundColor = UIColor.lightGray
        }
        present(viewController, animated: true, completion: nil)
    }
    
    // MARK: - Style
    override func colorForPacket(packet: UartPacket) -> UIColor {
        var color: UIColor?
        if let peripheralId = packet.peripheralId {
            color = colorForPeripheral[peripheralId]
        }
        return color ?? UIColor.black
    }
    
    // MARK: - MqttManagerDelegate
    override func onMqttMessageReceived(message: String, topic: String) {
        guard let blePeripheral = blePeripheral else { return }
        guard let uartData = self.uartData as? UartPacketManager else { DLog("Error send with invalid uartData class"); return }
        
        DispatchQueue.main.async {
            uartData.send(blePeripheral: blePeripheral, text: message, wasReceivedFromMqtt: true)
        }
    }
}


// MARK: - UartSelectPeripheralViewControllerDelegate
extension UartModeViewController: UartSelectPeripheralViewControllerDelegate {
    func onUartSendToChanged(uuid: UUID?, name: String) {
        multiUartSendToPeripheralId = uuid
        sendPeripheralButton?.setTitle(name, for: .normal)
    }
}
