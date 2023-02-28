//
//  UartPacketManager.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

class UartPacketManager: UartPacketManagerBase {

    // Params
    var isResetPacketsOnReconnectionEnabled = true
    
    // MARK: - Lifecycle
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
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main) {
                [weak self] _ in
                guard let self = self else { return }
                if self.isResetPacketsOnReconnectionEnabled {
                    self.clearPacketsCache()
                }
            }
        } else {
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
        }
    }
    
    // MARK: - Send data
    private func sendUart(blePeripheral: BlePeripheral, data: Data?, progress: ((Float)->Void)? = nil, completion: ((Error?) -> Void)? = nil) {
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

    /*
        Send data to MQTT (if enabled) and also to UART (if MQTT configuration allows it)
    */
    func send(blePeripheral: BlePeripheral, data: Data, wasReceivedFromMqtt: Bool = false) {

         #if MQTT_ENABLED
        if isMqttEnabled {
            // Mqtt publish to TX
            let mqttSettings = MqttSettings.shared
            if mqttSettings.isPublishEnabled, let text = String(data: data, encoding: .utf8) {
                if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.tx.rawValue) {
                    let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.tx.rawValue)
                    MqttManager.shared.publish(message: text, topic: topic, qos: qos)
                }
            }
        }
        #endif

        // Create data and send to Uart
        let uartPacket = UartPacket(peripheralId: blePeripheral.identifier, mode: .tx, data: data)
        
        // Add Packet
        packetsSemaphore.wait()
        packets.append(uartPacket)
        packetsSemaphore.signal()
        
        DispatchQueue.main.async {
            self.delegate?.onUartPacket(uartPacket)
        }
        
        #if MQTT_ENABLED
        let shouldBeSent = !wasReceivedFromMqtt || (isMqttEnabled && MqttSettings.shared.subscribeBehaviour == .transmit)
        #else
        let shouldBeSent = true
        #endif
        
        if shouldBeSent {
            sendUart(blePeripheral: blePeripheral, data: data)
        }
    }
    
    // MARK: - Force reset
    func reset(blePeripheral: BlePeripheral) {
        blePeripheral.reset()
    }

}
