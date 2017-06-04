//
//  MqttManager.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import Foundation
import CocoaMQTT

protocol MqttManagerDelegate: class {
    func onMqttConnected()
    func onMqttDisconnected()
    func onMqttMessageReceived(message: String, topic: String)
    func onMqttError(message: String)
}

class MqttManager {
    enum ConnectionStatus {
        case connecting
        case connected
        case disconnecting
        case disconnected
        case error
        case none
    }

    enum MqttQos: Int {
        case atMostOnce = 0
        case atLeastOnce = 1
        case exactlyOnce = 2
    }

    // Singleton
    static let sharedInstance = MqttManager()

    // Constants
    private static let defaultKeepAliveInterval: Int32 = 60

    // Data
    weak var delegate: MqttManagerDelegate?
    var status = ConnectionStatus.none

    private var mqttClient: CocoaMQTT?

    //
    private init() {
    }

    func connectFromSavedSettings() {
        let mqttSettings = MqttSettings.sharedInstance

        if let host = mqttSettings.serverAddress {
            let port = mqttSettings.serverPort
            let username = mqttSettings.username
            let password = mqttSettings.password

            connect(host: host, port: port, username: username, password: password, cleanSession: true)
        }
    }

    func connect(host: String, port: Int, username: String?, password: String?, cleanSession: Bool) {

        guard !host.isEmpty else {
            delegate?.onMqttDisconnected()
            return
        }

        // Init connection process
        MqttSettings.sharedInstance.isConnected = true
        status = .connecting

        // Configure MQTT connection
        let clientId = "Bluefruit_" + String(ProcessInfo().processIdentifier)

        mqttClient = CocoaMQTT(clientID: clientId, host: host, port: UInt16(port))
        if let mqttClient = mqttClient {

            mqttClient.username = username
            mqttClient.password = password

            //mqtt.willMessage = CocoaMQTTWill(topic: "/will", message: "dieout")
            mqttClient.keepAlive = UInt16(MqttManager.defaultKeepAliveInterval)
            mqttClient.cleanSession = cleanSession
            mqttClient.delegate = self
            mqttClient.connect()
        } else {
            delegate?.onMqttError(message: "Mqtt initialization error")
            status = .error
        }
    }

    func subscribe(topic: String, qos: MqttQos) {
        let qos = CocoaMQTTQOS(rawValue :UInt8(qos.rawValue))!
        mqttClient?.subscribe(topic, qos: qos)
    }

    func unsubscribe(topic: String) {
        mqttClient?.unsubscribe(topic)
    }

    func publish(message: String, topic: String, qos: MqttQos) {
        let qos = CocoaMQTTQOS(rawValue :UInt8(qos.rawValue))!
        mqttClient?.publish(topic, withString: message, qos: qos)
    }

    func disconnect() {
        MqttSettings.sharedInstance.isConnected = false

        if let client = mqttClient {
            status = .disconnecting
            client.disconnect()
        } else {
            status = .disconnected
        }
    }
}

extension MqttManager: CocoaMQTTDelegate {

    func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int) {
        DLog("didConnect: \(host):\(port)")
        status = .connected
    }

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        DLog("didConnectAck: \(ack)")

        let mqttSettings = MqttSettings.sharedInstance

        if ack == .accept {
            delegate?.onMqttConnected()

            if let topic = mqttSettings.subscribeTopic, mqttSettings.isSubscribeEnabled {
                self.subscribe(topic: topic, qos: mqttSettings.subscribeQos)
            }
        } else {
            // Connection error
            var errorDescription = "Unknown Error"
            switch ack {
            case .accept:
                errorDescription = "No Error"
            case .unacceptableProtocolVersion:
                errorDescription = "Proto ver"
            case .identifierRejected:
                errorDescription = "Invalid Id"
            case .serverUnavailable:
                errorDescription = "Invalid Server"
            case .badUsernameOrPassword:
                errorDescription = "Invalid Credentials"
            case .notAuthorized:
                errorDescription = "Authorization Error"
            default:
                errorDescription = "Unknown Error"
            }

            delegate?.onMqttError(message: errorDescription)

            self.disconnect()                       // Stop reconnecting
            mqttSettings.isConnected = false        // Disable automatic connect on start
        }

        self.status = ack == .accept ? ConnectionStatus.connected : ConnectionStatus.error      // Set AFTER sending onMqttError (so the delegate can detect that was an error while stablishing connection)

    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        DLog("mqttDidDisconnect: \(err?.localizedDescription ?? "")")

        if let error = err, status == .connecting {
            delegate?.onMqttError(message: error.localizedDescription)
        }

        status = err == nil ? .disconnected : .error
        delegate?.onMqttDisconnected()
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        DLog("didPublishMessage")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        DLog("didPublishAck")
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {

        if let string = message.string {
            DLog("didReceiveMessage: \(string) from topic: \(message.topic)")
            delegate?.onMqttMessageReceived(message: string, topic: message.topic)
        } else {
            DLog("didReceiveMessage but message is not defined")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        DLog("didSubscribeTopic")
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        DLog("didUnsubscribeTopic")
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        //DLog("mqttDidPing")

    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
       // DLog("mqttDidReceivePong")

    }
}
