//
//  UartManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


class UartManager: NSObject {
    
// Use extension Notification.Name instead
//    enum UartNotifications : String {
//        case DidSendData = "didSendData"
//        case DidReceiveData = "didReceiveData"
//        case DidBecomeReady = "didBecomeReady"
//    }
    
    // Constants
    private static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxMaxCharacters = 20

    // Manager
    static let sharedInstance = UartManager()

    // Bluetooth Uart
    private var uartService: CBService?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var txWriteType = CBCharacteristicWriteType.withResponse
    
    var blePeripheral: BlePeripheral? {
        didSet {
            if blePeripheral?.peripheral.identifier != oldValue?.peripheral.identifier {
                // Discover UART
                resetService()
                if let blePeripheral = blePeripheral {
                    DLog(message: "Uart: discover services")
                    blePeripheral.peripheral.discoverServices([CBUUID(string: UartManager.UartServiceUUID)])
                }
            }
        }
    }
    
    // Data
    var dataBuffer = [UartDataChunk]()
    var dataBufferEnabled = Config.uartShowAllUartCommunication

    override init() {
        super.init()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(didDisconnectFromPeripheral), name: .bleDidDisconnectFromPeripheral, object: nil)
    }

    deinit {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: .bleDidDisconnectFromPeripheral, object: nil)
    }
    
    @objc func didDisconnectFromPeripheral(notification: NSNotification) {
        clearData()
        blePeripheral = nil
        resetService()
    }
    
    private func resetService() {
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }
    
    func sendDataWithCrc(data : NSData) {
        
        let len = data.length
        var dataBytes = [UInt8](repeating: 0, count: len)
        var crc: UInt8 = 0
        data.getBytes(&dataBytes, length: len)
        
        for i in dataBytes {    //add all bytes
            crc = crc &+ i
        }
        crc = ~crc  //invert
        
        let dataWithChecksum = NSMutableData(data: data as Data)
        dataWithChecksum.append(&crc, length: 1)
        
        sendData(data: dataWithChecksum)
    }

    func sendData(data: NSData) {
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
        sendChunk(dataChunk: dataChunk)
    }

    func sendChunk(dataChunk: UartDataChunk) {
        
      if let txCharacteristic = txCharacteristic, let blePeripheral = blePeripheral {
            let data = dataChunk.data
        
            if dataBufferEnabled {
                let bytesWithData = blePeripheral.uartData.sentBytes.addingReportingOverflow(Int64(data.length)) // += data.length
                if !bytesWithData.overflow {
                    blePeripheral.uartData.sentBytes = bytesWithData.partialValue
                    dataBuffer.append(dataChunk)
                }
            }
                
            // Split data  in txmaxcharacters bytes packets
            var offset = 0
            repeat {
                let chunkSize = min(data.length-offset, UartManager.TxMaxCharacters)
                // let chunk = NSData(bytesNoCopy: UnsafeMutablePointer<UInt8>(data.bytes) + offset, length: chunkSize, freeWhenDone:false)
                let chunk = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes) + offset, length: chunkSize, freeWhenDone: false)
                if Config.uartLogSend {
                    DLog(message: "send: \(hexString(data: chunk))")
                }
                
                blePeripheral.peripheral.writeValue(chunk as Data, for: txCharacteristic, type: txWriteType)
                offset+=chunkSize
            }while(offset<data.length)
            
        NotificationCenter.default.post(name: .uartDidSendData, object: nil, userInfo:["dataChunk" : dataChunk])
        }
        else {
        DLog(message: "Error: sendChunk with uart not ready")
        }
    }
    
    private func receivedData(data: NSData) {
        
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .RX, data: data)
        receivedChunk(dataChunk: dataChunk)
    }
    
    private func receivedChunk(dataChunk: UartDataChunk) {
        if Config.uartLogReceive {
            DLog(message: "received: \(hexString(data: dataChunk.data))")
        }
        
        if dataBufferEnabled,
            let bytesWithData = blePeripheral?.uartData.receivedBytes.addingReportingOverflow(Int64(dataChunk.data.length)),
            !bytesWithData.overflow {
            
            blePeripheral?.uartData.receivedBytes = bytesWithData.partialValue
            dataBuffer.append(dataChunk)
        }
        
        NotificationCenter.default.post(name: .uartDidReceiveData, object: nil, userInfo:["dataChunk" : dataChunk]);
    }
    
    func isReady() -> Bool {
        return txCharacteristic != nil && rxCharacteristic != nil// &&  rxCharacteristic!.isNotifying
    }
    
    func clearData() {
        dataBuffer.removeAll()
        blePeripheral?.uartData.receivedBytes = 0
        blePeripheral?.uartData.sentBytes = 0
    }
}

