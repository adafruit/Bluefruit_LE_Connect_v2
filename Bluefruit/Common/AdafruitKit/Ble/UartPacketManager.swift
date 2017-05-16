//
//  UartPacketManager.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

protocol UartPacketManagerDelegate: class {
    func onUartPacket(_ packet: UartPacket)
}

struct UartPacket {      // A packet of data received or sent
    var timestamp: CFAbsoluteTime
    enum TransferMode {
        case tx
        case rx
    }
    var mode: TransferMode
    var data: Data
    var peripheralId: UUID
    
    init(peripheralId: UUID, timestamp: CFAbsoluteTime? = nil, mode: TransferMode, data: Data) {
        self .peripheralId = peripheralId
        self.timestamp = timestamp ?? CFAbsoluteTimeGetCurrent()
        self.mode = mode
        self.data = data
    }
}


class UartPacketManager {
    // Data
    fileprivate weak var delegate: UartPacketManagerDelegate?
    fileprivate var packets = [UartPacket]()
    fileprivate var packetsSemaphore = DispatchSemaphore(value: 1)
    fileprivate var isMqttEnabled: Bool
    fileprivate var isPacketCacheEnabled: Bool
    
    var receivedBytes: Int64 = 0
    var sentBytes: Int64 = 0
    
    init(delegate: UartPacketManagerDelegate?, isPacketCacheEnabled: Bool, isMqttEnabled: Bool) {
        self.isPacketCacheEnabled = isPacketCacheEnabled
        self.isMqttEnabled = isMqttEnabled
        self.delegate = delegate
        
        registerNotifications(enabled: true)
    }
    
    deinit {
        registerNotifications(enabled: false)
    }
    
    // MARK: - BLE Notifications
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: didConnectToPeripheral)
        }
        else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        clearPacketsCache()
    }
    
    // MARK: - Send data
    func send(blePeripheral: BlePeripheral, data: Data?, completion: ((Error?) -> Void)? = nil) {
        sentBytes += Int64(data?.count ?? 0)
        blePeripheral.uartSend(data: data, completion: completion)
    }
    
    func sendAndWaitReply(blePeripheral: BlePeripheral, data: Data?, writeCompletion: ((Error?) -> Void)? = nil, readTimeout: Double? = BlePeripheral.kUartReplyDefaultTimeout, readCompletion: @escaping BlePeripheral.CapturedReadCompletionHandler) {
        sentBytes += Int64(data?.count ?? 0)
        blePeripheral.uartSendWithAndWaitReply(data: data, writeCompletion: writeCompletion, readTimeout: readTimeout, readCompletion: readCompletion)
    }
    
    func send(blePeripheral: BlePeripheral, text: String, wasReceivedFromMqtt: Bool = false) {
        
        #if os(iOS)
        if isMqttEnabled {
            // Mqtt publish to TX
            let mqttSettings = MqttSettings.sharedInstance
            if mqttSettings.isPublishEnabled {
                if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.tx.rawValue) {
                    let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.tx.rawValue)
                    MqttManager.sharedInstance.publish(message: text, topic: topic, qos: qos)
                }
            }
        }
        #endif
        
        // Create data and send to Uart
        if let data = text.data(using: .utf8) {
            let uartPacket = UartPacket(peripheralId: blePeripheral.identifier, mode: .tx, data: data)
            
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.onUartPacket(uartPacket)
            }
            
            #if os(iOS)
                let shouldBeSent = (!wasReceivedFromMqtt || (isMqttEnabled && MqttSettings.sharedInstance.subscribeBehaviour == .transmit))
            #else
                let shouldBeSent = true
            #endif
            
            if shouldBeSent {
                send(blePeripheral: blePeripheral, data: data)
                
                packetsSemaphore.wait()            // don't append more data, till the delegate has finished processing it
                packets.append(uartPacket)
                packetsSemaphore.signal()
            }
        }
    }
    
    // MARK: - Received data
    func rxPacketReceived(data: Data?, peripheralIdentifier: UUID, error: Error?) {
        
        guard error == nil else {
            DLog("uartRxPacketReceived error: \(error!)")
            return
        }
        
        guard let data = data else {
            return
        }
        
        let uartPacket = UartPacket(peripheralId: peripheralIdentifier, mode: .rx, data: data)
        
        // Mqtt publish to RX
        #if os(iOS)
            if isMqttEnabled {
                let mqttSettings = MqttSettings.sharedInstance
                if mqttSettings.isPublishEnabled {
                    if let message = String(data: uartPacket.data, encoding: .utf8) {
                        if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.rx.rawValue) {
                            let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.rx.rawValue)
                            MqttManager.sharedInstance.publish(message: message, topic: topic, qos: qos)
                        }
                    }
                }
            }
        #endif
        
        packetsSemaphore.wait()            // don't append more data, till the delegate has finished processing it
        receivedBytes += Int64(data.count)
        if isPacketCacheEnabled {
            packets.append(uartPacket)
        }
        
        // Send data to delegate
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.onUartPacket(uartPacket)
        }
        
        //DLog("packetsData: \(packetsData.count)")
        
        packetsSemaphore.signal()
    }
    
    func clearPacketsCache() {
        packets.removeAll()
    }
        
    func packetsCache() -> [UartPacket] {
        return packets
    }
    
    // MARK: - Counters
    func resetCounters() {
        receivedBytes = 0
        sentBytes = 0
    }
}
