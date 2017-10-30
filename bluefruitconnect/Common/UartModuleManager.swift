//
//  UartData.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

protocol UartModuleDelegate: class {
    func addChunkToUI(dataChunk: UartDataChunk)
    func mqttUpdateStatusUI()
    func mqttError(message: String, isConnectionError: Bool)
}

// Wrapper around UartManager to implenent an UartModule
class UartModuleManager: NSObject {
    enum DisplayMode {
        case Text           // Display a TextView with all uart data as a String
        case Table          // Display a table where each data chunk is a row
    }
    
    enum ExportFormat: String {
        case txt = "txt"
        case csv = "csv"
        case json = "json"
        case xml = "xml"
        case bin = "bin"
    }
    
    // Proxies
    var blePeripheral : BlePeripheral? {
        get {
        return UartManager.sharedInstance.blePeripheral
        }
        set {
            UartManager.sharedInstance.blePeripheral = newValue
        }
    }
    
    var dataBufferEnabled : Bool {
        set {
            UartManager.sharedInstance.dataBufferEnabled = newValue
        }
        get {
            return UartManager.sharedInstance.dataBufferEnabled
        }
    }
    
    var dataBuffer : [UartDataChunk] {
        return UartManager.sharedInstance.dataBuffer
    }
    
    // Current State
    weak var delegate: UartModuleDelegate?
    
    // Export
    #if os(OSX)
    static let kExportFormats: [ExportFormat] = [.txt, .csv, .json, .xml, .bin]
    #else
    static let kExportFormats: [ExportFormat] = [.txt, .csv, .json/*, .xml*/, .bin]
    #endif
    
    override init() {
        super.init()
        
        let notificationCenter =  NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didReceiveData), name: .uartDidReceiveData, object: nil)
    }
    
    deinit {
        let notificationCenter =  NotificationCenter.default
        notificationCenter.removeObserver(self, name: .uartDidReceiveData, object: nil)
    }
    
    // MARK: - Uart
    func sendMessageToUart(text: String) {
      sendMessageToUart(text: text, wasReceivedFromMqtt: false)
    }
    
    func sendMessageToUart(text: String, wasReceivedFromMqtt: Bool) {
        
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
          if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.TX.rawValue) {
            let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.TX.rawValue)
            MqttManager.sharedInstance.publish(message: text, topic: topic, qos: qos)
            }
        }
        
        // Create data and send to Uart
      if let data = text.data(using: String.Encoding.utf8) {
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data as NSData)
            
            DispatchQueue.main.async {[unowned self] in
              self.delegate?.addChunkToUI(dataChunk: dataChunk)
                }
            
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .Transmit) {
              UartManager.sharedInstance.sendChunk(dataChunk: dataChunk)
            }
        }
    }
    
  @objc func didReceiveData(notification: NSNotification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
          receivedChunk(dataChunk: dataChunk)
        }
    }
    
    private func receivedChunk(dataChunk: UartDataChunk) {
        
        // Mqtt publish to RX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
          if let message = NSString(data: dataChunk.data as Data, encoding: String.Encoding.utf8.rawValue) {
            if let topic = mqttSettings.getPublishTopic(index: MqttSettings.PublishFeed.RX.rawValue) {
              let qos = mqttSettings.getPublishQos(index: MqttSettings.PublishFeed.RX.rawValue)
              MqttManager.sharedInstance.publish(message: message as String, topic: topic, qos: qos)
                }
            }
        }

        // Add to UI
        DispatchQueue.main.async {[unowned self] in
          self.delegate?.addChunkToUI(dataChunk: dataChunk)
            }
        
    }
    
    
    func isReady() -> Bool {
        return UartManager.sharedInstance.isReady()
    }
    
    func clearData() {
        UartManager.sharedInstance.clearData()
    }
    
    // MARK: - UI Utils
    static func attributeTextFromData(data: NSData, useHexMode: Bool, color: Color, font: Font) -> NSAttributedString? {
        var attributedString : NSAttributedString?
        
      let textAttributes: [NSAttributedStringKey: Any] = [.font: font, .foregroundColor: color]
        
        if (useHexMode) {
          let hexValue = hexString(data: data)
            attributedString = NSAttributedString(string: hexValue, attributes: textAttributes)
        }
        else {
          if let value = String(data: data as Data, encoding: .ascii) {
                
                var representableValue: String
                
                if Preferences.uartShowInvisibleChars {
                    representableValue = ""
                    for scalar in value.unicodeScalars {
                        let isRepresentable = scalar.value>=32 && scalar.value<127
                        //DLog("\(scalar.value). isVis: \( isRepresentable ? "true":"false" )")
                        let scalarString: String = isRepresentable ? String(scalar) : String(UnicodeScalar("�")!)
                        representableValue.append(scalarString)
                    }
                }
                else {
                    representableValue = value
                }
                
                attributedString = NSAttributedString(string: representableValue, attributes: textAttributes)
            }
        }
        
        return attributedString
    }
}

// MARK: - CBPeripheralDelegate
extension UartModuleManager: CBPeripheralDelegate {
    // Pass peripheral callbacks to UartData
    
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        UartManager.sharedInstance.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverServices:error)
    }
    
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)
    }
    
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        UartManager.sharedInstance.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
    }
}

// MARK: - MqttManagerDelegate
extension UartModuleManager: MqttManagerDelegate {
    func onMqttConnected() {
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            }
    }
    
    func onMqttDisconnected() {
        DispatchQueue.main.async { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            }
        
    }
    
    func onMqttMessageReceived(message: String, topic: String) {
        DispatchQueue.main.async { [unowned self] in
          self.sendMessageToUart(text: message, wasReceivedFromMqtt: true)
            }
    }
    
    func onMqttError(message: String) {
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        let isConnectionError = status == .Connecting
        
       DispatchQueue.main.async { [unowned self] in
        self.delegate?.mqttError(message: message, isConnectionError: isConnectionError)
            }
    }
}
