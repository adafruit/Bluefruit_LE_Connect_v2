//
//  UartPacketManager.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

protocol UartPacketManagerDelegate: class {
    //func onUartRx(cache: [UartPacket])
    func addPacketToUI(packet: UartPacket)
    func mqttUpdateStatusUI()
    func mqttError(message: String, isConnectionError: Bool)
}

class UartPacketManager {
    // Data
    var enabled: Bool = false {
        didSet {
            if enabled != oldValue {
                registerNotifications(enabled: enabled)
            }
        }
    }
    
    weak var delegate: UartPacketManagerDelegate?
    fileprivate var cachedRx = [UartPacket]()
    fileprivate var cachedRxSemaphore = DispatchSemaphore(value: 1)
    
    var receivedBytes: Int64 = 0
    var sentBytes: Int64 = 0
    
    init(delegate: UartPacketManagerDelegate) {
        self.delegate = delegate
        
        enabled = true
    }
    
    deinit {
        enabled = false
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
        clearRxCache()
    }
    
    // MARK: - Send data
    
    
    private func uartSend(blePeripheral: BlePeripheral, data: Data?, completion: ((Error?) -> Void)? = nil) {
        sentBytes += data?.count ?? 0
        blePeripheral.uartSend(data: data, completion: completion)
    }

    private func uartSendWithAndWaitReply(blePeripheral: BlePeripheral, data: Data?, writeCompletion: ((Error?) -> Void)? = nil, readTimeout: Double? = BlePeripheral.kUartReplyDefaultTimeout, readCompletion: @escaping BlePeripheral.CapturedReadCompletionHandler) {
        sentBytes += data?.count ?? 0
        blePeripheral.uartSendWithAndWaitReply(data: data, writeCompletion: writeCompletion, readTimeout: readTimeout, readCompletion: readCompletion)
    }

    func uartSend(blePeripheral: BlePeripheral, text: String, wasReceivedFromMqtt: Bool = false) {
        /*
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
            if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.TX.rawValue) {
                let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.TX.rawValue)
                MqttManager.sharedInstance.publish(text, topic: topic, qos: qos)
            }
        }*/
        
        // Create data and send to Uart
        if let data = text.data(using: .utf8) {
            let uartPacket = UartPacket(timestamp: CFAbsoluteTimeGetCurrent(), mode: .tx, data: data)
            
            self.delegate?.addPacketToUI(packet: uartPacket)
            
            /*
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .transmit) {
                UartManager.sharedInstance.sendChunk(dataChunk)
            }*/
        }
    }
    

    // MARK: - Received data
    func uartRxPacketReceived(data: Data?, error: Error?) {
        
        guard error == nil else {
            DLog("uartRxPacketReceived error: \(error!)")
            return
        }
        
        guard let data = data else {
            return
        }
        
        let uartPacket = UartPacket(timestamp: CFAbsoluteTimeGetCurrent(), mode: .rx, data: data)
        
        // Mqtt publish to RX
        /*
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let message = String(data: uartPacket.data, encoding: .utf8) {
                if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.rx.rawValue) {
                    let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.rx.rawValue)
                    MqttManager.sharedInstance.publish(message, topic: topic, qos: qos)
                }
            }
        }*/
        
        cachedRxSemaphore.wait()            // don't append more data, till the delegate has finished processing it
        cachedRx.append(uartPacket)
        
        // Send data to delegate
        delegate?.addPacketToUI(packet: uartPacket)
        
        //DLog("cachedRxData: \(cachedRxData.count)")
        
        cachedRxSemaphore.signal()
    }
    
    func clearRxCache() {
        cachedRx.removeAll()
    }
    
    func removeRxCacheFirst(n: Int) {
        if n <= cachedRx.count {
            cachedRx.removeFirst(n)
        }
        else {
            clearRxCache()
        }
    }
        
    func rxCache() -> [UartPacket] {
        return cachedRx
    }
    
    
    // MARK: - Counters
    func resetCounters() {
        receivedBytes = 0
        sentBytes = 0
    }
    
    
}
