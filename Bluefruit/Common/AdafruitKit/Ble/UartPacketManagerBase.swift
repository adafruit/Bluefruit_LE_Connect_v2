//
//  UartPacketManagerBase.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
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
    var peripheralId: UUID?
    
    init(peripheralId: UUID?, timestamp: CFAbsoluteTime? = nil, mode: TransferMode, data: Data) {
        self.peripheralId = peripheralId
        self.timestamp = timestamp ?? CFAbsoluteTimeGetCurrent()
        self.mode = mode
        self.data = data
    }
}


class UartPacketManagerBase {
    
    // Data
    internal weak var delegate: UartPacketManagerDelegate?
    internal var packets = [UartPacket]()
    internal var packetsSemaphore = DispatchSemaphore(value: 1)
    internal var isMqttEnabled: Bool
    internal var isPacketCacheEnabled: Bool 
    
    var receivedBytes: Int64 = 0
    var sentBytes: Int64 = 0
    
    init(delegate: UartPacketManagerDelegate?, isPacketCacheEnabled: Bool, isMqttEnabled: Bool) {
        self.isPacketCacheEnabled = isPacketCacheEnabled
        self.isMqttEnabled = isMqttEnabled
        self.delegate = delegate
    }
    
    
    // MARK: - Received data
    func rxPacketReceived(data: Data?, peripheralIdentifier: UUID?, error: Error?) {
        
        guard error == nil else { DLog("uartRxPacketReceived error: \(error!)"); return }
        guard let data = data else { return }
        
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