// MARK: - CBPeripheralDelegate
extension UartManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog(message: "UartManager: resetService because didModifyServices")
        resetService()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        guard blePeripheral != nil else {
            return
        }
        
        if uartService == nil {
            if let services = peripheral.services {
                var found = false
                var i = 0
                while (!found && i < services.count) {
                    let service = services[i]
                    if (service.uuid.uuidString .caseInsensitiveCompare(UartManager.UartServiceUUID) == .orderedSame) {
                        found = true
                        uartService = service
                        
                        peripheral.discoverCharacteristics([CBUUID(string: UartManager.RxCharacteristicUUID), CBUUID(string: UartManager.TxCharacteristicUUID)], for: service)
                    }
                    i += 1
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard blePeripheral != nil else {
            return
        }

        //DLog("uart didDiscoverCharacteristicsForService")
      if let uartService = uartService, rxCharacteristic == nil || txCharacteristic == nil {
            if rxCharacteristic == nil || txCharacteristic == nil {
                if let characteristics = uartService.characteristics {
                    var found = false
                    var i = 0
                    while !found && i < characteristics.count {
                        let characteristic = characteristics[i]
                        if characteristic.uuid.uuidString .caseInsensitiveCompare(UartManager.RxCharacteristicUUID) == .orderedSame {
                            rxCharacteristic = characteristic
                        }
                        else if characteristic.uuid.uuidString .caseInsensitiveCompare(UartManager.TxCharacteristicUUID) == .orderedSame {
                            txCharacteristic = characteristic
                            txWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse:.withResponse
                            DLog(message: "Uart: detected txWriteType: \(txWriteType.rawValue)")
                        }
                        found = rxCharacteristic != nil && txCharacteristic != nil
                        i += 1
                    }
                }
            }
            
            // Check if characteristics are ready
            if (rxCharacteristic != nil && txCharacteristic != nil) {
                // Set rx enabled
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                
                // Send notification that uart is ready
                NotificationCenter.default.post(name: .uartDidBecomeReady, object: nil, userInfo:nil)
                
                DLog(message: "Uart: did become ready")

            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        guard blePeripheral != nil else {
            return
        }

        DLog(message: "didUpdateNotificationStateForCharacteristic")
        /*
        if characteristic == rxCharacteristic {
            if error != nil {
                 DLog("Uart RX isNotifying error: \(error)")
            }
            else {
                if characteristic.isNotifying {
                    DLog("Uart RX isNotifying: true")
                    
                    // Send notification that uart is ready
                    NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidBecomeReady.rawValue, object: nil, userInfo:nil)
                }
                else {
                    DLog("Uart RX isNotifying: false")
                }
            }
        }
*/
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard blePeripheral != nil else {
            return
        }

        
        if characteristic == rxCharacteristic && characteristic.service == uartService {
            
            if let characteristicDataValue = characteristic.value {
                receivedData(data: characteristicDataValue as NSData)
            }
        }
    }
}

// MARK: - extension Notification.Name
extension Notification.Name {
    static let uartDidSendData = Notification.Name("uartDidSendData")
    static let uartDidReceiveData = Notification.Name("uartDidReceiveData")
    static let uartDidBecomeReady = Notification.Name("uartDidBecomeReady")
}
