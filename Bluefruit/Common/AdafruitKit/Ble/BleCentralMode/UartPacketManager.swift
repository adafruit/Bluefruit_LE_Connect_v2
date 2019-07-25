//
//  UartPacketManager.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

class UartPacketManager: UartPacketManagerBase {

    override init(delegate: UartPacketManagerDelegate?, isPacketCacheEnabled: Bool, isMqttEnabled: Bool) {
        super.init(delegate: delegate, isPacketCacheEnabled: isPacketCacheEnabled, isMqttEnabled: isMqttEnabled)

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
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main) {[weak self] _ in self?.clearPacketsCache()}
        } else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    // MARK: - Send data
    func send(blePeripheral: BlePeripheral, data: Data?, progress: ((Float)->Void)? = nil, completion: ((Error?) -> Void)? = nil) {
        sentBytes += Int64(data?.count ?? 0)
        blePeripheral.uartSend(data: data, progress: progress, completion: completion)
    }

    func sendEachPacketSequentially(blePeripheral: BlePeripheral, data: Data?, withResponseEveryPacketCount: Int, progress: ((Float)->Void)? = nil, completion: ((Error?) -> Void)? = nil) {
        sentBytes += Int64(data?.count ?? 0)
        blePeripheral.uartSendEachPacketSequentially(data: data, withResponseEveryPacketCount: withResponseEveryPacketCount, progress: progress, completion: completion)
    }
    
    func cancelOngoingSendPacketSequentiallyInMainThread(blePeripheral: BlePeripheral) {
        blePeripheral.uartCancelOngoingSendPacketSequentiallyInMainThread()
    }
    
    func sendAndWaitReply(blePeripheral: BlePeripheral, data: Data?, writeProgress: ((Float)->Void)? = nil, writeCompletion: ((Error?) -> Void)? = nil, readTimeout: Double? = BlePeripheral.kUartReplyDefaultTimeout, readCompletion: @escaping BlePeripheral.CapturedReadCompletionHandler) {
        sentBytes += Int64(data?.count ?? 0)
        blePeripheral.uartSendAndWaitReply(data: data, writeProgress: writeProgress, writeCompletion: writeCompletion, readTimeout: readTimeout, readCompletion: readCompletion)
    }

    func send(blePeripheral: BlePeripheral, text: String, wasReceivedFromMqtt: Bool = false) {

        #if os(iOS)
        if isMqttEnabled {
            // Mqtt publish to TX
            let mqttSettings = MqttSettings.shared
            if mqttSettings.isPublishEnabled {
                if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.tx.rawValue) {
                    let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.tx.rawValue)
                    MqttManager.shared.publish(message: text, topic: topic, qos: qos)
                }
            }
        }
        #endif

        // Create data and send to Uart
        if let data = text.data(using: .utf8) {
            let uartPacket = UartPacket(peripheralId: blePeripheral.identifier, mode: .tx, data: data)

            // Add Packet
            packetsSemaphore.wait()
            packets.append(uartPacket)
            packetsSemaphore.signal()
            
            DispatchQueue.main.async {
                self.delegate?.onUartPacket(uartPacket)
            }
            
            #if os(iOS)
            let shouldBeSent = !wasReceivedFromMqtt || (isMqttEnabled && MqttSettings.shared.subscribeBehaviour == .transmit)
            #else
            let shouldBeSent = true
            #endif
            
            if shouldBeSent {
                send(blePeripheral: blePeripheral, data: data)
            }
        }
    }
    
    // MARK: - Force reset
    func reset(blePeripheral: BlePeripheral) {
        blePeripheral.reset()
    }

}
