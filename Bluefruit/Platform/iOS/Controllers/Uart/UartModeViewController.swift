//
//  UartModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UartModeViewController: UartBaseViewController {

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        let localizationManager = LocalizationManager.sharedInstance
        let name = blePeripheral?.name ?? localizationManager.localizedString("peripherallist_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("uart_navigation_title_format"), arguments: [name])  : localizationManager.localizedString("uart_tab_title")

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
        let colors = UartColors.defaultColors()
        colorForPeripheral.removeAll()
        
        // Enable uart
        if isInMultiUartMode() {            // Multiple peripheral mode
            let blePeripherals = BleManager.sharedInstance.connectedPeripherals()
            for (i, blePeripheral) in blePeripherals.enumerated() {
                colorForPeripheral[blePeripheral.identifier] = colors[i % colors.count]
                blePeripheral.uartEnable(uartRxHandler: uartData.rxPacketReceived) { [weak self] error in
                    guard let context = self else { return }
                    
                    let peripheralName = blePeripheral.name ?? blePeripheral.identifier.uuidString
                    DispatchQueue.main.async { [unowned context] in
                        guard error == nil else {
                            DLog("Error initializing uart")
                            context.dismiss(animated: true, completion: { [weak self] () -> Void in
                                if let context = self {
                                    showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized for peripheral: \(peripheralName)")
                                    
                                    BleManager.sharedInstance.disconnect(from: blePeripheral)
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
                
                DispatchQueue.main.async { [unowned context] in
                    guard error == nil else {
                        DLog("Error initializing uart")
                        context.dismiss(animated: true, completion: { [weak self] () -> Void in
                            if let context = self {
                                showErrorAlert(from: context, title: "Error", message: "Uart protocol can not be initialized")
                                
                                if let blePeripheral = context.blePeripheral {
                                    BleManager.sharedInstance.disconnect(from: blePeripheral)
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
        if let blePeripheral = blePeripheral {      // Single peripheral mode
            uartData.send(blePeripheral: blePeripheral, text: message)
        } else {      // Multiple peripheral mode
            let peripherals = BleManager.sharedInstance.connectedPeripherals()
            
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
        let color = colorForPeripheral[packet.peripheralId] ?? UIColor.black
        return color
    }
    
}
