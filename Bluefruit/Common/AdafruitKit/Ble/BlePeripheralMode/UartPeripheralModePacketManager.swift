//
//  UartPeripheralModePacketManager.swift
//  Bluefruit
//
//  Created by Antonio on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

class UartPeripheralModePacketManager: UartPacketManagerBase {

    // MARK: - Send data
    func send(uartPeripheralService: UartPeripheralService, data: Data?, completion: ((Error?) -> Void)? = nil) {
        sentBytes += Int64(data?.count ?? 0)
        uartPeripheralService.rx = data
    }

    func send(uartPeripheralService: UartPeripheralService, text: String, wasReceivedFromMqtt: Bool = false) {

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
            let uartPacket = UartPacket(peripheralId: nil, mode: .rx, data: data)

            DispatchQueue.main.async { [unowned self] in
                self.delegate?.onUartPacket(uartPacket)
            }

            #if os(iOS)
                let shouldBeSent = !wasReceivedFromMqtt || (isMqttEnabled && MqttSettings.sharedInstance.subscribeBehaviour == .transmit)
            #else
                let shouldBeSent = true
            #endif

            if shouldBeSent {
                send(uartPeripheralService: uartPeripheralService, data: data)

                packetsSemaphore.wait()            // don't append more data, till the delegate has finished processing it
                packets.append(uartPacket)
                packetsSemaphore.signal()
            }
        }
    }
}
