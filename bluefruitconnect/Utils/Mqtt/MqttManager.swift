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
        status = ConnectionStatus.Connecting
        
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
        }
        else {
          delegate?.onMqttError(message: "Mqtt initialization error")
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

    func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int) {
      DLog(message: "didConnect: \(host):\(port)")
        self.status = ConnectionStatus.Connected
    }
    
  func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
    DLog(message: "didConnectAck: \(ack)")
        
        let mqttSettings = MqttSettings.sharedInstance
        
        if (ack == .accept) {
            delegate?.onMqttConnected()
            
          if let topic = mqttSettings.subscribeTopic, mqttSettings.isSubscribeEnabled {
            self.subscribe(topic: topic, qos: mqttSettings.subscribeQos)
            }
        }
        else {
            // Connection error
            var errorDescription = "Unknown Error"
          switch(ack) {
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
          case .reserved:
            errorDescription = "Reserved"
          }
            
          delegate?.onMqttError(message: errorDescription);
            
            self.disconnect()                       // Stop reconnecting
            mqttSettings.isConnected = false        // Disable automatic connect on start
        }

        self.status = (ack == .accept) ? ConnectionStatus.Connected : ConnectionStatus.Error      // Set AFTER sending onMqttError (so the delegate can detect that was an error while stablishing connection)

    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
      DLog(message: "mqttDidDisconnect: \(err != nil ? err! : NSError())")

      if let error = err, status == .Connecting {
        delegate?.onMqttError(message: error.localizedDescription)
        }
       
        status = err == nil ? .Disconnected : .Error
        delegate?.onMqttDisconnected()
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        
        if let string = message.string {
          DLog(message: "didReceiveMessage: \(string) from topic: \(message.topic)")
          delegate?.onMqttMessageReceived(message: string, topic: message.topic)
        }
        else {
          DLog(message: "didReceiveMessage but message is not defined")
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        DLog(message: "didPublishMessage")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        DLog(message: "didSubscribeTopic")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        DLog(message: "didUnsubscribeTopic")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        DLog(message: "didPublishAck")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        DLog(message: "mqttDidPing")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        DLog(message: "mqttDidReceivePong")
    }
}
