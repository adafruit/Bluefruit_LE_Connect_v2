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
    static let kExportFormats: [ExportFormat] = [.txt, .csv, .json/*, .xml*/]
    #endif
    
    override init() {
        super.init()
        
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(didReceiveData(_:)), name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
    }
    
    deinit {
        let notificationCenter =  NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: UartManager.UartNotifications.DidReceiveData.rawValue, object: nil)
    }
    
    // MARK: - Uart
    func sendMessageToUart(text: String) {
        sendMessageToUart(text, wasReceivedFromMqtt: false)
    }
    
    func sendMessageToUart(text: String, wasReceivedFromMqtt: Bool) {
        
        // Mqtt publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
            if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.TX.rawValue) {
                let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.TX.rawValue)
                MqttManager.sharedInstance.publish(text, topic: topic, qos: qos)
            }
        }
        
        // Create data and send to Uart
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
            
            dispatch_async(dispatch_get_main_queue(), {[unowned self] in
                self.delegate?.addChunkToUI(dataChunk)
                })
            
            if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .Transmit) {
                UartManager.sharedInstance.sendChunk(dataChunk)
            }
        }
    }
    
    func didReceiveData(notification: NSNotification) {
        if let dataChunk = notification.userInfo?["dataChunk"] as? UartDataChunk {
            receivedChunk(dataChunk)
        }
    }
    
    private func receivedChunk(dataChunk: UartDataChunk) {
        
        // Mqtt publish to RX
        let mqttSettings = MqttSettings.sharedInstance
        if mqttSettings.isPublishEnabled {
            if let message = NSString(data: dataChunk.data, encoding: NSUTF8StringEncoding) {
                if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.RX.rawValue) {
                    let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.RX.rawValue)
                    MqttManager.sharedInstance.publish(message as String, topic: topic, qos: qos)
                }
            }
        }

        // Add to UI
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.delegate?.addChunkToUI(dataChunk)
            })
        
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
        
        let textAttributes: [String:AnyObject] = [NSFontAttributeName: font, NSForegroundColorAttributeName: color]
        
        if (useHexMode) {
            let hexValue = hexString(data)
            attributedString = NSAttributedString(string: hexValue, attributes: textAttributes)
        }
        else {
            if let value = NSString(data:data, encoding: NSASCIIStringEncoding) as String? {
                
                var representableValue: String
                
                if Preferences.uartShowInvisibleChars {
                    representableValue = ""
                    for scalar in value.unicodeScalars {
                        let isRepresentable = scalar.value>=32 && scalar.value<127
                        //DLog("\(scalar.value). isVis: \( isRepresentable ? "true":"false" )")
                        representableValue.append(isRepresentable ? scalar:UnicodeScalar("�"))
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
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        UartManager.sharedInstance.peripheral(peripheral, didModifyServices: invalidatedServices)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverServices:error)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        UartManager.sharedInstance.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: error)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        UartManager.sharedInstance.peripheral(peripheral, didUpdateValueForCharacteristic: characteristic, error: error)
    }
}

// MARK: - MqttManagerDelegate
extension UartModuleManager : MqttManagerDelegate {
    func onMqttConnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            })
    }
    
    func onMqttDisconnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.delegate?.mqttUpdateStatusUI()
            })
        
    }
    
    func onMqttMessageReceived(message : String, topic: String) {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.sendMessageToUart(message, wasReceivedFromMqtt: true)
            })
    }
    
    func onMqttError(message : String) {
        let mqttManager = MqttManager.sharedInstance
        let status = mqttManager.status
        let isConnectionError = status == .Connecting
        
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.delegate?.mqttError(message, isConnectionError: isConnectionError)
            })
    }
}
