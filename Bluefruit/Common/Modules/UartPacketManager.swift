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
    
    init(timestamp: CFAbsoluteTime, mode: TransferMode, data: Data) {
        self.timestamp = timestamp
        self.mode = mode
        self.data = data
    }
}


class UartPacketManager {
    // Data
    weak var delegate: UartPacketManagerDelegate?
    fileprivate var packets = [UartPacket]()
    fileprivate var packetsSemaphore = DispatchSemaphore(value: 1)
    
    var receivedBytes: Int64 = 0
    var sentBytes: Int64 = 0
    
    init(delegate: UartPacketManagerDelegate) {
        self.delegate = delegate
        
        registerNotifications(enabled: true)
    }
    
    deinit {
        registerNotifications(enabled: false)
    }
    
    // MARK: - BLE Notifications
    var didConnectToPeripheralObserver: NSObjectProtocol?
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: OperationQueue.main, using: didConnectToPeripheral)
        }
        else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    private func didConnectToPeripheral(notification: Notification) {
        clearPacketsCache()
    }
    
    // MARK: - Send data
    private func send(blePeripheral: BlePeripheral, data: Data?, completion: ((Error?) -> Void)? = nil) {
        blePeripheral.uartSend(data: data, completion: completion)
    }

    /*
    private func sendAndWaitReply(blePeripheral: BlePeripheral, data: Data?, writeCompletion: ((Error?) -> Void)? = nil, readTimeout: Double? = BlePeripheral.kUartReplyDefaultTimeout, readCompletion: @escaping BlePeripheral.CapturedReadCompletionHandler) {
        blePeripheral.uartSendWithAndWaitReply(data: data, writeCompletion: writeCompletion, readTimeout: readTimeout, readCompletion: readCompletion)
    }*/

    func send(blePeripheral: BlePeripheral, text: String, wasReceivedFromMqtt: Bool = false) {
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.tx.rawValue) {
                let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.tx.rawValue)
                MqttManager.sharedInstance.publish(message: text, topic: topic, qos: qos)
            }
        }
        
        // Create data and send to Uart
        if let data = text.data(using: .utf8) {
            let uartPacket = UartPacket(timestamp: CFAbsoluteTimeGetCurrent(), mode: .tx, data: data)
            
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.onUartPacket(uartPacket)
            }
            
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .transmit) {
                send(blePeripheral: blePeripheral, data: data)
                
                packetsSemaphore.wait()            // don't append more data, till the delegate has finished processing it
                sentBytes += data.count
                packets.append(uartPacket)
                packetsSemaphore.signal()
            }
        }
    }

    // MARK: - Received data
    func rxPacketReceived(data: Data?, error: Error?) {
        
        guard error == nil else {
            DLog("uartRxPacketReceived error: \(error!)")
            return
        }
        
        guard let data = data else {
            return
        }
        
        let uartPacket = UartPacket(timestamp: CFAbsoluteTimeGetCurrent(), mode: .rx, data: data)
        
        // Mqtt publish to RX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let message = String(data: uartPacket.data, encoding: .utf8) {
                if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.rx.rawValue) {
                    let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.rx.rawValue)
                    MqttManager.sharedInstance.publish(message: message, topic: topic, qos: qos)
                }
            }
        }
        
        packetsSemaphore.wait()            // don't append more data, till the delegate has finished processing it
        receivedBytes += data.count
        packets.append(uartPacket)
        
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

