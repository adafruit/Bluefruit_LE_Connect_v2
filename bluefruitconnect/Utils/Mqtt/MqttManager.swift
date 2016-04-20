//
//  MqttManager.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import Foundation
import CocoaMQTT

protocol MqttManagerDelegate : class {
    func onMqttConnected()
    func onMqttDisconnected()
    func onMqttMessageReceived(message : String, topic: String)
    func onMqttError(message : String)
}

class MqttManager
{
    enum ConnectionStatus {
        case Connecting
        case Connected
        case Disconnecting
        case Disconnected
        case Error
        case None
    }
    
    enum MqttQos : Int  {
        case AtMostOnce = 0
        case AtLeastOnce = 1
        case ExactlyOnce = 2
    }
    
    // Singleton
    static let sharedInstance = MqttManager()
    
    // Constants
    private static let defaultKeepAliveInterval : Int32 = 60;
    
    // Data
    weak var delegate : MqttManagerDelegate?
    var status = ConnectionStatus.None

    private var mqttClient : CocoaMQTT?
    
    //
    private init() {
    }

    func connectFromSavedSettings() {
        let mqttSettings = MqttSettings.sharedInstance;
        
        if let host = mqttSettings.serverAddress {
            let port = mqttSettings.serverPort
            let username = mqttSettings.username
            let password = mqttSettings.password

            connect(host, port: port, username: username, password: password, cleanSession: true)
        }
    }

    func connect(host: String, port: Int, username: String?, password: String?, cleanSession: Bool) {
        
        guard !host.isEmpty else {
            delegate?.onMqttDisconnected()
            return
        }

        // Init connection process
        MqttSettings.sharedInstance.isConnected = true
        status = ConnectionStatus.Connecting
        
        // Configure MQTT connection
        let clientId = "Bluefruit_" + String(NSProcessInfo().processIdentifier)
        
        mqttClient = CocoaMQTT(clientId: clientId, host: host, port: UInt16(port))
        if let mqttClient = mqttClient {

            mqttClient.username = username
            mqttClient.password = password

            //mqtt.willMessage = CocoaMQTTWill(topic: "/will", message: "dieout")
            mqttClient.keepAlive = UInt16(MqttManager.defaultKeepAliveInterval)
            mqttClient.cleanSess = cleanSession
            mqttClient.delegate = self
            mqttClient.connect()
        }
        else {
            delegate?.onMqttError("Mqtt initialization error")
            status = .Error
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
            status = .Disconnecting
            client.disconnect()
        }
        else {
            status = .Disconnected
        }
    }
}

extension MqttManager: CocoaMQTTDelegate {
    
    func mqtt(mqtt: CocoaMQTT, didConnect host: String, port: Int) {
        DLog("didConnect: \(host):\(port)")
        self.status = ConnectionStatus.Connected
    }
    
    func mqtt(mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        DLog("didConnectAck: \(ack)")
        
        let mqttSettings = MqttSettings.sharedInstance
        
        if (ack == .ACCEPT) {
            delegate?.onMqttConnected()
            
            if let topic = mqttSettings.subscribeTopic where mqttSettings.isSubscribeEnabled {
                self.subscribe(topic, qos: mqttSettings.subscribeQos)
            }
        }
        else {
            // Connection error
            var errorDescription = "Unknown Error"
            switch(ack) {
            case .ACCEPT:
                errorDescription = "No Error"
            case .PROTO_VER:
                errorDescription = "Proto ver"
            case .INVALID_ID:
                errorDescription = "Invalid Id"
            case .SERVER:
                errorDescription = "Invalid Server"
            case .CREDENTIALS:
                errorDescription = "Invalid Credentials"
            case .AUTH:
                errorDescription = "Authorization Error"
            }
            
            delegate?.onMqttError(errorDescription);
            
            self.disconnect()                       // Stop reconnecting
            mqttSettings.isConnected = false        // Disable automatic connect on start
        }

        self.status = ack == .ACCEPT ? ConnectionStatus.Connected : ConnectionStatus.Error      // Set AFTER sending onMqttError (so the delegate can detect that was an error while stablishing connection)

    }
    
    func mqttDidDisconnect(mqtt: CocoaMQTT, withError err: NSError?) {
        DLog("mqttDidDisconnect: \(err != nil ? err! : "")")

        if let error = err where status == .Connecting {
            delegate?.onMqttError(error.localizedDescription)
        }
       
        status = err == nil ? .Disconnected : .Error
        delegate?.onMqttDisconnected()
    }

    func mqtt(mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        DLog("didPublishMessage")
    }
    
    func mqtt(mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        DLog("didPublishAck")
    }
    
    func mqtt(mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        
        if let string = message.string {
            DLog("didReceiveMessage: \(string) from topic: \(message.topic)")
            delegate?.onMqttMessageReceived(string, topic: message.topic)
        }
        else {
            DLog("didReceiveMessage but message is not defined")
        }
    }
    
    func mqtt(mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        DLog("didSubscribeTopic")
    }
    
    func mqtt(mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        DLog("didUnsubscribeTopic")
    }
    
    func mqttDidPing(mqtt: CocoaMQTT) {
        //DLog("mqttDidPing")
        
    }
    
    func mqttDidReceivePong(mqtt: CocoaMQTT) {
       // DLog("mqttDidReceivePong")
        
    }
}