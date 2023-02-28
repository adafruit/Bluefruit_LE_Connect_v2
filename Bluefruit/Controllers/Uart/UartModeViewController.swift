//
//  UartModeViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class UartModeViewController: UartBaseViewController {

    // UI
    @IBOutlet weak var sendPeripheralButton: UIButton!
    @IBOutlet var inputAccesoryView: UIView!
    @IBOutlet weak var terminalTitleView: UIView!
    @IBOutlet weak var terminalTitleLabel: UILabel!
    
    // Params
    var uartServiceUuid: CBUUID = BlePeripheral.kUartServiceUUID
    var txCharacteristicUuid: CBUUID = BlePeripheral.kUartTxCharacteristicUUID
    var rxCharacteristicUuid: CBUUID = BlePeripheral.kUartRxCharacteristicUUID
    var isResetPacketsOnReconnectionEnabled = true

    // Data
    private var colorForPeripheral = [UUID: UIColor]()
    private var multiUartSendToPeripheralId: UUID?       // nil = all peripherals
    private var terminalTitle: String?
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        let localizationManager = LocalizationManager.shared
        let name = blePeripheral?.name ?? localizationManager.localizedString("scanner_unnamed")
        self.title = traitCollection.horizontalSizeClass == .regular ? String(format: localizationManager.localizedString("uart_navigation_title_format"), arguments: [name])  : localizationManager.localizedString("uart_tab_title")
        
        // Setup controls
        sendPeripheralButton.isHidden = !isInMultiUartMode()
        
        inputTextField.inputAccessoryView = inputAccesoryView
                
        // Localization
        sendPeripheralButton.setTitle(localizationManager.localizedString("uart_send_toall_action"), for: .normal)     // Default value
        
        // Init Uart
        let uartPacketManager = UartPacketManager(delegate: self, isPacketCacheEnabled: true, isMqttEnabled: true)
        uartPacketManager.isResetPacketsOnReconnectionEnabled = isResetPacketsOnReconnectionEnabled
        uartData = uartPacketManager
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        // Notifications
        registerNotifications(enabled: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Notifications
        registerNotifications(enabled: false)
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
                blePeripheral.uartEnable(uartServiceUuid: uartServiceUuid,
                                         txCharacteristicUuid: txCharacteristicUuid,
                                         rxCharacteristicUuid: rxCharacteristicUuid,
                                         uartRxHandler: uartData.rxPacketReceived
                ) { [weak self] error in
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
            blePeripheral.uartEnable(uartServiceUuid: uartServiceUuid,
                                     txCharacteristicUuid: txCharacteristicUuid,
                                     rxCharacteristicUuid: rxCharacteristicUuid,
                                     uartRxHandler: uartData.rxPacketReceived
            ) { [weak self] error in
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

    override func send(data: Data) {
        guard let uartData = self.uartData as? UartPacketManager else { DLog("Error send with invalid uartData class"); return }
        
        if let blePeripheral = blePeripheral {      // Single peripheral mode
            uartData.send(blePeripheral: blePeripheral, data: data)
        } else {      // Multiple peripheral mode
            let peripherals = BleManager.shared.connectedPeripherals()
            
            if let multiUartSendToPeripheralId = multiUartSendToPeripheralId {
                // Send to single peripheral
                if let peripheral = peripherals.first(where: {$0.identifier == multiUartSendToPeripheralId}) {
                    uartData.send(blePeripheral: peripheral, data: data)
                }
            } else {
                // Send to all peripherals
                for peripheral in peripherals {
                    uartData.send(blePeripheral: peripheral, data: data)
                }
            }
        }
    }
    
    
    @objc override func reloadData() {
        super.reloadData()
        updateTerminalTitle()
    }
    
    private static let oscTitleRegex = #"\x1b]0\;(?<title>.+?(?=\x1b\\))"#
    
    override func onUartPacketTextPreProcess(packet: UartPacket) -> UartPacket {
        // Terminal OSC commands
        guard Preferences.uartDisplayMode == .terminal,
              packet.mode == .rx,
              let text = String(data: packet.data, encoding: .utf8)
        else { return packet }
       
        
        let matchingStrings = text.matchingStrings(regex: Self.oscTitleRegex)
        guard let result = matchingStrings.last, result.count > 1 else { return packet }
        
        terminalTitle = result[1].0         // result[1] contains the <title> in the regex expression
        DLog("OSC title found: \(String(describing: terminalTitle))")
        updateTerminalTitle()
        
        // Remove range of matching string
        let expressionRange = result[0].1        // result[0] contains the full match for the regex expression
        let remainingText = (text as NSString).replacingCharacters(in: NSMakeRange(expressionRange.location, expressionRange.length+2), with: "")
        let remainingData = remainingText.data(using: .utf8) ?? Data()
        return UartPacket(peripheralId: packet.peripheralId, mode: packet.mode, data: remainingData)
    }
    
    private func updateTerminalTitle() {
        terminalTitleView.isHidden = Preferences.uartDisplayMode != .terminal || (terminalTitle?.isEmpty ?? true)
        terminalTitleLabel.text = terminalTitle
    }
    
    // MARK: - BLE Notifications
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var willReconnectToPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main) { [weak self] _ in
                self?.setupUart()
            }
            willReconnectToPeripheralObserver = notificationCenter.addObserver(forName: .willReconnectToPeripheral, object: nil, queue: .main) { [weak self] _ in
                DLog("Reconnecting...")
                self?.updateUartReadyUI(isReady: false)
            }
        } else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let willReconnectToPeripheralObserver = willReconnectToPeripheralObserver {notificationCenter.removeObserver(willReconnectToPeripheralObserver)}
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
    
    @IBAction func onSendCtrlC(_ sender: Any) {
        let data = Data([0x03])
        send(data: data)

    }
    
    @IBAction func onSendCtrlD(_ sender: Any) {
        let data = Data([0x04])
        send(data: data)
    }
    
    @IBAction func onSendCtrlZ(_ sender: Any) {
        let data = Data([0x1a])
        send(data: data)
    }
    
    // MARK: - Style
    override func colorForPacket(packet: UartPacket) -> UIColor {
        guard Preferences.uartDisplayMode != .terminal else  { return UIColor.black }
        
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
        guard let data = message.data(using: .utf8) else { DLog("Warning: cant convert message to data"); return }
        
        DispatchQueue.main.async {
            uartData.send(blePeripheral: blePeripheral, data: data, wasReceivedFromMqtt: true)
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
